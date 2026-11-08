import { describe, expect, it } from 'vitest';
import {
  addDays,
  dayKeyInZone,
  dayOfMonth,
  formatClock,
  formatDay,
  formatDuration,
  formatWeekday,
  minuteOfDayInZone,
  partsInZone,
  weekOf,
  zonedToUtc,
} from '../../src/web/lib/time';

const LISBON = 'Europe/Lisbon';
const NEW_YORK = 'America/New_York';
const KOLKATA = 'Asia/Kolkata';

describe('reading an instant in a time zone', () => {
  it('gives the wall-clock date and time', () => {
    const instant = new Date('2025-07-01T23:30:00Z');
    expect(partsInZone(instant, LISBON)).toEqual({
      year: 2025,
      month: 7,
      day: 2,
      hour: 0,
      minute: 30,
    });
    expect(partsInZone(instant, NEW_YORK)).toEqual({
      year: 2025,
      month: 7,
      day: 1,
      hour: 19,
      minute: 30,
    });
    expect(partsInZone(instant, KOLKATA)).toEqual({
      year: 2025,
      month: 7,
      day: 2,
      hour: 5,
      minute: 0,
    });
  });

  it('shows midnight as hour 0, never 24', () => {
    expect(partsInZone(new Date('2025-01-10T00:00:00Z'), 'UTC').hour).toBe(0);
    expect(minuteOfDayInZone(new Date('2025-01-10T00:00:00Z'), 'UTC')).toBe(0);
  });

  it('gives the day and the minute of the day', () => {
    const instant = new Date('2025-03-03T14:30:00Z');
    expect(dayKeyInZone(instant, LISBON)).toBe('2025-03-03');
    expect(minuteOfDayInZone(instant, LISBON)).toBe(14 * 60 + 30);
    expect(dayKeyInZone(new Date('2025-03-03T23:30:00Z'), KOLKATA)).toBe('2025-03-04');
  });
});

describe('zonedToUtc', () => {
  it('converts a wall-clock time to the instant, in winter and in summer', () => {
    expect(zonedToUtc('2025-01-15', 9 * 60, LISBON).toISOString()).toBe('2025-01-15T09:00:00.000Z');
    expect(zonedToUtc('2025-07-15', 9 * 60, LISBON).toISOString()).toBe('2025-07-15T08:00:00.000Z');
    expect(zonedToUtc('2025-01-15', 9 * 60, NEW_YORK).toISOString()).toBe(
      '2025-01-15T14:00:00.000Z',
    );
    expect(zonedToUtc('2025-07-15', 9 * 60 + 30, KOLKATA).toISOString()).toBe(
      '2025-07-15T04:00:00.000Z',
    );
  });

  it('is right on the day the clocks go forward', () => {
    // Lisbon, 30 March 2025: 01:00 becomes 02:00.
    expect(zonedToUtc('2025-03-30', 0, LISBON).toISOString()).toBe('2025-03-30T00:00:00.000Z');
    expect(zonedToUtc('2025-03-30', 8 * 60, LISBON).toISOString()).toBe('2025-03-30T07:00:00.000Z');
    expect(zonedToUtc('2025-03-31', 0, LISBON).toISOString()).toBe('2025-03-30T23:00:00.000Z');
  });

  it('is right on the day the clocks go back', () => {
    // New York, 2 November 2025: 02:00 becomes 01:00.
    expect(zonedToUtc('2025-11-02', 0, NEW_YORK).toISOString()).toBe('2025-11-02T04:00:00.000Z');
    expect(zonedToUtc('2025-11-02', 12 * 60, NEW_YORK).toISOString()).toBe(
      '2025-11-02T17:00:00.000Z',
    );
  });

  it('treats minute 1440 as midnight at the start of the next day', () => {
    expect(zonedToUtc('2025-03-03', 1440, LISBON)).toEqual(zonedToUtc('2025-03-04', 0, LISBON));
  });

  it('round-trips with the reading functions for every half hour of a clock-change day', () => {
    for (let minute = 2 * 60; minute < 24 * 60; minute += 30) {
      const instant = zonedToUtc('2025-03-30', minute, LISBON);
      expect(dayKeyInZone(instant, LISBON)).toBe('2025-03-30');
      expect(minuteOfDayInZone(instant, LISBON)).toBe(minute);
    }
  });
});

describe('days and weeks', () => {
  it('adds days across months, years and leap days', () => {
    expect(addDays('2025-01-31', 1)).toBe('2025-02-01');
    expect(addDays('2024-02-28', 1)).toBe('2024-02-29');
    expect(addDays('2025-01-01', -1)).toBe('2024-12-31');
    expect(addDays('2025-03-29', 2)).toBe('2025-03-31');
    expect(addDays('2025-03-03', 0)).toBe('2025-03-03');
  });

  it('lists a week from Monday to Sunday, whichever day is asked for', () => {
    const week = [
      '2025-03-03',
      '2025-03-04',
      '2025-03-05',
      '2025-03-06',
      '2025-03-07',
      '2025-03-08',
      '2025-03-09',
    ];
    expect(weekOf('2025-03-03')).toEqual(week);
    expect(weekOf('2025-03-06')).toEqual(week);
    expect(weekOf('2025-03-09')).toEqual(week);
    expect(weekOf('2025-03-10')[0]).toBe('2025-03-10');
  });
});

describe('formatting', () => {
  it('prints clock times with two digits', () => {
    expect(formatClock(0)).toBe('00:00');
    expect(formatClock(9 * 60 + 5)).toBe('09:05');
    expect(formatClock(1440)).toBe('24:00');
  });

  it('prints lengths in words', () => {
    expect(formatDuration(30)).toBe('30 minutes');
    expect(formatDuration(60)).toBe('1 hour');
    expect(formatDuration(90)).toBe('1 hour 30 minutes');
    expect(formatDuration(180)).toBe('3 hours');
  });

  it('prints days', () => {
    expect(formatDay('2025-03-03')).toBe('Monday 3 March');
    expect(formatWeekday('2025-03-09')).toBe('Sun');
    expect(dayOfMonth('2025-03-09')).toBe(9);
  });
});
