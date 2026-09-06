'use client';
import { useEffect, useState } from 'react';
import { PublicShell } from '@/components/public-shell';
import { clientAPI, ClientRequestError } from '@/lib/client-api';
export default function JudgeQueue(){
  const [rows,setRows]=useState<{id:string;discipline:string;athlete:string;claimed_metric:number;unit:string}[]>();const [message,setMessage]=useState('');const [retry,setRetry]=useState(0);
  useEffect(()=>{const abort=new AbortController();clientAPI<{data:NonNullable<typeof rows>}>('/judge/queue','GET',undefined,abort.signal).then(data=>{setRows(data.data);setMessage('');}).catch(error=>{if(!abort.signal.aborted){setRows(undefined);setMessage(error instanceof ClientRequestError?error.message:'The review queue could not be loaded.');}});return()=>abort.abort();},[retry]);
  return <PublicShell active="profile"><section className="directory-page"><p className="overline">Review</p><h1>Review queue</h1>{message?<p role="alert">{message}</p>:rows?<><p>{rows.length} awaiting review</p><div className="directory-list">{rows.map(item=><article key={item.id}><div className="detail-plan"><h3><a href={`/submissions/${item.id}`}>{item.discipline} · {item.athlete}</a></h3><p>{item.claimed_metric} {item.unit}</p></div></article>)}</div>{!rows.length&&<p>No submissions waiting. You’re caught up.</p>}</>:<p>Loading…</p>}<button className="secondary-button detail-link" onClick={()=>setRetry(retry+1)}>Refresh queue</button></section></PublicShell>;
}
