import { useState } from 'react';
import { BellRing, Building2, CalendarClock, Gauge } from 'lucide-react';
import { useNavigate } from 'react-router';
import { ThemeToggle } from '../../components/ThemeToggle';
import { Banner, Button } from '../../components/ui';
import { homePath, isFailure, useSession } from '../auth/session';
import { Brand } from '../shell/AppShell';

/** Demo accounts seeded by the server. They are fictional and documented in the README. */
export const DEMO_PASSWORD = 'practice-demo';
export const DEMO_ACCOUNTS = [
  {
    role: 'Admin',
    email: 'odile@example.com',
    can: 'everything, and is a student at a second school',
  },
  { role: 'Staff', email: 'bram@example.com', can: 'book, move, cancel and check in for anyone' },
  { role: 'Student', email: 'suvi@example.com', can: 'book rooms for herself' },
  { role: 'New student', email: 'teo@example.com', can: 'book, after giving two details once' },
] as const;

const FEATURES = [
  {
    icon: CalendarClock,
    title: 'Bookings that cannot collide',
    text: 'Database triggers refuse two bookings of one room at the same time, however many requests arrive at once.',
  },
  {
    icon: BellRing,
    title: 'Messages as a system',
    text: 'Editable templates with checked merge tags, a calendar file on every message, and unsubscribe links that work without signing in.',
  },
  {
    icon: Gauge,
    title: 'A rate limit that drops nothing',
    text: 'Outgoing mail passes a token bucket. What cannot go now stays queued in a visible log and goes later.',
  },
  {
    icon: Building2,
    title: 'Schools kept apart',
    text: 'Every query runs inside one workspace and fails closed without one. Students see that a room is taken, not by whom.',
  },
] as const;

export function LandingPage() {
  const { viewer, signIn } = useSession();
  const navigate = useNavigate();
  const [busy, setBusy] = useState<string | null>(null);
  const [failure, setFailure] = useState<string | null>(null);

  const open = async (email: string): Promise<void> => {
    setBusy(email);
    setFailure(null);
    const result = await signIn(email, DEMO_PASSWORD);
    setBusy(null);
    if (isFailure(result)) {
      setFailure(result.message);
      return;
    }
    await navigate(homePath(result));
  };

  return (
    <>
      <header className="shell__header">
        <div className="shell__bar row--between">
          <Brand />
          <div className="row">
            <ThemeToggle />
            {viewer ? (
              <Button
                variant="primary"
                onClick={() => {
                  void navigate(homePath(viewer));
                }}
              >
                Open the calendar
              </Button>
            ) : (
              <Button
                onClick={() => {
                  void navigate('/login');
                }}
              >
                Sign in
              </Button>
            )}
          </div>
        </div>
      </header>
      <main id="main" className="page rise-in">
        <section className="hero">
          <p className="eyebrow">A portfolio demo</p>
          <h1 className="hero__title">A room to practise in, held for you.</h1>
          <p className="hero__lead">
            Room Booking is a small product for a fictional music school. Students book rehearsal
            rooms, staff look after the day, and everyone gets the right message at the right time.
            It exists to show a Rails GraphQL API and a typed React front end working on time,
            concurrency and notifications.
          </p>
        </section>

        <section className="stack stack--loose" aria-labelledby="demo-heading">
          <div className="card stack">
            <h2 id="demo-heading">Open the demo</h2>
            <p className="muted">
              The data is seeded and fictional. Pick a role to sign in. Every account uses the
              password <code>{DEMO_PASSWORD}</code>.
            </p>
            {failure ? (
              <Banner tone="danger" role="alert">
                {failure}
              </Banner>
            ) : null}
            <div className="row">
              {DEMO_ACCOUNTS.map((account) => (
                <Button
                  key={account.email}
                  variant={account.role === 'Admin' ? 'primary' : 'default'}
                  busy={busy === account.email}
                  disabled={busy !== null}
                  onClick={() => {
                    void open(account.email);
                  }}
                >
                  Continue as {account.role.toLowerCase()}
                </Button>
              ))}
            </div>
            <dl className="definition small">
              {DEMO_ACCOUNTS.map((account) => (
                <div key={account.email} style={{ display: 'contents' }}>
                  <dt>{account.role}</dt>
                  <dd>
                    <code>{account.email}</code>, can {account.can}
                  </dd>
                </div>
              ))}
            </dl>
          </div>

          <div className="feature-grid">
            {FEATURES.map((feature) => (
              <article key={feature.title} className="card stack stack--tight">
                <feature.icon aria-hidden="true" />
                <h3>{feature.title}</h3>
                <p className="muted small">{feature.text}</p>
              </article>
            ))}
          </div>
        </section>
      </main>
    </>
  );
}
