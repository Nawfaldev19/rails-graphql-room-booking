import { defineConfig, devices } from '@playwright/test';

const PORT = 3417;
const baseURL = `http://localhost:${String(PORT)}`;

/**
 * End-to-end tests run against the real Rails server with the built web app and
 * a throwaway database seeded with the demo data.
 *
 * PW_CHANNEL=chrome uses an installed Google Chrome instead of the Chromium that
 * Playwright downloads, for machines Playwright no longer ships a browser for.
 */
const channel = process.env.PW_CHANNEL;
const database = 'storage/e2e.sqlite3';

export default defineConfig({
  testDir: 'tests/e2e',
  fullyParallel: false,
  workers: 1,
  forbidOnly: Boolean(process.env.CI),
  retries: process.env.CI ? 1 : 0,
  reporter: process.env.CI ? [['github'], ['html', { open: 'never' }]] : 'list',
  use: {
    baseURL,
    trace: 'retain-on-failure',
    ...(channel ? { channel } : {}),
  },
  projects: [
    { name: 'desktop', use: { ...devices['Desktop Chrome'], ...(channel ? { channel } : {}) } },
    {
      name: 'phone',
      testMatch: /layout\.spec\.ts/,
      use: { ...devices['Pixel 7'], ...(channel ? { channel } : {}) },
    },
  ],
  webServer: {
    command: [
      'npm run build',
      'cd src/api',
      `rm -f ${database} ${database}-shm ${database}-wal`,
      'bin/rails db:migrate db:seed',
      `bin/rails server -p ${String(PORT)}`,
    ].join(' && '),
    url: `${baseURL}/healthz`,
    reuseExistingServer: !process.env.CI,
    timeout: 180_000,
    env: {
      RAILS_ENV: 'development',
      DATABASE_PATH: database,
      PUBLIC_URL: baseURL,
      // A tight limit, so the tests can watch mail queue up and then drain.
      MAIL_BURST: '3',
      MAIL_PER_SECOND: '0.25',
    },
  },
});
