'use client';

import { useEffect, useMemo, useState } from 'react';
import { ArrowRight, Search } from 'lucide-react';

import { DataState } from './public-shell';

type Row = Record<string, unknown>;

export function PublicDirectory({ domain }: { domain: 'gyms' | 'events' | 'leaderboards' }) {
  const [rows, setRows] = useState<Row[]>([]);
  const [query, setQuery] = useState('');
  const apiBase = process.env.NEXT_PUBLIC_API_BASE_URL;
  const [loading, setLoading] = useState(Boolean(apiBase));
  const [error, setError] = useState<string | undefined>(
    apiBase ? undefined : 'Production API address is awaiting deployment configuration.',
  );

  useEffect(() => {
    if (!apiBase) return;
    const controller = new AbortController();
    fetch(`${apiBase}/${domain}?pageSize=100`, { signal: controller.signal })
      .then(async (response) => {
        if (!response.ok) throw new Error('The directory is temporarily unavailable.');
        return response.json() as Promise<{ data?: Row[] }>;
      })
      .then((payload) => setRows(payload.data ?? []))
      .catch((reason: unknown) => {
        if ((reason as Error).name !== 'AbortError') setError(reason instanceof Error ? reason.message : 'Unable to load data.');
      })
      .finally(() => setLoading(false));
    return () => controller.abort();
  }, [apiBase, domain]);

  const visible = useMemo(() => rows.filter((row) => JSON.stringify(row).toLowerCase().includes(query.toLowerCase())), [query, rows]);
  if (loading) return <DataState title="Loading verified records"><div className="loading-bar" /></DataState>;
  if (error) return <DataState title="Connection pending"><p>{error} No unverified production records are substituted.</p></DataState>;
  if (!visible.length) return <DataState title="No published records"><p>{query ? 'Try another search.' : 'Client-confirmed records will appear here after an administrator publishes them.'}</p></DataState>;

  return (
    <>
      <label className="directory-search"><Search size={18} /><span className="sr-only">Search</span><input value={query} onChange={(event) => setQuery(event.target.value)} placeholder={`Search ${domain}`} /></label>
      <div className="directory-list">
        {visible.map((row, index) => {
          const title = String(row.name ?? row.display_name ?? row.discipline ?? 'FitCalgary record');
          const subtitle = String(row.operator ?? row.location ?? row.region_name ?? row.city ?? 'Calgary');
          const price = typeof row.lowest_ongoing_monthly_cents === 'number' ? `$${(row.lowest_ongoing_monthly_cents / 100).toFixed(2)}/mo` : undefined;
          return <article key={String(row.id ?? index)}><span className="directory-number">{String(index + 1).padStart(2, '0')}</span><div><p className="operator">{domain === 'leaderboards' ? String(row.board_type ?? 'Leaderboard') : subtitle}</p><h3>{title}</h3><p>{domain === 'events' ? String(row.registration_status ?? 'Registration status pending') : subtitle}</p></div><strong>{price ?? String(row.display_label ?? '')}</strong><ArrowRight /></article>;
        })}
      </div>
    </>
  );
}
