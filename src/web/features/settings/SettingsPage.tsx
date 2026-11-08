import { useEffect, useMemo, useState } from 'react';
import { useMutation, useQuery } from 'urql';
import { useToast } from '../../components/overlays';
import { Badge, Banner, Button, ErrorState, Field, Segmented, Skeleton } from '../../components/ui';
import {
  SettingsQuery,
  TemplatePreviewQuery,
  UpdateStatusLabelsMutation,
  UpdateTemplateMutation,
} from '../../graphql/operations';
import type { ResultOf } from '../../graphql/tada';
import { issuesByField, readFailure, summarize } from '../../lib/errors';
import type { ApiFailure } from '../../lib/errors';
import { useDebounced } from '../../lib/hooks';
import { useWorkspace } from '../auth/session';

type Settings = ResultOf<typeof SettingsQuery>['workspace'];
type Template = Settings['notificationTemplates'][number];
type Kind = Template['kind'];

const KIND_LABELS: Readonly<Record<Kind, string>> = {
  CONFIRMATION: 'Confirmation',
  CHANGE: 'Change',
  CANCELLATION: 'Cancellation',
};

export function SettingsPage() {
  const workspace = useWorkspace();
  const [{ data, fetching, error }, refetch] = useQuery({ query: SettingsQuery });

  if (!workspace.isAdmin) {
    return <ErrorState title="Admins only" message="Only an admin can change these settings." />;
  }
  if (fetching && !data) return <Skeleton lines={8} label="Loading settings" />;
  if (error && !data) {
    return (
      <ErrorState
        message={readFailure(error)?.message ?? 'Please try again.'}
        onRetry={() => {
          refetch({ requestPolicy: 'network-only' });
        }}
      />
    );
  }
  if (!data) return null;

  return (
    <div className="stack stack--loose">
      <div className="stack stack--tight">
        <h1>Settings</h1>
        <p className="muted">How {data.workspace.name} words its statuses and its messages.</p>
      </div>
      <StatusLabelsForm labels={data.workspace.statusLabels} />
      <TemplateEditor
        templates={data.workspace.notificationTemplates}
        tags={data.workspace.templateTags}
      />
    </div>
  );
}

function StatusLabelsForm({ labels }: { labels: Settings['statusLabels'] }) {
  const toast = useToast();
  const [saving, updateLabels] = useMutation(UpdateStatusLabelsMutation);
  const [failure, setFailure] = useState<string | null>(null);
  const [draft, setDraft] = useState<Record<string, string>>(() =>
    Object.fromEntries(
      labels.map((item) => [item.status, item.label === item.defaultLabel ? '' : item.label]),
    ),
  );

  const submit = async (event: { preventDefault(): void }): Promise<void> => {
    event.preventDefault();
    setFailure(null);
    const result = await updateLabels({
      labels: labels.map((item) => ({ status: item.status, label: draft[item.status] ?? '' })),
    });
    const problem = readFailure(result.error);
    if (problem) setFailure(summarize(problem));
    else toast('Status names saved');
  };

  return (
    <form
      className="card stack"
      aria-labelledby="labels-heading"
      onSubmit={(event) => {
        void submit(event);
      }}
    >
      <div className="stack stack--tight">
        <h2 id="labels-heading">Status names</h2>
        <p className="muted small">
          Use your school's own words. This changes the names only: what each status does stays the
          same. Leave a box empty to use the standard word.
        </p>
      </div>
      {failure ? (
        <Banner tone="danger" role="alert">
          {failure}
        </Banner>
      ) : null}
      <div className="two-columns">
        {labels.map((item) => (
          <Field key={item.status} label={`Name for "${item.defaultLabel}"`}>
            {(control) => (
              <input
                {...control}
                className="input"
                maxLength={24}
                placeholder={item.defaultLabel}
                value={draft[item.status] ?? ''}
                onChange={(event) => {
                  setDraft((current) => ({ ...current, [item.status]: event.target.value }));
                }}
              />
            )}
          </Field>
        ))}
      </div>
      <div className="row row--end">
        <Button type="submit" variant="primary" busy={saving.fetching}>
          Save status names
        </Button>
      </div>
    </form>
  );
}

function TemplateEditor({
  templates,
  tags,
}: {
  templates: Settings['notificationTemplates'];
  tags: Settings['templateTags'];
}) {
  const toast = useToast();
  const [kind, setKind] = useState<Kind>('CONFIRMATION');
  const current = templates.find((item) => item.kind === kind);
  const [subject, setSubject] = useState(current?.subject ?? '');
  const [body, setBody] = useState(current?.body ?? '');
  const [failure, setFailure] = useState<ApiFailure | null>(null);
  const [saving, updateTemplate] = useMutation(UpdateTemplateMutation);

  // Load the chosen kind's wording into the editor when the kind changes.
  useEffect(() => {
    setSubject(current?.subject ?? '');
    setBody(current?.body ?? '');
    setFailure(null);
    // eslint-disable-next-line react-hooks/exhaustive-deps -- only the kind decides when to reload
  }, [kind]);

  const previewInput = useDebounced(useMemo(() => ({ subject, body }), [subject, body]));
  const [{ data: previewData }] = useQuery({
    query: TemplatePreviewQuery,
    variables: previewInput,
    requestPolicy: 'network-only',
  });
  const preview = previewData?.workspace.templatePreview;
  const issues = issuesByField(failure?.issues ?? []);

  const submit = async (event: { preventDefault(): void }): Promise<void> => {
    event.preventDefault();
    setFailure(null);
    const result = await updateTemplate({ kind, subject, body });
    const problem = readFailure(result.error);
    if (problem) setFailure(problem);
    else toast(`${KIND_LABELS[kind]} message saved`);
  };

  return (
    <form
      className="card stack"
      aria-labelledby="templates-heading"
      onSubmit={(event) => {
        void submit(event);
      }}
    >
      <div className="row row--between">
        <h2 id="templates-heading">Messages</h2>
        <Segmented
          label="Kind of message"
          value={kind}
          onChange={setKind}
          options={templates.map((item) => ({ value: item.kind, label: KIND_LABELS[item.kind] }))}
        />
      </div>
      {current?.isDefault ? <Badge>Standard wording, not yet changed</Badge> : null}
      {failure && failure.issues.length === 0 ? (
        <Banner tone="danger" role="alert">
          {failure.message}
        </Banner>
      ) : null}

      <div className="two-columns">
        <div className="stack">
          <Field label="Subject" errors={issues.get('subject') ?? []}>
            {(control) => (
              <input
                {...control}
                className="input"
                maxLength={150}
                value={subject}
                onChange={(event) => {
                  setSubject(event.target.value);
                }}
              />
            )}
          </Field>
          <Field label="Message" errors={issues.get('body') ?? []}>
            {(control) => (
              <textarea
                {...control}
                className="textarea"
                style={{ minHeight: 220 }}
                maxLength={4000}
                value={body}
                onChange={(event) => {
                  setBody(event.target.value);
                }}
              />
            )}
          </Field>
          <div className="stack stack--tight">
            <span className="field__label">Tags you can use</span>
            <div className="tag-list">
              {tags.map((tag) => (
                <Button
                  key={tag.name}
                  title={tag.description}
                  aria-label={`Add the tag ${tag.name} to the message: ${tag.description}`}
                  onClick={() => {
                    setBody((text) => `${text}{{${tag.name}}}`);
                  }}
                >
                  <code>{`{{${tag.name}}}`}</code>
                </Button>
              ))}
            </div>
          </div>
        </div>

        <section className="stack" aria-labelledby="preview-heading">
          <h3 id="preview-heading">Preview with sample details</h3>
          {preview && preview.problems.length > 0 ? (
            <Banner tone="warning">
              <ul style={{ margin: 0, paddingLeft: '1.2em' }}>
                {preview.problems.map((problem) => (
                  <li key={problem}>{problem}</li>
                ))}
              </ul>
            </Banner>
          ) : null}
          <div className="preview" data-testid="template-preview">
            <strong>{preview?.subject ?? subject}</strong>
            {'\n\n'}
            {preview?.body ?? body}
          </div>
        </section>
      </div>

      <div className="row row--end">
        <Button
          type="submit"
          variant="primary"
          busy={saving.fetching}
          disabled={(preview?.problems.length ?? 0) > 0}
        >
          Save this message
        </Button>
      </div>
    </form>
  );
}
