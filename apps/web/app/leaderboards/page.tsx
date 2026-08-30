import { PublicDirectory } from '@/components/public-directory';
import { PublicShell } from '@/components/public-shell';

export default function LeaderboardsPage() {
  return <PublicShell active="board"><section className="directory-page dark-directory"><p className="overline">Community + official</p><h1>The city,<br />ranked.</h1><p className="directory-intro">Official in-person results remain distinct from evidence-reviewed community marks. Every placement is calculated server-side.</p><PublicDirectory domain="leaderboards" /></section></PublicShell>;
}
