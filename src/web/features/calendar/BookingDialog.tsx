import { useMemo, useState } from 'react';
import { useMutation, useQuery } from 'urql';
import { Dialog, useToast } from '../../components/overlays';
import { Banner, Button, Field } from '../../components/ui';
import {
  CancelBookingMutation,
  CreateBookingMutation,
  PeopleQuery,
  RescheduleBookingMutation,
  SetBookingStatusMutation,
  UpdateProfileMutation,
} from '../../graphql/operations';
import type { BookingParts } from '../../graphql/operations';
import type { ResultOf } from '../../graphql/tada';
import { issuesByField, readFailure, summarize } from '../../lib/errors';
import type { ApiFailure } from '../../lib/errors';
import {
  formatClock,
  formatDay,
  formatDuration,
  minuteOfDayInZone,
  dayKeyInZone,
  zonedToUtc,
} from '../../lib/time';
import { useWorkspace } from '../auth/session';
import { earliestStart, freeStarts, lengthsFrom, placeBookings } from './calendar-model';
import type { RoomHours } from './calendar-model';

export type Booking = ResultOf<typeof BookingParts>;

export interface Room extends RoomHours {
  name: string;
}

/** What the dialog was opened for: a new booking in a slot, or an existing one. */
export type DialogTarget =
  | { kind: 'new'; roomId: string; day: string; startMinute: number | null }
  | { kind: 'existing'; booking: Booking };

interface BookingDialogProps {
  target: DialogTarget | null;
  rooms: readonly Room[];
  /** The bookings already loaded (the visible week), used to offer only free slots. */
  bookings: readonly Booking[];
  now: Date;
  onClose: () => void;
  onChanged: () => void;
}

export function BookingDialog({ target, ...rest }: BookingDialogProps) {
  const title =
    target === null ? '' : target.kind === 'new' ? 'Book a room' : 'Manage this booking';
  return (
    <Dialog open={target !== null} title={title} onClose={rest.onClose}>
      {target ? <BookingForm key={dialogKey(target)} target={target} {...rest} /> : null}
    </Dialog>
  );
}

const dialogKey = (target: DialogTarget): string =>
  target.kind === 'new'
    ? `new-${target.roomId}-${target.day}-${String(target.startMinute)}`
    : `existing-${target.booking.id}-${String(target.booking.lockVersion)}`;

function BookingForm({
  target,
  rooms,
  bookings,
  now,
  onClose,
  onChanged,
}: BookingDialogProps & { target: DialogTarget }) {
  const workspace = useWorkspace();
  const toast = useToast();
  const existing = target.kind === 'existing' ? target.booking : null;
  const { timeZone } = workspace;

  const [roomId, setRoomId] = useState(
    existing?.room.id ?? (target.kind === 'new' ? target.roomId : ''),
  );
  const [day, setDay] = useState(
    existing
      ? dayKeyInZone(new Date(existing.startsAt), timeZone)
      : target.kind === 'new'
        ? target.day
        : '',
  );
  const [start, setStart] = useState<number | null>(
    existing
      ? minuteOfDayInZone(new Date(existing.startsAt), timeZone)
      : target.kind === 'new'
        ? target.startMinute
        : null,
  );
  const [length, setLength] = useState(
    existing
      ? Math.round((Date.parse(existing.endsAt) - Date.parse(existing.startsAt)) / 60_000)
      : 60,
  );
  const [personId, setPersonId] = useState(workspace.membershipId);
  const [note, setNote] = useState('');
  const [notify, setNotify] = useState(true);
  const [reason, setReason] = useState('');
  const [cancelling, setCancelling] = useState(false);
  const [instrument, setInstrument] = useState('');
  const [phone, setPhone] = useState('');
  const [failure, setFailure] = useState<ApiFailure | null>(null);
  const [busy, setBusy] = useState(false);

  const [{ data: peopleData }] = useQuery({ query: PeopleQuery, pause: !workspace.isStaff });
  const [, createBooking] = useMutation(CreateBookingMutation);
  const [, reschedule] = useMutation(RescheduleBookingMutation);
  const [, cancelBooking] = useMutation(CancelBookingMutation);
  const [, setStatus] = useMutation(SetBookingStatusMutation);
  const [, updateProfile] = useMutation(UpdateProfileMutation);

  const room = rooms.find((item) => item.id === roomId) ?? rooms[0];
  const placed = useMemo(
    () =>
      placeBookings(
        bookings.map((item) => ({ ...item, roomId: item.room.id })),
        day,
        timeZone,
      ),
    [bookings, day, timeZone],
  );
  if (!room) return <p className="muted">This school has no rooms yet.</p>;

  const taken = placed.get(room.id) ?? [];
  const starts = freeStarts(room, taken, {
    earliest: workspace.isStaff ? 0 : earliestStart(day, now, timeZone),
    ignoreId: existing?.id,
  });
  const chosenStart = start !== null && starts.includes(start) ? start : (starts[0] ?? null);
  const lengths = chosenStart === null ? [] : lengthsFrom(room, taken, chosenStart, existing?.id);
  const chosenLength = lengths.includes(length) ? length : (lengths.at(-1) ?? 0);
  const issues = issuesByField(failure?.issues ?? []);
  const needsProfile = failure?.code === 'PROFILE_INCOMPLETE';
  const forSomeoneElse = existing ? !existing.isMine : personId !== workspace.membershipId;
  const readOnly = existing !== null && !existing.canReschedule;

  const finish = (message: string): void => {
    toast(message);
    onChanged();
    onClose();
  };

  /** Runs one API call, keeping the busy state and the failure display in one place. */
  const attempt = async (
    call: () => Promise<{ error?: Parameters<typeof readFailure>[0] }>,
    done: string,
  ): Promise<void> => {
    setBusy(true);
    setFailure(null);
    const result = await call();
    setBusy(false);
    const problem = readFailure(result.error);
    if (problem) {
      setFailure(problem);
      // The data on screen was stale: fetch what is true now.
      if (problem.code === 'CONFLICT') onChanged();
      return;
    }
    finish(done);
  };

  const save = async (event: { preventDefault(): void }): Promise<void> => {
    event.preventDefault();
    if (chosenStart === null || chosenLength === 0) return;
    const times = {
      roomId: room.id,
      startsAt: zonedToUtc(day, chosenStart, timeZone).toISOString(),
      endsAt: zonedToUtc(day, chosenStart + chosenLength, timeZone).toISOString(),
    };

    if (needsProfile) {
      setBusy(true);
      const saved = await updateProfile({ instrument, phone });
      setBusy(false);
      const problem = readFailure(saved.error);
      if (problem) {
        setFailure({ ...problem, code: 'PROFILE_INCOMPLETE' });
        return;
      }
    }

    if (existing) {
      await attempt(
        () =>
          reschedule({
            bookingId: existing.id,
            lockVersion: existing.lockVersion,
            notify,
            ...times,
          }),
        'Booking changed',
      );
    } else {
      await attempt(
        () =>
          createBooking({
            ...times,
            note: note.trim() === '' ? null : note,
            membershipId: workspace.isStaff ? personId : null,
            notify,
          }),
        'Room booked',
      );
    }
  };

  return (
    <form
      className="stack"
      onSubmit={(event) => {
        void save(event);
      }}
    >
      {/* Problems tied to one input are shown at that input, not repeated here. */}
      {failure && failure.issues.length === 0 ? (
        <Banner tone="danger" role="alert">
          {summarize(failure)}
        </Banner>
      ) : null}

      {existing ? (
        <dl className="definition small">
          <dt>For</dt>
          <dd>{existing.personName ?? 'Someone else'}</dd>
          <dt>Status</dt>
          <dd>{existing.statusLabel}</dd>
          {existing.note ? (
            <>
              <dt>Note</dt>
              <dd>{existing.note}</dd>
            </>
          ) : null}
        </dl>
      ) : null}

      <Field label="Room">
        {(control) => (
          <select
            {...control}
            className="select"
            disabled={readOnly}
            value={room.id}
            onChange={(event) => {
              setRoomId(event.target.value);
            }}
          >
            {rooms.map((item) => (
              <option key={item.id} value={item.id}>
                {item.name}
              </option>
            ))}
          </select>
        )}
      </Field>
      <Field label="Day" hint={day ? formatDay(day) : null}>
        {(control) => (
          <input
            {...control}
            className="input"
            type="date"
            required
            disabled={readOnly}
            value={day}
            onChange={(event) => {
              setDay(event.target.value);
            }}
          />
        )}
      </Field>
      <div className="row">
        <div className="grow">
          <Field
            label="Start"
            errors={
              issues.get('startsAt') ??
              (starts.length === 0 ? ['Nothing is free on this day.'] : [])
            }
          >
            {(control) => (
              <select
                {...control}
                className="select"
                disabled={readOnly || starts.length === 0}
                value={chosenStart ?? ''}
                onChange={(event) => {
                  setStart(Number(event.target.value));
                }}
              >
                {starts.map((minute) => (
                  <option key={minute} value={minute}>
                    {formatClock(minute)}
                  </option>
                ))}
              </select>
            )}
          </Field>
        </div>
        <div className="grow">
          <Field label="Length" errors={issues.get('endsAt') ?? []}>
            {(control) => (
              <select
                {...control}
                className="select"
                disabled={readOnly || lengths.length === 0}
                value={chosenLength}
                onChange={(event) => {
                  setLength(Number(event.target.value));
                }}
              >
                {lengths.map((minutes) => (
                  <option key={minutes} value={minutes}>
                    {formatDuration(minutes)}
                  </option>
                ))}
              </select>
            )}
          </Field>
        </div>
      </div>

      {!existing && workspace.isStaff ? (
        <Field label="For">
          {(control) => (
            <select
              {...control}
              className="select"
              value={personId}
              onChange={(event) => {
                setPersonId(event.target.value);
              }}
            >
              {(peopleData?.workspace.people ?? []).map((person) => (
                <option key={person.id} value={person.id}>
                  {person.name}
                  {person.id === workspace.membershipId ? ' (you)' : ''}
                </option>
              ))}
            </select>
          )}
        </Field>
      ) : null}
      {!existing ? (
        <Field label="Note (optional)" hint="Only you and the staff can read it.">
          {(control) => (
            <input
              {...control}
              className="input"
              maxLength={200}
              value={note}
              onChange={(event) => {
                setNote(event.target.value);
              }}
            />
          )}
        </Field>
      ) : null}
      {workspace.isStaff && forSomeoneElse ? (
        <label className="check">
          <input
            type="checkbox"
            checked={notify}
            onChange={(event) => {
              setNotify(event.target.checked);
            }}
          />
          <span>Tell the person by email</span>
        </label>
      ) : null}

      {needsProfile ? (
        <fieldset className="card stack">
          <legend className="eyebrow">Before your first booking</legend>
          <p className="small muted">
            We ask for these two details once and keep them for next time.
          </p>
          <Field label="Your instrument" errors={issues.get('instrument') ?? []}>
            {(control) => (
              <input
                {...control}
                className="input"
                maxLength={60}
                value={instrument}
                onChange={(event) => {
                  setInstrument(event.target.value);
                }}
              />
            )}
          </Field>
          <Field label="A phone number" errors={issues.get('phone') ?? []}>
            {(control) => (
              <input
                {...control}
                className="input"
                type="tel"
                maxLength={30}
                value={phone}
                onChange={(event) => {
                  setPhone(event.target.value);
                }}
              />
            )}
          </Field>
        </fieldset>
      ) : null}

      {cancelling && existing ? (
        <fieldset className="card stack">
          <legend className="eyebrow">Cancel this booking</legend>
          <Field
            label={forSomeoneElse ? 'Reason (the person will see it)' : 'Reason (optional)'}
            errors={issues.get('reason') ?? []}
          >
            {(control) => (
              <input
                {...control}
                className="input"
                maxLength={200}
                value={reason}
                onChange={(event) => {
                  setReason(event.target.value);
                }}
              />
            )}
          </Field>
          <div className="row row--end">
            <Button
              onClick={() => {
                setCancelling(false);
              }}
            >
              Keep the booking
            </Button>
            <Button
              variant="danger"
              busy={busy}
              onClick={() => {
                void attempt(
                  () => cancelBooking({ bookingId: existing.id, reason, notify }),
                  'Booking cancelled',
                );
              }}
            >
              Cancel booking
            </Button>
          </div>
        </fieldset>
      ) : (
        <div className="row row--end">
          {existing?.canCheckIn ? (
            <Button
              busy={busy}
              onClick={() => {
                void attempt(
                  () => setStatus({ bookingId: existing.id, status: 'CHECKED_IN' }),
                  'Checked in',
                );
              }}
            >
              Check in
            </Button>
          ) : null}
          {existing?.canMarkMissed ? (
            <Button
              busy={busy}
              onClick={() => {
                void attempt(
                  () => setStatus({ bookingId: existing.id, status: 'MISSED' }),
                  'Marked as not attended',
                );
              }}
            >
              Did not attend
            </Button>
          ) : null}
          {existing?.canCancel ? (
            <Button
              variant="danger"
              onClick={() => {
                setCancelling(true);
              }}
            >
              Cancel booking…
            </Button>
          ) : null}
          <Button onClick={onClose}>Close</Button>
          {readOnly ? null : (
            <Button
              type="submit"
              variant="primary"
              busy={busy}
              disabled={chosenStart === null || chosenLength === 0}
            >
              {existing ? 'Save changes' : needsProfile ? 'Save details and book' : 'Book room'}
            </Button>
          )}
        </div>
      )}
    </form>
  );
}
