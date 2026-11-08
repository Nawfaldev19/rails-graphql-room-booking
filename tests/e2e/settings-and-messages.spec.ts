import { expect, test } from '@playwright/test';
import { goForward, pathOf, signInAs } from './helpers';

test('an admin renames a status and everyone sees the new word', async ({ page }) => {
  await signInAs(page, 'admin');
  await page.getByRole('link', { name: 'Settings' }).click();
  await page.getByLabel('Name for "Booked"').fill('Reserved');
  await page.getByRole('button', { name: 'Save status names' }).click();
  await expect(page.getByText('Status names saved')).toBeVisible();

  await page.getByLabel('Name for "Checked in"').fill('Reserved');
  await page.getByRole('button', { name: 'Save status names' }).click();
  await expect(page.getByRole('alert')).toHaveText(
    'Status labels must be different from each other',
  );

  await page.getByRole('link', { name: 'Calendar' }).click();
  await goForward(page, 1);
  await expect(page.getByTestId('day-grid').getByText('Reserved').first()).toBeVisible();

  await page.getByRole('link', { name: 'Settings' }).click();
  await page.getByLabel('Name for "Booked"').fill('');
  await page.getByLabel('Name for "Checked in"').fill('');
  await page.getByRole('button', { name: 'Save status names' }).click();
  await expect(page.getByText('Status names saved')).toBeVisible();
});

test('the template editor previews live and refuses an unknown tag', async ({ page }) => {
  await signInAs(page, 'admin');
  await page.getByRole('link', { name: 'Settings' }).click();
  await page.getByRole('button', { name: 'Change', exact: true }).click();
  await expect(page.getByText('Standard wording, not yet changed')).toBeVisible();

  const subject = page.getByLabel('Subject');
  const preview = page.getByTestId('template-preview');
  const save = page.getByRole('button', { name: 'Save this message' });

  await subject.fill('Moved to {{room_nme}}');
  await expect(page.getByText('The subject uses the unknown tag {{room_nme}}.')).toBeVisible();
  await expect(save).toBeDisabled();

  await subject.fill('Moved to {{room_name}} at {{start_time}}');
  await expect(preview).toContainText('Moved to Room 2 at 16:00');
  await expect(save).toBeEnabled();

  await page.getByLabel('Message', { exact: true }).fill('Hello ');
  await page.getByRole('button', { name: /^Add the tag student_name/ }).click();
  await expect(preview).toContainText('Hello Ada Fictional');
  await save.click();
  await expect(page.getByText('Change message saved')).toBeVisible();

  await page.reload();
  await page.getByRole('button', { name: 'Change', exact: true }).click();
  await expect(page.getByLabel('Subject')).toHaveValue('Moved to {{room_name}} at {{start_time}}');
  await expect(page.getByText('Standard wording, not yet changed')).toBeHidden();
});

test('an unsubscribe link works without signing in and stops later messages', async ({
  page,
  browser,
}) => {
  await signInAs(page, 'staff');
  await page.getByRole('link', { name: 'Messages' }).click();
  const forSuvi = page
    .getByRole('list', { name: 'Messages' })
    .getByRole('listitem')
    .filter({ hasText: 'suvi@example.com' })
    .first();
  await forSuvi.locator('summary').first().click();
  const body = (await forSuvi.locator('.preview').first().textContent()) ?? '';
  const link = /https?:\/\/\S+\/preferences\/\S+/.exec(body)?.[0] ?? '';
  expect(link).not.toBe('');

  const context = await browser.newContext();
  const visitor = await context.newPage();
  await visitor.goto(pathOf(link));
  await expect(visitor.getByRole('heading', { name: 'Messages for Suvi Lahtinen' })).toBeVisible();
  const confirmations = visitor.getByLabel('When a room is booked for me');
  await expect(confirmations).toBeChecked();
  await confirmations.uncheck();
  await visitor.getByRole('button', { name: 'Save my choices' }).click();
  await expect(visitor.getByText('Saved. Your choices apply from now on.')).toBeVisible();
  await visitor.reload();
  await expect(visitor.getByLabel('When a room is booked for me')).not.toBeChecked();
  await expect(visitor.getByLabel('When one of my bookings is moved')).toBeChecked();

  await visitor.goto('/preferences/not-a-real-token');
  await expect(visitor.getByRole('heading', { name: 'This link is not valid' })).toBeVisible();
  await context.close();

  await page.getByRole('link', { name: 'Calendar' }).click();
  await goForward(page, 7);
  await page.getByRole('button', { name: 'Book Room 1, upright piano at 12:00' }).click();
  const dialog = page.getByRole('dialog', { name: 'Book a room' });
  await dialog.getByLabel('For').selectOption({ label: 'Suvi Lahtinen' });
  await expect(dialog.getByLabel('Tell the person by email')).toBeChecked();
  await dialog.getByRole('button', { name: 'Book room' }).click();
  await expect(page.getByText('Room booked')).toBeVisible();

  await page.getByRole('link', { name: 'Messages' }).click();
  const newest = page.getByRole('list', { name: 'Messages' }).getByRole('listitem').first();
  await expect(newest).toContainText('suvi@example.com');
  await expect(newest).toContainText('Not sent');
  await expect(newest).toContainText('The person turned these messages off.');
});

test('queued mail goes out as far as the rate limit allows, and the rest stays queued', async ({
  page,
}) => {
  // Draining the queue waits for the rate limit on purpose, so allow for it.
  test.setTimeout(120_000);
  await signInAs(page, 'staff');
  await goForward(page, 8);
  for (const time of ['08:00', '09:00', '10:00', '11:00', '12:00', '13:00', '14:00', '15:00']) {
    await page.getByRole('button', { name: `Book Ensemble room at ${time}` }).click();
    const dialog = page.getByRole('dialog', { name: 'Book a room' });
    await dialog.getByLabel('Length').selectOption({ label: '30 minutes' });
    await dialog.getByRole('button', { name: 'Book room' }).click();
    await expect(page.getByRole('button', { name: `Book Ensemble room at ${time}` })).toBeHidden();
  }

  await page.getByRole('link', { name: 'Messages' }).click();
  const messages = page.getByRole('list', { name: 'Messages' });
  await expect(messages.getByRole('listitem').first()).toContainText('bram@example.com');
  await expect(messages.getByText('Queued').first()).toBeVisible();

  await expect(async () => {
    const send = page.getByRole('button', { name: /^Send queued now/ });
    if (await send.isEnabled()) await send.click();
    await page.reload();
    await expect(page.getByRole('button', { name: 'Send queued now (0)' })).toBeVisible({
      timeout: 2000,
    });
  }).toPass({ timeout: 90_000 });
  await expect(messages.getByText('Queued')).toHaveCount(0);
});
