import { expect, test } from '@playwright/test';
import { goForward, signInAs } from './helpers';

/**
 * The main journey across three people: a student books a room, a new student
 * sees the slot as taken (without a name) and books another after giving two
 * details once, and a staff member cancels with a reason that reaches the
 * student and the message log.
 */
test('book, see it as taken, give details once, cancel with a reason', async ({
  page,
  browser,
}) => {
  const DAYS_AHEAD = 4;
  await signInAs(page, 'student');
  const day = await goForward(page, DAYS_AHEAD);

  await test.step('a student books a free slot from the grid', async () => {
    await page.getByRole('button', { name: 'Book Ensemble room at 10:00' }).click();
    const dialog = page.getByRole('dialog', { name: 'Book a room' });
    await expect(dialog.getByLabel('Room')).toHaveValue(/\d+/);
    await expect(dialog.getByLabel('Start')).toContainText('10:00');
    await dialog.getByLabel('Length').selectOption({ label: '1 hour 30 minutes' });
    await dialog.getByLabel('Note (optional)').fill('Quartet run-through');
    await dialog.getByRole('button', { name: 'Book room' }).click();

    await expect(page.getByText('Room booked')).toBeVisible();
    await expect(
      page.getByRole('button', { name: 'Ensemble room, 10:00 to 11:30, Suvi Lahtinen' }),
    ).toBeVisible();
    await expect(page.getByRole('button', { name: 'Book Ensemble room at 10:30' })).toBeHidden();
    await expect(page.getByRole('button', { name: 'Book Ensemble room at 11:30' })).toBeVisible();
  });

  await test.step('a new student sees the slot as taken, without a name', async () => {
    const context = await browser.newContext();
    const other = await context.newPage();
    await signInAs(other, 'new student');
    await goForward(other, DAYS_AHEAD);

    await expect(
      other.getByRole('img', { name: 'Ensemble room, 10:00 to 11:30, taken' }),
    ).toBeVisible();
    await expect(other.getByText('Suvi Lahtinen')).toBeHidden();
    await expect(other.getByText('Quartet run-through')).toBeHidden();

    await other.getByRole('button', { name: 'Book Ensemble room at 11:30' }).click();
    const dialog = other.getByRole('dialog', { name: 'Book a room' });
    await dialog.getByRole('button', { name: 'Book room' }).click();

    await expect(dialog.getByText('Before your first booking', { exact: true })).toBeVisible();
    await dialog.getByRole('button', { name: 'Save details and book' }).click();
    await expect(dialog.getByText('This is needed.').first()).toBeVisible();

    await dialog.getByLabel('Your instrument').fill('Clarinet');
    await dialog.getByLabel('A phone number').fill('+351 555 0177');
    await dialog.getByRole('button', { name: 'Save details and book' }).click();
    await expect(other.getByText('Room booked')).toBeVisible();

    await other.getByRole('button', { name: 'Book Ensemble room at 13:00' }).click();
    await other.getByRole('dialog').getByRole('button', { name: 'Book room' }).click();
    await expect(other.getByText('Room booked').last()).toBeVisible();
    await expect(other.getByText('Before your first booking', { exact: true })).toBeHidden();
    await context.close();
  });

  await test.step('staff cancel the first booking with a reason', async () => {
    const context = await browser.newContext();
    const staff = await context.newPage();
    await signInAs(staff, 'staff');
    await goForward(staff, DAYS_AHEAD);

    await staff
      .getByRole('button', { name: 'Ensemble room, 10:00 to 11:30, Suvi Lahtinen' })
      .click();
    const dialog = staff.getByRole('dialog', { name: 'Manage this booking' });
    await expect(dialog.getByText('Quartet run-through')).toBeVisible();
    await dialog.getByRole('button', { name: 'Cancel booking…' }).click();
    await dialog.getByRole('button', { name: 'Cancel booking', exact: true }).click();
    await expect(dialog.getByText('Say why this booking is cancelled.')).toBeVisible();

    await dialog
      .getByLabel('Reason (the person will see it)')
      .fill('The room is needed for an exam');
    await dialog.getByRole('button', { name: 'Cancel booking', exact: true }).click();
    await expect(staff.getByText('Booking cancelled')).toBeVisible();
    await expect(staff.getByRole('button', { name: 'Book Ensemble room at 10:00' })).toBeVisible();

    await staff.getByRole('link', { name: 'Messages' }).click();
    const latest = staff.getByRole('list', { name: 'Messages' }).getByRole('listitem').first();
    await expect(latest).toContainText(`Cancelled: Ensemble room on ${day}`);
    await latest.locator('summary').first().click();
    await expect(latest).toContainText('Reason: The room is needed for an exam');
    await context.close();
  });

  await test.step('the student sees the cancellation and its reason', async () => {
    await page.getByRole('link', { name: 'My bookings' }).click();
    const cancelled = page
      .getByRole('listitem')
      .filter({ hasText: 'The room is needed for an exam' });
    await expect(cancelled).toContainText('Cancelled');
    await expect(cancelled).toContainText('Ensemble room');
    await expect(cancelled.getByRole('button', { name: 'Cancel' })).toBeHidden();
  });
});

test('two people going for the same slot: one books, the other is told and sees the truth', async ({
  page,
  browser,
}) => {
  await signInAs(page, 'student');
  await goForward(page, 5);
  await page.getByRole('button', { name: 'Book Room 1, upright piano at 15:00' }).click();
  const mine = page.getByRole('dialog', { name: 'Book a room' });
  await expect(mine.getByLabel('Start')).toContainText('15:00');

  const context = await browser.newContext();
  const rival = await context.newPage();
  await signInAs(rival, 'staff');
  await goForward(rival, 5);
  await rival.getByRole('button', { name: 'Book Room 1, upright piano at 15:00' }).click();
  await rival.getByRole('dialog').getByRole('button', { name: 'Book room' }).click();
  await expect(rival.getByText('Room booked')).toBeVisible();
  await context.close();

  await mine.getByRole('button', { name: 'Book room' }).click();
  await expect(mine.getByRole('alert')).toHaveText(
    'That room is already booked for part of this time.',
  );
  await expect(mine.getByLabel('Start')).not.toContainText('15:00');
  await mine.getByRole('button', { name: 'Close' }).click();
  await expect(
    page.getByRole('img', { name: 'Room 1, upright piano, 15:00 to 16:00, taken' }),
  ).toBeVisible();
});

test('a student moves and then cancels their own booking, and downloads the calendar file', async ({
  page,
}) => {
  await signInAs(page, 'student');
  await goForward(page, 6);
  await page.getByRole('button', { name: 'Book Room 1, upright piano at 09:00' }).click();
  await page.getByRole('dialog').getByRole('button', { name: 'Book room' }).click();
  await expect(page.getByText('Room booked')).toBeVisible();

  await page
    .getByRole('button', { name: 'Room 1, upright piano, 09:00 to 10:00, Suvi Lahtinen' })
    .click();
  const dialog = page.getByRole('dialog', { name: 'Manage this booking' });
  await dialog.getByLabel('Start').selectOption({ label: '16:00' });
  await dialog.getByRole('button', { name: 'Save changes' }).click();
  await expect(page.getByText('Booking changed')).toBeVisible();
  await expect(
    page.getByRole('button', { name: 'Room 1, upright piano, 16:00 to 17:00, Suvi Lahtinen' }),
  ).toBeVisible();

  await page.getByRole('link', { name: 'My bookings' }).click();
  // The seeded data has an older booking at the same hour; the new one is last.
  const row = page.getByRole('listitem').filter({ hasText: '16:00 to 17:00' }).last();
  const download = page.waitForEvent('download');
  await row.getByRole('button', { name: /Download the calendar file/ }).click();
  expect((await download).suggestedFilename()).toMatch(/^booking-\d+\.ics$/);

  await row.getByRole('button', { name: 'Cancel' }).click();
  await page
    .getByRole('dialog', { name: 'Cancel this booking?' })
    .getByRole('button', { name: 'Cancel booking' })
    .click();
  await expect(page.getByText('Booking cancelled')).toBeVisible();
  await expect(row).toContainText('Cancelled');
});
