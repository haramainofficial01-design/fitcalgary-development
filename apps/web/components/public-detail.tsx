'use client';

import { useEffect, useState } from 'react';
import { DataState } from './public-shell';
import { SaveGym } from './save-gym';

type Row = Record<string, unknown>;
const text = (value: unknown) => typeof value === 'string' ? value : '';
const money = (value: unknown) => typeof value === 'number' ? new Intl.NumberFormat('en-CA', { style: 'currency', currency: 'CAD' }).format(value / 100) : 'Not available';
function external(value: unknown) {
  try { const url = new URL(text(value)); return ['https:', 'http:'].includes(url.protocol) && !url.username && !url.password ? url.href : undefined; } catch { return undefined; }
}

export function PublicDetail({ domain, id }: { domain: 'gyms' | 'events' | 'leaderboards' | 'clubs'; id: string }) {
  const [record, setRecord] = useState<Row>();
  const [failure, setFailure] = useState(0);
  const [retry, setRetry] = useState(0);
  useEffect(() => {
    const controller = new AbortController();
    fetch(`/api/public/${domain}/${encodeURIComponent(id)}?pageSize=100`, { signal: controller.signal })
      .then(async response => { if (!response.ok) { if (!controller.signal.aborted) setFailure(response.status); return; } const data = await response.json() as Row; if (!controller.signal.aborted) { setRecord(data); setFailure(0); } })
      .catch(() => { if (!controller.signal.aborted) setFailure(503); });
    return () => controller.abort();
  }, [domain, id, retry]);
  if (failure) return <DataState title={failure === 404 ? 'This listing is no longer available' : 'Please try again'}><p>Return to the listings or try loading this page again.</p><button className="secondary-button" onClick={() => setRetry(retry + 1)}>Retry</button></DataState>;
  if (!record) return <DataState title="Loading"><p>Getting the latest details.</p></DataState>;
  const discipline = record.discipline as Row | undefined;
  const plans = Array.isArray(record.pricing) ? record.pricing as Row[] : [];
  const entries = Array.isArray(record.entries) ? record.entries as Row[] : [];
  const website = external(record.external_registration_url ?? record.registration_url ?? record.website_url);
  return <>
    <a className="secondary-button" href={`/${domain}`}>Back to {domain === 'leaderboards' ? 'boards' : domain}</a>
    <p className="overline detail-overline">{domain === 'leaderboards' ? record.boardType === 'OFFICIAL' ? 'Official board' : 'Community board' : text(record.city)}</p>
    <h1>{text(record.name) || text(discipline?.name)}</h1>
    {domain === 'gyms' && <SaveGym id={text(record.id)} />}
    {text(record.description) && <p className="directory-intro">{text(record.description)}</p>}
    {domain === 'gyms' && <><p>{text(record.address_line1)} {text(record.neighbourhood)}</p><h2>Membership costs</h2><div className="directory-list">{plans.map(plan => <article key={text(plan.id)}><div className="detail-plan"><h3>{text(plan.plan_name)}</h3><p>Advertised: {money(plan.recurring_cents)} · {text(plan.billing_frequency).toLowerCase().replaceAll('_', ' ')}</p><p>Ongoing monthly: {plan.pricing_complete ? money(plan.ongoing_monthly_cents) : 'Confirm with the gym'}</p><p>First-year monthly: {plan.pricing_complete ? money(plan.first_year_monthly_cents) : 'Confirm with the gym'}</p>{text(plan.terms) && <p>{text(plan.terms)}</p>}{text(plan.last_verified_at)&&<p>Price checked {new Date(text(plan.last_verified_at)).toLocaleDateString('en-CA')}</p>}</div></article>)}</div>{!plans.length && <p>Contact the gym for current membership pricing.</p>}</>}
    {domain === 'events' && <div className="data-panel"><h2>Event details</h2><p>{text(record.phase).toLowerCase()} · Registration {text(record.registration_status).toLowerCase()}</p><p>{text(record.location)}</p>{text(record.start_at) && <p><time dateTime={text(record.start_at)}>{new Date(text(record.start_at)).toLocaleString('en-CA', { timeZone: 'America/Edmonton' })} · Calgary time</time></p>}<p>{text(record.entry_requirements)}</p><p>{text(record.organizer)}</p></div>}
    {domain==='clubs'&&<div className="data-panel"><h2>Club details</h2><p>{text(record.sport)} · {text(record.category)}</p><p>{text(record.address)}</p><p>{text(record.eligibility)}</p><p>{text(record.season_information)}</p></div>}
    {domain === 'leaderboards' && <><p>{text((record.division as Row)?.label)} · {text((record.region as Row)?.name)}</p><div className="directory-list">{entries.map(entry => <article key={text(entry.result_id)}><span className="directory-number">{String(entry.rank)}</span><div><h3>{text(entry.display_name)}</h3><p>{text(entry.gym_name)}</p><p>{record.boardType === 'OFFICIAL' ? 'Verified result' : 'Community result'}</p></div><strong>{text(entry.display_metric)}</strong></article>)}</div>{!entries.length && <DataState title="Your next challenge"><p>No results on this board yet.</p></DataState>}{entries.length === 100 && <p>Showing the first 100 ranked athletes.</p>}</>}
    {website && <a className="primary-button detail-link" href={website} target="_blank" rel="noopener noreferrer">{domain === 'events' ? 'Event website' : 'Visit website'}</a>}
  </>;
}
