'use client';

import { useEffect, useState } from 'react';

export function SaveGym({ id }: { id: string }) {
  const [saved, setSaved] = useState(false);
  const [busy, setBusy] = useState(true);
  const [message, setMessage] = useState('');
  const [signIn, setSignIn] = useState(false);
  useEffect(() => {
    const controller = new AbortController();
    fetch('/api/backend/saved-gyms', { signal: controller.signal, cache: 'no-store' })
      .then(async response => {
        if (response.status === 401) { setSignIn(true); return; }
        if (!response.ok) throw new Error('unavailable');
        const data = await response.json() as { data: { id: string }[] };
        setSaved(data.data.some(gym => gym.id === id));
      })
      .catch(() => { if (!controller.signal.aborted) setMessage('Saved gyms could not be loaded. Please try again.'); })
      .finally(() => { if (!controller.signal.aborted) setBusy(false); });
    return () => controller.abort();
  }, [id]);
  async function toggle() {
    setBusy(true); setMessage('');
    try {
      const response = await fetch(`/api/backend/saved-gyms/${encodeURIComponent(id)}`, { method: saved ? 'DELETE' : 'PUT' });
      if (response.status === 401) { setSignIn(true); return; }
      if (!response.ok) throw new Error('unavailable');
      setSaved(!saved); setMessage(saved ? 'Removed from saved gyms.' : 'Added to your saved gyms.');
    } catch { setMessage('We couldn’t update your saved gyms. Please try again.'); }
    finally { setBusy(false); }
  }
  return <div className="detail-link">{signIn ? <a className="secondary-button" href="/signin">Sign in to save this gym</a> : <button className="secondary-button" disabled={busy} aria-pressed={saved} onClick={() => void toggle()}>{busy ? 'Loading…' : saved ? 'Unsave gym' : 'Save gym'}</button>}<p role="status">{message}</p></div>;
}
