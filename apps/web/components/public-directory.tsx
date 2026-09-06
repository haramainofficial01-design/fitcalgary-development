'use client';

import { useEffect, useState } from 'react';
import { Search } from 'lucide-react';
import { DataState } from './public-shell';

type Row = Record<string, unknown>;

export function PublicDirectory({ domain, preview = false }: { domain: 'gyms' | 'events' | 'leaderboards'; preview?: boolean }) {
  const [rows, setRows] = useState<Row[]>([]);
  const [query, setQuery] = useState('');
  const [page, setPage] = useState(1);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(false);
  const [retry, setRetry] = useState(0);
  const pageSize = preview ? 3 : 20;

  useEffect(() => {
    const timer = setTimeout(() => {
      if (!preview) setQuery(new URLSearchParams(window.location.search).get('search') ?? '');
    }, 0);
    return () => clearTimeout(timer);
  }, [preview]);

  useEffect(() => {
    const controller = new AbortController();
    const timer = setTimeout(() => {
      setLoading(true);
      setError(false);
      const params = new URLSearchParams({ pageSize: String(pageSize), page: String(page), q: query });
      fetch(`/api/public/${domain}?${params}`, { signal: controller.signal })
        .then(async (response) => {
          if (!response.ok) throw new Error('unavailable');
          return response.json() as Promise<{ data?: Row[]; total?: number }>;
        })
        .then((payload) => {
          if (controller.signal.aborted) return;
          setRows(payload.data ?? []);
          setTotal(payload.total ?? payload.data?.length ?? 0);
        })
        .catch(() => { if (!controller.signal.aborted) setError(true); })
        .finally(() => { if (!controller.signal.aborted) setLoading(false); });
    }, query ? 200 : 0);
    return () => { clearTimeout(timer); controller.abort(); };
  }, [domain, page, pageSize, query, retry]);

  return <>
    {!preview && <label className="directory-search"><Search size={18} /><span className="sr-only">Search {domain}</span><input value={query} onChange={(event) => { setQuery(event.target.value); setPage(1); }} placeholder={`Search ${domain}`} /></label>}
    <div aria-live="polite" aria-busy={loading}>
      {loading ? <DataState title="Loading"><div className="loading-bar" /></DataState> : error ? <DataState title="Please try again"><p>We couldn’t load these listings.</p><button className="secondary-button" onClick={() => setRetry(retry + 1)}>Retry</button></DataState> : !rows.length ? <DataState title="No matches yet"><p>{query ? 'Try another search.' : 'Check back for new listings.'}</p></DataState> :
        <div className="directory-list">{rows.map((row, index) => {
          const title = String(row.name ?? row.display_name ?? row.discipline ?? 'FitCalgary');
          const subtitle = String(row.operator ?? row.location ?? row.region_name ?? row.city ?? 'Calgary');
          const price = typeof row.lowest_ongoing_monthly_cents === 'number' ? `$${(row.lowest_ongoing_monthly_cents / 100).toFixed(2)}/mo` : undefined;
          const identifier = domain === 'leaderboards' ? row.id : row.slug;
          return <article key={String(row.id ?? index)}><span className="directory-number">{String((page - 1) * pageSize + index + 1).padStart(2, '0')}</span><div><p className="operator">{domain === 'leaderboards' ? String(row.board_type ?? 'Leaderboard') : subtitle}</p><h3>{identifier ? <a href={`/${domain}/${encodeURIComponent(String(identifier))}`}>{title}</a> : title}</h3><p>{domain === 'events' ? String(row.registration_status ?? subtitle) : subtitle}</p></div><strong>{price ?? String(row.display_label ?? '')}</strong></article>;
        })}</div>}
    </div>
    {!preview && !error && total > pageSize && <nav className="pagination" aria-label={`${domain} pages`}><button disabled={loading || page === 1} onClick={() => setPage(page - 1)}>Previous</button><span>Page {page} of {Math.ceil(total / pageSize)}</span><button disabled={loading || page * pageSize >= total} onClick={() => setPage(page + 1)}>Next</button></nav>}
  </>;
}
