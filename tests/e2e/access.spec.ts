import { expect, test } from '@playwright/test';
import { pathOf, signInAs } from './helpers';

test('students get no staff pages, in the menu or by address', async ({ page }) => {
  await signInAs(page, 'student');
  await expect(page.getByText('Student', { exact: true })).toBeVisible();
  await expect(page.getByRole('link', { name: 'Messages' })).toBeHidden();
  await expect(page.getByRole('link', { name: 'Settings' })).toBeHidden();

  const base = pathOf(page.url()).replace('/calendar', '');
  await page.goto(`${base}/settings`);
  await expect(page.getByRole('heading', { name: 'Admins only' })).toBeVisible();
  await page.goto(`${base}/outbox`);
  await expect(page.getByRole('alert')).toContainText('Your role does not allow this.');
});

test('switching school shows only that school, with the role held there', async ({ page }) => {
  await signInAs(page, 'admin');
  await expect(page.getByText('Room 1, upright piano').first()).toBeVisible();

  await page.getByLabel('Workspace').selectOption({ label: 'Harbour Street Rehearsal Rooms' });
  await expect(page.getByText('Studio A').first()).toBeVisible();
  await expect(page.getByText('Room 1, upright piano')).toBeHidden();
  await expect(page.getByText('Student', { exact: true })).toBeVisible();
  await expect(page.getByRole('link', { name: 'Settings' })).toBeHidden();
});

test('a school the user is not in looks like one that does not exist', async ({ page }) => {
  await signInAs(page, 'staff');
  await page.goto('/w/999999/calendar');
  await expect(page.getByRole('heading', { name: 'Workspace not found' })).toBeVisible();
});

test('workspace pages send signed-out visitors to the sign-in page and back', async ({ page }) => {
  await signInAs(page, 'staff');
  const target = pathOf(page.url()).replace('/calendar', '/outbox');
  await page.getByRole('button', { name: 'Sign out' }).click();
  await expect(page.getByRole('heading', { name: /A room to practise in/ })).toBeVisible();

  await page.goto(target);
  await expect(page.getByRole('heading', { name: 'Sign in' })).toBeVisible();
  await page.getByLabel('Email').fill('bram@example.com');
  await page.getByLabel('Password').fill('wrong-password');
  await page.getByRole('button', { name: 'Sign in' }).click();
  await expect(page.getByText('Email or password is wrong.')).toBeVisible();

  await page.getByLabel('Password').fill('practice-demo');
  await page.getByRole('button', { name: 'Sign in' }).click();
  await expect(page.getByRole('heading', { name: 'Messages', level: 1 })).toBeVisible();
  expect(pathOf(page.url())).toBe(target);
});
