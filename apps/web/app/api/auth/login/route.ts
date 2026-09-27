import { NextRequest, NextResponse } from 'next/server';

import { oidcConfig, pkceChallenge, randomUrlSafe, safeReturnTo, seal, transactionCookie } from '@/lib/server-auth';

export async function GET(request: NextRequest) {
  try {
    const config = oidcConfig();
    const verifier = randomUrlSafe(64);
    const state = randomUrlSafe();
    const returnTo = safeReturnTo(request.nextUrl.searchParams.get('returnTo'));
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
  } catch {
    return NextResponse.json({ error: 'Sign-in is temporarily unavailable. Please try again shortly.' }, { status: 503 });
  }
}
