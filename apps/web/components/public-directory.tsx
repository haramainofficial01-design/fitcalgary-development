'use client';

import { useEffect, useState } from 'react';
import { Search } from 'lucide-react';
import { DataState } from './public-shell';

type Row = Record<string, unknown>;

export function PublicDirectory({ domain, preview = false }: { domain: 'gyms' | 'events' | 'leaderboards' | 'clubs'; preview?: boolean }) {
  const [rows, setRows] = useState<Row[]>([]);
  const [query, setQuery] = useState('');
  const [page, setPage] = useState(1);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(false);
  const [retry, setRetry] = useState(0);
  const [filters,setFilters]=useState<Record<string,string>>({});
  const [selected,setSelected]=useState<string[]>([]);
  const [catalog,setCatalog]=useState<{disciplines:Row[];divisions:Row[]}>({disciplines:[],divisions:[]});
  const update=(key:string,value:string)=>{setPage(1);setFilters(current=>({...current,[key]:value}));};
  const pageSize = preview ? 3 : 20;

  useEffect(() => {
    const timer = setTimeout(() => {
      if (!preview) setQuery(new URLSearchParams(window.location.search).get('search') ?? '');
    }, 0);
    return () => clearTimeout(timer);
  }, [preview]);

  useEffect(()=>{
    if(preview||domain!=='leaderboards')return;
    const controller=new AbortController();
    Promise.all(['disciplines','divisions'].map(async key=>{const response=await fetch(`/api/public/${key}`,{signal:controller.signal});if(!response.ok)throw new Error();return response.json() as Promise<{data:Row[]}>;})).then(([disciplines,divisions])=>setCatalog({disciplines:disciplines.data,divisions:divisions.data})).catch(()=>{});
    return()=>controller.abort();
  },[domain,preview]);

  useEffect(() => {
    const controller = new AbortController();
    const timer = setTimeout(() => {
      setLoading(true);
      setError(false);
      const params = new URLSearchParams({ pageSize: String(pageSize), page: String(page), q: query });
      for(const [key,value] of Object.entries(filters))if(value)params.set(key,value);
      fetch(`/api/public/${domain}?${params}`, { signal: controller.signal })
        .then(async (response) => {
          if (!response.ok) throw new Error('unavailable');
          return response.json() as Promise<{ data?: Row[]; total?: number }>;
        })
        .then((payload) => {
          if (controller.signal.aborted) return;
          const data=payload.data??[];
          if(domain==='leaderboards'){
            const matches=data.filter(row=>[row.discipline_name,row.division_label,row.region_name].map(value=>String(value??'')).join(' ').toLowerCase().includes(query.toLowerCase()));
            setRows(matches.slice((page-1)*pageSize,page*pageSize));setTotal(matches.length);
          }else{setRows(data);setTotal(payload.total ?? data.length);}
        })
        .catch(() => { if (!controller.signal.aborted) setError(true); })
        .finally(() => { if (!controller.signal.aborted) setLoading(false); });
    }, query ? 200 : 0);
    return () => { clearTimeout(timer); controller.abort(); };
  }, [domain, page, pageSize, query, retry, filters]);

  return <>
    {!preview && <label className="directory-search"><Search size={18} /><span className="sr-only">Search {domain}</span><input value={query} onChange={(event) => { setQuery(event.target.value); setPage(1); }} placeholder={`Search ${domain}`} /></label>}
    {!preview&&<div className="directory-filters">
      {domain==='gyms'&&<><label>Area<input value={filters.area??''} onChange={e=>update('area',e.target.value)} placeholder="Neighbourhood"/></label><label>Maximum monthly (CAD)<input type="number" min={0} step={1} value={filters.maxMonthlyCents?Number(filters.maxMonthlyCents)/100:''} onChange={e=>update('maxMonthlyCents',e.target.value?String(Math.round(Number(e.target.value)*100)):'')}/></label><label>Sort<select value={filters.sort??'name'} onChange={e=>update('sort',e.target.value)}><option value="name">Name</option><option value="cost">Lowest all-in cost</option></select></label><label>Price information<select value={filters.pricing??''} onChange={e=>update('pricing',e.target.value)}><option value="">All gyms</option><option value="complete">All fees confirmed</option><option value="incomplete">Needs confirmation</option></select></label></>}
      {(domain==='clubs'||domain==='events')&&<label>Sport<input value={filters.sport??''} onChange={e=>update('sport',e.target.value)} placeholder="Search a sport"/></label>}
      {domain==='events'&&<><label>Event status<select value={filters.phase??''} onChange={e=>update('phase',e.target.value)}><option value="">All dates</option>{['UPCOMING','CURRENT','COMPLETED','CANCELLED','POSTPONED'].map(value=><option key={value} value={value}>{value.toLowerCase()}</option>)}</select></label><label>Month<input type="month" value={filters.month??''} onChange={e=>update('month',e.target.value)}/></label></>}
      {domain==='leaderboards'&&<><label>Discipline<select value={filters.discipline??''} onChange={e=>update('discipline',e.target.value)}><option value="">All disciplines</option>{catalog.disciplines.map(row=><option value={String(row.slug)} key={String(row.id)}>{String(row.display_name)}</option>)}</select></label><label>Division<select value={filters.division??''} onChange={e=>update('division',e.target.value)}><option value="">All divisions</option>{catalog.divisions.map(row=><option value={String(row.slug)} key={String(row.id)}>{String(row.display_label)}</option>)}</select></label><label>Board<select value={filters.boardType??''} onChange={e=>update('boardType',e.target.value)}><option value="">All boards</option><option value="OFFICIAL">Official · verified</option><option value="COMMUNITY">Community · unverified</option></select></label></>}
      <button className="secondary-button" onClick={()=>{setFilters({});setQuery('');setPage(1);}}>Clear filters</button>
    </div>}
    {!preview&&domain==='gyms'&&selected.length>0&&<div className="comparison-tray"><p>{selected.length} of 4 selected</p>{selected.length>=2&&<a className="primary-button" href={`/gyms/compare?gyms=${selected.join(',')}`}>Compare selected gyms</a>}<button className="secondary-button" onClick={()=>setSelected([])}>Clear selection</button></div>}
    <div aria-live="polite" aria-busy={loading}>
      {loading ? <DataState title="Loading"><div className="loading-bar" /></DataState> : error ? <DataState title="Please try again"><p>We couldn’t load these listings.</p><button className="secondary-button" onClick={() => setRetry(retry + 1)}>Retry</button></DataState> : !rows.length ? <DataState title="No matches yet"><p>{query ? 'Try another search.' : 'Check back for new listings.'}</p></DataState> :
        <div className="directory-list">{rows.map((row, index) => {
          const title = String(row.name ?? row.display_name ?? row.discipline_name ?? row.discipline ?? 'FitCalgary');
          const subtitle = String(row.operator ?? row.location ?? row.region_name ?? row.city ?? 'Calgary');
          const price = typeof row.lowest_ongoing_monthly_cents === 'number' ? `$${(row.lowest_ongoing_monthly_cents / 100).toFixed(2)}/mo` : undefined;
          const identifier = domain === 'leaderboards' ? row.id : row.slug;
          return <article key={String(row.id ?? index)}><span className="directory-number">{String((page - 1) * pageSize + index + 1).padStart(2, '0')}</span><div><p className="operator">{domain === 'leaderboards' ? row.board_type==='OFFICIAL'?'Official · verified':'Community · unverified' : subtitle}</p><h3>{identifier ? <a href={`/${domain}/${encodeURIComponent(String(identifier))}`}>{title}</a> : title}</h3><p>{domain === 'events' ? String(row.phase ?? row.registration_status ?? subtitle) : domain==='leaderboards'?String(row.division_label??subtitle):subtitle}</p>{domain==='gyms'&&!preview&&<label className="compare-choice"><input type="checkbox" checked={selected.includes(String(row.slug))} disabled={selected.length>=4&&!selected.includes(String(row.slug))} onChange={e=>setSelected(current=>e.target.checked?[...current,String(row.slug)]:current.filter(slug=>slug!==row.slug))}/>Compare {title}</label>}</div><strong>{price ?? String(row.display_label ?? '')}</strong></article>;
        })}</div>}
    </div>
    {!preview && !error && total > pageSize && <nav className="pagination" aria-label={`${domain} pages`}><button disabled={loading || page === 1} onClick={() => setPage(page - 1)}>Previous</button><span>Page {page} of {Math.ceil(total / pageSize)}</span><button disabled={loading || page * pageSize >= total} onClick={() => setPage(page + 1)}>Next</button></nav>}
  </>;
}
