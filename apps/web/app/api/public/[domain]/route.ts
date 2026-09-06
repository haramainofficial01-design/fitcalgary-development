import { NextRequest, NextResponse } from 'next/server';

// Deliberately read-only and allowlisted: never forward cookies or bearer tokens.
export async function GET(request: NextRequest, context: { params: Promise<{ domain: string }> }) {
  const { domain } = await context.params;
  if (!['gyms', 'events', 'leaderboards', 'clubs'].includes(domain)) {
    return NextResponse.json({ error: 'Not found' }, { status: 404 });
  }
  const base = process.env.API_BASE_URL ?? process.env.NEXT_PUBLIC_API_BASE_URL;
  if (!base) return NextResponse.json({ error: 'Temporarily unavailable' }, { status: 503 });
  try {
    const url = new URL(`${base.replace(/\/$/, '')}/${domain}`);
    for (const key of ['q', 'page', 'pageSize', 'sort', 'area', 'category']) {
      const value = request.nextUrl.searchParams.get(key);
      if (value !== null) url.searchParams.set(key, value);
    }
    const upstream = await fetch(url, { headers: { accept: 'application/json' }, cache: 'no-store', signal: AbortSignal.timeout(10000) });
    if (!upstream.ok) return NextResponse.json({ error: 'Temporarily unavailable' }, { status: upstream.status >= 500 ? 503 : upstream.status });
    return NextResponse.json(await upstream.json(), { headers: { 'cache-control': 'no-store' } });
  } catch {
    return NextResponse.json({ error: 'Temporarily unavailable' }, { status: 503 });
  }
}
