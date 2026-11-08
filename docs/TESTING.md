# Testing

## How to run

```bash
cd src/api && bundle exec rspec     # API specs, with a coverage report
npm test                            # web unit and component tests
npm run test:coverage               # the same, with coverage and thresholds
npm run test:e2e                    # browser tests against the real server
```

The first browser run needs `npx playwright install chromium`. On a system Playwright
has no browser build for, use an installed Chrome: `PW_CHANNEL=chrome npm run test:e2e`.

## Layers

| Layer         | Where             | Runs in                            | Count                                | What it is for                                                                 |
| ------------- | ----------------- | ---------------------------------- | ------------------------------------ | ------------------------------------------------------------------------------ |
| API specs     | `src/api/spec`    | Ruby, real SQLite                  | 166                                  | Models, services, the database rules and the GraphQL endpoint                  |
| Web unit      | `tests/unit`      | Node                               | 88                                   | Time-zone arithmetic, the calendar model, error reading, design-token contrast |
| Web component | `tests/component` | jsdom                              | 19                                   | Shared components and hooks                                                    |
| End to end    | `tests/e2e`       | A real browser and the real server | 15, three of them also at phone size | Journeys across several signed-in people                                       |

Counts are examples and test cases at the time of writing.

### API specs

Nothing is mocked except the clock (and, in one spec, the schema, to force an
unexpected error). The specs run against SQLite with the real triggers, constraints
and foreign keys.

- **`models/tenancy_spec.rb`** attacks isolation in the data layer: queries raise
  without a workspace; another workspace's records cannot be found, updated or
  deleted by id; a record cannot be created in or moved to another workspace; raw SQL
  that joins two workspaces is refused by a foreign key. Two further examples guard
  the rule itself: every table with a `workspace_id` column must have a scoped model,
  and no code under `app/` may call `unscoped`.
- **`services/bookings/overlap_spec.rb`** goes around the application with raw SQL
  to show the triggers hold on insert and on update, and that cancelled and missed
  bookings do not block a slot. A second group runs **four real threads on four
  database connections** against one slot and asserts that exactly one booking
  exists afterwards. That group cannot use the usual per-test transaction, so it
  cleans the tables itself.
- **`services/bookings/rules_spec.rb`** covers each rule and its edges: both ends of
  the opening hours, a room that closes at midnight, the Monday boundary of the
  weekly limit, and the day the clocks change in Lisbon.
- **`services/bookings/actions_spec.rb`** covers who may create, move, cancel, check
  in and mark as missed, when, and what message each action causes.
- **`services/notifications/notifications_spec.rb`** covers the renderer (unknown
  and unfinished tags), the calendar file (line endings, escaping, folding at 75
  octets without splitting a character, sequence numbers), token forgery, and the
  dispatcher's handling of opt-outs.
- **`services/rate_limiting/token_bucket_spec.rb`** runs one set of shared examples
  against both stores, then the outbox and the job with a clock the spec controls.
- **`requests/graphql_spec.rb`** drives the HTTP endpoint: content type, cookies,
  the workspace header, cross-workspace ids in mutations, what a student's response
  does not contain, role checks, paging, and a query-count assertion that fails if a
  field starts causing one query per booking.

### Web unit tests

`time.test.ts` checks conversions in three zones, including a half-hour offset, on
both kinds of clock-change day, and round-trips every half hour of such a day.
`calendar-model.test.ts` checks placement, free slots and possible lengths.
`design-tokens.test.ts` reads `tokens.css` and computes WCAG contrast for every text
and background pair in both themes.

### Component tests

They render the shared components and hooks and act through roles and labels.
jsdom lacks the `<dialog>` methods, which `tests/component/setup.ts` stands in for;
the real dialogs are exercised in the browser tests.

### End-to-end tests

They start Rails with the built web app and a throwaway database holding the demo
data, with a tight mail limit so that queueing can be observed.

- `booking-flow.spec.ts`: a student books from the grid; a new student sees the slot
  as taken with no name, is asked for two details once, and is not asked again;
  staff cancel with a reason, which appears in the log and in the student's list.
  Then two people go for one slot, and one student moves, downloads and cancels.
- `settings-and-messages.spec.ts`: renaming a status, the template editor's live
  preview and its refusal of an unknown tag, an unsubscribe link used without signing
  in and its effect on the next message, and mail queueing then draining.
- `access.spec.ts`: what students cannot reach, switching school, and the sign-in
  redirect.
- `layout.spec.ts`: the grid on a wide screen and the list on a phone, booking from
  the phone layout, theme persistence, and the skip link.

Tests book on later days, never today, so that they pass at any hour.

## Coverage

API, measured by SimpleCov over `app/` (thresholds: 90% lines, 75% branches):

| Measure  | Result |
| -------- | ------ |
| Lines    | 99.38% |
| Branches | 93.01% |

Web, measured over `src/web/lib` and the calendar model (thresholds: 80%, branches 75%):

| Measure    | Result |
| ---------- | ------ |
| Statements | 98.71% |
| Branches   | 93.42% |
| Functions  | 96.29% |
| Lines      | 99.25% |

## Known gaps

- **Pages are not unit tested.** Files under `src/web/features`, apart from the
  calendar model, are covered by the browser tests and are outside the web coverage
  figure. Testing them in jsdom would mean mocking the GraphQL client.
- **The concurrency spec proves the rule on SQLite.** On a database with many
  writers the mechanism would differ (ADR 2) and the same spec would need to be run
  against it.
- **Time-zone tests depend on the zone data of the runtime.** They use dates in 2025
  whose rules are settled.
- **The async job adapter is not exercised end to end.** Specs run the job directly;
  the browser tests rely on it only loosely.
- **The container setup is not tested.**
- **No automated accessibility audit**, for licence reasons explained in
  `THIRD_PARTY_NOTICES.md`. Roles, labels, keyboard order and contrast are tested.
- **One browser engine.** The browser tests run on Chromium only.
