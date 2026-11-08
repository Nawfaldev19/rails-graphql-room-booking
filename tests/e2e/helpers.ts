import { expect } from '@playwright/test';
import type { Page } from '@playwright/test';

export type DemoRole = 'admin' | 'staff' | 'student' | 'new student';

/** Signs in from the start page with one of the seeded demo accounts. */
export async function signInAs(page: Page, role: DemoRole): Promise<void> {
  await page.goto('/');
  await page.getByRole('button', { name: `Continue as ${role}`, exact: true }).click();
  await expect(page.getByRole('group', { name: 'Days of this week' })).toBeVisible();
}

/**
 * Moves the calendar forward. Tests book on later days so that they pass at any
 * time of day: today's remaining slots depend on when the suite happens to run.
 */
export async function goForward(page: Page, days: number): Promise<string> {
  for (let step = 0; step < days; step += 1) {
    const before = await page.getByRole('heading', { level: 1 }).textContent();
    await page.getByRole('button', { name: 'Next day' }).click();
    await expect(page.getByRole('heading', { level: 1 })).not.toHaveText(before ?? '');
  }
  return (await page.getByRole('heading', { level: 1 }).textContent()) ?? '';
}

export function pathOf(url: string): string {
  return new URL(url).pathname;
}
