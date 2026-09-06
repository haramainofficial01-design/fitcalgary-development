import { NextRequest, NextResponse } from 'next/server';

export async function GET(request: NextRequest, context: { params: Promise<{ domain: string; id: string }> }) {
  const { domain, id } = await context.params;
  if (!['gyms', 'events', 'leaderboards', 'clubs'].includes(domain) || !/^[a-zA-Z0-9-]{1,180}$/.test(id)) return NextResponse.json({ error: 'Not found' }, { status: 404 });
  const base = process.env.API_BASE_URL ?? process.env.NEXT_PUBLIC_API_BASE_URL;
  if (!base) return NextResponse.json({ error: 'Temporarily unavailable' }, { status: 503 });
  try {
    const url = new URL(`${base.replace(/\/$/, '')}/${domain}/${encodeURIComponent(id)}`);
    for (const key of ['city', 'page', 'pageSize']) {
      const value = request.nextUrl.searchParams.get(key);
      if (value !== null) url.searchParams.set(key, value);
    }
    const upstream = await fetch(url, { headers: { accept: 'application/json' }, cache: 'no-store', signal: AbortSignal.timeout(10000) });
    if (!upstream.ok) return NextResponse.json({ error: 'Unavailable' }, { status: upstream.status >= 500 ? 503 : upstream.status });
    return NextResponse.json(await upstream.json(), { headers: { 'cache-control': 'no-store' } });
  } catch { return NextResponse.json({ error: 'Temporarily unavailable' }, { status: 503 }); }
}
