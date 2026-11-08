# Architecture decision records

Each record states the situation, the decision and what follows from it, including
the costs. They are numbered in the order they were made.

## ADR 1: Prevent overlapping bookings in the database, with triggers

**Context.** A room can hold one booking at a time. The obvious code is "look for an
overlap, and if there is none, insert". Two requests can both look, both find
nothing, and both insert.

**Decision.** Two SQLite triggers, on insert and on update, abort the statement when
another active booking of the same room intersects the new time range. The
application does not check first. It writes, and turns the trigger's error into a
`CONFLICT` for the caller.

**Rejected.** _A model validation_: it is the check-then-write race in a tidier
place. _A lock in the application_: correct in one process, wrong the day there are
two. _A unique index on room and start_: bookings have different lengths, so equal
starts are only one way to overlap.

**Consequences.** The rule holds for every writer: the API, a console session, a
future import script. A spec fires four threads at one slot and asserts that exactly
one wins. The cost is logic in SQL, outside the reach of most Ruby tooling, so it has
its own spec file that goes around the application on purpose.

## ADR 2: SQLite, for a demo that starts with one command

**Context.** The demo should run with Ruby and Node only. ADR 1 needs a database
that can enforce the overlap rule itself.

**Decision.** Use SQLite. It allows one writer at a time, which makes the trigger in
ADR 1 free of races without further locking.

**Rejected.** _Postgres_: the better tool for this exact problem (an exclusion
constraint on a time range states the rule in one line), but it needs a server or a
container to try the demo.

**Consequences.** Nothing to install, and tests run against the real engine. The
limit is one writer at a time. Moving to Postgres would replace the two triggers with
an exclusion constraint and the JSON columns with `jsonb`; the services and the
specs would stay, because they assert behaviour ("exactly one wins"), not mechanism.

## ADR 3: Tenant scoping as a default that fails closed

**Context.** Two schools share the tables. A query without a workspace filter would
show one school's bookings to the other.

**Decision.** Models that belong to a workspace include `TenantScoped`: a default
scope on the current workspace, automatic assignment on create, and a read-only
`workspace_id`. If no workspace is current, the scope raises instead of matching all
rows. The controller sets the workspace once per request, after checking membership.
Composite foreign keys repeat the rule in the database.

**Rejected.** _Passing the workspace to every query by hand_: one omission is a
breach. _A gem_: this is forty lines, and writing them shows the idea; a production
system could reasonably use a maintained library instead. _A database per school_:
out of proportion here.

**Consequences.** Forgetting to think about tenancy produces an error or an empty
result, never another school's data. Default scopes have a known cost: `unscoped`
switches them off. So `unscoped` is used nowhere, and a spec fails if it appears
under `app/`. Another spec asks the database for every table with a `workspace_id`
column and fails if its model lacks the concern.

## ADR 4: No schema file; migrations are the source of truth

**Context.** Rails keeps `db/schema.rb` and loads it to create databases. That file
is written in a Ruby DSL that cannot express triggers. The alternative format,
`structure.sql`, needs the SQLite command-line tool at load time.

**Decision.** Do not dump a schema file. Databases are created by running the
migrations, in development, in tests and in the container.

**Rejected.** _`structure.sql`_: adds a system dependency to every environment for a
schema that fits in one migration. _Creating the triggers outside migrations_: they
would be easy to forget.

**Consequences.** One place defines the schema, including the parts Rails cannot
describe. The cost grows with the number of migrations; past a few dozen,
`structure.sql` and its dependency would be the better trade.

## ADR 5: Decide per field what a viewer may see

**Context.** Students need to see that a room is taken. They should not see who took
it or why. Staff need everything.

**Decision.** `Bookings::Policy` answers both "may I act?" and "may I see details?".
The `Booking` type returns `null` for the person's name, the note, the reason and
the calendar file when the viewer is neither the person booked nor staff. Mutations
on a booking the viewer cannot see answer `NOT_FOUND`.

**Rejected.** _Two types, public and private_: doubles the schema and the client
code. _Filtering in the web app_: the data would still be in the response.

**Consequences.** One list query serves every role, and what is hidden never leaves
the server. A request spec asserts that the hidden name and note are absent from the
raw response body, not only from the parsed fields.

## ADR 6: Strict merge tags, checked when a template is saved

**Context.** Admins write the messages. A typing mistake in a tag would otherwise
reach every student's inbox as literal curly brackets.

**Decision.** A small renderer knows a fixed list of tags. Saving a template with an
unknown or unfinished tag is refused, with a message naming the tag. The editor
shows the same problems live, next to a preview filled with sample values.

**Rejected.** _A general template language_: it would let a template call methods
and reach data, which is a security problem to solve for no benefit here.
_Rendering unknown tags as empty text_: hides the mistake.

**Consequences.** A template cannot leak data or fail at send time. The cost is that
a new tag needs a code change; the list and its descriptions are in one constant.

## ADR 7: A token bucket in front of outgoing mail, with the queue in the database

**Context.** Mail services limit how fast they accept messages. A burst of bookings
must not turn into errors or lost mail.

**Decision.** Every message is first a row in `deliveries`. A job sends queued rows
while a token bucket allows it and reschedules itself when the bucket is empty. The
bucket's state is a database row, read and written in one transaction.

**Rejected.** _Sending inline in the request_: slow, and a failure would undo the
booking. _An in-memory limiter_: resets on restart and is wrong with two processes.
(Sign-in attempts do use an in-memory bucket, where both of those are acceptable.)
_Dropping what exceeds the limit_: silent loss.

**Consequences.** Mail goes out as fast as allowed, no faster, and nothing is lost
on a restart. The log doubles as the record staff read. The limiter takes its store
as an argument, so the same class and the same specs cover the memory store and the
database store.

## ADR 8: One GraphQL client per workspace in the browser

**Context.** The API learns the workspace from a header. A GraphQL client caches
results by query and variables. If the header is not part of that key, switching
school could show the previous school's cached calendar.

**Decision.** The web app creates a client for each workspace it shows. The client
sends that workspace's id with every request and has its own cache.

**Rejected.** _Adding the workspace id to every operation's variables_: works, but
relies on remembering it for every new query. _Clearing one shared cache on switch_:
relies on remembering to clear it.

**Consequences.** Cross-workspace cache bleed is impossible by construction. The
session (who is signed in) lives above the workspace clients in its own context, so
signing in and out is seen everywhere.

## ADR 9: Compute time-zone conversions in the browser with the Intl API

**Context.** The calendar shows a school's day in the school's time zone, which may
differ from the viewer's. Slots are wall-clock times; the API takes UTC instants.

**Decision.** A small module converts both ways using `Intl.DateTimeFormat` with a
`timeZone`. To go from wall-clock time to an instant it guesses, reads back what the
zone's clock shows, and corrects by the difference.

**Rejected.** _A date library with time-zone data_: tens of kilobytes for two
functions. _Doing all conversion on the server_: every click on the grid would need
a round trip.

**Consequences.** No dependency, and the browser's own zone data is used, which is
kept current by the browser. Unit tests cover both directions of clock change in two
zones and a zone with a half-hour offset. The cost is forty lines of careful code
that must be read with their tests.
