import assert from 'node:assert/strict';
import test from 'node:test';

import {
  clearTransaction,
  exchangeAuthorizationCode,
  open,
  parseTokenResponse,
  pkceChallenge,
  refreshSession,
  safeReturnTo,
  seal,
  SessionExpiredError,
  transactionCookie,
} from '../lib/server-auth.ts';
import { trustedMutation } from '../lib/request-security.ts';
import { productLink } from '../lib/product-link.ts';

test('sign-in transactions are cleared on the original cookie path', () => {
  let deletion;
  clearTransaction({
    cookies: {
      set: (...args) => {
        deletion = args;
      },
    },
  });
  assert.equal(deletion[0], transactionCookie);
  assert.equal(deletion[1], '');
  assert.equal(deletion[2].path, '/api/auth');
  assert.equal(deletion[2].maxAge, 0);
  assert.equal(deletion[2].httpOnly, true);
  assert.equal(deletion[2].secure, true);
});

test('notification links only open supported internal destinations', () => {
  assert.equal(
    productLink('fitcalgary://submissions/abc-123'),
    '/submissions/abc-123',
  );
  for (const input of [
    'https://evil.example',
    'javascript:alert(1)',
    'fitcalgary://admin/users',
    'fitcalgary://events/../admin',
    'fitcalgary://events/x?redirect=evil',
    null,
  ]) {
    assert.equal(productLink(input), undefined);
  }
});

test('cookie-authenticated writes require the exact configured origin', () => {
  const check = (
    method,
    origin,
    site,
    publicUrl = 'https://fitcalgary.example',
  ) => {
    const headers = new Headers();
    if (origin) headers.set('origin', origin);
    if (site) headers.set('sec-fetch-site', site);
    return trustedMutation({ method, headers }, publicUrl);
  };
  for (const method of ['POST', 'PUT', 'PATCH', 'DELETE']) {
    assert.equal(
      check(method, 'https://fitcalgary.example', 'same-origin'),
      true,
    );
    assert.equal(check(method, 'https://evil.example', 'cross-site'), false);
    assert.equal(
      check(method, 'https://fitcalgary.example.evil.example'),
      false,
    );
    assert.equal(check(method, 'https://fitcalgary.example:8443'), false);
    assert.equal(check(method, 'http://fitcalgary.example'), false);
    assert.equal(
      check(method, 'https://fitcalgary.example', 'cross-site'),
      false,
    );
    assert.equal(check(method, 'https://fitcalgary.example/path'), false);
    assert.equal(check(method, 'null'), false);
    assert.equal(check(method, undefined), false);
    assert.equal(
      check(method, 'https://fitcalgary.example', undefined, ''),
      false,
    );
  }
  assert.equal(
    check(
      'POST',
      'http://localhost:3000',
      'same-origin',
      'http://localhost:3000',
    ),
    true,
  );
  assert.equal(check('GET', undefined), true);
});

test('web session is encrypted, authenticated, and bound to its secret', async () => {
  const secret = 'phase-1-session-secret-at-least-32-bytes';
  const session = {
    accessToken: 'not-a-real-access-token',
    refreshToken: 'not-a-real-refresh-token',
    expiresAt: 1_800_000_000_000,
  };
  const sealed = await seal(session, secret);

  assert.equal(sealed.includes(session.accessToken), false);
  assert.deepEqual(await open(sealed, secret), session);
  assert.equal(await open(sealed, `${secret}-wrong`), null);

  const [iv, ciphertext] = sealed.split('.');
  const tampered = `${iv}.${ciphertext.startsWith('A') ? 'B' : 'A'}${ciphertext.slice(1)}`;
  assert.equal(await open(tampered, secret), null);
});

test('PKCE challenge matches the RFC 7636 S256 example', async () => {
  const verifier = 'dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk';
  assert.equal(
    await pkceChallenge(verifier),
    'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM',
  );
});

test('sign-in return paths cannot escape the website origin', () => {
  assert.equal(safeReturnTo('/profile?tab=results'), '/profile?tab=results');
  for (const value of [
    null,
    '',
    'https://evil.example',
    '//evil.example',
    '/\\evil.example',
    '/profile\nLocation: https://evil.example',
  ]) {
    assert.equal(safeReturnTo(value), '/');
  }
});

test('token exchange and refresh reject malformed successful responses', () => {
  assert.deepEqual(
    parseTokenResponse({ access_token: 'signed-token', expires_in: 300 }),
    {
      accessToken: 'signed-token',
      expiresIn: 300,
      refreshToken: undefined,
      idToken: undefined,
    },
  );
  for (const value of [
    null,
    {},
    { expires_in: 300 },
    { access_token: '', expires_in: 300 },
    { access_token: '   ' },
    { access_token: 'signed-token', expires_in: '300' },
    { access_token: 'signed-token', expires_in: -1 },
    { access_token: 'signed-token', refresh_token: 42 },
  ]) {
    assert.throws(
      () => parseTokenResponse(value),
      /Authentication response invalid/,
    );
  }
});

test('authorization exchange bounds network waits and rejects outages or invalid tokens', async () => {
  const originalFetch = globalThis.fetch;
  const names = [
    'OIDC_ISSUER',
    'OIDC_WEB_CLIENT_ID',
    'WEB_PUBLIC_URL',
    'API_BASE_URL',
    'SESSION_COOKIE_SECRET',
  ];
  const original = Object.fromEntries(
    names.map((name) => [name, process.env[name]]),
  );
  try {
    Object.assign(process.env, {
      OIDC_ISSUER: 'https://identity.example',
      OIDC_WEB_CLIENT_ID: 'fitcalgary-web',
      WEB_PUBLIC_URL: 'https://fitcalgary.example',
      API_BASE_URL: 'https://api.example',
      SESSION_COOKIE_SECRET: 'unit-test-secret',
    });
    globalThis.fetch = async (_url, options) => {
      assert.ok(options.signal instanceof AbortSignal);
      assert.equal(options.body.get('code_verifier'), 'verifier');
      assert.equal(
        options.body.get('redirect_uri'),
        'https://fitcalgary.example/api/auth/callback',
      );
      return Response.json({
        access_token: 'test-only-token',
        expires_in: 300,
      });
    };
    assert.equal(
      (await exchangeAuthorizationCode('code', 'verifier')).accessToken,
      'test-only-token',
    );
    globalThis.fetch = async () => {
      throw new TypeError('Network unavailable');
    };
    await assert.rejects(
      exchangeAuthorizationCode('code', 'verifier'),
      /Network unavailable/,
    );
    globalThis.fetch = async () => new Response(null, { status: 503 });
    await assert.rejects(
      exchangeAuthorizationCode('code', 'verifier'),
      /Sign-in unavailable/,
    );
    globalThis.fetch = async () => Response.json({ access_token: ' ' });
    await assert.rejects(
      exchangeAuthorizationCode('code', 'verifier'),
      /Authentication response invalid/,
    );
  } finally {
    globalThis.fetch = originalFetch;
    for (const name of names) {
      if (original[name] === undefined) delete process.env[name];
      else process.env[name] = original[name];
    }
  }
});

test('missing refresh tokens are expired sessions, not service outages', async () => {
  await assert.rejects(
    refreshSession({ accessToken: 'expired', expiresAt: 0 }),
    SessionExpiredError,
  );
});

test('revoked refresh tokens expire sessions while provider outages do not', async () => {
  const originalFetch = globalThis.fetch;
  const names = [
    'OIDC_ISSUER',
    'OIDC_WEB_CLIENT_ID',
    'WEB_PUBLIC_URL',
    'API_BASE_URL',
    'SESSION_COOKIE_SECRET',
  ];
  const original = Object.fromEntries(
    names.map((name) => [name, process.env[name]]),
  );
  try {
    process.env.OIDC_ISSUER = 'https://identity.example';
    process.env.OIDC_WEB_CLIENT_ID = 'fitcalgary-web';
    process.env.WEB_PUBLIC_URL = 'https://fitcalgary.example';
    process.env.API_BASE_URL = 'https://api.example';
    process.env.SESSION_COOKIE_SECRET = 'unit-test-secret';
    const session = {
      accessToken: 'expired',
      refreshToken: 'old-refresh',
      expiresAt: 0,
    };
    globalThis.fetch = async () => new Response(null, { status: 400 });
    await assert.rejects(refreshSession(session), SessionExpiredError);
    globalThis.fetch = async () => new Response(null, { status: 503 });
    await assert.rejects(
      refreshSession(session),
      /Session refresh unavailable/,
    );
  } finally {
    globalThis.fetch = originalFetch;
    for (const name of names) {
      if (original[name] === undefined) delete process.env[name];
      else process.env[name] = original[name];
    }
  }
});
