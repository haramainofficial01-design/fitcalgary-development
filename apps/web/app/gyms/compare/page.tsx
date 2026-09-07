'use client';
import { useEffect,useState } from 'react';
import { PublicShell,DataState } from '@/components/public-shell';
type Row=Record<string,unknown>;
const cost=(value:unknown)=>typeof value==='number'?new Intl.NumberFormat('en-CA',{style:'currency',currency:'CAD'}).format(value/100):'Not supplied';
function ComparedGym({gym}:{gym:Row}){
  const plans=Array.isArray(gym.pricing)?gym.pricing as Row[]:[];
  const [selected,setSelected]=useState('');
  const plan=plans.find(p=>p.id===selected)??plans[0];
  return <article className="data-panel comparison-card"><p className="overline">{String(gym.neighbourhood??gym.city)}</p><h2><a href={`/gyms/${String(gym.slug)}`}>{String(gym.name)}</a></h2>{!plan?<p>Contact the gym for membership pricing.</p>:<>
    <label>Membership plan<select value={String(plan.id)} onChange={event=>setSelected(event.target.value)}>{plans.map(p=><option key={String(p.id)} value={String(p.id)}>{String(p.plan_name)}</option>)}</select></label>
    <dl><dt>Advertised payment</dt><dd>{cost(plan.recurring_cents)} / {String(plan.billing_frequency).toLowerCase()}</dd><dt>Ongoing all-in monthly</dt><dd className="comparison-price">{plan.pricing_complete?cost(plan.ongoing_monthly_cents):'Confirm all fees'}</dd><dt>First-year monthly equivalent</dt><dd>{plan.pricing_complete?cost(plan.first_year_monthly_cents):'Confirm all fees'}</dd><dt>Mandatory recurring fee</dt><dd>{cost(plan.mandatory_recurring_fee_cents)}</dd><dt>Annual fee</dt><dd>{cost(plan.mandatory_annual_fee_cents)}</dd><dt>Joining fee</dt><dd>{cost(plan.initiation_fee_cents)}</dd></dl>
    {Boolean(plan.last_verified_at)&&<p>Price checked {new Date(String(plan.last_verified_at)).toLocaleDateString('en-CA')}</p>}
  </>}</article>;
}
export default function Comparison(){
  const [gyms,setGyms]=useState<Row[]>();const [error,setError]=useState('');const [retry,setRetry]=useState(0);
  useEffect(()=>{const controller=new AbortController();
    async function load(){
      const slugs=[...new Set((new URLSearchParams(window.location.search).get('gyms')??'').split(','))];
      if(slugs.length<2||slugs.length>4||slugs.some(slug=>!/^[a-z0-9-]{1,180}$/.test(slug)))throw new Error('selection');
      return Promise.all(slugs.map(async slug=>{const response=await fetch(`/api/public/gyms/${slug}`,{signal:controller.signal});if(!response.ok)throw new Error('unavailable');return response.json() as Promise<Row>;}));
    }
    load().then(data=>{if(!controller.signal.aborted){setGyms(data);setError('');}}).catch(()=>{if(!controller.signal.aborted)setError('Choose two to four available gyms from the index, or retry your selection.');});return()=>controller.abort();
  },[retry]);
  return <PublicShell active="gyms"><section className="directory-page"><p className="overline">The real number</p><h1>Compare the<br/>all-in cost.</h1><p className="directory-intro">Compare actual membership plans. Monthly equivalents include supplied mandatory fees; first-year costs also include joining fees. Biweekly billing means 26 payments per year.</p><a className="secondary-button" href="/gyms">Back to the index</a>{error?<DataState title="Check your selection"><p>{error}</p><button className="secondary-button" onClick={()=>setRetry(retry+1)}>Retry</button></DataState>:!gyms?<DataState title="Loading membership plans"><p>Checking current price information.</p></DataState>:<div className="comparison-grid">{gyms.map(gym=><ComparedGym key={String(gym.id)} gym={gym}/>)}</div>}</section></PublicShell>;
}
