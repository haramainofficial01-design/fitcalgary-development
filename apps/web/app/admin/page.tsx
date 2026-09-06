'use client';

import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import type { SyntheticEvent } from 'react';
import { contentFields, contentPayload, contentValue } from '@/lib/admin-content';
import { Activity, BadgeDollarSign, Bell, CalendarDays, ChartNoAxesCombined, ClipboardCheck, Dumbbell, FileClock, Flag, Gauge, Layers3, ListChecks, Settings, ShieldCheck, Tags, Users } from 'lucide-react';

type Json = Record<string, unknown>;
type Session = { authenticated: boolean; displayName?: string; roles?: string[] };

const sections = [
  ['overview', 'Overview', Gauge, 'admin/overview'],
  ['users', 'Users', Users, 'admin/users'],
  ['roles', 'Roles', ShieldCheck, 'admin/users'],
  ['gyms', 'Gyms', Dumbbell, 'admin/gyms'],
  ['pricing', 'Pricing', BadgeDollarSign, 'admin/pricing'],
  ['clubs', 'Clubs', Activity, 'admin/clubs'],
  ['events', 'Events', CalendarDays, 'admin/events'],
  ['disciplines', 'Disciplines', Tags, 'admin/disciplines'],
  ['divisions', 'Divisions', Layers3, 'admin/divisions'],
  ['leaderboards', 'Leaderboards', ChartNoAxesCombined, 'admin/leaderboards'],
  ['submissions', 'Submissions', ClipboardCheck, 'admin/submissions'],
  ['judges', 'Judges & reviews', ListChecks, 'admin/submissions'],
  ['moderation', 'Moderation', Flag, 'admin/moderation'],
  ['notifications', 'Notifications', Bell, 'admin/notifications'],
  ['analytics', 'Analytics', ChartNoAxesCombined, 'admin/analytics'],
  ['settings', 'Content & settings', Settings, 'admin/settings'],
  ['audit', 'Audit log', FileClock, 'admin/audit-log'],
] as const;

const sectionFor = (key: string) => sections.find(([candidate]) => candidate === key);

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
  const [page, setPage] = useState(1);
  const loadSequence = useRef(0);
  const userArea = active === 'users' || active === 'roles';
  const remoteSearch = userArea ? search : '';

  const load = useCallback(async (section: string, query = '', pageNumber = 1) => {
    const sequence = ++loadSequence.current;
    const endpoint = sectionFor(section)?.[3];
    setBusy(true);
    setError(undefined);
    if (!endpoint) {
      setData({});
      setBusy(false);
      return;
    }
    try {
      const suffix = section === 'users' || section === 'roles' ? `?q=${encodeURIComponent(query)}&page=${pageNumber}&pageSize=50` : '';
      const result = await backend(endpoint+suffix);
      if (sequence === loadSequence.current) setData(result);
    } catch (reason) {
      if (sequence !== loadSequence.current) return;
      setData({});
      setError(reason instanceof Error ? reason.message : 'Unable to load this area.');
    } finally {
      if (sequence === loadSequence.current) setBusy(false);
    }
  }, []);

  useEffect(() => {
    fetch('/api/auth/session', { cache: 'no-store' })
      .then((response) => response.json() as Promise<Session>)
      .then((value) => {
        setSession(value);
        if (value.authenticated && value.roles?.map((role) => role.toUpperCase()).includes('ADMIN')) {
          const requested = new URLSearchParams(location.search).get('section') ?? 'overview';
          const initial = sectionFor(requested) ? requested : 'overview';
          setActive(initial);
          void Promise.all([backend('admin/reference-data'), backend('admin/gyms')]).then(([ref, gyms]) => setReference({...ref, gyms:gyms.data})).catch(() => undefined);
        } else {
          setBusy(false);
        }
      })
      .catch(() => {
        setSession({ authenticated: false });
        setBusy(false);
      });
  }, [load]);

  useEffect(() => {
    if (!session?.authenticated || !session.roles?.map(role => role.toUpperCase()).includes('ADMIN')) return;
    const timer = setTimeout(() => void load(active, remoteSearch, page), remoteSearch ? 250 : 0);
    return () => clearTimeout(timer);
  }, [active, remoteSearch, page, session, load]);

  const select = (section: string) => {
    setActive(section);
    setNotice(undefined);
    setSearch('');
    history.replaceState(null, '', `/admin?section=${encodeURIComponent(section)}`);
    setPage(1);
  };

  if (!session) return <AdminGate title="Checking your secure session…" />;
  if (!session.authenticated) return <AdminGate title="Administrator sign-in required" action="/api/auth/login?returnTo=/admin" />;
  if (!session.roles?.map((role) => role.toUpperCase()).includes('ADMIN')) return <AdminGate title="This account is not authorized for FitCalgary administration." />;

  return (
    <main className="admin-shell">
      <aside className="admin-sidebar">
        <a className="wordmark admin-wordmark" href="/"><strong>FITCALGARY</strong><span>ADMIN</span></a>
        <nav aria-label="Admin areas">{sections.map(([key, label, Icon]) => <button key={key} aria-label={label} title={label} className={active === key ? 'active' : ''} aria-current={active === key ? 'page' : undefined} onClick={() => select(key)}><Icon size={17} /><span>{label}</span></button>)}</nav>
        <div className="admin-user"><span>{session.displayName}</span><button onClick={async () => { await fetch('/api/auth/logout', { method: 'POST' }); location.href = '/'; }}>Sign out</button></div>
      </aside>
      <section className="admin-main">
        <header><div><p className="overline">Operations console</p><h1>{sections.find(([key]) => key === active)?.[1]}</h1></div><span className="connection-chip"><i /> Authoritative API</span></header>
        {notice && <div className="admin-notice">{notice}</div>}
        {error && <div className="admin-error"><strong>Could not load this area.</strong><p>{error}</p><button onClick={() => void load(active, remoteSearch, page)}>Retry</button></div>}
        {busy ? <div className="admin-loading"><div className="loading-bar" /></div> : !error && (
          <AdminContent
            active={active}
            data={data}
            reference={reference}
            search={search}
            setSearch={value => { setSearch(value); setPage(1); }}
            onChanged={async (message) => { setNotice(message); await Promise.all([load(active, remoteSearch, page), Promise.all([backend('admin/reference-data'), backend('admin/gyms')]).then(([ref, gyms]) => setReference({...ref, gyms:gyms.data}))]); }}
          />
        )}
        {userArea && !busy && !error && <div className="admin-pagination">
          <button disabled={page===1} onClick={()=>setPage(p=>p-1)}>Previous</button>
          <span>Page {page} · {String(data.total??0)} accounts</span>
          <button disabled={page*50>=Number(data.total??0)} onClick={()=>setPage(p=>p+1)}>Next</button>
        </div>}
      </section>
    </main>
  );
}

function AdminGate({ title, action }: { title: string; action?: string }) {
  return <main className="admin-gate"><div><a className="wordmark" href="/"><strong>FITCALGARY</strong><span>ADMIN</span></a><h1>{title}</h1>{action && <a className="primary-button" href={action}>Sign in securely →</a>}<p>All administrator permissions are enforced again by the Go API. UI visibility is never treated as authorization.</p></div></main>;
}

function AdminContent({ active, data, reference, search, setSearch, onChanged }: { active: string; data: Json; reference: Json; search: string; setSearch: (value: string) => void; onChanged: (message: string) => Promise<void> }) {
  if (active === 'overview') return <Overview data={data} />;
  if (!sectionFor(active)?.[3]) return <PlannedAdminArea active={active} />;
  const rows = Array.isArray(data.data) ? data.data as Json[] : [];
  const visible = rows.filter((row) => JSON.stringify(row).toLowerCase().includes(search.toLowerCase()));
  return <div className="admin-content">
    <div className="admin-toolbar"><input aria-label={`Search ${active}`} value={search} onChange={(event) => setSearch(event.target.value)} placeholder={`Search ${active}`} />{contentFields[active] && <ContentEditor area={active} reference={reference} onChanged={onChanged}/ >}{['disciplines','divisions','leaderboards'].includes(active) && <CompetitionForm area={active} reference={reference} onChanged={onChanged} />}</div>
    {visible.length ? <AdminTable rows={visible} actions={row => <AdminRowActions area={active} row={row} reference={reference} onChanged={onChanged}/>} /> : <div className="admin-empty"><h2>No records returned</h2><p>Client-approved content can be added here. Empty production data is never replaced with fabricated records.</p></div>}
  </div>;
}

function AdminRowActions({area,row,reference,onChanged}: {area:string;row:Json;reference:Json;onChanged:(message:string)=>Promise<void>}) {
  if(contentFields[area]) return <ContentEditor area={area} reference={reference} record={row} onChanged={onChanged}/>;
  if(['disciplines','divisions','leaderboards'].includes(area)) return <CompetitionForm area={area} reference={reference} record={row} onChanged={onChanged}/>;
  if(['users','roles'].includes(area)) return <AdminCreate label="Manage permissions" onSubmit={async form=>{
    const role=String(form.get('role'));
    await backend(`admin/users/${String(row.id)}/roles/${role}`,{method:form.get('action')==='GRANT'?'PUT':'DELETE'});
    await onChanged('Permission change saved and audited. It applies to subsequent protected requests.');
  }}>
    <p>{String(row.display_name)} · {String(row.email??'No email supplied')}</p>
    <p>Additional application grants: {display(row.roles)}. Explicit restrictions: {display(row.restricted_roles)}.</p>
    <label>Role<select name="role" aria-label="Role" required>{['MODERATOR','ADMIN','PERSONAL_TRAINER','JUDGE'].map(role=><option key={role}>{role}</option>)}</select></label>
    <label>Change<select name="action" aria-label="Permission change" required><option value="">Choose a change</option><option value="GRANT">Grant access</option><option value="REVOKE">Revoke access, including identity-provider claims</option></select></label>
    <p>USER is the base account role. An administrator cannot revoke their own ADMIN access.</p>
  </AdminCreate>;
  if(area==='settings') return <AdminCreate label="Edit setting" onSubmit={async form=>{
    let value:unknown;
    try { value=JSON.parse(String(form.get('value'))); } catch { throw new Error('Enter valid JSON for this setting.'); }
    await backend(`admin/settings/${encodeURIComponent(String(row.key))}`,{method:'PUT',body:JSON.stringify({value,public:form.has('public')})});
    await onChanged('Application setting saved and audited.');
  }}><p>{String(row.key)}. Never enter passwords, tokens or provider credentials here.</p><label>Value (JSON)<textarea name="value" aria-label="Value (JSON)" defaultValue={JSON.stringify(row.value,null,2)} rows={8} required/></label><label><input type="checkbox" name="public" defaultChecked={row.public===true}/>Public setting</label></AdminCreate>;
  return <span>Read-only record</span>;
}

function PlannedAdminArea({ active }: { active: string }) {
  const label = sectionFor(active)?.[1] ?? 'This area';
  return <div className="admin-planned"><div className="admin-planned-mark"><ShieldCheck size={28} /></div><p className="overline">Protected structure established</p><h2>{label}</h2><p>The authenticated route, permission boundary, navigation, loading and error patterns are in place. Deeper content operations are part of the agreed Phase 2 product work.</p><div className="admin-planned-state"><span>ADMIN ROUTE</span><strong>READY</strong><span>SERVER AUTHORIZATION</span><strong>ENFORCED</strong><span>PRODUCTION CONTENT</span><strong>CLIENT / PHASE 2</strong></div></div>;
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

function AdminTable({ rows, actions }: { rows: Json[]; actions?: (row: Json) => React.ReactNode }) {
  const columns = useMemo(() => {
    const available=Array.from(new Set(rows.flatMap(row=>Object.keys(row))));
    const preferred=['name','plan_name','display_name','title','athlete','discipline','division','region','gym','email','publish_status','event_status','status','delivery_status','account_status','roles','recurring_cents','billing_frequency','ongoing_monthly_cents','start_at','sport','city','action','reason','created_at'];
    return Array.from(new Set([...preferred,...available])).filter(key=>available.includes(key)&&!['id','before_data','after_data','privacy','description','total'].includes(key)&&!key.endsWith('_id')).slice(0,7);
  },[rows]);
  return <div className="admin-table-wrap"><table><thead><tr>{columns.map((column) => <th key={column}>{column.replaceAll('_', ' ')}</th>)}{actions && <th>Actions</th>}</tr></thead><tbody>{rows.map((row, index) => <tr key={String(row.id ?? index)}>{columns.map((column) => <td key={column}>{column.endsWith('_cents') && row[column] != null ? new Intl.NumberFormat('en-CA',{style:'currency',currency:'CAD'}).format(Number(row[column])/100) : display(row[column])}</td>)}{actions && <td>{actions(row)}</td>}</tr>)}</tbody></table></div>;
}

function display(value: unknown) {
  if (value == null) return '—';
  if (typeof value === 'object') return JSON.stringify(value);
  return String(value);
}

function ContentEditor({area,reference,record,onChanged}: {area:string;reference:Json;record?:Json;onChanged:(message:string)=>Promise<void>}) {
  const r=record??{};
  const refs=(key:string)=>Array.isArray(reference[key])?reference[key] as Json[]:[];
  const fields=contentFields[area];
  return <AdminCreate label={record?'Edit record':area==='pricing'?'Add pricing plan':`Add ${area.slice(0,-1)}`} onSubmit={async form=>{
    const body=contentPayload(area,form);
    const gym=String(record?.gym_id??form.get('gymId')??'');
    const endpoint=area==='pricing'?`admin/gyms/${encodeURIComponent(gym)}/pricing`:`admin/${area}`;
    await backend(endpoint+(record?`/${String(record.id)}`:''),{method:record?'PUT':'POST',body:JSON.stringify(body)});
    await onChanged('Record saved and audited. Published changes are available through the shared API.');
  }}>
    {area==='pricing'&&!record&&<label>Gym<select name="gymId" aria-label="Gym" required><option value="">Choose a gym</option>{refs('gyms').map(g=><option key={String(g.id)} value={String(g.id)}>{String(g.name)}</option>)}</select></label>}
    {area==='pricing'&&<p>Enter advertised charges in Canadian dollars. Monthly and first-year comparisons are calculated by the server. Leave costs unconfirmed if information is incomplete.</p>}
    {fields.map(f=>{
      const value=contentValue(f,r);
      const props={name:f.key,'aria-label':f.label+(f.type==='list'?' (comma-separated)':''),required:f.required,defaultValue:String(value)};
      if(f.type==='boolean') return <label key={f.key}><input type="checkbox" name={f.key} defaultChecked={Boolean(value)}/>{f.label}</label>;
      if(f.type==='select') return <label key={f.key}>{f.label}<select {...props}><option value="">{f.required?'Choose an option':'Not specified'}</option>{f.reference?refs(f.reference).map(row=><option key={String(row.id)} value={String(row.id)}>{String(row.name)}</option>):f.options?.map(v=><option key={v} value={v}>{v.replaceAll('_',' ')}</option>)}</select></label>;
      if(f.type==='textarea') return <label key={f.key}>{f.label}<textarea {...props} rows={3}/></label>;
      const type=f.type==='datetime'?'datetime-local':['money','number'].includes(f.type??'')?'number':['date','url'].includes(f.type??'')?f.type:'text';
      return <label key={f.key}>{f.label}{f.type==='list'?' (comma-separated)':''}<input {...props} type={type} step={f.type==='money'?'0.01':f.type==='number'||f.type==='datetime'?'1':undefined} min={f.type==='money'||f.type==='number'?0:undefined} pattern={f.key==='slug'?'[a-z0-9-]+':undefined}/></label>;
    })}
    {area!=='pricing'&&<p>Draft and archived records are hidden from public clients. Archiving preserves relationships and history.</p>}
  </AdminCreate>;
}

function AdminCreate({ label, children, onSubmit }: { label: string; children: React.ReactNode; onSubmit: (form: FormData) => Promise<void> }) {
  const [open, setOpen] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string>();
  const dialog = useRef<HTMLDialogElement>(null);
  useEffect(() => {
    const element = dialog.current;
    if (open && element) {
      element.showModal();
      element.querySelector<HTMLElement>('input, select, textarea')?.focus();
      return () => element.close();
    }
  }, [open]);
  const submit = async (event: SyntheticEvent<HTMLFormElement, SubmitEvent>) => {
    event.preventDefault();
    setBusy(true);
    setError(undefined);
    try { await onSubmit(new FormData(event.currentTarget)); setOpen(false); }
    catch (reason) { setError(reason instanceof Error ? reason.message : 'Save failed.'); }
    finally { setBusy(false); }
  };
  return <><button className="primary-button" onClick={() => { setError(undefined); setOpen(true); }}>{label}</button>{open && <dialog ref={dialog} className="admin-modal" aria-label={label} onCancel={event => { if (busy) event.preventDefault(); else setOpen(false); }}><form onSubmit={submit}><header><h2>{label}</h2><button type="button" disabled={busy} onClick={() => setOpen(false)}>Close</button></header>{children}{error && <p className="form-error" role="alert">{error}</p>}<button className="primary-button" disabled={busy}>{busy ? 'Saving…' : 'Save'}</button></form></dialog>}</>;
}

function CompetitionForm({area,reference,record,onChanged}: {area:string;reference:Json;record?:Json;onChanged:(message:string)=>Promise<void>}) {
  const r=record??{};
  const field=(name:string,label:string,value:unknown='',type='text',required=false)=><label>{label}<input name={name} type={type} defaultValue={String(value??'')} required={required} step={type==='number'?'any':undefined}/></label>;
  const select=(name:string,label:string,options:Array<[string,string]>,value:unknown)=><label>{label}<select name={name} defaultValue={String(value??'')} required>{options.map(([v,l])=><option key={v} value={v}>{l}</option>)}</select></label>;
  const flag=(name:string,label:string,value:unknown=true)=><label><input type="checkbox" name={name} defaultChecked={Boolean(value)}/>{label}</label>;
  const refs=(key:string,label:string)=>((reference[key] as Json[]|undefined)??[]).map(row=>[String(row.id),String(row[label])]) as Array<[string,string]>;
  return <AdminCreate label={record?'Edit configuration':`Add ${area.slice(0,-1)}`} onSubmit={async(form)=>{
    const val=(key:string)=>String(form.get(key)??'').trim();
    const number=(key:string)=>val(key)===''?null:Number(val(key));
    const yes=(key:string)=>form.has(key);
    let body:Json;
    if(area==='disciplines'){
      const checklist=val('checks').split('\n').map(s=>s.trim()).filter(Boolean).map((line)=>{
        const colon=line.indexOf(':');
        if(colon<1)throw new Error('Each verification check needs a unique key followed by a colon and its label.');
        return {key:line.slice(0,colon).trim(),label:line.slice(colon+1).trim()};
      });
      body={slug:val('slug'),displayName:val('displayName'),metricType:val('metricType'),unit:val('unit'),rankingDirection:val('rankingDirection'),evidenceType:val('evidenceType'),minimumMetric:number('minimumMetric')??0,maximumMetric:number('maximumMetric'),officialEligible:yes('officialEligible'),communityEligible:yes('communityEligible'),active:yes('active'),verificationChecklist:checklist};
    }else if(area==='divisions'){
      body={slug:val('slug'),displayLabel:val('displayLabel'),minimumAge:number('minimumAge'),maximumAge:number('maximumAge'),minimumInclusive:yes('minimumInclusive'),maximumInclusive:yes('maximumInclusive'),open:yes('open'),sexCategory:val('sexCategory'),active:yes('active')};
    }else{
      body={regionId:val('regionId'),disciplineId:val('disciplineId'),divisionId:val('divisionId'),boardType:val('boardType'),visible:yes('visible')};
    }
    await backend('admin/'+area+(record?'/'+record.id:''),{method:record?'PUT':'POST',body:JSON.stringify(body)});
    await onChanged('Configuration saved and audited. All clients read these rules from the shared service.');
  }}>
    <p>Existing performance meaning is protected. Create a new discipline or division version when eligibility or measurement changes.</p>
    {area!=='leaderboards' && field('slug','Stable slug',r.slug,'text',true)}
    {area==='disciplines' && <>
      {field('displayName','Display name',r.display_name,'text',true)}
      {select('metricType','Metric type',['TIME','REPETITIONS','WEIGHT','DISTANCE','POINTS','CUSTOM_NUMERIC'].map(v=>[v,v]),r.metric_type??'WEIGHT')}
      {field('unit','Unit (for example kg, reps, seconds)',r.unit??'kg','text',true)}
      {select('rankingDirection','Ranking direction',[['HIGHER_IS_BETTER','Higher wins'],['LOWER_IS_BETTER','Lower wins']],r.ranking_direction??'HIGHER_IS_BETTER')}
      {select('evidenceType','Required evidence',[['VIDEO','Private video'],['ACTIVITY_OR_OFFICIAL','Activity file / official performance']],r.evidence_type??'VIDEO')}
      {field('minimumMetric','Minimum result',r.minimum_metric??0,'number')}
      {field('maximumMetric','Maximum result (optional)',r.maximum_metric,'number')}
      <label>Verification checklist — one key: label per line<textarea name="checks" rows={5} defaultValue={((r.verification_checklist as Json[]|undefined)??[]).map(c=>`${String(c.key)}: ${String(c.label)}`).join('\n')}/></label>
      {flag('officialEligible','Official results eligible',r.official_eligible??true)}
      {flag('communityEligible','Community claims eligible',r.community_eligible??true)}
      {flag('active','Active',r.active??true)}
    </>}
    {area==='divisions' && <>
      {field('displayLabel','Division label',r.display_label,'text',true)}
      {field('minimumAge','Minimum age (blank for open)',r.minimum_age,'number')}
      {field('maximumAge','Maximum age (blank for open)',r.maximum_age,'number')}
      {flag('minimumInclusive','Include minimum age',r.minimum_inclusive??true)}
      {flag('maximumInclusive','Include maximum age',r.maximum_inclusive??true)}
      {flag('open','Open — no age bounds',r.open??true)}
      {select('sexCategory','Category',[['ALL','All'],['MEN','Men'],['WOMEN','Women']],r.sex_category??'ALL')}
      {flag('active','Active',r.active??true)}
    </>}
    {area==='leaderboards' && <>
      {select('regionId','Region',refs('regions','name'),r.region_id??(reference.regions as Json[]|undefined)?.[0]?.id)}
      {select('disciplineId','Discipline',refs('disciplines','display_name'),r.discipline_id??(reference.disciplines as Json[]|undefined)?.[0]?.id)}
      {select('divisionId','Division',refs('divisions','display_label'),r.division_id??(reference.divisions as Json[]|undefined)?.[0]?.id)}
      {select('boardType','Verification class',[['OFFICIAL','Official — verified'],['COMMUNITY','Community']],r.board_type??'OFFICIAL')}
      {flag('visible','Published / visible',r.visible??true)}
    </>}
  </AdminCreate>;
}
