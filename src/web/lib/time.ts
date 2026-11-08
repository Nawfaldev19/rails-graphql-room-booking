/**
 * Calendar arithmetic in a named time zone, using only the browser's Intl API.
 *
 * A school's opening hours are wall-clock times in the school's zone, while the
 * API speaks in UTC instants. These helpers convert between the two, and stay
 * correct on the days the clocks change.
 */

export interface ZonedParts {
  year: number;
  month: number;
  day: number;
  hour: number;
  minute: number;
}

const formatters = new Map<string, Intl.DateTimeFormat>();

function formatterFor(timeZone: string): Intl.DateTimeFormat {
  let formatter = formatters.get(timeZone);
  if (!formatter) {
    formatter = new Intl.DateTimeFormat('en-CA', {
      timeZone,
      hourCycle: 'h23',
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
    });
    formatters.set(timeZone, formatter);
  }
  return formatter;
}

/** The wall-clock date and time that an instant has in a time zone. */
export function partsInZone(instant: Date, timeZone: string): ZonedParts {
  const parts: Record<string, number> = {};
  for (const part of formatterFor(timeZone).formatToParts(instant)) {
    if (part.type !== 'literal') parts[part.type] = Number(part.value);
  }
  return {
    year: parts.year ?? 0,
    month: parts.month ?? 0,
    day: parts.day ?? 0,
    hour: parts.hour ?? 0,
    minute: parts.minute ?? 0,
  };
}

const pad = (value: number): string => String(value).padStart(2, '0');

/** A calendar day as "YYYY-MM-DD", which sorts and compares as text. */
export function dayKey(parts: Pick<ZonedParts, 'year' | 'month' | 'day'>): string {
  return `${String(parts.year)}-${pad(parts.month)}-${pad(parts.day)}`;
}

export function dayKeyInZone(instant: Date, timeZone: string): string {
  return dayKey(partsInZone(instant, timeZone));
}

export function minuteOfDayInZone(instant: Date, timeZone: string): number {
  const parts = partsInZone(instant, timeZone);
  return parts.hour * 60 + parts.minute;
}

function wallClockAsUtc(day: string, minuteOfDay: number): number {
  const [year = 0, month = 1, date = 1] = day.split('-').map(Number);
  return Date.UTC(year, month - 1, date, 0, minuteOfDay);
}

/**
 * The instant at which a zone's wall clock shows the given day and minute.
 * The offset is found by trial: assume UTC, see what the zone's clock shows,
 * and correct by the difference. A second pass settles days with a clock change.
 */
export function zonedToUtc(day: string, minuteOfDay: number, timeZone: string): Date {
  const wanted = wallClockAsUtc(day, minuteOfDay);
  let guess = wanted;
  for (let pass = 0; pass < 3; pass += 1) {
    const shown = partsInZone(new Date(guess), timeZone);
    const difference = wanted - wallClockAsUtc(dayKey(shown), shown.hour * 60 + shown.minute);
    if (difference === 0) break;
    guess += difference;
  }
  return new Date(guess);
}

export function addDays(day: string, count: number): string {
  const moved = new Date(wallClockAsUtc(day, 0) + count * 86_400_000);
  return dayKey({
    year: moved.getUTCFullYear(),
    month: moved.getUTCMonth() + 1,
    day: moved.getUTCDate(),
  });
}

/** The seven days, Monday first, of the week a day belongs to. */
export function weekOf(day: string): string[] {
  const weekday = (new Date(wallClockAsUtc(day, 0)).getUTCDay() + 6) % 7;
  return Array.from({ length: 7 }, (_, index) => addDays(day, index - weekday));
}

export function formatClock(minuteOfDay: number): string {
  return `${pad(Math.floor(minuteOfDay / 60))}:${pad(minuteOfDay % 60)}`;
}

export function formatDuration(minutes: number): string {
  const hours = Math.floor(minutes / 60);
  const rest = minutes % 60;
  if (hours === 0) return `${String(rest)} minutes`;
  const hourText = hours === 1 ? '1 hour' : `${String(hours)} hours`;
  return rest === 0 ? hourText : `${hourText} ${String(rest)} minutes`;
}

const dayNames = new Intl.DateTimeFormat('en-GB', {
  timeZone: 'UTC',
  weekday: 'long',
  day: 'numeric',
  month: 'long',
});
const shortDayNames = new Intl.DateTimeFormat('en-GB', { timeZone: 'UTC', weekday: 'short' });

/** "Monday 3 March" for a day key. The key is zone-free, so UTC is used to print it. */
export function formatDay(day: string): string {
  return dayNames.format(new Date(wallClockAsUtc(day, 0))).replace(',', '');
}

export function formatWeekday(day: string): string {
  return shortDayNames.format(new Date(wallClockAsUtc(day, 0)));
}

export function dayOfMonth(day: string): number {
  return Number(day.slice(8));
}
