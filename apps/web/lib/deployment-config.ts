type DeploymentEnvironment = Record<string, string | undefined>;

function httpsEndpoint(name: string, environment: DeploymentEnvironment): string {
  const value = environment[name]?.trim();
  if (!value) throw new Error(`${name} is required for production deployment`);
  let url: URL;
  try {
    url = new URL(value);
  } catch {
    throw new Error(`${name} must be a valid HTTPS endpoint`);
  }
  const host = url.hostname.toLowerCase();
  if (
    url.protocol !== 'https:' || url.username || url.password || url.search ||
    url.hash || host === 'localhost' || host.endsWith('.localhost') ||
    host.endsWith('.invalid') || host.endsWith('.test') || host.startsWith('127.') ||
    host === '0.0.0.0' || host.includes(':')
  ) throw new Error(`${name} must be a public HTTPS endpoint without credentials`);
  return url.toString().replace(/\/$/, '');
}

export function productionDeploymentVars(environment: DeploymentEnvironment): Record<string, string> {
  if (environment.FITCALGARY_DEPLOY_TARGET !== 'production') return {};
  const web = httpsEndpoint('WEB_PUBLIC_URL', environment);
  if (new URL(web).pathname !== '/') throw new Error('WEB_PUBLIC_URL must be an origin');
  const api = httpsEndpoint('API_BASE_URL', environment);
  const issuer = httpsEndpoint('OIDC_ISSUER', environment);
  if (new URL(api).pathname.replace(/\/$/, '') !== '/api/v1') {
    throw new Error('API_BASE_URL must identify the versioned /api/v1 API');
  }
  if (new URL(issuer).pathname.replace(/\/$/, '') !== '/realms/fitcalgary') {
    throw new Error('OIDC_ISSUER must identify the preserved fitcalgary realm');
  }
  if (environment.OIDC_WEB_CLIENT_ID?.trim() !== 'fitcalgary-web') {
    throw new Error('OIDC_WEB_CLIENT_ID must preserve the fitcalgary-web client');
  }
  return { WEB_PUBLIC_URL: web, NEXT_PUBLIC_SITE_URL: web, API_BASE_URL: api,
    OIDC_ISSUER: issuer, OIDC_WEB_CLIENT_ID: 'fitcalgary-web' };
}
