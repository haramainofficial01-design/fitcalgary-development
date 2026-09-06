import assert from 'node:assert/strict';
import test from 'node:test';

import { open, pkceChallenge, seal } from '../lib/server-auth.ts';
import { trustedMutation } from '../lib/request-security.ts';
import { productLink } from '../lib/product-link.ts';

test('notification links only open supported internal destinations', () => {
  assert.equal(productLink('fitcalgary://submissions/abc-123'), '/submissions/abc-123');
  for (const input of ['https://evil.example', 'javascript:alert(1)', 'fitcalgary://admin/users', 'fitcalgary://events/../admin', 'fitcalgary://events/x?redirect=evil', null]) {
    assert.equal(productLink(input), undefined);
  }
});

test('cookie-authenticated writes require the exact configured origin', () => {
  const check = (method, origin, site, publicUrl = 'https://fitcalgary.example') => {
    const headers = new Headers();
    if (origin) headers.set('origin', origin);
    if (site) headers.set('sec-fetch-site', site);
    return trustedMutation({ method, headers }, publicUrl);
  };
  for (const method of ['POST', 'PUT', 'PATCH', 'DELETE']) {
    assert.equal(check(method, 'https://fitcalgary.example', 'same-origin'), true);
    assert.equal(check(method, 'https://evil.example', 'cross-site'), false);
    assert.equal(check(method, 'https://fitcalgary.example.evil.example'), false);
    assert.equal(check(method, 'https://fitcalgary.example:8443'), false);
    assert.equal(check(method, 'http://fitcalgary.example'), false);
    assert.equal(check(method, 'https://fitcalgary.example', 'cross-site'), false);
    assert.equal(check(method, 'https://fitcalgary.example/path'), false);
    assert.equal(check(method, 'null'), false);
    assert.equal(check(method, undefined), false);
    assert.equal(check(method, 'https://fitcalgary.example', undefined, ''), false);
  }
  assert.equal(check('POST', 'http://localhost:3000', 'same-origin', 'http://localhost:3000'), true);
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
  assert.equal(await pkceChallenge(verifier), 'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM');
});
