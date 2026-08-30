'use client';

import { ArrowRight, CalendarDays, ChartNoAxesColumnIncreasing, Dumbbell, Home as HomeIcon, Search, UserRound } from 'lucide-react';

const gymPreview = [
  { name: 'Gym pricing preview', operator: 'Development data', price: '$—', note: 'Awaiting client-verified pricing' },
  { name: 'Independent training preview', operator: 'Development data', price: '$—', note: 'Awaiting client-verified pricing' },
  { name: 'Recreation centre preview', operator: 'Development data', price: '$—', note: 'Awaiting client-verified pricing' },
];

const eventPreview = [
  { day: '—', month: 'TBD', title: 'Calgary event listings', place: 'Published by FitCalgary administrators', tag: 'CLIENT DATA PENDING' },
  { day: '—', month: 'TBD', title: 'Recreational club calendar', place: 'Verified source and registration links', tag: 'CLIENT DATA PENDING' },
];

export default function Home() {
  return (
    <main>
      <header className="site-header">
        <a className="wordmark" href="#top" aria-label="FitCalgary Index home"><strong>FITCALGARY</strong><span>INDEX</span></a>
        <nav aria-label="Primary navigation"><a href="#gyms">Gyms</a><a href="#board">Board</a><a href="#compete">Compete</a></nav>
        <div className="header-actions"><a className="secondary-button" href="/signin">Sign in</a><a className="primary-button" href="/submit">Post a result</a></div>
      </header>

      <section id="top" className="hero">
        <div className="hero-grid" aria-hidden="true" />
        <div className="hero-content">
          <p className="overline">Calgary · community verified</p>
          <h1>The city,<br />ranked.</h1>
          <p className="hero-copy">Find Calgary gyms, see the real cost of membership, and post a mark for evidence review against a published standard.</p>
          <div className="hero-actions"><a className="primary-button" href="/submit">Post a result <ArrowRight size={17} /></a><a className="ghost-button" href="#gyms">Browse gyms <ArrowRight size={17} /></a></div>
        </div>
        <div className="hero-index" aria-label="Product pillars"><div><span>01</span><b>DISCOVER</b><p>Gyms, clubs and events</p></div><div><span>02</span><b>COMPARE</b><p>Transparent normalized pricing</p></div><div><span>03</span><b>COMPETE</b><p>Trusted local leaderboards</p></div></div>
      </section>

      <section id="gyms" className="content-section">
        <div className="section-topline"><span>The real number</span><a href="/gyms">Full gym index <ArrowRight size={14} /></a></div>
        <div className="section-heading"><div><h2>Compare the all-in.</h2><p>Biweekly billing is 26 payments a year, not 24. Ongoing and first-year costs stay distinct.</p></div><div className="live-note"><i />Connected admin content</div></div>
        <form className="search-strip" role="search"><label><Search size={18} /><span className="sr-only">Search gyms</span><input type="search" placeholder="Search gyms, operators, areas" /></label><button type="button">Search</button></form>
        <div className="gym-grid">{gymPreview.map((gym, index) => <article className="gym-card" key={gym.name}><span className="card-number">0{index + 1}</span><p className="operator">{gym.operator}</p><h3>{gym.name}</h3><div className="price"><strong>{gym.price}</strong><span>normalized monthly</span></div><p className="data-state">{gym.note}</p><a href="/gyms">View listing <ArrowRight size={14} /></a></article>)}</div>
      </section>

      <section id="board" className="board-section">
        <div className="section-topline inverted"><span>Community leaderboard</span><a href="/leaderboards">All boards <ArrowRight size={14} /></a></div>
        <div className="board-layout"><div><p className="overline">5K · Open · Calgary</p><h2>Put a number<br />on it.</h2><p>Verified marks are ranked on the server—never granted by the client.</p><a className="primary-button" href="/leaderboards">Browse the board <ArrowRight size={17} /></a></div><div className="empty-board"><span>RANK</span><span>ATHLETE</span><span>MARK</span><div><b>—</b><p>Production leaderboard awaiting approved results.</p><strong>—:—</strong></div><div><b>—</b><p>Every placement keeps its verified historical context.</p><strong>—:—</strong></div></div></div>
      </section>

      <section id="compete" className="content-section events-section">
        <div className="section-topline"><span>Next up</span><a href="/events">All events <ArrowRight size={14} /></a></div>
        <div className="section-heading"><div><h2>You can enter these.</h2><p>Competitions, recreational leagues, races and local clubs—published from one authoritative admin system.</p></div></div>
        <div className="event-list">{eventPreview.map((event) => <article key={event.title}><div className="event-date"><strong>{event.day}</strong><span>{event.month}</span></div><div><h3>{event.title}</h3><p>{event.place}</p><span className="tag">{event.tag}</span></div><a href="/events" aria-label={`View ${event.title}`}><ArrowRight /></a></article>)}</div>
      </section>

      <nav className="mobile-dock" aria-label="Mobile navigation"><a className="active" href="#top"><HomeIcon /><span>Home</span></a><a href="#gyms"><Dumbbell /><span>Gyms</span></a><a href="#board"><ChartNoAxesColumnIncreasing /><span>Board</span></a><a href="#compete"><CalendarDays /><span>Compete</span></a><a href="/signin"><UserRound /><span>Me</span></a></nav>
    </main>
  );
}
