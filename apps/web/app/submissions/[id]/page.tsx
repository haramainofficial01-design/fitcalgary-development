import { PublicShell } from '@/components/public-shell';
import { SubmissionReview } from '@/components/submission-review';
export default async function SubmissionPage({params}:{params:Promise<{id:string}>}){
  const {id}=await params;
  return <PublicShell active="profile"><section className="directory-page"><SubmissionReview id={id}/></section></PublicShell>;
}
