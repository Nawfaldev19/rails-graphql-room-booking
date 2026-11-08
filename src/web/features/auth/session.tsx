import { createContext, use, useMemo } from 'react';
import type { ReactNode } from 'react';
import { Navigate, Outlet, useLocation, useParams } from 'react-router';
import { Context as GraphQLClientContext, useClient, useQuery } from 'urql';
import { ErrorState, Skeleton } from '../../components/ui';
import { createClient } from '../../graphql/client';
import { LoginMutation, LogoutMutation, ViewerQuery } from '../../graphql/operations';
import type { ResultOf } from '../../graphql/tada';
import { readFailure } from '../../lib/errors';
import type { ApiFailure } from '../../lib/errors';

type Viewer = NonNullable<ResultOf<typeof ViewerQuery>['viewer']>;
type Membership = Viewer['memberships'][number];

interface Session {
  viewer: Viewer | null;
  loading: boolean;
  failure: ApiFailure | null;
  signIn: (email: string, password: string) => Promise<Viewer | ApiFailure>;
  signOut: () => Promise<void>;
}

const SessionContext = createContext<Session | null>(null);

/**
 * Holds "who is signed in" for the whole app. It uses the root GraphQL client,
 * so the answer stays the same whichever workspace's client a page is using.
 */
export function SessionHost({ children }: { children: ReactNode }) {
  const client = useClient();
  const [{ data, fetching, error }] = useQuery({ query: ViewerQuery });

  const session = useMemo<Session>(() => {
    const refresh = async (): Promise<Viewer | null> => {
      const result = await client
        .query(ViewerQuery, {}, { requestPolicy: 'network-only' })
        .toPromise();
      return result.data?.viewer ?? null;
    };
    return {
      viewer: data?.viewer ?? null,
      loading: fetching && !data,
      failure: data ? null : readFailure(error),
      signIn: async (email, password) => {
        const result = await client.mutation(LoginMutation, { email, password }).toPromise();
        const failure = readFailure(result.error);
        if (failure) return failure;
        const viewer = await refresh();
        return viewer ?? { code: 'INTERNAL', message: 'Sign-in did not complete.', issues: [] };
      },
      signOut: async () => {
        await client.mutation(LogoutMutation, {}).toPromise();
        await refresh();
      },
    };
  }, [client, data, fetching, error]);

  return <SessionContext value={session}>{children}</SessionContext>;
}

export function useSession(): Session {
  const session = use(SessionContext);
  if (!session) throw new Error('useSession must be used inside SessionHost.');
  return session;
}

const ROLE_RANK = { ADMIN: 0, STAFF: 1, STUDENT: 2 } as const;

/**
 * Where to take someone after signing in: the workspace in which they hold the
 * most responsibility, which is where they most likely have work to do.
 */
export function homePath(viewer: Viewer): string {
  const [home] = [...viewer.memberships].sort((a, b) => ROLE_RANK[a.role] - ROLE_RANK[b.role]);
  return home ? `/w/${home.workspace.id}/calendar` : '/';
}

export function isFailure(value: Viewer | ApiFailure): value is ApiFailure {
  return 'code' in value;
}

export interface WorkspaceContextValue {
  id: string;
  name: string;
  /** The school's IANA time zone. Opening hours and days are shown in it. */
  timeZone: string;
  membershipId: string;
  role: Membership['role'];
  /** Staff and admins manage bookings for everyone. */
  isStaff: boolean;
  isAdmin: boolean;
  viewer: Viewer;
}

const WorkspaceContext = createContext<WorkspaceContextValue | null>(null);

export function useWorkspace(): WorkspaceContextValue {
  const workspace = use(WorkspaceContext);
  if (!workspace) throw new Error('useWorkspace must be used inside a workspace route.');
  return workspace;
}

/**
 * Guards every /w/:workspaceId page and gives it a GraphQL client of its own.
 * Signed-out visitors go to the sign-in page; a workspace the viewer is not a
 * member of shows "not found". The API enforces both rules as well.
 */
export function WorkspaceRoute({ shell }: { shell: (content: ReactNode) => ReactNode }) {
  const { viewer, loading, failure } = useSession();
  const { workspaceId = '' } = useParams();
  const location = useLocation();
  const client = useMemo(() => createClient(workspaceId), [workspaceId]);

  if (loading) {
    return (
      <main className="page">
        <Skeleton lines={5} label="Checking your session" />
      </main>
    );
  }
  if (failure && !viewer) {
    return (
      <main className="page">
        <ErrorState message={failure.message} />
      </main>
    );
  }
  if (!viewer) {
    return <Navigate to="/login" replace state={{ from: location.pathname }} />;
  }

  const membership = viewer.memberships.find((item) => item.workspace.id === workspaceId);
  if (!membership) {
    return (
      <main className="page">
        <ErrorState
          title="Workspace not found"
          message="It does not exist, or you are not a member of it."
        />
      </main>
    );
  }

  const value: WorkspaceContextValue = {
    id: membership.workspace.id,
    name: membership.workspace.name,
    timeZone: membership.workspace.timeZone,
    membershipId: membership.id,
    role: membership.role,
    isStaff: membership.role !== 'STUDENT',
    isAdmin: membership.role === 'ADMIN',
    viewer,
  };
  return (
    <GraphQLClientContext value={client}>
      <WorkspaceContext value={value}>{shell(<Outlet />)}</WorkspaceContext>
    </GraphQLClientContext>
  );
}
