import { PublicDetail } from '@/components/public-detail';
import { PublicShell } from '@/components/public-shell';

export default async function DetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  return <PublicShell active="events"><section className="directory-page"><PublicDetail domain="events" id={id} /></section></PublicShell>;
}
