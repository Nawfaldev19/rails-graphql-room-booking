import { Client, cacheExchange, fetchExchange } from 'urql';

/**
 * Creates a GraphQL client. The session lives in an HttpOnly cookie, so the
 * client holds no credentials.
 *
 * A client made for a workspace sends that workspace's id with every request
 * and keeps its own cache. Each workspace gets its own client, which means data
 * cached for one workspace can never be shown under another.
 */
export function createClient(workspaceId?: string): Client {
  return new Client({
    url: '/graphql',
    exchanges: [cacheExchange, fetchExchange],
    requestPolicy: 'cache-and-network',
    // Always POST with a JSON body. The API accepts nothing else, which is part
    // of its protection against cross-site requests.
    preferGetMethod: false,
    fetchOptions: {
      credentials: 'same-origin',
      headers: workspaceId ? { 'X-Workspace-Id': workspaceId } : {},
    },
  });
}
