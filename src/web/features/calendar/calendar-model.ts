import { dayKeyInZone, minuteOfDayInZone } from '../../lib/time';

/**
 * The arithmetic behind the day view: where a booking sits on the grid, which
 * half-hour slots are free, and which lengths fit. Pure functions over plain
 * values, so the rules are tested without rendering anything.
 */

export const SLOT_MINUTES = 30;
export const MIN_MINUTES = 30;
export const MAX_MINUTES = 180;

export interface RoomHours {
  id: string;
  opensMinute: number;
  closesMinute: number;
}

export interface BookingSpan {
  id: string;
  roomId: string;
  startsAt: string;
  endsAt: string;
}

/** A booking's position within one day, in minutes after local midnight. */
export interface Placed<Booking> {
  booking: Booking;
  startMinute: number;
  endMinute: number;
}

/** The earliest opening and the latest closing over all rooms: the grid's height. */
export function gridHours(rooms: readonly RoomHours[]): { from: number; to: number } {
  if (rooms.length === 0) return { from: 8 * 60, to: 20 * 60 };
  return {
    from: Math.min(...rooms.map((room) => room.opensMinute)),
    to: Math.max(...rooms.map((room) => room.closesMinute)),
  };
}

export function slotStarts(from: number, to: number): number[] {
  const starts: number[] = [];
  for (let minute = from; minute < to; minute += SLOT_MINUTES) starts.push(minute);
  return starts;
}

/** Places the bookings of one day per room, in the school's time zone. */
export function placeBookings<Booking extends BookingSpan>(
  bookings: readonly Booking[],
  day: string,
  timeZone: string,
): Map<string, Placed<Booking>[]> {
  const byRoom = new Map<string, Placed<Booking>[]>();
  for (const booking of bookings) {
    const start = new Date(booking.startsAt);
    const end = new Date(booking.endsAt);
    if (dayKeyInZone(start, timeZone) !== day) continue;
    const startMinute = minuteOfDayInZone(start, timeZone);
    // A booking that ends at midnight ends at minute 1440 of the day it began.
    const endMinute =
      dayKeyInZone(end, timeZone) === day ? minuteOfDayInZone(end, timeZone) : 24 * 60;
    const list = byRoom.get(booking.roomId) ?? [];
    list.push({ booking, startMinute, endMinute });
    byRoom.set(booking.roomId, list);
  }
  for (const list of byRoom.values()) list.sort((a, b) => a.startMinute - b.startMinute);
  return byRoom;
}

function isTaken(
  placed: readonly Placed<unknown>[],
  from: number,
  to: number,
  ignoreId?: string,
): boolean {
  return placed.some(
    (item) =>
      (item.booking as BookingSpan).id !== ignoreId &&
      item.startMinute < to &&
      item.endMinute > from,
  );
}

/**
 * Slot starts in a room that can begin a booking: inside opening hours, not
 * taken, and (unless staff are booking) not already in the past.
 */
export function freeStarts(
  room: RoomHours,
  placed: readonly Placed<unknown>[],
  options: { earliest?: number; ignoreId?: string } = {},
): number[] {
  const earliest = options.earliest ?? 0;
  return slotStarts(room.opensMinute, room.closesMinute).filter(
    (start) => start >= earliest && !isTaken(placed, start, start + SLOT_MINUTES, options.ignoreId),
  );
}

/** Booking lengths that fit from a start: up to closing time or the next booking. */
export function lengthsFrom(
  room: RoomHours,
  placed: readonly Placed<unknown>[],
  start: number,
  ignoreId?: string,
): number[] {
  const lengths: number[] = [];
  for (let length = MIN_MINUTES; length <= MAX_MINUTES; length += SLOT_MINUTES) {
    const end = start + length;
    if (end > room.closesMinute || isTaken(placed, start, end, ignoreId)) break;
    lengths.push(length);
  }
  return lengths;
}

/** The first slot that has not started yet, for "today"; zero for later days. */
export function earliestStart(day: string, now: Date, timeZone: string): number {
  const today = dayKeyInZone(now, timeZone);
  if (day > today) return 0;
  if (day < today) return Number.POSITIVE_INFINITY;
  return Math.ceil(minuteOfDayInZone(now, timeZone) / SLOT_MINUTES) * SLOT_MINUTES;
}
