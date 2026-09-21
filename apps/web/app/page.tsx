'use client';

import { PublicDirectory } from '@/components/public-directory';

import { ArrowRight, CalendarDays, ChartNoAxesColumnIncreasing, Dumbbell, Home as HomeIcon, Search, UserRound } from 'lucide-react';



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
        <div className="section-heading"><div><h2>Compare the all-in.</h2><p>Biweekly billing is 26 payments a year, not 24. Ongoing and first-year costs stay distinct.</p></div></div>
        <form className="search-strip" role="search" action="/gyms"><label><Search size={18} /><span className="sr-only">Search gyms</span><input type="search" name="search" placeholder="Search gyms, operators, areas" /></label><button type="submit">Search</button></form>
        <PublicDirectory domain="gyms" preview />
      </section>

      <section id="board" className="board-section">
        <div className="section-topline inverted"><span>Community leaderboard</span><a href="/leaderboards">All boards <ArrowRight size={14} /></a></div>
        <div className="board-layout"><div><p className="overline">5K · Open · Calgary</p><h2>Put a number<br />on it.</h2><p>Official results are reviewed against published standards. Community boards give everyone a place to start.</p><a className="primary-button" href="/leaderboards">Browse the board <ArrowRight size={17} /></a></div><div className="empty-board"><PublicDirectory domain="leaderboards" preview /></div></div>
      </section>

      <section id="compete" className="content-section events-section">
        <div className="section-topline"><span>Next up</span><a href="/events">All events <ArrowRight size={14} /></a></div>
        <div className="section-heading"><div><h2>You can enter these.</h2><p>Find your next race, recreational league or local competition.</p></div></div>
        <PublicDirectory domain="events" preview />
      </section>

      <footer className="site-footer"><span>FITCALGARY INDEX</span><nav aria-label="Legal and support"><a href="/privacy">Privacy</a><a href="/support">Support</a></nav></footer>

      <nav className="mobile-dock" aria-label="Mobile navigation"><a className="active" href="#top"><HomeIcon /><span>Home</span></a><a href="#gyms"><Dumbbell /><span>Gyms</span></a><a href="#board"><ChartNoAxesColumnIncreasing /><span>Board</span></a><a href="#compete"><CalendarDays /><span>Compete</span></a><a href="/profile"><UserRound /><span>Me</span></a></nav>
    </main>
  );
}
