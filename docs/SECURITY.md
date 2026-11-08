# Security

This document describes what Room Booking protects, from whom, and how. It also lists
what it does not protect.

## What is worth protecting

| Asset                                       | Why it matters                                          |
| ------------------------------------------- | ------------------------------------------------------- |
| A school's bookings, notes and delivery log | Private to that school; they show who is where and when |
| Who booked a room, and why                  | Students may see that a room is taken, not by whom      |
| Phone numbers and email addresses           | Personal details                                        |
| Sessions and passwords                      | They open everything a person may do                    |
| A person's message preferences              | Only that person should change them                     |

## Who might attack

| Actor                               | Starting point                                                 |
| ----------------------------------- | -------------------------------------------------------------- |
| Anonymous visitor                   | Can reach the API, guess passwords and guess unsubscribe links |
| Student                             | A valid session, and curiosity about other people's bookings   |
| Staff member                        | Wide access in one school, none in another                     |
| Member of another school            | A valid session and knowledge of how the API works             |
| Admin writing templates             | Could try to make a template reveal data                       |
| Someone with a copy of the database | A leaked backup                                                |

## Threats and controls

| Threat                                               | Control                                                                                                         | Where                                                                       |
| ---------------------------------------------------- | --------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------- |
| A query returns another school's rows                | Tenant models are scoped to the current workspace by default and raise without one                              | `app/models/concerns/tenant_scoped.rb`                                      |
| A row is attached to another school's room or person | Composite foreign keys on `(workspace_id, id)`                                                                  | `db/migrate`                                                                |
| Probing for another school's ids                     | A non-member gets `NOT_FOUND`, the same answer as for a missing workspace; so do mutations with foreign ids     | `app/controllers/graphql_controller.rb`                                     |
| A student learns who booked a room                   | Name, note, reason and calendar file are `null` unless the viewer is the person or staff                        | `app/graphql/types/booking_type.rb`                                         |
| A student acts on someone else's booking             | The booking is reported as not found                                                                            | `app/services/bookings/actions.rb`                                          |
| A student uses staff features                        | Role checked in the resolver or service, not only hidden in the menu                                            | `app/graphql/guards.rb`                                                     |
| Two requests book the same slot                      | Database triggers; one request gets `CONFLICT`                                                                  | `db/migrate`                                                                |
| A stale edit overwrites a newer one                  | Optimistic locking with `lock_version`                                                                          | `app/services/bookings/actions.rb`                                          |
| Password guessing                                    | bcrypt; eight attempts per minute for one address and email; equal work for unknown emails                      | `app/services/auth/sign_in.rb`                                              |
| Finding out which emails have accounts               | One message for both failures, and a decoy hash check                                                           | `app/services/auth/sign_in.rb`                                              |
| Session theft through script                         | `HttpOnly` cookie; a Content-Security-Policy with no inline scripts                                             | `app/graphql/mutations/login.rb`, `config/application.rb`                   |
| Cross-site request forgery                           | `SameSite=Lax` cookie; the endpoint accepts only `application/json` bodies, which a cross-site form cannot send | `app/controllers/graphql_controller.rb`                                     |
| A database copy is used to sign in                   | Only SHA-256 digests of session tokens are stored                                                               | `app/models/session.rb`                                                     |
| Changing someone else's message preferences          | The link carries a signed membership id with a fixed purpose; a forged or altered token is refused              | `app/services/notifications/unsubscribe_token.rb`                           |
| A template reveals data or runs code                 | The renderer substitutes a fixed list of tags and nothing else; unknown tags are refused on save                | `app/services/notifications/template_renderer.rb`                           |
| Injection into calendar files                        | Text is escaped as RFC 5545 requires                                                                            | `app/services/notifications/calendar_file.rb`                               |
| An expensive query                                   | Limits on depth, complexity, page size and the calendar period                                                  | `app/graphql/room_booking_schema.rb`, `app/graphql/types/workspace_type.rb` |
| A mail burst                                         | A token bucket per school, shared through the database                                                          | `app/services/notifications/outbox.rb`                                      |
| SQL injection                                        | Active Record with bound parameters throughout; the one SQL string in `app/` takes its values as named binds    | `app/graphql/cursor.rb`                                                     |
| Internal details leak through errors                 | Only `ApiError` reaches the client; anything else is logged and answered generically                            | `app/controllers/graphql_controller.rb`                                     |
| Personal details in logs                             | Passwords, tokens, emails and phone numbers are filtered from logged parameters                                 | `config/initializers/filter_parameter_logging.rb`                           |
| Clickjacking and referrer leaks                      | `frame-ancestors 'none'`, `X-Frame-Options`, `Referrer-Policy: no-referrer`                                     | `config/application.rb`                                                     |

Nearly every control has a spec that fails if the control is removed;
[TESTING.md](TESTING.md) describes them. The ones that rest on review are bound
parameters and log filtering.

## How a request is authorized

1. The session cookie's token is hashed and looked up. No session means no user.
2. If the request names a workspace, the user's membership of it is read. No
   membership: `NOT_FOUND`, and the operation does not run.
3. The whole operation runs inside `Tenancy.with(workspace)`. From here every tenant
   model sees only that workspace.
4. Guards in the schema (`actor!`, `staff!`, `admin!`) and `Bookings::Policy` decide
   what this person may do and see.

Steps 3 and 4 are independent: a missing guard still cannot reach another school.

The preferences page is the one public path into tenant data. It has no user. The
signed token names one membership, and the resolver enters that membership's
workspace to read or write only that person's preferences.

## Secrets and configuration

In development and test, Rails generates its own signing secret under `tmp/`. In
production `SECRET_KEY_BASE` must be set; `.env.example` names it. The container
image generates one on first start if none is given and keeps it in its data volume. No secret is committed: the generated credentials file and master key
were removed, because nothing uses them. The demo password in the README belongs to
fictional seed accounts and is published on purpose.

## What is not covered

- **Email verification, password reset and second factors.** Accounts come from seed
  data.
- **Unsubscribe links do not expire**, by design: a link in an old message must
  still work. Anyone who obtains a message can change that person's message
  preferences, and nothing else.
- **Rotating the signing secret** invalidates all unsubscribe links. A real system
  would rotate keys with an overlap period.
- **Transport security.** The server speaks plain HTTP and expects TLS in front of
  it; `FORCE_SSL=true` then marks cookies secure.
- **Sign-in rate limits are per process** and reset on restart.
- **Staff can read every note and every message of their school.** That is the
  product's intent, and it is a trust decision a real school would have to make.
- **Data retention.** Nothing is deleted, and there is no export or erasure for a
  person's data.
- **Dependency monitoring.** `npm audit` reported no known issues when this was
  written; nothing checks gems or packages continuously.

## Reporting a problem

This is a demo with no deployment. If you find a flaw, open an issue on the
repository.
