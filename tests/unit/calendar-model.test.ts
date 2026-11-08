import { describe, expect, it } from 'vitest';
import {
  earliestStart,
  freeStarts,
  gridHours,
  lengthsFrom,
  placeBookings,
  slotStarts,
} from '../../src/web/features/calendar/calendar-model';
import type { BookingSpan } from '../../src/web/features/calendar/calendar-model';

const LISBON = 'Europe/Lisbon';
const DAY = '2025-03-03';
const room = { id: 'r1', opensMinute: 8 * 60, closesMinute: 22 * 60 };

const booking = (id: string, from: string, to: string, roomId = 'r1'): BookingSpan => ({
  id,
  roomId,
  startsAt: `${from}:00Z`,
  endsAt: `${to}:00Z`,
});

const placedIn = (bookings: BookingSpan[], roomId = 'r1') =>
  placeBookings(bookings, DAY, LISBON).get(roomId) ?? [];

describe('the grid', () => {
  it('spans from the earliest opening to the latest closing', () => {
    expect(
      gridHours([
        room,
        { id: 'r2', opensMinute: 10 * 60, closesMinute: 23 * 60 },
        { id: 'r3', opensMinute: 7 * 60, closesMinute: 12 * 60 },
      ]),
    ).toEqual({ from: 7 * 60, to: 23 * 60 });
  });

  it('falls back to a working day when there are no rooms', () => {
    expect(gridHours([])).toEqual({ from: 480, to: 1200 });
  });

  it('has one slot per half hour, ending before the closing time', () => {
    expect(slotStarts(480, 600)).toEqual([480, 510, 540, 570]);
    expect(slotStarts(600, 600)).toEqual([]);
  });
});

describe('placeBookings', () => {
  it('places a day’s bookings per room, in order, in the school’s time', () => {
    const placed = placeBookings(
      [
        booking('late', '2025-03-03T16:00', '2025-03-03T17:30'),
        booking('early', '2025-03-03T09:00', '2025-03-03T10:00'),
        booking('other-room', '2025-03-03T09:00', '2025-03-03T10:00', 'r2'),
        booking('other-day', '2025-03-04T09:00', '2025-03-04T10:00'),
      ],
      DAY,
      LISBON,
    );
    expect(
      placed.get('r1')?.map((item) => [item.booking.id, item.startMinute, item.endMinute]),
    ).toEqual([
      ['early', 540, 600],
      ['late', 960, 1050],
    ]);
    expect(placed.get('r2')).toHaveLength(1);
  });

  it('uses the school’s zone to decide which day a booking is on', () => {
    // 23:30 UTC on 2 July is already 00:30 on 3 July in Lisbon (summer time).
    const summer = booking('s', '2025-07-02T23:30', '2025-07-03T00:30');
    expect(placeBookings([summer], '2025-07-03', LISBON).get('r1')?.[0]).toMatchObject({
      startMinute: 30,
      endMinute: 90,
    });
    expect(placeBookings([summer], '2025-07-02', LISBON).size).toBe(0);
  });

  it('ends a booking that runs to midnight at minute 1440', () => {
    const late = booking('l', '2025-03-03T22:00', '2025-03-04T00:00');
    expect(placedIn([late])[0]).toMatchObject({ startMinute: 1320, endMinute: 1440 });
  });
});

describe('freeStarts', () => {
  const taken = placedIn([booking('a', '2025-03-03T09:00', '2025-03-03T10:30')]);

  it('offers every slot inside opening hours that no booking covers', () => {
    const starts = freeStarts(room, taken);
    expect(starts[0]).toBe(480);
    expect(starts).toContain(510);
    expect(starts).not.toContain(540);
    expect(starts).not.toContain(600);
    expect(starts).toContain(630);
    expect(starts.at(-1)).toBe(21 * 60 + 30);
  });

  it('leaves out slots before the earliest allowed start', () => {
    expect(freeStarts(room, taken, { earliest: 14 * 60 })[0]).toBe(14 * 60);
    expect(freeStarts(room, taken, { earliest: Number.POSITIVE_INFINITY })).toEqual([]);
  });

  it('treats the booking being moved as free', () => {
    expect(freeStarts(room, taken, { ignoreId: 'a' })).toContain(540);
  });
});

describe('lengthsFrom', () => {
  it('offers thirty minutes to three hours in an empty room', () => {
    expect(lengthsFrom(room, [], 10 * 60)).toEqual([30, 60, 90, 120, 150, 180]);
  });

  it('stops at the next booking', () => {
    const taken = placedIn([booking('a', '2025-03-03T11:00', '2025-03-03T12:00')]);
    expect(lengthsFrom(room, taken, 10 * 60)).toEqual([30, 60]);
    expect(lengthsFrom(room, taken, 10 * 60 + 30)).toEqual([30]);
    expect(lengthsFrom(room, taken, 11 * 60)).toEqual([]);
  });

  it('stops at closing time', () => {
    expect(lengthsFrom(room, [], 21 * 60)).toEqual([30, 60]);
    expect(lengthsFrom(room, [], 22 * 60)).toEqual([]);
  });

  it('lets a booking keep or extend over its own old slot', () => {
    const taken = placedIn([booking('a', '2025-03-03T10:00', '2025-03-03T11:00')]);
    expect(lengthsFrom(room, taken, 10 * 60, 'a')).toEqual([30, 60, 90, 120, 150, 180]);
  });
});

describe('earliestStart', () => {
  const now = new Date('2025-03-03T14:10:00Z');

  it('is the next slot boundary today', () => {
    expect(earliestStart(DAY, now, LISBON)).toBe(14 * 60 + 30);
    expect(earliestStart(DAY, new Date('2025-03-03T14:30:00Z'), LISBON)).toBe(14 * 60 + 30);
  });

  it('is the whole day for later days and nothing for earlier ones', () => {
    expect(earliestStart('2025-03-04', now, LISBON)).toBe(0);
    expect(earliestStart('2025-03-02', now, LISBON)).toBe(Number.POSITIVE_INFINITY);
  });

  it('uses the school’s day, not the viewer’s', () => {
    // 23:30 UTC on 3 March is still 3 March in Lisbon but 4 March in Kolkata.
    const lateEvening = new Date('2025-03-03T23:30:00Z');
    expect(earliestStart('2025-03-04', lateEvening, LISBON)).toBe(0);
    expect(earliestStart('2025-03-04', lateEvening, 'Asia/Kolkata')).toBe(5 * 60);
  });
});
