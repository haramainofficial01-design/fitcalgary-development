import assert from 'node:assert/strict';
import test from 'node:test';

import { open, pkceChallenge, seal } from '../lib/server-auth.ts';

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
