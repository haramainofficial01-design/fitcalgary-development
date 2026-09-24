import { PublicDirectory } from '@/components/public-directory';
import { PublicShell } from '@/components/public-shell';

export default function GymsPage() {
  return <PublicShell active="gyms"><section className="directory-page"><p className="overline">The gym index</p><h1>Every major gym<br />in Calgary.</h1><p className="directory-intro">Compare advertised rates. All-in costs appear only when mandatory fees are confirmed. Biweekly means 26 payments a year.</p><PublicDirectory domain="gyms" /></section></PublicShell>;
}
