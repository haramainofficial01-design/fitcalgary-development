import { PublicShell } from '@/components/public-shell';
import { CommunityEntry } from '@/components/community-entry';
import { OfficialEntry } from '@/components/official-entry';

export default function SubmitPage() {
  return <PublicShell><section className="account-page"><p className="overline">Your next best</p><h1>Put a number<br />on it.</h1><p>Submit evidence for an official result, or record a self-reported mark on a separate community board.</p><OfficialEntry /><CommunityEntry /></section></PublicShell>;
}
