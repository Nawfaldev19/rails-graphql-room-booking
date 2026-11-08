# Changelog

All notable changes to this project are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com), and the project uses
[Semantic Versioning](https://semver.org).

## [1.0.0] - 2026-10-12

### Added

- Workspaces with admin, staff and student roles, isolated by tenant-scoped models
  that fail closed and by composite foreign keys.
- Room bookings with a half-hour grid, length limits, opening hours in the school's
  time zone and a weekly limit per student.
- Overlap protection by database triggers, and optimistic locking for edits.
- Moving and cancelling bookings, check-in and "missed", with per-role policies.
- Two profile details asked once before a student's first booking.
- Status names that each school can change without changing behaviour.
- Message templates with validated merge tags and a live preview.
- An iCalendar file for every booking message.
- Unsubscribe links that work without signing in, with choices per kind of message.
- A token-bucket rate limit for outgoing mail with a database-backed queue and a
  delivery log.
- A day calendar that is a grid on wide screens and a list on phones.
- Seeded demo data and one-click demo sign-in.
- API specs, web unit and component tests, end-to-end tests, and a CI workflow.
