import { PublicDirectory } from '@/components/public-directory';
import { PublicShell } from '@/components/public-shell';

export default function EventsPage() {
  return <PublicShell active="events"><section className="directory-page"><p className="overline">Compete</p><h1>You can enter<br />these.</h1><p className="directory-intro">Competitions, leagues, races, recreational clubs, and registration information from verified sources.</p><PublicDirectory domain="events" /></section></PublicShell>;
}
