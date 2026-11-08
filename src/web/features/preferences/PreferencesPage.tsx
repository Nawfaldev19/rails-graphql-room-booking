import { useEffect, useState } from 'react';
import { useParams } from 'react-router';
import { useMutation, useQuery } from 'urql';
import { ThemeToggle } from '../../components/ThemeToggle';
import { Banner, Button, ErrorState, Skeleton } from '../../components/ui';
import { PreferencesQuery, UpdatePreferencesMutation } from '../../graphql/operations';
import type { ResultOf } from '../../graphql/tada';
import { readFailure } from '../../lib/errors';
import { Brand } from '../shell/AppShell';

type Preference = ResultOf<
  typeof PreferencesQuery
>['notificationPreferences']['preferences'][number];

const DESCRIPTIONS: Readonly<Record<Preference['kind'], string>> = {
  CONFIRMATION: 'When a room is booked for me',
  CHANGE: 'When one of my bookings is moved',
  CANCELLATION: 'When one of my bookings is cancelled',
};

/**
 * The page behind the link at the foot of every message. It needs no sign-in:
 * the signed token in the address says whose choices these are.
 */
export function PreferencesPage() {
  const { token = '' } = useParams();
  const [{ data, fetching, error }] = useQuery({ query: PreferencesQuery, variables: { token } });
  const [saving, update] = useMutation(UpdatePreferencesMutation);
  const [choices, setChoices] = useState<Preference[]>([]);
  const [saved, setSaved] = useState(false);
  const [failure, setFailure] = useState<string | null>(null);

  const loaded = data?.notificationPreferences.preferences;
  useEffect(() => {
    if (loaded) setChoices(loaded.map((item) => ({ kind: item.kind, enabled: item.enabled })));
  }, [loaded]);

  const submit = async (event: { preventDefault(): void }): Promise<void> => {
    event.preventDefault();
    setFailure(null);
    setSaved(false);
    const result = await update({ token, preferences: choices });
    const problem = readFailure(result.error);
    if (problem) setFailure(problem.message);
    else setSaved(true);
  };

  return (
    <>
      <header className="shell__header">
        <div className="shell__bar row--between">
          <Brand />
          <ThemeToggle />
        </div>
      </header>
      <main id="main" className="page page--narrow rise-in">
        {fetching && !data ? <Skeleton lines={5} label="Loading your choices" /> : null}
        {!data && !fetching ? (
          <ErrorState
            title={
              readFailure(error)?.code === 'NOT_FOUND'
                ? 'This link is not valid'
                : 'Something went wrong'
            }
            message="Use the link at the foot of a recent message from the school."
          />
        ) : null}
        {data ? (
          <form
            className="card stack"
            onSubmit={(event) => {
              void submit(event);
            }}
          >
            <div className="stack stack--tight">
              <p className="eyebrow">{data.notificationPreferences.workspaceName}</p>
              <h1>Messages for {data.notificationPreferences.personName}</h1>
              <p className="muted">Choose which emails you want about your room bookings.</p>
            </div>
            {failure ? (
              <Banner tone="danger" role="alert">
                {failure}
              </Banner>
            ) : null}
            {saved ? <Banner tone="success">Saved. Your choices apply from now on.</Banner> : null}
            <fieldset className="stack" style={{ border: 0, padding: 0, margin: 0 }}>
              <legend className="sr-only">Emails to receive</legend>
              {choices.map((choice) => (
                <label key={choice.kind} className="check">
                  <input
                    type="checkbox"
                    checked={choice.enabled}
                    onChange={(event) => {
                      setSaved(false);
                      setChoices((current) =>
                        current.map((item) =>
                          item.kind === choice.kind
                            ? { ...item, enabled: event.target.checked }
                            : item,
                        ),
                      );
                    }}
                  />
                  <span>{DESCRIPTIONS[choice.kind]}</span>
                </label>
              ))}
            </fieldset>
            <div className="row row--between">
              <Button
                onClick={() => {
                  setSaved(false);
                  setChoices((current) => current.map((item) => ({ ...item, enabled: false })));
                }}
              >
                Turn everything off
              </Button>
              <Button type="submit" variant="primary" busy={saving.fetching}>
                Save my choices
              </Button>
            </div>
          </form>
        ) : null}
      </main>
    </>
  );
}
