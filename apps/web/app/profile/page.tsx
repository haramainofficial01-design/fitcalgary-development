'use client';

import { useCallback, useEffect, useState } from 'react';
import { PublicShell, DataState } from '@/components/public-shell';

type Row = Record<string, unknown>;
class AccountError extends Error { constructor(public status: number) { super('Account request failed'); } }
async function account(path: string, method = 'GET', body?: unknown) {
  const options: RequestInit = { method, cache: 'no-store', headers: { 'content-type': 'application/json' } };
  if (body !== undefined && method !== 'GET') options.body = JSON.stringify(body);
  const response = await fetch(`/api/backend${path}`, options);
  if (!response.ok) throw new AccountError(response.status);
  return response.status === 204 ? {} : await response.json() as Row;
}
const rows = (data: Row) => Array.isArray(data.data) ? data.data as Row[] : [];

export default function ProfilePage() {
  const [profile, setProfile] = useState<Row>();
  const [saved, setSaved] = useState<Row[]>([]);
  const [notices, setNotices] = useState<Row[]>([]);
  const [failure, setFailure] = useState(0);
  const [message, setMessage] = useState('');
  const [busy, setBusy] = useState(false);
  const load = useCallback(async () => {
    try {
      const [current, gyms, notifications] = await Promise.all([account('/profile'), account('/saved-gyms'), account('/notifications')]);
      setProfile(current); setSaved(rows(gyms)); setNotices(rows(notifications)); setFailure(0);
    } catch (error) { setFailure(error instanceof AccountError ? error.status : 503); }
  }, []);
  useEffect(() => {
    const timer = setTimeout(() => void load(), 0);
    const refresh = () => { if (document.visibilityState === 'visible') void load(); };
    window.addEventListener('focus', refresh);
    document.addEventListener('visibilitychange', refresh);
    return () => { clearTimeout(timer); window.removeEventListener('focus', refresh); document.removeEventListener('visibilitychange', refresh); };
  }, [load]);
  async function mutate(path: string, method: string, body?: unknown) {
    setBusy(true); setMessage('');
    try { await account(path, method, body); await load(); setMessage('Saved.'); }
    catch (error) {
      if (error instanceof AccountError && error.status === 401) setFailure(401);
      setMessage(error instanceof AccountError && error.status === 403 ? 'Your account does not have access to this action.' : 'We couldn’t save this change. Please check the details and try again.');
    } finally { setBusy(false); }
  }
  return <PublicShell active="profile"><section className="directory-page account-content">
    {failure === 401 ? <DataState title="Your FitCalgary account"><p>Sign in to save gyms and follow your results.</p><a className="primary-button" href="/signin">Sign in</a></DataState> : failure ? <DataState title="Please try again"><p>We couldn’t load your account.</p><button className="secondary-button" onClick={() => void load()}>Retry</button></DataState> : !profile ? <DataState title="Loading your account"><p>Getting your latest updates.</p></DataState> : <>
      <p className="overline">Your account</p><h1>{String(profile.display_name ?? profile.username ?? 'Your profile')}</h1>
      <form className="profile-form data-panel" onSubmit={event => {
        event.preventDefault(); const form = new FormData(event.currentTarget);
        void mutate('/profile', 'PATCH', { displayName: form.get('displayName'), bio: form.get('bio'), privacy: { publicProfile: form.has('publicProfile'), showGym: form.has('showGym') }, notificationPreferences: { eventUpdates: form.has('eventUpdates'), announcements: form.has('announcements') } });
      }} key={JSON.stringify(profile)}>
        <h2>Profile & preferences</h2>
        <label>Display name<input name="displayName" required maxLength={80} defaultValue={String(profile.display_name ?? '')} /></label>
        <label htmlFor="profile-bio">About you</label><textarea id="profile-bio" name="bio" maxLength={500} defaultValue={String(profile.bio ?? '')} />
        <label className="check-row"><input type="checkbox" name="publicProfile" defaultChecked={(profile.privacy as Row)?.publicProfile === true} />Show my name on boards</label>
        <label className="check-row"><input type="checkbox" name="showGym" defaultChecked={(profile.privacy as Row)?.showGym === true} />Show my gym</label>
        <label className="check-row"><input type="checkbox" name="eventUpdates" defaultChecked={(profile.notification_preferences as Row)?.eventUpdates !== false} />Event updates</label>
        <label className="check-row"><input type="checkbox" name="announcements" defaultChecked={(profile.notification_preferences as Row)?.announcements !== false} />FitCalgary announcements</label>
        <button disabled={busy} className="primary-button">{busy ? 'Saving…' : 'Save profile'}</button>
      </form>
      <p role="status">{message}</p>
      <h2>Saved gyms</h2><div className="directory-list">{saved.map(gym => <article key={String(gym.id)}><div className="detail-plan"><h3><a href={`/gyms/${encodeURIComponent(String(gym.slug))}`}>{String(gym.name)}</a></h3><button disabled={busy} className="secondary-button" onClick={() => void mutate(`/saved-gyms/${String(gym.id)}`, 'DELETE')}>Remove saved gym</button></div></article>)}</div>{!saved.length && <p>No saved gyms yet. <a href="/gyms">Explore the index.</a></p>}
      <h2>Notifications</h2><div className="directory-list">{notices.map(notice => <article key={String(notice.id)}><div className="detail-plan"><h3>{String(notice.title)}</h3><p>{String(notice.body)}</p>{!notice.opened_at && <button disabled={busy} className="secondary-button" onClick={() => void mutate(`/notifications/${String(notice.id)}/opened`, 'PUT')}>Mark as read</button>}</div></article>)}</div>{!notices.length && <p>You’re all caught up.</p>}
      {Array.isArray(profile.roles) && profile.roles.includes('ADMIN') && <a className="secondary-button detail-link" href="/admin">Administration</a>}
      <button disabled={busy} className="secondary-button detail-link" onClick={async () => {
        setBusy(true);
        try {
          const response = await fetch('/api/auth/logout', { method: 'POST' });
          if (!response.ok) throw new Error('logout');
          window.location.assign('/signin');
        } catch { setMessage('Sign-out could not finish. Please try again.'); setBusy(false); }
      }}>Sign out</button>
    </>}
  </section></PublicShell>;
}
