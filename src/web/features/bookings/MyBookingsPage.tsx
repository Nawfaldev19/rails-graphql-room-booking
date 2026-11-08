import { useState } from 'react';
import { CalendarPlus } from 'lucide-react';
import { Link } from 'react-router';
import { useMutation, useQuery } from 'urql';
import { StatusBadge } from '../../components/StatusBadge';
import { Dialog, useToast } from '../../components/overlays';
import { Banner, Button, EmptyState, ErrorState, Skeleton } from '../../components/ui';
import { CancelBookingMutation, MyBookingsQuery } from '../../graphql/operations';
import { readFailure, summarize } from '../../lib/errors';
import { downloadText } from '../../lib/hooks';
import { dayKeyInZone, formatClock, formatDay, minuteOfDayInZone } from '../../lib/time';
import { useWorkspace } from '../auth/session';

export function MyBookingsPage() {
  const workspace = useWorkspace();
  const toast = useToast();
  const [{ data, fetching, error }, refetch] = useQuery({ query: MyBookingsQuery });
  const [cancelling, cancelBooking] = useMutation(CancelBookingMutation);
  const [confirming, setConfirming] = useState<string | null>(null);
  const [failure, setFailure] = useState<string | null>(null);

  if (fetching && !data) return <Skeleton lines={6} label="Loading your bookings" />;
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

  const bookings = data?.workspace.myBookings ?? [];
  const { timeZone } = workspace;

  const cancel = async (bookingId: string): Promise<void> => {
    setFailure(null);
    const result = await cancelBooking({ bookingId });
    setConfirming(null);
    const problem = readFailure(result.error);
    if (problem) {
      setFailure(summarize(problem));
      return;
    }
    toast('Booking cancelled');
    refetch({ requestPolicy: 'network-only' });
  };

  return (
    <div className="stack stack--loose">
      <div className="stack stack--tight">
        <h1>My bookings</h1>
        <p className="muted">Your bookings at {workspace.name}, from the last week onward.</p>
      </div>
      {failure ? (
        <Banner tone="danger" role="alert">
          {failure}
        </Banner>
      ) : null}

      <div className="card card--flush">
        {bookings.length === 0 ? (
          <EmptyState
            title="Nothing booked"
            action={
              <Link className="button button--primary" to={`/w/${workspace.id}/calendar`}>
                Open the calendar
              </Link>
            }
          >
            Pick a free slot in the calendar to book a room.
          </EmptyState>
        ) : (
          <ul className="list" aria-label="My bookings">
            {bookings.map((booking) => {
              const start = new Date(booking.startsAt);
              const day = dayKeyInZone(start, timeZone);
              return (
                <li key={booking.id} className="list__item">
                  <div className="grow stack stack--tight">
                    <Link className="list__link" to={`/w/${workspace.id}/calendar?day=${day}`}>
                      {formatDay(day)}, {formatClock(minuteOfDayInZone(start, timeZone))} to{' '}
                      {formatClock(minuteOfDayInZone(new Date(booking.endsAt), timeZone) || 1440)}
                    </Link>
                    <span className="small muted">
                      {booking.room.name}
                      {booking.cancelReason ? ` · Reason: ${booking.cancelReason}` : ''}
                    </span>
                  </div>
                  <div className="row">
                    <StatusBadge status={booking.status} label={booking.statusLabel} />
                    {booking.calendarFile ? (
                      <Button
                        aria-label={`Download the calendar file for ${formatDay(day)}`}
                        onClick={() => {
                          downloadText(
                            `booking-${booking.id}.ics`,
                            'text/calendar',
                            booking.calendarFile ?? '',
                          );
                        }}
                      >
                        <CalendarPlus aria-hidden="true" />
                        Calendar file
                      </Button>
                    ) : null}
                    {booking.canCancel ? (
                      <Button
                        variant="danger"
                        onClick={() => {
                          setConfirming(booking.id);
                        }}
                      >
                        Cancel
                      </Button>
                    ) : null}
                  </div>
                </li>
              );
            })}
          </ul>
        )}
      </div>

      <Dialog
        open={confirming !== null}
        title="Cancel this booking?"
        onClose={() => {
          setConfirming(null);
        }}
      >
        <p>The room becomes free for others straight away. You will get a message to confirm it.</p>
        <div className="row row--end">
          <Button
            onClick={() => {
              setConfirming(null);
            }}
          >
            Keep it
          </Button>
          <Button
            variant="danger"
            busy={cancelling.fetching}
            onClick={() => {
              if (confirming) void cancel(confirming);
            }}
          >
            Cancel booking
          </Button>
        </div>
      </Dialog>
    </div>
  );
}
