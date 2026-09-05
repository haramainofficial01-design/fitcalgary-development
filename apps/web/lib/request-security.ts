/** Cookie-authenticated mutations must originate from the configured application. */
export function trustedMutation(request: Pick<Request, 'method' | 'headers'>, publicUrl: string | undefined): boolean {
  if (['GET', 'HEAD', 'OPTIONS'].includes(request.method.toUpperCase())) return true;
  if (!publicUrl) return false;
  const origin = request.headers.get('origin');
  if (!origin || request.headers.get('sec-fetch-site') === 'cross-site') return false;
  try {
    const expected = new URL(publicUrl);
    const actual = new URL(origin);
    return ['https:', 'http:'].includes(expected.protocol)
      && actual.origin === expected.origin
      && origin === actual.origin;
  } catch {
    return false;
  }
}
