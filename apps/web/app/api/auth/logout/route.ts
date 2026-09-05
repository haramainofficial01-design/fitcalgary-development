import { NextRequest, NextResponse } from 'next/server';

import { oidcConfig, readSession, sessionCookie } from '@/lib/server-auth';
import { trustedMutation } from '@/lib/request-security';

export async function POST(request: NextRequest) {
  if (!trustedMutation(request, process.env.WEB_PUBLIC_URL)) {
    return NextResponse.json({ error: { code: 'FORBIDDEN_ORIGIN', message: 'Request origin is not permitted' } }, { status: 403 });
  }
  try {
    const session = await readSession(request);
    const config = oidcConfig();
    if (session?.refreshToken) {
      const body = new URLSearchParams({
        client_id: config.clientId,
        token: session.refreshToken,
        token_type_hint: 'refresh_token',
      });
      if (config.clientSecret) body.set('client_secret', config.clientSecret);
      await fetch(`${config.issuer}/protocol/openid-connect/revoke`, {
        method: 'POST',
        headers: { 'content-type': 'application/x-www-form-urlencoded' },
        body,
      });
    }
  } catch {
    // Local logout must still succeed if the provider is temporarily unavailable.
  }
  const response = NextResponse.json({ signedOut: true });
  response.cookies.delete(sessionCookie);
  return response;
}
