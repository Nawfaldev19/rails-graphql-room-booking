import { Badge } from './ui';

export type BookingStatus = 'BOOKED' | 'CHECKED_IN' | 'CANCELLED' | 'MISSED';

const TONES = {
  BOOKED: 'primary',
  CHECKED_IN: 'success',
  CANCELLED: 'neutral',
  MISSED: 'danger',
} as const satisfies Record<BookingStatus, string>;

/**
 * Shows a booking's status in the school's own words. The label comes from the
 * API, because each school may rename statuses; the colour follows the status.
 */
export function StatusBadge({ status, label }: { status: BookingStatus; label: string }) {
  return <Badge tone={TONES[status]}>{label}</Badge>;
}
