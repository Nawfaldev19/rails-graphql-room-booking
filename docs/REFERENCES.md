# References

The specifications, documentation and books behind the patterns in this project.
Each entry says what it was used for.

## Specifications and standards

- **RFC 5545, Internet Calendaring and Scheduling Core Object Specification
  (iCalendar).** <https://www.rfc-editor.org/rfc/rfc5545>. The calendar file: line
  folding, text escaping, `UID`, `SEQUENCE` and `METHOD`.
- **RFC 8058, Signaling One-Click Functionality for List Email Headers.**
  <https://www.rfc-editor.org/rfc/rfc8058>. Background for unsubscribe links that
  work without signing in. This project implements the link, not the mail headers.
- **RFC 6265, HTTP State Management Mechanism.** <https://www.rfc-editor.org/rfc/rfc6265>.
  Cookie attributes used for the session.
- **GraphQL Specification.** <https://spec.graphql.org/>. Type system, nullability
  and errors with `extensions`.
- **Web Content Accessibility Guidelines (WCAG) 2.2.** <https://www.w3.org/TR/WCAG22/>.
  Contrast thresholds and the luminance formula used in the design-token test.
- **ECMAScript Internationalization API Specification (ECMA-402).**
  <https://tc39.es/ecma402/>. `Intl.DateTimeFormat` with a time zone, which the
  browser-side time arithmetic relies on.

## Rails and Ruby

- **Ruby on Rails Guides.** <https://guides.rubyonrails.org>. In particular Active
  Record Migrations, Active Record Validations, Active Job Basics, and Securing
  Rails Applications.
- **Rails API documentation, ActiveSupport::CurrentAttributes.**
  <https://api.rubyonrails.org/classes/ActiveSupport/CurrentAttributes.html>. Holds
  the current workspace for a request.
- **Rails API documentation, ActiveSupport::MessageVerifier.**
  <https://api.rubyonrails.org/classes/ActiveSupport/MessageVerifier.html>. Signs
  unsubscribe tokens.
- **Rails API documentation, ActiveRecord::Locking::Optimistic.**
  <https://api.rubyonrails.org/classes/ActiveRecord/Locking/Optimistic.html>. The
  `lock_version` column on bookings.
- **GraphQL Ruby documentation.** <https://graphql-ruby.org>. Class-based schema,
  mutations, error handling and the dataloader.
- **RSpec documentation.** <https://rspec.info>.
- **RuboCop documentation.** <https://docs.rubocop.org>.

## Database

- **SQLite documentation, CREATE TRIGGER.** <https://www.sqlite.org/lang_createtrigger.html>.
  The overlap triggers and `RAISE(ABORT, ...)`.
- **SQLite documentation, Foreign Key Support.** <https://www.sqlite.org/foreignkeys.html>.
  Composite foreign keys.
- **SQLite documentation, File Locking And Concurrency.**
  <https://www.sqlite.org/lockingv3.html>. Why one writer at a time makes the
  triggers free of races.
- **PostgreSQL documentation, Constraints (exclusion constraints).**
  <https://www.postgresql.org/docs/current/ddl-constraints.html>. The alternative
  named in ADR 2.
- **Markus Winand, "We need tool support for keyset pagination".**
  <https://use-the-index-luke.com/no-offset>. Paging of the delivery log.

## Security guidance

- **OWASP Cheat Sheet Series, Password Storage.**
  <https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html>.
- **OWASP Cheat Sheet Series, Session Management.**
  <https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html>.
- **OWASP Cheat Sheet Series, Cross-Site Request Forgery Prevention.**
  <https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html>.
- **MDN Web Docs, Content-Security-Policy.**
  <https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Security-Policy>.

## Ideas and books

- **Token bucket.** A long-established rate-limiting algorithm from network traffic
  shaping; see for example Andrew S. Tanenbaum, "Computer Networks" (Prentice Hall).
- **Martin Kleppmann, "Designing Data-Intensive Applications", O'Reilly, 2017.**
  Race conditions between a check and a write, and why constraints belong in the
  database.
- **Michael Nygard, "Documenting Architecture Decisions", 2011.** The format of
  `docs/DECISIONS.md`.

## Browser platform

- **MDN Web Docs, Intl.DateTimeFormat.**
  <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Intl/DateTimeFormat>.
- **MDN Web Docs, the dialog element.**
  <https://developer.mozilla.org/en-US/docs/Web/HTML/Element/dialog>.
- **MDN Web Docs, CSS grid layout.**
  <https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_grid_layout>. The calendar.

## Libraries

- **React.** <https://react.dev>
- **React Router.** <https://reactrouter.com>
- **urql.** <https://github.com/urql-graphql/urql>
- **gql.tada.** <https://gql-tada.0no.co>
- **Vite.** <https://vite.dev>
- **Vitest.** <https://vitest.dev>
- **Testing Library.** <https://testing-library.com>
- **Playwright.** <https://playwright.dev>

## Conventions

- **Conventional Commits.** <https://www.conventionalcommits.org>
- **Keep a Changelog.** <https://keepachangelog.com>
- **Semantic Versioning.** <https://semver.org>
