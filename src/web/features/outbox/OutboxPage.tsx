import { useState } from 'react';
import { Send } from 'lucide-react';
import { useMutation, useQuery } from 'urql';
import { useToast } from '../../components/overlays';
import { Badge, Banner, Button, EmptyState, ErrorState, Skeleton } from '../../components/ui';
import { OutboxQuery, SendQueuedMailMutation } from '../../graphql/operations';
import { readFailure, summarize } from '../../lib/errors';
import { useWorkspace } from '../auth/session';

const STATUS = {
  QUEUED: { tone: 'accent', label: 'Queued' },
  SENT: { tone: 'success', label: 'Sent' },
  SKIPPED: { tone: 'neutral', label: 'Not sent' },
} as const;

const KIND_LABELS = {
  CONFIRMATION: 'Confirmation',
  CHANGE: 'Change',
  CANCELLATION: 'Cancellation',
} as const;

const timeFormat = new Intl.DateTimeFormat(undefined, { dateStyle: 'medium', timeStyle: 'short' });

/** One page of the log. The parent renders one per cursor, so "Load more" appends. */
function DeliveryPage({
  after,
  isLast,
  onLoadMore,
}: {
  after: string | null;
  isLast: boolean;
  onLoadMore: (cursor: string) => void;
}) {
  const [{ data, fetching, error }, refetch] = useQuery({
    query: OutboxQuery,
    variables: { after },
  });
  const page = data?.workspace.deliveries;

  if (fetching && !page) {
    return (
      <li className="list__item">
        <Skeleton lines={3} label="Loading messages" />
      </li>
    );
  }
  if (error && !page) {
    return (
      <li>
        <ErrorState
          message={readFailure(error)?.message ?? 'Please try again.'}
          onRetry={() => {
            refetch({ requestPolicy: 'network-only' });
          }}
        />
      </li>
    );
  }
  if (!page) return null;
  if (page.items.length === 0 && after === null) {
    return (
      <li>
        <EmptyState title="No messages yet">
          Messages appear here when a booking is made, changed or cancelled.
        </EmptyState>
      </li>
    );
  }

  return (
    <>
      {page.items.map((delivery) => (
        <li key={delivery.id} className="list__item">
          <details className="grow">
            <summary>
              <strong>{delivery.subject}</strong>{' '}
              <span className="small muted">
                to {delivery.toEmail} · {timeFormat.format(new Date(delivery.createdAt))}
              </span>
            </summary>
            <div className="stack" style={{ paddingTop: 'var(--space-3)' }}>
              <p className="preview">{delivery.body}</p>
              {delivery.calendarFile ? (
                <details>
                  <summary className="small">Attached calendar file</summary>
                  <pre className="preview mono">{delivery.calendarFile}</pre>
                </details>
              ) : null}
            </div>
          </details>
          <div className="row">
            <Badge>{KIND_LABELS[delivery.kind]}</Badge>
            <Badge tone={STATUS[delivery.status].tone}>{STATUS[delivery.status].label}</Badge>
          </div>
          {delivery.skipReason ? (
            <p className="small muted" style={{ flexBasis: '100%' }}>
              {delivery.skipReason}
            </p>
          ) : null}
        </li>
      ))}
      {isLast && page.hasNextPage && page.endCursor ? (
        <li className="list__item row--end">
          <Button
            onClick={() => {
              if (page.endCursor) onLoadMore(page.endCursor);
            }}
          >
            Load more
          </Button>
        </li>
      ) : null}
    </>
  );
}

export function OutboxPage() {
  const workspace = useWorkspace();
  const toast = useToast();
  const [cursors, setCursors] = useState<(string | null)[]>([null]);
  const [round, setRound] = useState(0);
  const [{ data }, refetch] = useQuery({ query: OutboxQuery, variables: { after: null } });
  const [sending, sendQueued] = useMutation(SendQueuedMailMutation);
  const [failure, setFailure] = useState<string | null>(null);
  // Undefined until the first answer arrives, so the button never claims "0" early.
  const queued = data?.workspace.queuedDeliveries;

  const send = async (): Promise<void> => {
    setFailure(null);
    const result = await sendQueued({});
    const problem = readFailure(result.error);
    if (problem) {
      setFailure(summarize(problem));
      return;
    }
    const outcome = result.data?.sendQueuedMail;
    toast(
      outcome && outcome.remaining > 0
        ? `Sent ${String(outcome.sent)}. ${String(outcome.remaining)} still queued by the rate limit.`
        : `Sent ${String(outcome?.sent ?? 0)}. Nothing is queued.`,
    );
    setCursors([null]);
    setRound((current) => current + 1);
    refetch({ requestPolicy: 'network-only' });
  };

  return (
    <div className="stack stack--loose">
      <div className="row row--between">
        <div className="stack stack--tight">
          <h1>Messages</h1>
          <p className="muted">
            Every message {workspace.name} sent or decided not to send. In this demo nothing leaves
            the server: "sent" means it reached this log.
          </p>
        </div>
        <Button
          variant="primary"
          disabled={!queued}
          busy={sending.fetching}
          onClick={() => {
            void send();
          }}
        >
          <Send aria-hidden="true" />
          Send queued now{queued === undefined ? '' : ` (${String(queued)})`}
        </Button>
      </div>
      {failure ? (
        <Banner tone="danger" role="alert">
          {failure}
        </Banner>
      ) : null}
      <div className="card card--flush">
        <ul className="list" aria-label="Messages">
          {cursors.map((cursor, index) => (
            <DeliveryPage
              key={`${String(round)}-${cursor ?? 'first'}`}
              after={cursor}
              isLast={index === cursors.length - 1}
              onLoadMore={(next) => {
                setCursors((current) => [...current, next]);
              }}
            />
          ))}
        </ul>
      </div>
    </div>
  );
}
