import { NextRequest, NextResponse } from 'next/server';

import { oidcConfig, readSession, refreshSession, setSession } from '@/lib/server-auth';

async function proxy(request: NextRequest, context: { params: Promise<{ path: string[] }> }) {
  try {
    const current = await readSession(request);
    if (!current) return NextResponse.json({ error: { code: 'UNAUTHENTICATED', message: 'Sign in required' } }, { status: 401 });
    const refreshed = await refreshSession(current);
    const { path } = await context.params;
    const config = oidcConfig();
    const url = new URL(`${config.apiBaseUrl}/${path.map(encodeURIComponent).join('/')}`);
    request.nextUrl.searchParams.forEach((value, key) => url.searchParams.append(key, value));
    const headers = new Headers({
      accept: 'application/json',
      authorization: `Bearer ${refreshed.session.accessToken}`,
      'x-request-id': crypto.randomUUID(),
    });
    const contentType = request.headers.get('content-type');
    if (contentType) headers.set('content-type', contentType);
    const idempotency = request.headers.get('idempotency-key');
    if (idempotency) headers.set('idempotency-key', idempotency);
    const upstream = await fetch(url, {
      method: request.method,
      headers,
      body: request.method === 'GET' || request.method === 'HEAD' ? undefined : await request.arrayBuffer(),
      cache: 'no-store',
    });
    const response = new NextResponse(upstream.body, {
      status: upstream.status,
      headers: { 'content-type': upstream.headers.get('content-type') ?? 'application/json' },
    });
    if (refreshed.changed) await setSession(response, refreshed.session);
    return response;
  } catch (error) {
    return NextResponse.json(
      { error: { code: 'WEB_SESSION_ERROR', message: error instanceof Error ? error.message : 'Request failed' } },
      { status: 503 },
    );
  }
}

export const GET = proxy;
export const POST = proxy;
export const PUT = proxy;
export const PATCH = proxy;
export const DELETE = proxy;
