import { NextRequest, NextResponse } from 'next/server';

import { oidcConfig, readSession, refreshSession, setSession } from '@/lib/server-auth';

export async function GET(request: NextRequest) {
  try {
    const existing = await readSession(request);
    if (!existing) return NextResponse.json({ authenticated: false });
    const refreshed = await refreshSession(existing);
    const account = await fetch(`${oidcConfig().apiBaseUrl}/profile`, {
      headers: { authorization: `Bearer ${refreshed.session.accessToken}` }, cache: 'no-store',
    });
    if (account.status === 401 || account.status === 403) {
      const rejected = NextResponse.json({ authenticated: false }, { status: 401 });
      rejected.cookies.delete('fitcalgary_session');
      return rejected;
    }
    if (!account.ok) return NextResponse.json({ authenticated: false, error: 'Account service temporarily unavailable' }, { status: 503 });
    const profile = await account.json() as Record<string, unknown>;
    const response = NextResponse.json({
      authenticated: true,
      displayName: profile.display_name ?? profile.username ?? 'Athlete',
      roles: profile.roles ?? [],
    });
    if (refreshed.changed) await setSession(response, refreshed.session);
    return response;
  } catch {
    const response = NextResponse.json({ authenticated: false }, { status: 401 });
    response.cookies.delete('fitcalgary_session');
    return response;
  }
}
