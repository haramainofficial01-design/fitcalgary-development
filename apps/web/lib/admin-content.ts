export type ContentRecord = Record<string, unknown>;
export type ContentField = {
  key: string; label: string; type?: 'textarea'|'list'|'boolean'|'date'|'datetime'|'money'|'number'|'url'|'select';
  required?: boolean; options?: string[]; reference?: string; default?: unknown;
};
const publication: ContentField = {key:'publishStatus',label:'Publication',type:'select',options:['DRAFT','PUBLISHED','ARCHIVED'],default:'DRAFT',required:true};
const city: ContentField = {key:'cityId',label:'City',type:'select',reference:'cities',required:true};
const identity: ContentField[] = [city,{key:'name',label:'Name',required:true},{key:'slug',label:'URL slug',required:true}];
const text=(key:string,label:string):ContentField=>({key,label});
const url=(key:string,label:string):ContentField=>({key,label,type:'url'});
const list=(key:string,label:string):ContentField=>({key,label,type:'list'});
const long=(key:string,label:string):ContentField=>({key,label,type:'textarea'});
const money=(key:string,label:string,required=true):ContentField=>({key,label:`${label} (CAD)`,type:'money',required,default:required?0:undefined});

export const contentFields: Record<string,ContentField[]> = {
  gyms:[...identity,{key:'brandId',label:'Brand',type:'select',reference:'brands'},text('operator','Operator'),long('description','Description'),text('addressLine1','Street address'),text('neighbourhood','Area / neighbourhood'),text('postalCode','Postal code'),url('websiteUrl','Website'),text('telephone','Telephone'),list('categories','Categories'),list('amenities','Amenities'),url('sourceUrl','Source'),publication],
  clubs:[...identity,{key:'sport',label:'Sport',required:true},text('category','Category'),long('description','Description'),text('address','Address'),url('websiteUrl','Website'),url('registrationUrl','Registration link'),long('eligibility','Eligibility'),list('ageCategories','Age categories'),long('seasonInformation','Season information'),list('tags','Tags'),url('sourceUrl','Source'),publication],
  events:[...identity,text('organizer','Organizer'),text('category','Category'),long('description','Description'),{key:'startAt',label:'Starts (your local time)',type:'datetime'},{key:'endAt',label:'Ends (your local time)',type:'datetime'},{key:'registrationDeadline',label:'Registration deadline (your local time)',type:'datetime'},{key:'registrationStatus',label:'Registration',type:'select',options:['OPEN','CLOSED','UNKNOWN','NOT_APPLICABLE'],default:'UNKNOWN',required:true},text('location','Location'),url('externalRegistrationUrl','Event website'),text('sport','Sport'),{key:'officialFitcalgary',label:'Official FitCalgary event',type:'boolean'},list('tags','Tags'),url('sourceUrl','Source'),{key:'eventStatus',label:'Event status',type:'select',options:['ACTIVE','CANCELLED','POSTPONED'],default:'ACTIVE',required:true},publication,long('entryRequirements','Entry requirements'),url('imageUrl','Image URL')],
  pricing:[{key:'planName',label:'Plan name',required:true},money('recurringCents','Recurring charge'),{key:'billingFrequency',label:'Billing frequency',type:'select',options:['WEEKLY','BIWEEKLY','MONTHLY','QUARTERLY','ANNUALLY'],default:'MONTHLY',required:true},money('mandatoryRecurringFeeCents','Mandatory fee per payment'),money('mandatoryAnnualFeeCents','Mandatory annual fee'),money('initiationFeeCents','Initiation fee'),{key:'pricingComplete',label:'All mandatory costs have been confirmed',type:'boolean'},url('sourceUrl','Pricing source'),{key:'effectiveFrom',label:'Effective from',type:'date'},{key:'effectiveTo',label:'Effective until (set to retire an old plan)',type:'date'},text('membershipType','Membership type'),{key:'contractMonths',label:'Contract months',type:'number'},long('eligibility','Eligibility'),money('dropInCents','Drop-in price',false),long('trialDetails','Trial details'),long('notes','Notes')],
};

export function recordKey(key:string):string { return key.replace(/[A-Z]/g,c=>'_'+c.toLowerCase()); }
export function contentValue(field:ContentField,record:ContentRecord):string|boolean {
  const raw=record[recordKey(field.key)]??field.default;
  if(field.type==='boolean') return raw===true;
  if(field.type==='list') return Array.isArray(raw)?raw.join(', '):'';
  if(raw==null) return '';
  if(field.type==='money') return (Number(raw)/100).toFixed(2);
  if(field.type==='date') return String(raw).slice(0,10);
  if(field.type==='datetime') {
    const d=new Date(String(raw));
    if(Number.isNaN(d.getTime())) return '';
    const pad=(v:number)=>String(v).padStart(2,'0');
    return `${d.getFullYear()}-${pad(d.getMonth()+1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}`;
  }
  return String(raw);
}
export function contentPayload(area:string,form:FormData):ContentRecord {
  const fields=contentFields[area];
  if(!fields) throw new Error('Unknown content area');
  return Object.fromEntries(fields.map(field=>{
    const value=String(form.get(field.key)??'').trim();
    if(field.required&&!value&&field.type!=='boolean') throw new Error(`${field.label} is required`);
    let parsed:unknown=value||null;
    if(field.type==='boolean') parsed=form.has(field.key);
    else if(field.type==='list') parsed=value.split(',').map(v=>v.trim()).filter(Boolean);
    else if(value&&field.type==='datetime') parsed=new Date(value).toISOString();
    else if(value&&(field.type==='money'||field.type==='number')) {
      const n=Number(value);
      if(!Number.isFinite(n)||n<0) throw new Error(`${field.label} must be a nonnegative number`);
      if(field.type==='money') {
        if(!/^\d+(\.\d{1,2})?$/.test(value)) throw new Error(`${field.label} supports up to two decimal places`);
        parsed=Math.round(n*100);
      } else {
        if(!Number.isInteger(n)) throw new Error(`${field.label} must be a whole number`);
        parsed=n;
      }
    }
    return [field.key,parsed];
  }));
}
