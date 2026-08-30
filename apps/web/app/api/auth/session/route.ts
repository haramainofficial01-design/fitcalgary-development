import { NextRequest, NextResponse } from 'next/server';

import { decodeClaims, readSession, refreshSession, setSession } from '@/lib/server-auth';

export async function GET(request: NextRequest) {
  try {
    const existing = await readSession(request);
    if (!existing) return NextResponse.json({ authenticated: false });
    const refreshed = await refreshSession(existing);
    const claims = decodeClaims(refreshed.session.accessToken);
    const realmAccess = claims.realm_access as { roles?: string[] } | undefined;
    const response = NextResponse.json({
      authenticated: true,
      displayName: claims.name ?? claims.preferred_username ?? 'Athlete',
      email: claims.email ?? null,
      roles: realmAccess?.roles ?? [],
    });
    if (refreshed.changed) await setSession(response, refreshed.session);
    return response;
  } catch {
    const response = NextResponse.json({ authenticated: false }, { status: 401 });
    response.cookies.delete('fitcalgary_session');
    return response;
  }
}
