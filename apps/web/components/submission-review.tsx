'use client';
import { useEffect, useState } from 'react';
import { clientAPI, ClientRequestError } from '@/lib/client-api';
type Submission={id:string;profile_id:string;discipline:string;claimed_metric:number;unit:string;status:string;correction_id?:string;verification_checklist:{key:string;label:string}[];reviews?:{decision:string;comments?:string}[];result?:{leaderboardId:string;displayMetric:string}};
export function SubmissionReview({id}:{id:string}){
  const [item,setItem]=useState<Submission>();const [owner,setOwner]=useState(false);const [reviewer,setReviewer]=useState(false);const [message,setMessage]=useState('');const [busy,setBusy]=useState(false);const [retry,setRetry]=useState(0);const [video,setVideo]=useState('');
  useEffect(()=>{const abort=new AbortController();Promise.all([clientAPI<Submission>(`/submissions/${id}`,'GET',undefined,abort.signal),clientAPI<{id:string;roles:string[]}>('/profile','GET',undefined,abort.signal)]).then(([submission,profile])=>{setItem(submission);setOwner(profile.id===submission.profile_id);setReviewer(profile.id!==submission.profile_id&&profile.roles.some(role=>['JUDGE','ADMIN'].includes(role)));setMessage('');}).catch(error=>{if(!abort.signal.aborted)setMessage(error instanceof ClientRequestError?error.message:'This submission could not be loaded. Please retry.');});return()=>abort.abort();},[id,retry]);
  return <>{!item?<div className="data-panel"><h1>Submission</h1><p>{message||'Loading your submission…'}</p><button className="secondary-button" onClick={()=>setRetry(retry+1)}>Retry</button></div>:<>
    <p className="overline">{item.status.toLowerCase().replaceAll('_',' ')}</p><h1>{item.discipline}</h1><p>{item.claimed_metric} {item.unit}</p>
    {item.reviews?.map((review,index)=><div className="data-panel" key={index}><h2>Review feedback</h2><p>{review.comments||review.decision.toLowerCase().replaceAll('_',' ')}</p></div>)}
    {item.result&&<a className="primary-button" href={`/leaderboards/${item.result.leaderboardId}`}>View verified placement · {item.result.displayMetric}</a>}
    {owner&&['CHANGES_REQUESTED','REJECTED'].includes(item.status)&&<a className="primary-button detail-link" href={item.correction_id?`/submissions/${item.correction_id}`:`/submit?parent=${id}`}>{item.correction_id?'View correction':'Correct and resubmit'}</a>}
    {owner&&['DRAFT','UPLOADING','PENDING_REVIEW'].includes(item.status)&&<button disabled={busy} className="secondary-button detail-link" onClick={async()=>{if(!window.confirm('Withdraw this submission?'))return;setBusy(true);try{await clientAPI(`/submissions/${id}/cancel`,'POST');setRetry(retry+1);}catch(error){setMessage(error instanceof ClientRequestError?error.message:'Please retry.');}finally{setBusy(false);}}}>Withdraw submission</button>}
    {reviewer&&item.status==='PENDING_REVIEW'&&<form className="profile-form data-panel" onSubmit={async event=>{event.preventDefault();const form=new FormData(event.currentTarget);setBusy(true);try{await clientAPI(`/judge/submissions/${id}/decision`,'POST',{decision:form.get('decision'),comments:form.get('comments'),checklistResponses:Object.fromEntries(item.verification_checklist.map(rule=>[rule.key,form.has(rule.key)]))});setVideo('');setRetry(retry+1);}catch(error){setMessage(error instanceof ClientRequestError?error.message:'Please retry.');}finally{setBusy(false);}}}>
      <h2>Review evidence</h2><button className="secondary-button" type="button" disabled={busy} onClick={async()=>{try{const response=await clientAPI<{url:string}>(`/judge/submissions/${id}/evidence`);setVideo(response.url);}catch(error){setMessage(error instanceof ClientRequestError?error.message:'Evidence could not be opened. Please retry.');}}}>Open private evidence</button>
      {/* Athlete-uploaded evidence has no supplied caption track; do not invent one. */}
      {/* eslint-disable-next-line jsx-a11y/media-has-caption */}
      {video&&<video aria-label="Private athlete evidence" controls src={video} preload="metadata" style={{width:'100%'}} onError={()=>setMessage('Playback could not load. Open private evidence again to refresh access.')} />}
      {item.verification_checklist.map(rule=><label className="check-row" key={rule.key}><input name={rule.key} type="checkbox"/>{rule.label}</label>)}
      <label htmlFor="review-comments">Feedback</label><textarea id="review-comments" name="comments" maxLength={2000}/>
      <label htmlFor="review-decision">Decision</label><select id="review-decision" name="decision"><option value="RESUBMISSION_REQUESTED">Request correction</option><option value="REJECTED">Reject</option><option value="APPROVED">Approve</option></select>
      <button className="primary-button" disabled={busy}>Save decision</button>
    </form>}
    <p role="status">{message}</p><a className="secondary-button detail-link" href={reviewer?'/judge':'/profile'}>Back</a>
  </>}</>;
}
