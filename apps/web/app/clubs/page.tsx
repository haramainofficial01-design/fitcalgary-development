import { PublicDirectory } from '@/components/public-directory';
import { PublicShell } from '@/components/public-shell';
export default function ClubsPage(){
  return <PublicShell active="events"><section className="directory-page"><p className="overline">Find your community</p><h1>Clubs. Teams.<br/>Your people.</h1><p className="directory-intro">Explore recreational clubs, sports and ways to get involved.</p><a className="secondary-button" href="/events">Competitions & events</a><PublicDirectory domain="clubs"/></section></PublicShell>;
}
