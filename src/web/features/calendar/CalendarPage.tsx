import { useMemo, useState } from 'react';
import { ChevronLeft, ChevronRight, Plus } from 'lucide-react';
import { useSearchParams } from 'react-router';
import { useQuery } from 'urql';
import { StatusBadge } from '../../components/StatusBadge';
import { Button, EmptyState, ErrorState, Skeleton } from '../../components/ui';
import { CalendarQuery } from '../../graphql/operations';
import { readFailure } from '../../lib/errors';
import { useMediaQuery, useNow } from '../../lib/hooks';
import {
  addDays,
  dayKeyInZone,
  dayOfMonth,
  formatClock,
  formatDay,
  formatWeekday,
  weekOf,
  zonedToUtc,
} from '../../lib/time';
import { useWorkspace } from '../auth/session';
import { BookingDialog } from './BookingDialog';
import type { Booking, DialogTarget, Room } from './BookingDialog';
import {
  SLOT_MINUTES,
  earliestStart,
  freeStarts,
  gridHours,
  placeBookings,
  slotStarts,
} from './calendar-model';
import type { Placed } from './calendar-model';

const DAY_KEY = /^\d{4}-\d{2}-\d{2}$/;

type PlacedBooking = Placed<Booking & { roomId: string }>;

export function CalendarPage() {
  const workspace = useWorkspace();
  const { timeZone } = workspace;
  const now = useNow();
  const narrow = useMediaQuery('(max-width: 760px)');
  const [params, setParams] = useSearchParams();
  const today = dayKeyInZone(now, timeZone);
  const requested = params.get('day');
  const day = requested && DAY_KEY.test(requested) ? requested : today;
  const [target, setTarget] = useState<DialogTarget | null>(null);

  const week = useMemo(() => weekOf(day), [day]);
  const variables = useMemo(
    () => ({
      from: zonedToUtc(week[0] ?? day, 0, timeZone).toISOString(),
      to: zonedToUtc(addDays(week[6] ?? day, 1), 0, timeZone).toISOString(),
    }),
    [week, day, timeZone],
  );
  const [{ data, fetching, error }, refetch] = useQuery({ query: CalendarQuery, variables });

  const rooms: Room[] = data?.workspace.rooms ?? [];
  const bookings = useMemo(() => data?.workspace.bookings ?? [], [data]);
  const placed = useMemo(
    () =>
      placeBookings(
        bookings.map((item) => ({ ...item, roomId: item.room.id })),
        day,
        timeZone,
      ),
    [bookings, day, timeZone],
  );

  const goTo = (next: string): void => {
    setParams(next === today ? {} : { day: next });
  };

  if (fetching && !data) return <Skeleton lines={8} label="Loading the calendar" />;
  if (error && !data) {
    return (
      <ErrorState
        message={readFailure(error)?.message ?? 'Please try again.'}
        onRetry={() => {
          refetch({ requestPolicy: 'network-only' });
        }}
      />
    );
  }

  const earliest = workspace.isStaff ? 0 : earliestStart(day, now, timeZone);
  const firstRoom = rooms[0];

  return (
    <div className="stack stack--loose">
      <div className="row row--between">
        <div className="stack stack--tight">
          <h1>{formatDay(day)}</h1>
          <p className="muted">
            {workspace.name} · times are shown in {timeZone.replace('_', ' ')}
          </p>
        </div>
        <div className="row">
          <Button
            iconOnly
            aria-label="Previous day"
            onClick={() => {
              goTo(addDays(day, -1));
            }}
          >
            <ChevronLeft aria-hidden="true" />
          </Button>
          <Button
            disabled={day === today}
            onClick={() => {
              goTo(today);
            }}
          >
            Today
          </Button>
          <Button
            iconOnly
            aria-label="Next day"
            onClick={() => {
              goTo(addDays(day, 1));
            }}
          >
            <ChevronRight aria-hidden="true" />
          </Button>
          {firstRoom ? (
            <Button
              variant="primary"
              onClick={() => {
                setTarget({ kind: 'new', roomId: firstRoom.id, day, startMinute: null });
              }}
            >
              <Plus aria-hidden="true" />
              Book a room
            </Button>
          ) : null}
        </div>
      </div>

      <div className="day-strip" role="group" aria-label="Days of this week">
        {week.map((item) => (
          <button
            key={item}
            type="button"
            className="day-strip__day"
            aria-pressed={item === day}
            aria-label={formatDay(item)}
            onClick={() => {
              goTo(item);
            }}
          >
            <span>{formatWeekday(item)}</span>
            <strong>{dayOfMonth(item)}</strong>
          </button>
        ))}
      </div>

      {rooms.length === 0 ? (
        <div className="card">
          <EmptyState title="No rooms yet">This school has not set up any rooms.</EmptyState>
        </div>
      ) : narrow ? (
        <Agenda rooms={rooms} placed={placed} onOpen={setTarget} />
      ) : (
        <DayGrid rooms={rooms} placed={placed} day={day} earliest={earliest} onOpen={setTarget} />
      )}

      <BookingDialog
        target={target}
        rooms={rooms}
        bookings={bookings}
        now={now}
        onClose={() => {
          setTarget(null);
        }}
        onChanged={() => {
          refetch({ requestPolicy: 'network-only' });
        }}
      />
    </div>
  );
}

interface ViewProps {
  rooms: readonly Room[];
  placed: ReadonlyMap<string, PlacedBooking[]>;
  onOpen: (target: DialogTarget) => void;
}

/** Whether the viewer may open this booking: their own, or any booking for staff. */
function canOpen(booking: Booking): boolean {
  return booking.isMine || booking.personName !== null;
}

function BookingSummary({ booking }: { booking: Booking }) {
  return (
    <>
      <strong>{booking.personName ?? 'Taken'}</strong>
      <span>
        <StatusBadge status={booking.status} label={booking.statusLabel} />
      </span>
    </>
  );
}

/**
 * The desktop view: one column per room, one row per half hour. Free slots are
 * buttons, so the whole grid can be used from the keyboard; the "Book a room"
 * button above is the short way for the same task.
 */
function DayGrid({
  rooms,
  placed,
  day,
  earliest,
  onOpen,
}: ViewProps & { day: string; earliest: number }) {
  const hours = gridHours(rooms);
  const slots = slotStarts(hours.from, hours.to);
  const rowOf = (minute: number): number => (minute - hours.from) / SLOT_MINUTES + 3;

  return (
    <div
      className="calendar"
      style={{ '--calendar-rooms': rooms.length } as React.CSSProperties}
      data-testid="day-grid"
    >
      <div className="calendar__corner" style={{ gridColumn: 1, gridRow: '1 / span 2' }} />
      {rooms.map((room, index) => (
        <div
          key={room.id}
          className="calendar__room"
          style={{ gridColumn: index + 2, gridRow: '1 / span 2' }}
        >
          {room.name}
          <span className="muted small">
            {formatClock(room.opensMinute)} to {formatClock(room.closesMinute)}
          </span>
        </div>
      ))}

      {slots.map((minute) => (
        <div
          key={minute}
          className={minute % 60 === 0 ? 'calendar__time' : 'calendar__time calendar__time--half'}
          style={{ gridColumn: 1, gridRow: rowOf(minute) }}
        >
          {minute % 60 === 0 ? formatClock(minute) : ''}
        </div>
      ))}

      {rooms.map((room, index) => {
        const taken = placed.get(room.id) ?? [];
        const free = new Set(freeStarts(room, taken, { earliest }));
        const covered = new Set(
          taken.flatMap((item) => slotStarts(item.startMinute, item.endMinute)),
        );
        return [
          ...slots
            .filter((minute) => !covered.has(minute))
            .map((minute) =>
              free.has(minute) ? (
                <button
                  key={`${room.id}-${String(minute)}`}
                  type="button"
                  className="calendar__slot"
                  style={{ gridColumn: index + 2, gridRow: rowOf(minute) }}
                  aria-label={`Book ${room.name} at ${formatClock(minute)}`}
                  onClick={() => {
                    onOpen({ kind: 'new', roomId: room.id, day, startMinute: minute });
                  }}
                >
                  {formatClock(minute)}
                </button>
              ) : (
                <div
                  key={`${room.id}-${String(minute)}`}
                  className="calendar__slot calendar__slot--closed"
                  style={{ gridColumn: index + 2, gridRow: rowOf(minute) }}
                  aria-hidden="true"
                />
              ),
            ),
          ...taken.map(({ booking, startMinute, endMinute }) => {
            const style = {
              gridColumn: index + 2,
              gridRow: `${String(rowOf(startMinute))} / ${String(rowOf(endMinute))}`,
            };
            const classes = [
              'calendar__booking',
              booking.isMine ? 'calendar__booking--mine' : '',
              `calendar__booking--${booking.status.toLowerCase()}`,
            ].join(' ');
            const label = `${room.name}, ${formatClock(startMinute)} to ${formatClock(endMinute)}, ${
              booking.personName ?? 'taken'
            }`;
            return canOpen(booking) ? (
              <button
                key={booking.id}
                type="button"
                className={classes}
                style={style}
                aria-label={label}
                onClick={() => {
                  onOpen({ kind: 'existing', booking });
                }}
              >
                <BookingSummary booking={booking} />
              </button>
            ) : (
              <div key={booking.id} className={classes} style={style} aria-label={label} role="img">
                <BookingSummary booking={booking} />
              </div>
            );
          }),
        ];
      })}
    </div>
  );
}

/** The phone view: the day's bookings as a list per room. */
function Agenda({ rooms, placed, onOpen }: ViewProps) {
  return (
    <div className="stack" data-testid="agenda">
      {rooms.map((room) => {
        const taken = placed.get(room.id) ?? [];
        return (
          <section key={room.id} className="card card--flush" aria-label={room.name}>
            <div className="list__item">
              <strong className="grow">{room.name}</strong>
              <span className="small muted">
                {formatClock(room.opensMinute)} to {formatClock(room.closesMinute)}
              </span>
            </div>
            <ul className="list">
              {taken.length === 0 ? (
                <li className="list__item muted small">Free all day</li>
              ) : (
                taken.map(({ booking, startMinute, endMinute }) => (
                  <li key={booking.id} className="list__item">
                    <span className="mono small">
                      {formatClock(startMinute)} to {formatClock(endMinute)}
                    </span>
                    <span className="grow">{booking.personName ?? 'Taken'}</span>
                    <StatusBadge status={booking.status} label={booking.statusLabel} />
                    {canOpen(booking) ? (
                      <Button
                        onClick={() => {
                          onOpen({ kind: 'existing', booking });
                        }}
                      >
                        Manage
                      </Button>
                    ) : null}
                  </li>
                ))
              )}
            </ul>
          </section>
        );
      })}
    </div>
  );
}
