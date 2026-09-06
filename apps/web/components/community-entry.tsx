'use client';
import { useEffect, useState } from 'react';

type Discipline = { id: string; display_name: string; metric_type: string; unit: string; minimum_metric: number; maximum_metric?: number; community_eligible: boolean };
type Choice = { id: string; name?: string; display_label?: string };
export function CommunityEntry() {
  const [disciplines, setDisciplines] = useState<Discipline[]>([]);
  const [cities, setCities] = useState<Choice[]>([]);
  const [divisions, setDivisions] = useState<Choice[]>([]);
  const [selected, setSelected] = useState('');
  const [message, setMessage] = useState('');
  const [busy, setBusy] = useState(false);
  const [loading, setLoading] = useState(true);
  const [retry, setRetry] = useState(0);
  const [signIn, setSignIn] = useState(false);
  const [result, setResult] = useState<{ leaderboard_id: string; display_metric: string }>();
  useEffect(() => {
    const controller = new AbortController();
    Promise.all(['disciplines', 'cities', 'divisions'].map(async domain => {
      const response = await fetch(`/api/public/${domain}`, { signal: controller.signal });
      if (!response.ok) throw new Error('unavailable');
      return await response.json() as { data: unknown[] };
    })).then(([d, c, v]) => {
      if (controller.signal.aborted) return;
      setDisciplines((d.data as Discipline[]).filter(item => item.community_eligible));
      setCities(c.data as Choice[]); setDivisions(v.data as Choice[]); setMessage('');
    }).catch(() => { if (!controller.signal.aborted) setMessage('We couldn’t load the available challenges. Please try again.'); })
      .finally(() => { if (!controller.signal.aborted) setLoading(false); });
    return () => controller.abort();
  }, [retry]);
  const discipline = disciplines.find(item => item.id === selected);
  if (result) return <div className="data-panel"><h2>Result posted</h2><p>{result.display_metric} · Community result</p><p>This is a self-reported mark, separate from verified competition results.</p><a className="primary-button" href={`/leaderboards/${encodeURIComponent(result.leaderboard_id)}`}>View your board</a></div>;
  return <form className="profile-form data-panel" onSubmit={async event => {
    event.preventDefault(); if (!discipline || busy) return;
    const form = new FormData(event.currentTarget); setBusy(true); setMessage('');
    try {
      const profile = await fetch('/api/backend/profile', { method: 'PATCH', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ cityId: form.get('city') }) });
      if (profile.status === 401) { setSignIn(true); return; }
      if (!profile.ok) throw new Error('profile');
      const response = await fetch('/api/backend/results/community', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ disciplineId: discipline.id, divisionId: form.get('division') || null, metric: Number(form.get('metric')) }) });
      if (!response.ok) { setMessage(response.status === 422 ? 'Check the result and your profile’s eligibility for this division.' : 'We couldn’t post your result. Please try again.'); return; }
      setResult(await response.json() as { leaderboard_id: string; display_metric: string });
    } catch { setMessage('We couldn’t connect. Please try again.'); } finally { setBusy(false); }
  }}>
    <h2>Community result</h2><p>Record a personal mark on the community board. Community results are self-reported, not verified results.</p>
    {loading ? <p>Loading challenges…</p> : !disciplines.length ? <><p>No challenges available right now.</p><button type="button" className="secondary-button" onClick={() => setRetry(retry + 1)}>Retry</button></> : <>
      <label>Discipline<select required value={selected} onChange={event => setSelected(event.target.value)}><option value="">Choose a discipline</option>{disciplines.map(item => <option key={item.id} value={item.id}>{item.display_name}</option>)}</select></label>
      <label>City represented<select name="city" required defaultValue=""><option value="">Choose your city</option>{cities.map(item => <option key={item.id} value={item.id}>{item.name}</option>)}</select></label>
      <p>This also updates the city on your profile.</p>
      <label>Division<select name="division" defaultValue=""><option value="">Open</option>{divisions.map(item => <option key={item.id} value={item.id}>{item.display_label}</option>)}</select></label>
      <label>Result {discipline ? `(${discipline.metric_type === 'TIME' ? 'seconds' : discipline.unit})` : ''}<input name="metric" required type="number" min={discipline?.minimum_metric || 0.001} max={discipline?.maximum_metric ?? undefined} step={discipline?.metric_type === 'REPETITIONS' ? 1 : 'any'} /></label>
      <button className="primary-button" disabled={busy || !discipline}>{busy ? 'Posting…' : 'Post community result'}</button>
    </>}
    <p role="status">{message}</p>{signIn && <a className="secondary-button" href="/signin">Sign in to continue</a>}
  </form>;
}
