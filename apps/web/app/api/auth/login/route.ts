import { NextRequest, NextResponse } from 'next/server';

import { oidcConfig, pkceChallenge, randomUrlSafe, seal, transactionCookie } from '@/lib/server-auth';

export async function GET(request: NextRequest) {
  try {
    const config = oidcConfig();
    const verifier = randomUrlSafe(64);
    const state = randomUrlSafe();
    const requested = request.nextUrl.searchParams.get('returnTo') ?? '/';
    const returnTo = requested.startsWith('/') && !requested.startsWith('//') ? requested : '/';
    const transaction = await seal({ verifier, state, returnTo }, config.cookieSecret);
    const authorization = new URL(`${config.issuer}/protocol/openid-connect/auth`);
    authorization.search = new URLSearchParams({
      client_id: config.clientId,
      redirect_uri: `${config.publicUrl}/api/auth/callback`,
      response_type: 'code',
      scope: 'openid profile email offline_access',
      code_challenge: await pkceChallenge(verifier),
      code_challenge_method: 'S256',
      state,
    }).toString();
    const response = NextResponse.redirect(authorization);
    response.cookies.set(transactionCookie, transaction, {
      httpOnly: true,
      secure: true,
      sameSite: 'lax',
      path: '/api/auth',
      maxAge: 600,
    });
    return response;
  } catch (error) {
    return NextResponse.json({ error: error instanceof Error ? error.message : 'Authentication unavailable' }, { status: 503 });
  }
}
