# Plan

This is the plan the demo was built from. It is kept so that a reader can compare
what was intended with what exists.

## Goal

Show, in one small and complete application, a Rails GraphQL API and a React front
end handling three things that are easy to get subtly wrong:

1. **concurrency**: two people wanting the same room at the same moment,
2. **time**: opening hours, weekly limits and calendar files across time zones and
   clock changes,
3. **notifications**: who is told what, in whose words, how fast, and how they opt
   out.

## The fictional setting

A music school has a few rehearsal rooms. Students book them; staff run the day and
sometimes book, move or cancel on a student's behalf. A second school uses the same
system and must never see the first one's data.

## In scope

| Area          | What is built                                                                          |
| ------------- | -------------------------------------------------------------------------------------- |
| Workspaces    | Sign-in, membership of several schools, three roles (admin, staff, student)            |
| Calendar      | A day view with one column per room, a week strip, a phone layout                      |
| Bookings      | Create, move, cancel with a reason, check in, mark as missed                           |
| Rules         | Half-hour grid, length limits, opening hours, a weekly limit per student, no overlap   |
| First booking | Two profile details asked once                                                         |
| Status names  | Each school may rename the four statuses; behaviour stays the same                     |
| Messages      | Editable templates with merge tags and a live preview, a calendar file, a delivery log |
| Opting out    | A signed link per person, choices per kind of message                                  |
| Rate limit    | A token bucket in front of outgoing mail, with a queue                                 |

## Out of scope

Sending real email, reminders, recurring bookings, payments, managing rooms and
people, and anything beyond one process. The README lists these limits for readers.

## Requirements that shaped the design

- "One room, one booking at a time" must hold even if two requests arrive together.
  This puts the rule in the database (ADR 1).
- The demo must start with one command and no database server. This picks SQLite and
  shapes how the first requirement is met (ADR 2).
- A forgotten filter must not leak another school's data. This makes tenant scoping
  the default and makes its absence an error (ADR 3).
- A student must not learn who booked a room. This makes visibility a policy the API
  applies per field (ADR 5).
- A burst of bookings must not become a burst of mail, and no message may be lost.
  This gives a rate limit with a queue behind it (ADR 7).

## Order of work

1. The Rails application: schema with constraints and triggers, then models.
2. Tenancy, with its specs first.
3. Booking rules as a pure class, then the policy, then the actions.
4. Notifications: renderer, calendar file, tokens, dispatcher, outbox, rate limit.
5. The GraphQL schema and the controller.
6. Seed data built through the real services.
7. The web app: tokens and shared components, time helpers and the calendar model
   with tests, then the pages.
8. Browser tests for the journeys across several people.
9. Documentation, continuous integration and the container setup.

## Definition of done

- `bundle exec rspec` and `bundle exec rubocop` pass in `src/api`, with line
  coverage above 90%.
- `npm run check` passes: lint, type check, tests with coverage above 80% on the web
  logic, and the build.
- `npm run test:e2e` passes.
- A reader can start the demo using only the README.
- Every claim in the docs can be traced to code or to a test.
