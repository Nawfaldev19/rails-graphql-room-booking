import { expect, test } from '@playwright/test';
import type { Page } from '@playwright/test';
import { signInAs } from './helpers';

/** These run twice: on a desktop viewport and on a phone-sized one. */

async function expectNoSidewaysScroll(page: Page): Promise<void> {
  const overflow = await page.evaluate(
    () => document.documentElement.scrollWidth - document.documentElement.clientWidth,
  );
  expect(overflow).toBeLessThanOrEqual(1);
}

test('the calendar is a grid on a wide screen and a list on a phone', async ({
  page,
  isMobile,
}) => {
  await page.goto('/');
  await expect(page.getByRole('heading', { level: 1 })).toBeVisible();
  await expectNoSidewaysScroll(page);

  await signInAs(page, 'staff');
  await expect(page.getByTestId(isMobile ? 'agenda' : 'day-grid')).toBeVisible();
  await expect(page.getByTestId(isMobile ? 'day-grid' : 'agenda')).toBeHidden();
  await expectNoSidewaysScroll(page);

  await page.getByRole('button', { name: 'Book a room' }).click();
  await expect(page.getByRole('dialog', { name: 'Book a room' })).toBeVisible();
  await expectNoSidewaysScroll(page);
});

test('booking works from the phone layout too', async ({ page, isMobile }) => {
  test.skip(!isMobile, 'The grid flow is covered in booking-flow.spec.ts.');
  await signInAs(page, 'staff');
  for (let step = 0; step < 9; step += 1)
    await page.getByRole('button', { name: 'Next day' }).click();
  await page.getByRole('button', { name: 'Book a room' }).click();
  const dialog = page.getByRole('dialog', { name: 'Book a room' });
  await dialog.getByLabel('Room').selectOption({ label: 'Ensemble room' });
  await dialog.getByLabel('Start').selectOption({ label: '18:00' });
  await dialog.getByRole('button', { name: 'Book room' }).click();

  const room = page.getByRole('region', { name: 'Ensemble room' });
  await expect(room).toContainText('18:00 to 19:00');
  await room.getByRole('button', { name: 'Manage' }).click();
  await expect(page.getByRole('dialog', { name: 'Manage this booking' })).toBeVisible();
});

test('the theme choice is applied before paint and survives a reload', async ({ page }) => {
  await page.emulateMedia({ colorScheme: 'light' });
  await page.goto('/');
  const html = page.locator('html');
  await expect(html).toHaveAttribute('data-theme', 'light');
  await page.getByRole('button', { name: 'Switch to dark theme' }).click();
  await expect(html).toHaveAttribute('data-theme', 'dark');
  await page.reload();
  await expect(html).toHaveAttribute('data-theme', 'dark');
});

test('the first Tab stop inside the app is a skip link to the content', async ({
  page,
  isMobile,
}) => {
  test.skip(isMobile, 'Tab order is a keyboard concern.');
  await signInAs(page, 'student');
  await page.reload();
  await expect(page.getByRole('group', { name: 'Days of this week' })).toBeVisible();
  await page.keyboard.press('Tab');
  await expect(page.getByRole('link', { name: 'Skip to content' })).toBeFocused();
});
