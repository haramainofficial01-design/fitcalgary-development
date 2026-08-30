import { createRemoteJWKSet, jwtVerify, type JWTPayload } from 'jose';
import type { Role } from '@fitcalgary/contracts';

export interface Principal { subject:string; email:string|null; emailVerified:boolean; roles:Role[]; token:JWTPayload; }
const known=new Set<Role>(['USER','MODERATOR','ADMIN','PERSONAL_TRAINER','JUDGE']);

export function createOidcVerifier(issuer:string,audience:string){
  const normalized=issuer.replace(/\/$/,''); const jwks=createRemoteJWKSet(new URL(`${normalized}/protocol/openid-connect/certs`));
  return async(token:string):Promise<Principal>=>{const {payload}=await jwtVerify(token,jwks,{issuer:normalized,audience});if(!payload.sub)throw new Error('Token has no subject');
    const realm=(payload.realm_access as {roles?:unknown}|undefined)?.roles;const resources=(payload.resource_access as Record<string,{roles?:unknown}>|undefined)?.[audience]?.roles;const raw=[...(Array.isArray(realm)?realm:[]),...(Array.isArray(resources)?resources:[])];const roles=[...new Set(raw.map((role)=>String(role).toUpperCase()).filter((role):role is Role=>known.has(role as Role)))];
    if(!roles.includes('USER'))roles.push('USER');return{subject:payload.sub,email:typeof payload.email==='string'?payload.email:null,emailVerified:payload.email_verified===true,roles,token:payload};};
}
export function bearer(value:unknown):string|null { if(typeof value!=='string')return null;const match=value.match(/^Bearer\s+(.+)$/i);return match?.[1]??null; }
