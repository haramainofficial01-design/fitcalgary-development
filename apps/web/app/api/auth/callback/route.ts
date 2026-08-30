import { NextRequest, NextResponse } from 'next/server';

import { oidcConfig, open, setSession, transactionCookie } from '@/lib/server-auth';

type Transaction = { verifier: string; state: string; returnTo: string };

export async function GET(request: NextRequest) {
  const config = oidcConfig();
  const failure = (reason: string) => NextResponse.redirect(`${config.publicUrl}/signin?error=${encodeURIComponent(reason)}`);
  const rawTransaction = request.cookies.get(transactionCookie)?.value;
  const transaction = rawTransaction ? await open<Transaction>(rawTransaction, config.cookieSecret) : null;
  const code = request.nextUrl.searchParams.get('code');
  const state = request.nextUrl.searchParams.get('state');
  if (!transaction || !code || !state || state !== transaction.state) return failure('invalid_callback');

  const body = new URLSearchParams({
    grant_type: 'authorization_code',
    client_id: config.clientId,
    redirect_uri: `${config.publicUrl}/api/auth/callback`,
    code,
    code_verifier: transaction.verifier,
  });
  if (config.clientSecret) body.set('client_secret', config.clientSecret);
  const tokenResponse = await fetch(`${config.issuer}/protocol/openid-connect/token`, {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body,
    cache: 'no-store',
  });
  if (!tokenResponse.ok) return failure('token_exchange_failed');
  const tokens = (await tokenResponse.json()) as Record<string, unknown>;
  if (!tokens.access_token) return failure('missing_access_token');
  const response = NextResponse.redirect(`${config.publicUrl}${transaction.returnTo}`);
  response.cookies.delete(transactionCookie);
  await setSession(response, {
    accessToken: String(tokens.access_token),
    refreshToken: tokens.refresh_token ? String(tokens.refresh_token) : undefined,
    idToken: tokens.id_token ? String(tokens.id_token) : undefined,
    expiresAt: Date.now() + Number(tokens.expires_in ?? 300) * 1000,
  });
  return response;
}
