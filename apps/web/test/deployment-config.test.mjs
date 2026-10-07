import test from 'node:test';
import assert from 'node:assert/strict';
import { productionDeploymentVars } from '../lib/deployment-config.ts';

const valid = { FITCALGARY_DEPLOY_TARGET: 'production',
  WEB_PUBLIC_URL: 'https://fitcalgary-web.fitcalgary.workers.dev',
  API_BASE_URL: 'https://api.example.org/api/v1',
  OIDC_ISSUER: 'https://auth.example.org/realms/fitcalgary',
  OIDC_WEB_CLIENT_ID: 'fitcalgary-web' };

test('local builds do not embed production configuration', () => {
  assert.deepEqual(productionDeploymentVars({}), {});
});
test('production uses explicit replacement endpoints, not the old provider', () => {
  const vars = productionDeploymentVars(valid);
  assert.equal(vars.API_BASE_URL, valid.API_BASE_URL);
  assert.equal(vars.OIDC_ISSUER, valid.OIDC_ISSUER);
  assert.equal(vars.NEXT_PUBLIC_SITE_URL, valid.WEB_PUBLIC_URL);
  assert.equal(JSON.stringify(vars).includes('railway.app'), false);
});
test('production does not silently fall back when a required binding is missing', () => {
  for (const key of ['WEB_PUBLIC_URL', 'API_BASE_URL', 'OIDC_ISSUER', 'OIDC_WEB_CLIENT_ID']) {
    assert.throws(() => productionDeploymentVars({ ...valid, [key]: undefined }), new RegExp(key));
  }
});
test('unsafe and secret-bearing endpoints are rejected without echoing credentials', () => {
  for (const base of ['http://api.example.org', 'https://localhost', 'https://dev.localhost',
    'https://127.0.0.1', 'https://[::1]', 'https://0.0.0.0', 'https://api.invalid',
    'https://api.test', 'https://hidden:secret@api.example.org']) {
    assert.throws(() => productionDeploymentVars({ ...valid, API_BASE_URL: `${base}/api/v1` }),
      error => !error.message.includes('hidden') && !error.message.includes('secret@'));
  }
  assert.throws(() => productionDeploymentVars({ ...valid, API_BASE_URL: `${valid.API_BASE_URL}?token=private` }));
  assert.throws(() => productionDeploymentVars({ ...valid, OIDC_ISSUER: `${valid.OIDC_ISSUER}#fragment` }));
});
test('migration preserves API version, identity realm, client and public web origin', () => {
  assert.throws(() => productionDeploymentVars({ ...valid, API_BASE_URL: 'https://api.example.org' }));
  assert.throws(() => productionDeploymentVars({ ...valid, OIDC_ISSUER: 'https://auth.example.org/realms/other' }));
  assert.throws(() => productionDeploymentVars({ ...valid, OIDC_WEB_CLIENT_ID: 'other' }));
  assert.throws(() => productionDeploymentVars({ ...valid, WEB_PUBLIC_URL: `${valid.WEB_PUBLIC_URL}/admin` }));
});
