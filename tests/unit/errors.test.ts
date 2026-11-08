import { describe, expect, it } from 'vitest';
import type { CombinedError } from 'urql';
import { issuesByField, readFailure, summarize } from '../../src/web/lib/errors';

const graphQLFailure = (extensions: Record<string, unknown>, message = 'Nope'): CombinedError =>
  ({ graphQLErrors: [{ message, extensions }] }) as unknown as CombinedError;

describe('readFailure', () => {
  it('returns null when nothing failed', () => {
    expect(readFailure(undefined)).toBeNull();
  });

  it('reports a network failure when no GraphQL error arrived', () => {
    expect(readFailure({ graphQLErrors: [] } as unknown as CombinedError)).toMatchObject({
      code: 'NETWORK',
      issues: [],
    });
  });

  it('reads the code, message and well-formed issues', () => {
    const failure = readFailure(
      graphQLFailure({
        code: 'VALIDATION',
        issues: [
          { field: 'startsAt', message: 'Too early.' },
          { field: null, message: 'General.' },
          { field: 7, message: 'Wrong field type.' },
          'not an issue',
          null,
        ],
      }),
    );
    expect(failure).toEqual({
      code: 'VALIDATION',
      message: 'Nope',
      issues: [
        { field: 'startsAt', message: 'Too early.' },
        { field: null, message: 'General.' },
      ],
    });
  });

  it('falls back to INTERNAL when the code is missing or malformed', () => {
    expect(readFailure(graphQLFailure({}))).toMatchObject({ code: 'INTERNAL', issues: [] });
    expect(readFailure(graphQLFailure({ code: 42, issues: 'oops' }))).toMatchObject({
      code: 'INTERNAL',
      issues: [],
    });
  });
});

describe('issuesByField', () => {
  it('groups messages per field and leaves out general issues', () => {
    const grouped = issuesByField([
      { field: 'startsAt', message: 'One.' },
      { field: null, message: 'General.' },
      { field: 'startsAt', message: 'Two.' },
      { field: 'reason', message: 'Three.' },
    ]);
    expect([...grouped.entries()]).toEqual([
      ['startsAt', ['One.', 'Two.']],
      ['reason', ['Three.']],
    ]);
  });
});

describe('summarize', () => {
  it('prefers the first specific issue over the general message', () => {
    expect(
      summarize({
        code: 'VALIDATION',
        message: 'Invalid.',
        issues: [{ field: 'a', message: 'Too long.' }],
      }),
    ).toBe('Too long.');
    expect(summarize({ code: 'CONFLICT', message: 'Taken.', issues: [] })).toBe('Taken.');
  });
});
