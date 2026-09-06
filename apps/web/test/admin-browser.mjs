// Local-only real browser/API/database acceptance. Tokens are ephemeral, never logged.
import assert from 'node:assert/strict';
import { randomBytes } from 'node:crypto';
import { spawn } from 'node:child_process';
import { mkdir } from 'node:fs/promises';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { seal, sessionCookie } from '../lib/server-auth.ts';

const require=createRequire(import.meta.url);
const {chromium}=require('playwright');
const cwd=fileURLToPath(new URL('..',import.meta.url));
const database=process.env.TEST_DATABASE_URL;
if(!database) throw new Error('TEST_DATABASE_URL is required');
const parsed=new URL(database);
if(parsed.hostname!=='127.0.0.1'||!parsed.pathname.endsWith('_test')) throw new Error('Disposable loopback test database required');
const binary=process.env.TEST_API_HARNESS;
if(!binary) throw new Error('TEST_API_HARNESS is required');
const origin='http://localhost:3011',api='http://127.0.0.1:4404/api/v1';
const output=path.resolve(cwd,'../../.artifacts/phase2/admin-browser');
await mkdir(output,{recursive:true});
const admin=randomBytes(32).toString('hex'),user=randomBytes(32).toString('hex'),secret=randomBytes(32).toString('hex');
const processes=[];
const start=(command,args,env,dir)=>{
  const child=spawn(command,args,{cwd:dir,env:{...process.env,...env},stdio:'ignore',detached:true});
  processes.push(child);return child;
};
const pause=ms=>new Promise(resolve=>setTimeout(resolve,ms));
async function ready(url){
  for(let n=0;n<120;n++){
    if(processes.some(p=>p.exitCode!==null)) throw new Error('Local test service stopped before becoming ready');
    try{if((await fetch(url)).ok)return;}catch{}
    await pause(250);
  }
  throw new Error('Local service readiness timeout');
}
async function call(route,method='GET',body,token=admin){
  const options={method,headers:{authorization:`Bearer ${token}`,'content-type':'application/json'}};
  if(body && method!=='GET' && method!=='HEAD') options.body=JSON.stringify(body);
  const response=await fetch(api+route,options);
  assert.equal(response.ok,true,`${method} ${route}: ${response.status}`);
  return response.json();
}
let browser,page;
const created=[];
try{
  start(binary,[],{APP_ENV:'development',PHASE1_HARNESS_ENABLED:'true',DATABASE_URL:database,PHASE1_USER_TOKEN:user,PHASE1_ADMIN_TOKEN:admin,PHASE1_TOKEN_CIPHER_KEY:randomBytes(16).toString('hex'),PORT:'4404'},path.resolve(cwd,'../../services/api-go'));
  await ready('http://127.0.0.1:4404/health');
  await call('/profile','PATCH',{displayName:'Development administrator'});
  await call('/profile','PATCH',{displayName:'Development browser athlete'},user);
  start('pnpm',['dev','--port','3011'],{CLOUDFLARE_INCLUDE_PROCESS_ENV:'true',WEB_PUBLIC_URL:origin,API_BASE_URL:api,OIDC_ISSUER:'http://127.0.0.1:8080/realms/development',OIDC_WEB_CLIENT_ID:'development-browser',SESSION_COOKIE_SECRET:secret},cwd);
  await ready(origin);
  browser=await chromium.launch({headless:true,channel:'chrome'});
  const context=await browser.newContext({viewport:{width:1440,height:1000},recordVideo:{dir:output,size:{width:1440,height:1000}}});
  async function identity(token){
    await context.clearCookies();
    await context.addCookies([{name:sessionCookie,value:await seal({accessToken:token,expiresAt:Date.now()+3600000},secret),domain:'localhost',path:'/',secure:true,httpOnly:true,sameSite:'Lax'}]);
  }
  page=await context.newPage();
  await page.goto(origin+'/admin');
  await page.getByRole('heading',{name:'Administrator sign-in required'}).waitFor();
  await identity(user);
  assert.equal((await context.cookies()).some(c=>c.name===sessionCookie),true,'Test cookie was stored');
  const userSession=await page.evaluate(async()=>({status:200,...await (await fetch('/api/auth/session',{cache:'no-store'})).json()}));
  assert.equal(userSession.authenticated,true,`Development browser session: ${JSON.stringify(userSession)}`);
  await page.reload();
  await page.getByRole('heading',{name:'This account is not authorized for FitCalgary administration.'}).waitFor();
  assert.equal((await context.request.get(origin+'/api/backend/admin/overview')).status(),403);
  await identity(admin);await page.reload();
  await page.getByRole('heading',{name:'Overview',exact:true}).waitFor();
  assert.equal((await context.request.post(origin+'/api/backend/admin/gyms',{headers:{Origin:'https://untrusted.example'},data:{}})).status(),403);
  const suffix=Date.now().toString(36);
  const city=(await call('/cities')).data[0].id;
  const select=async area=>{await page.getByRole('navigation',{name:'Admin areas'}).getByRole('button',{name:area,exact:true}).click();await page.getByRole('heading',{name:area,exact:true}).waitFor();};
  const fill=async(name,value)=>page.getByRole('dialog').getByLabel(name,{exact:true}).fill(value);
  const choose=async(name,value)=>page.getByRole('dialog').getByLabel(name,{exact:true}).selectOption(value);
  const save=async()=>{await page.getByRole('dialog').getByRole('button',{name:'Save',exact:true}).click();await page.getByRole('dialog').waitFor({state:'hidden'});};
  await select('Gyms');await page.getByRole('button',{name:'Add gym',exact:true}).click();
  await choose('City',city);await fill('Name',`Development browser gym ${suffix}`);await fill('URL slug',`development-browser-${suffix}`);
  await fill('Description','Development-only browser acceptance record');await fill('Categories (comma-separated)','BUDGET, FULL_SERVICE');await choose('Publication','PUBLISHED');await save();
  const gyms=(await call('/admin/gyms')).data;const gym=gyms.find(g=>g.slug===`development-browser-${suffix}`);assert.ok(gym);created.push(['gyms',gym]);
  await select('Pricing');await page.getByRole('button',{name:'Add pricing plan',exact:true}).click();
  await choose('Gym',gym.id);await fill('Plan name',`Development browser plan ${suffix}`);await fill('Recurring charge (CAD)','20.00');await choose('Billing frequency','BIWEEKLY');await fill('Mandatory annual fee (CAD)','52.00');await page.getByRole('dialog').getByLabel('All mandatory costs have been confirmed').check();await save();
  const row=page.getByRole('row').filter({hasText:`Development browser plan ${suffix}`});await row.getByRole('button',{name:'Edit record'}).click();await fill('Recurring charge (CAD)','21.00');await save();
  const plan=(await call('/admin/pricing')).data.find(p=>p.gym_id===gym.id);assert.equal(plan.recurring_cents,2100);assert.ok(plan.ongoing_monthly_cents>2100);
  await select('Events');await page.getByRole('button',{name:'Add event',exact:true}).click();
  await choose('City',city);await fill('Name',`Development browser event ${suffix}`);await fill('URL slug',`development-event-${suffix}`);await fill('Starts (your local time)','2027-01-20T12:00');await fill('Entry requirements','Development entry requirements');await choose('Publication','PUBLISHED');await save();
  let event=(await call('/admin/events')).data.find(e=>e.slug===`development-event-${suffix}`);assert.ok(event);created.push(['events',event]);
  await page.getByRole('row').filter({hasText:event.name}).getByRole('button',{name:'Edit record'}).click();await fill('Description','Edited through the real admin browser');await page.screenshot({path:path.join(output,'event-editor.png')});await choose('Publication','DRAFT');await save();
  event=(await call('/admin/events')).data.find(e=>e.id===event.id);assert.equal(event.description,'Edited through the real admin browser');assert.equal(event.entry_requirements,'Development entry requirements');assert.equal(event.publish_status,'DRAFT');
  await select('Clubs');await page.getByRole('button',{name:'Add club',exact:true}).click();await choose('City',city);await fill('Name',`Development browser club ${suffix}`);await fill('URL slug',`development-club-${suffix}`);await fill('Sport','Running');await fill('Eligibility','Development eligibility');await choose('Publication','PUBLISHED');await save();
  const club=(await call('/admin/clubs')).data.find(c=>c.slug===`development-club-${suffix}`);assert.ok(club);created.push(['clubs',club]);
  await page.getByRole('row').filter({hasText:club.name}).getByRole('button',{name:'Edit record'}).click();await choose('Publication','ARCHIVED');await save();
  assert.equal((await call('/admin/clubs')).data.find(c=>c.id===club.id).publish_status,'ARCHIVED');
  await select('Overview');await page.getByText('Active users',{exact:true}).waitFor();await page.screenshot({path:path.join(output,'overview.png')});
  await select('Users');await page.getByRole('textbox',{name:'Search users'}).fill('phase1@example.invalid');
  const userRow=page.getByRole('row').filter({hasText:'Development browser athlete'});
  await userRow.getByRole('button',{name:'Manage permissions'}).click();await choose('Role','JUDGE');await choose('Permission change','GRANT');await save();
  assert.equal((await fetch(api+'/judge/queue',{headers:{authorization:`Bearer ${user}`}})).status,200);
  await userRow.getByRole('button',{name:'Manage permissions'}).click();await choose('Role','JUDGE');await choose('Permission change','REVOKE');await save();
  assert.equal((await fetch(api+'/judge/queue',{headers:{authorization:`Bearer ${user}`}})).status,403);
  await page.setViewportSize({width:390,height:844});
  await select('Events');await page.getByRole('button',{name:'Add event',exact:true}).click();
  assert.equal(await page.getByRole('dialog').locator('form').evaluate(el=>el.scrollWidth<=el.clientWidth),true,'Responsive form overflow');
  await page.screenshot({path:path.join(output,'mobile-event-editor.png')});
  await page.keyboard.press('Escape');await page.getByRole('dialog').waitFor({state:'hidden'});
  await context.clearCookies();
  await page.goto(origin+'/');
  await page.getByRole('searchbox').fill(`Development browser gym ${suffix}`);
  await page.getByRole('button',{name:'Search',exact:true}).click();
  await page.getByRole('heading',{name:`Development browser gym ${suffix}`,exact:true}).waitFor();
  const publicSearch=page.getByRole('textbox',{name:'Search gyms'});
  await publicSearch.fill('no-such-gym-'+suffix);
  await page.getByRole('heading',{name:'No matches yet'}).waitFor();
  await publicSearch.fill(`Development browser gym ${suffix}`);
  await page.getByRole('heading',{name:`Development browser gym ${suffix}`,exact:true}).waitFor();
  assert.equal(await page.locator('body').evaluate(el=>el.scrollWidth<=window.innerWidth),true,'Consumer mobile overflow');
  assert.equal((await context.request.get(origin+'/api/public/admin')).status(),404);
  await page.route('**/api/public/gyms?**',route=>route.fulfill({status:503,contentType:'application/json',body:'{}'}));
  await page.reload();await page.getByRole('heading',{name:'Please try again'}).waitFor();
  await page.unroute('**/api/public/gyms?**');
  await page.getByRole('button',{name:'Retry',exact:true}).click();
  await page.getByRole('heading',{name:`Development browser gym ${suffix}`,exact:true}).waitFor();
  await page.screenshot({path:path.join(output,'consumer-mobile-directory.png')});
  await page.getByRole('link',{name:`Development browser gym ${suffix}`,exact:true}).click();
  await page.getByRole('heading',{name:'Membership costs'}).waitFor();
  await page.getByText('Ongoing monthly: $49.83',{exact:true}).waitFor();
  await page.screenshot({path:path.join(output,'consumer-gym-details.png')});
  await page.goto(origin+'/gyms/nonexistent-'+suffix);
  await page.getByRole('heading',{name:'This listing is no longer available'}).waitFor();
  console.log('PASS: signed-out home search, actual published Go/PostgreSQL directory, empty-search recovery, network retry, mobile layout and public proxy allowlist.');
  await context.close();
  console.log('PASS: browser admin sign-in gates, role grant/revoke with live permission changes, origin rejection, gym/pricing create/edit, event create/edit/unpublish, club create/archive, responsive editor and Escape; real Go/PostgreSQL, development identity only.');
}catch(error){
  if(page) await page.screenshot({path:path.join(output,'failure.png')}).catch(()=>undefined);
  throw error;
}finally{
  // Preserve source audit history while hiding this run’s development content.
  for(const [area,record] of created){
    try{
      const latest=(await call('/admin/'+area)).data.find(r=>r.id===record.id);
      const {contentFields,contentValue,contentPayload}=await import('../lib/admin-content.ts');
      const form=new FormData();
      for(const field of contentFields[area]){const v=contentValue(field,latest);if(typeof v==='boolean'){if(v)form.set(field.key,'on');}else form.set(field.key,v);}
      form.set('publishStatus','ARCHIVED');await call(`/admin/${area}/${record.id}`,'PUT',contentPayload(area,form));
    }catch{console.error('Development content cleanup requires review:',area,record.id);}
  }
  await browser?.close();
  for(const child of processes.reverse()){try{process.kill(-child.pid,'SIGTERM');}catch{}}
}
