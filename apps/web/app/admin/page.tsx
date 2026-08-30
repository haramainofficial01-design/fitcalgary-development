'use client';

import { useCallback, useEffect, useMemo, useState } from 'react';
import type { SyntheticEvent } from 'react';
import { Activity, Bell, CalendarDays, ChartNoAxesCombined, ClipboardCheck, Dumbbell, FileClock, Flag, Gauge, Settings, ShieldCheck, Users } from 'lucide-react';

type Json = Record<string, unknown>;
type Session = { authenticated: boolean; displayName?: string; roles?: string[] };

const sections = [
  ['overview', 'Overview', Gauge],
  ['users', 'Users', Users],
  ['gyms', 'Gyms', Dumbbell],
  ['clubs', 'Clubs', Activity],
  ['events', 'Events', CalendarDays],
  ['leaderboards', 'Leaderboards', ChartNoAxesCombined],
  ['submissions', 'Submissions', ClipboardCheck],
  ['judges', 'Judges', ShieldCheck],
  ['moderation', 'Moderation', Flag],
  ['notifications', 'Notifications', Bell],
  ['analytics', 'Analytics', ChartNoAxesCombined],
  ['settings', 'Content & settings', Settings],
  ['audit', 'Audit log', FileClock],
] as const;

const endpoints: Record<string, string> = {
  overview: 'admin/overview',
  users: 'admin/users',
  gyms: 'admin/gyms',
  clubs: 'admin/clubs',
  events: 'admin/events',
  leaderboards: 'admin/leaderboards',
  submissions: 'admin/submissions',
  judges: 'admin/judges',
  moderation: 'admin/moderation',
  notifications: 'admin/notifications',
  analytics: 'admin/analytics',
  settings: 'admin/settings',
  audit: 'admin/audit-log',
};

async function backend(path: string, init?: RequestInit): Promise<Json> {
  const headers = new Headers(init?.headers);
  if (!headers.has('content-type')) headers.set('content-type', 'application/json');
  const response = await fetch(`/api/backend/${path}`, {
    ...init,
    headers,
  });
  const payload = (await response.json().catch(() => ({}))) as Json;
  if (!response.ok) {
    const error = payload.error as Json | undefined;
    throw new Error(String(error?.message ?? 'The admin request failed.'));
  }
  return payload;
}

export default function AdminPage() {
  const [session, setSession] = useState<Session>();
  const [active, setActive] = useState('overview');
  const [data, setData] = useState<Json>({});
  const [reference, setReference] = useState<Json>({});
  const [busy, setBusy] = useState(true);
  const [error, setError] = useState<string>();
  const [notice, setNotice] = useState<string>();
  const [search, setSearch] = useState('');

  const load = useCallback(async (section: string) => {
    setBusy(true);
    setError(undefined);
    try {
      setData(await backend(endpoints[section]));
    } catch (reason) {
      setData({});
      setError(reason instanceof Error ? reason.message : 'Unable to load this area.');
    } finally {
      setBusy(false);
    }
  }, []);

  useEffect(() => {
    fetch('/api/auth/session', { cache: 'no-store' })
      .then((response) => response.json() as Promise<Session>)
      .then((value) => {
        setSession(value);
        if (value.authenticated && value.roles?.map((role) => role.toUpperCase()).includes('ADMIN')) {
          void load('overview');
          void backend('admin/reference-data').then(setReference).catch(() => undefined);
        } else {
          setBusy(false);
        }
      })
      .catch(() => {
        setSession({ authenticated: false });
        setBusy(false);
      });
  }, [load]);

  const select = (section: string) => {
    setActive(section);
    setNotice(undefined);
    setSearch('');
    void load(section);
  };

  if (!session) return <AdminGate title="Checking your secure session…" />;
  if (!session.authenticated) return <AdminGate title="Administrator sign-in required" action="/api/auth/login?returnTo=/admin" />;
  if (!session.roles?.map((role) => role.toUpperCase()).includes('ADMIN')) return <AdminGate title="This account is not authorized for FitCalgary administration." />;

  return (
    <main className="admin-shell">
      <aside className="admin-sidebar">
        <a className="wordmark admin-wordmark" href="/"><strong>FITCALGARY</strong><span>ADMIN</span></a>
        <nav>{sections.map(([key, label, Icon]) => <button key={key} className={active === key ? 'active' : ''} onClick={() => select(key)}><Icon size={17} /><span>{label}</span></button>)}</nav>
        <div className="admin-user"><span>{session.displayName}</span><button onClick={async () => { await fetch('/api/auth/logout', { method: 'POST' }); location.href = '/'; }}>Sign out</button></div>
      </aside>
      <section className="admin-main">
        <header><div><p className="overline">Operations console</p><h1>{sections.find(([key]) => key === active)?.[1]}</h1></div><span className="connection-chip"><i /> Authoritative API</span></header>
        {notice && <div className="admin-notice">{notice}</div>}
        {error && <div className="admin-error"><strong>Could not load this area.</strong><p>{error}</p><button onClick={() => void load(active)}>Retry</button></div>}
        {busy ? <div className="admin-loading"><div className="loading-bar" /></div> : !error && (
          <AdminContent
            active={active}
            data={data}
            reference={reference}
            search={search}
            setSearch={setSearch}
            onChanged={async (message) => { setNotice(message); await load(active); }}
          />
        )}
      </section>
    </main>
  );
}

function AdminGate({ title, action }: { title: string; action?: string }) {
  return <main className="admin-gate"><div><a className="wordmark" href="/"><strong>FITCALGARY</strong><span>ADMIN</span></a><h1>{title}</h1>{action && <a className="primary-button" href={action}>Sign in securely →</a>}<p>All administrator permissions are enforced again by the Go API. UI visibility is never treated as authorization.</p></div></main>;
}

function AdminContent({ active, data, reference, search, setSearch, onChanged }: { active: string; data: Json; reference: Json; search: string; setSearch: (value: string) => void; onChanged: (message: string) => Promise<void> }) {
  if (active === 'overview') return <Overview data={data} />;
  const rows = Array.isArray(data.data) ? data.data as Json[] : [];
  const visible = rows.filter((row) => JSON.stringify(row).toLowerCase().includes(search.toLowerCase()));
  return <div className="admin-content">
    <div className="admin-toolbar"><input value={search} onChange={(event) => setSearch(event.target.value)} placeholder={`Search ${active}`} />{active === 'gyms' && <CreateGym reference={reference} onChanged={onChanged} />}{active === 'events' && <CreateEvent reference={reference} onChanged={onChanged} />}</div>
    {visible.length ? <AdminTable rows={visible} /> : <div className="admin-empty"><h2>No records returned</h2><p>This connected area is ready for authorized client content. Empty production data is never replaced with fabricated records.</p></div>}
  </div>;
}

function Overview({ data }: { data: Json }) {
  const cards: Array<[string, unknown]> = [
    ['Active users', data.total_users],
    ['Pending reviews', data.pending_submissions],
    ['Evidence nearing expiry', data.evidence_nearing_expiry],
    ['Published gyms', data.published_gyms],
    ['Upcoming events', data.upcoming_events],
    ['Failed notifications', data.failed_notifications],
  ];
  return <div className="kpi-grid">{cards.map(([label, value]) => <article key={String(label)}><span>{label}</span><strong>{String(value ?? '—')}</strong><p>Live database value</p></article>)}</div>;
}

function AdminTable({ rows }: { rows: Json[] }) {
  const columns = useMemo(() => Array.from(new Set(rows.flatMap((row) => Object.keys(row)))).filter((key) => !['before_data', 'after_data', 'privacy', 'description'].includes(key)).slice(0, 7), [rows]);
  return <div className="admin-table-wrap"><table><thead><tr>{columns.map((column) => <th key={column}>{column.replaceAll('_', ' ')}</th>)}</tr></thead><tbody>{rows.map((row, index) => <tr key={String(row.id ?? index)}>{columns.map((column) => <td key={column}>{display(row[column])}</td>)}</tr>)}</tbody></table></div>;
}

function display(value: unknown) {
  if (value == null) return '—';
  if (typeof value === 'object') return JSON.stringify(value);
  return String(value);
}

function CreateGym({ reference, onChanged }: { reference: Json; onChanged: (message: string) => Promise<void> }) {
  const cities = Array.isArray(reference.cities) ? reference.cities as Json[] : [];
  return <AdminCreate label="Add gym" onSubmit={async (form) => {
    const cityId = String(form.get('cityId') ?? cities[0]?.id ?? '');
    await backend('admin/gyms', { method: 'POST', body: JSON.stringify({ cityId, slug: form.get('slug'), name: form.get('name'), operator: form.get('operator') || null, neighbourhood: form.get('neighbourhood') || null, categories: [], amenities: [], publishStatus: form.get('publishStatus') }) });
    await onChanged('Gym saved. Published changes are immediately available to every client through the shared API.');
  }}><label>City<select name="cityId" required>{cities.map((city) => <option key={String(city.id)} value={String(city.id)}>{String(city.name)}</option>)}</select></label><label>Name<input name="name" required minLength={2} /></label><label>Slug<input name="slug" required pattern="[a-z0-9-]+" /></label><label>Operator<input name="operator" /></label><label>Neighbourhood<input name="neighbourhood" /></label><label>Status<select name="publishStatus"><option>DRAFT</option><option>PUBLISHED</option><option>ARCHIVED</option></select></label></AdminCreate>;
}

function CreateEvent({ reference, onChanged }: { reference: Json; onChanged: (message: string) => Promise<void> }) {
  const cities = Array.isArray(reference.cities) ? reference.cities as Json[] : [];
  return <AdminCreate label="Add event" onSubmit={async (form) => {
    const cityId = String(form.get('cityId') ?? cities[0]?.id ?? '');
    await backend('admin/events', { method: 'POST', body: JSON.stringify({ cityId, slug: form.get('slug'), name: form.get('name'), startAt: new Date(String(form.get('startAt'))).toISOString(), registrationStatus: 'OPEN', eventStatus: 'ACTIVE', publishStatus: form.get('publishStatus'), tags: [] }) });
    await onChanged('Event saved. Published changes are immediately available to web, iOS, Android, and watch clients.');
  }}><label>City<select name="cityId" required>{cities.map((city) => <option key={String(city.id)} value={String(city.id)}>{String(city.name)}</option>)}</select></label><label>Name<input name="name" required minLength={2} /></label><label>Slug<input name="slug" required pattern="[a-z0-9-]+" /></label><label>Starts<input name="startAt" type="datetime-local" required /></label><label>Status<select name="publishStatus"><option>DRAFT</option><option>PUBLISHED</option><option>ARCHIVED</option></select></label></AdminCreate>;
}

function AdminCreate({ label, children, onSubmit }: { label: string; children: React.ReactNode; onSubmit: (form: FormData) => Promise<void> }) {
  const [open, setOpen] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string>();
  const submit = async (event: SyntheticEvent<HTMLFormElement, SubmitEvent>) => {
    event.preventDefault();
    setBusy(true);
    setError(undefined);
    try { await onSubmit(new FormData(event.currentTarget)); setOpen(false); }
    catch (reason) { setError(reason instanceof Error ? reason.message : 'Save failed.'); }
    finally { setBusy(false); }
  };
  return <>{<button className="primary-button" onClick={() => setOpen(true)}>{label}</button>}{open && <div className="admin-modal" role="dialog" aria-modal="true"><form onSubmit={submit}><header><h2>{label}</h2><button type="button" onClick={() => setOpen(false)}>Close</button></header>{children}{error && <p className="form-error">{error}</p>}<button className="primary-button" disabled={busy}>{busy ? 'Saving…' : 'Save'}</button></form></div>}</>;
}
