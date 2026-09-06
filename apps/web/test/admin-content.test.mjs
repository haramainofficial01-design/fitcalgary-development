import assert from 'node:assert/strict';
import test from 'node:test';
import { contentFields, contentPayload, contentValue, recordKey } from '../lib/admin-content.ts';

test('complete event edit preserves domain fields and timestamps', () => {
  const record = {city_id:'city',name:'Development event',slug:'development-event',start_at:'2026-10-01T18:15:32Z',description:'Entry details',registration_status:'OPEN',event_status:'ACTIVE',publish_status:'DRAFT',official_fitcalgary:true,tags:['running','open'],entry_requirements:'Published rules',image_url:'https://example.invalid/event.png'};
  const form=new FormData();
  for(const field of contentFields.events) {
    const value=contentValue(field,record);
    if(typeof value==='boolean') { if(value) form.set(field.key,'on'); }
    else form.set(field.key,value);
  }
  const payload=contentPayload('events',form);
  assert.equal(payload.startAt,'2026-10-01T18:15:32.000Z');
  assert.equal(payload.officialFitcalgary,true);
  assert.equal(payload.entryRequirements,record.entry_requirements);
  assert.equal(payload.imageUrl,record.image_url);
  assert.deepEqual(payload.tags,record.tags);
  assert.equal(payload.endAt,null);
});
test('pricing converts dollars to integer cents without normalizing in the browser', () => {
  const form=new FormData();
  for(const f of contentFields.pricing) form.set(f.key,String(contentValue(f,{})));
  form.set('planName','Development plan');
  form.set('recurringCents','12.55');
  form.delete('pricingComplete');
  const payload=contentPayload('pricing',form);
  assert.equal(payload.recurringCents,1255);
  assert.equal(payload.pricingComplete,false);
  assert.equal(payload.dropInCents,null);
  assert.equal('ongoingMonthlyCents' in payload,false);
  form.set('recurringCents','12.555');
  assert.throws(()=>contentPayload('pricing',form));
  form.set('recurringCents','12.55');form.set('contractMonths','1.5');
  assert.throws(()=>contentPayload('pricing',form));
});
test('record mapping covers initialisms and distinguishes absent lists',()=>{
  assert.equal(recordKey('websiteUrl'),'website_url');
  assert.equal(recordKey('officialFitcalgary'),'official_fitcalgary');
  assert.equal(contentValue({key:'categories',label:'Categories',type:'list'},{}),'');
});
