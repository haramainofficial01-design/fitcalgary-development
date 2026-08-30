import { CalendarDays, ChartNoAxesColumnIncreasing, Dumbbell, Home, UserRound } from 'lucide-react';
import type { ReactNode } from 'react';

export function PublicShell({ children, active }: { children: ReactNode; active?: string }) {
  return (
    <main>
      <header className="site-header">
        <a className="wordmark" href="/" aria-label="FitCalgary Index home"><strong>FITCALGARY</strong><span>INDEX</span></a>
        <nav aria-label="Primary navigation"><a href="/gyms">Gyms</a><a href="/leaderboards">Board</a><a href="/events">Compete</a></nav>
        <div className="header-actions"><a className="secondary-button" href="/signin">Sign in</a><a className="primary-button" href="/submit">Post a result</a></div>
      </header>
      {children}
      <nav className="mobile-dock" aria-label="Mobile navigation">
        <a className={active === 'home' ? 'active' : ''} href="/"><Home /><span>Home</span></a>
        <a className={active === 'gyms' ? 'active' : ''} href="/gyms"><Dumbbell /><span>Gyms</span></a>
        <a className={active === 'board' ? 'active' : ''} href="/leaderboards"><ChartNoAxesColumnIncreasing /><span>Board</span></a>
        <a className={active === 'events' ? 'active' : ''} href="/events"><CalendarDays /><span>Compete</span></a>
        <a className={active === 'profile' ? 'active' : ''} href="/signin"><UserRound /><span>Me</span></a>
      </nav>
    </main>
  );
}

export function DataState({ title, children }: { title: string; children: ReactNode }) {
  return <div className="data-panel"><p className="operator">Live platform data</p><h3>{title}</h3><div>{children}</div></div>;
}
