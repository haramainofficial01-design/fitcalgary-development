'use client';
import { useEffect, useRef, useState } from 'react';
import { clientAPI, ClientRequestError } from '@/lib/client-api';

type Discipline = { id:string; display_name:string; metric_type:string; unit:string; official_eligible:boolean; evidence_type:string; verification_checklist:{key:string;label:string}[] };
export function OfficialEntry() {
  const [disciplines,setDisciplines]=useState<Discipline[]>([]);
  const [cities,setCities]=useState<{id:string;name:string}[]>([]);
  const [message,setMessage]=useState('');
  const [selected,setSelected]=useState('');
  const [busy,setBusy]=useState(false);
  const [progress,setProgress]=useState(0);
  const [parent,setParent]=useState<string|null>(null);
  const [draft,setDraft]=useState<string>();
  const [posted,setPosted]=useState<string>();
  const controller=useRef<AbortController|null>(null);
  useEffect(()=>{
    const abort=new AbortController();
    Promise.all(['disciplines','cities'].map(async domain=>{
      const response=await fetch(`/api/public/${domain}`,{signal:abort.signal});
      if(!response.ok) throw new Error('Challenges could not be loaded. Please refresh.');
      return await response.json() as {data:unknown[]};
    })).then(([d,c])=>{setDisciplines((d.data as Discipline[]).filter(item=>item.official_eligible));setCities(c.data as {id:string;name:string}[]);setParent(new URLSearchParams(window.location.search).get('parent'));})
      .catch(()=>{if(!abort.signal.aborted)setMessage('Challenges could not be loaded. Please refresh.');});
    return ()=>{abort.abort();controller.current?.abort();};
  },[]);
  const discipline=disciplines.find(item=>item.id===selected);
  if(posted) return <div className="data-panel"><h2>Ready for review</h2><p>Your evidence is private. Follow the review and any feedback from your submission.</p><a className="primary-button" href={`/submissions/${posted}`}>View submission</a></div>;
  return <form className="profile-form data-panel" onSubmit={async event=>{
    event.preventDefault();if(!discipline||busy)return;
    const form=new FormData(event.currentTarget),file=form.get('evidence');
    if(!(file instanceof File)||file.size===0){setMessage('Choose your evidence file.');return;}
    if(file.size>4_294_967_296){setMessage('This file exceeds the upload limit. Choose a smaller file.');return;}
    const abort=new AbortController();controller.current=abort;setBusy(true);setMessage('');setProgress(0);
    try {
      if(!draft)await clientAPI('/profile','PATCH',{cityId:form.get('city')},abort.signal);
      let id=draft;
      if(!id){const result=await clientAPI<{id:string}>('/submissions','POST',{disciplineId:discipline.id,claimedMetric:Number(form.get('metric')),evidenceType:discipline.evidence_type,boardType:'OFFICIAL',parentSubmissionId:parent,checklistAcceptance:Object.fromEntries(discipline.verification_checklist.map(item=>[item.key,form.has('check-'+item.key)]))},abort.signal);id=result.id;setDraft(id);}
      const session=await clientAPI<{id:string;partSizeBytes:number}>(`/submissions/${id}/uploads`,'POST',{contentType:file.type||'video/mp4',sizeBytes:file.size},abort.signal);
      const parts:{ETag:string;PartNumber:number}[]=[];
      for(let offset=0;offset<file.size;offset+=session.partSizeBytes){
        const part=parts.length+1;
        let etag='';
        for(let attempt=0;attempt<3;attempt++){
          try{const signed=await clientAPI<{url:string}>(`/uploads/${session.id}/parts/${part}`,'POST',undefined,abort.signal);
            const response=await fetch(signed.url,{method:'PUT',body:file.slice(offset,offset+session.partSizeBytes),signal:abort.signal});
            if(!response.ok)throw new Error('Upload could not finish. Please retry.');
            etag=response.headers.get('ETag')??'';if(!etag)throw new Error('Upload confirmation was unavailable. Please retry.');break;
          }catch(error){if(abort.signal.aborted||attempt===2)throw error;}
        }
        parts.push({ETag:etag,PartNumber:part});setProgress(Math.round(Math.min(offset+session.partSizeBytes,file.size)/file.size*100));
      }
      await clientAPI(`/uploads/${session.id}/finalize`,'POST',{parts},abort.signal);setPosted(id);
    }catch(error){setMessage(abort.signal.aborted?'Upload paused. Select the same file and retry.':error instanceof ClientRequestError?error.message:'Upload could not finish. Check your connection and retry.');}
    finally{setBusy(false);controller.current=null;}
  }}>
    <h2>{parent?'Correct your submission':'Submit for verification'}</h2>
    <p>Your file is shared only with authorized reviewers. Approved marks appear on the official board.</p>
    <fieldset disabled={busy||Boolean(draft)} className="profile-form">
      <label htmlFor="official-discipline">Discipline</label><select id="official-discipline" required value={selected} onChange={event=>setSelected(event.target.value)}><option value="">Choose a discipline</option>{disciplines.map(item=><option key={item.id} value={item.id}>{item.display_name}</option>)}</select>
      <label htmlFor="official-city">City represented</label><select id="official-city" name="city" required defaultValue=""><option value="">Choose your city</option>{cities.map(item=><option key={item.id} value={item.id}>{item.name}</option>)}</select>
      <label htmlFor="official-metric">Result {discipline?`(${discipline.metric_type==='TIME'?'seconds':discipline.unit})`:''}</label><input id="official-metric" name="metric" type="number" required min="0.001" step={discipline?.metric_type==='REPETITIONS'?1:'any'} />
      {discipline?.verification_checklist.map(item=><label className="check-row" key={item.key}><input type="checkbox" required name={'check-'+item.key} />{item.label}</label>)}
    </fieldset>
    <label htmlFor="official-file">Private evidence</label><input id="official-file" name="evidence" type="file" required disabled={busy} accept={discipline?.evidence_type==='VIDEO'?'video/mp4,video/quicktime,video/webm':'.gpx,image/jpeg,image/png'} />
    <button className="primary-button" disabled={busy||!discipline}>{busy?'Uploading…':draft?'Retry upload':'Send for review'}</button>
    {busy&&<><progress max={100} value={progress} aria-label="Upload progress"/><button type="button" className="secondary-button" onClick={()=>controller.current?.abort()}>Pause upload</button></>}
    <p role="status">{message}</p>
  </form>;
}
