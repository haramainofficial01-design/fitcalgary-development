import Fastify, { type FastifyRequest } from 'fastify';
import cors from '@fastify/cors';
import helmet from '@fastify/helmet';
import rateLimit from '@fastify/rate-limit';
import { ZodError } from 'zod';
import { bearer, createOidcVerifier } from './auth/oidc.js';
import { loadEnv } from './config/env.js';
import { createPool } from './db/pool.js';
import { registerPublicRoutes } from './http/public.js';
import { registerAccountRoutes } from './http/account.js';
import { registerSubmissionRoutes } from './http/submissions.js';
import { registerJudgeRoutes } from './http/judge.js';
import { registerAdminRoutes } from './http/admin.js';

const env=loadEnv();const db=createPool(env.DATABASE_URL);const verify=createOidcVerifier(env.KEYCLOAK_ISSUER,env.KEYCLOAK_AUDIENCE);
const app=Fastify({logger:{level:env.LOG_LEVEL,redact:{paths:['req.headers.authorization','*.token','*.url','*.encrypted_token'],censor:'[REDACTED]'}},requestIdHeader:'x-request-id',trustProxy:true,bodyLimit:1_048_576});
await app.register(helmet,{contentSecurityPolicy:false});await app.register(cors,{origin:[env.WEB_PUBLIC_URL],credentials:true,methods:['GET','POST','PUT','PATCH','DELETE','OPTIONS']});await app.register(rateLimit,{max:120,timeWindow:'1 minute',keyGenerator:(request)=>request.principal?.subject??request.ip});

const authenticate=async(request:FastifyRequest)=>{const token=bearer(request.headers.authorization);if(!token){const error=new Error('Authentication required') as Error&{statusCode:number;code:string};error.statusCode=401;error.code='UNAUTHENTICATED';throw error;}request.principal=await verify(token);const tokenName=typeof request.principal.token.preferred_username==='string'?request.principal.token.preferred_username:request.principal.email?.split('@')[0]??'Athlete';const profile=await db.query(`INSERT INTO profiles(keycloak_subject,email,display_name) VALUES($1,$2,$3) ON CONFLICT(keycloak_subject) DO UPDATE SET email=COALESCE(EXCLUDED.email,profiles.email),updated_at=now() RETURNING id,account_status`,[request.principal.subject,request.principal.email,tokenName]);if(profile.rows[0].account_status!=='ACTIVE'){const error=new Error('Account is restricted') as Error&{statusCode:number;code:string};error.statusCode=403;error.code='ACCOUNT_RESTRICTED';throw error;}request.profileId=profile.rows[0].id;const stored=await db.query('SELECT role FROM user_roles WHERE profile_id=$1',[request.profileId]);request.principal.roles=[...new Set([...request.principal.roles,...stored.rows.map((row)=>row.role)])];};

app.get('/health',async()=>({status:'ok',service:'fitcalgary-api'}));app.get('/ready',async(_request,reply)=>{try{await db.query('SELECT 1');return{status:'ready'};}catch{return reply.code(503).send({status:'not_ready'});}});
await registerPublicRoutes(app,db);await registerAccountRoutes(app,db,authenticate);await registerSubmissionRoutes(app,db,env,authenticate);await registerJudgeRoutes(app,db,env,authenticate);await registerAdminRoutes(app,db,authenticate);

app.setNotFoundHandler((request,reply)=>reply.code(404).send({error:{code:'NOT_FOUND',message:'Route not found',requestId:request.id}}));
app.setErrorHandler((error,request,reply)=>{const err=error as Error&{statusCode?:number;code?:string};const status=typeof err.statusCode==='number'?err.statusCode:error instanceof ZodError?422:500;const code=typeof err.code==='string'?err.code:error instanceof ZodError?'VALIDATION_ERROR':'INTERNAL_ERROR';if(status>=500)request.log.error({err:error},'request failed');reply.code(status).send({error:{code,message:status>=500?'An unexpected error occurred':err.message,requestId:request.id,details:error instanceof ZodError?{issues:error.issues}:undefined}});});

const stop=async(signal:string)=>{app.log.info({signal},'shutting down');await app.close();await db.end();process.exit(0);};process.on('SIGTERM',()=>void stop('SIGTERM'));process.on('SIGINT',()=>void stop('SIGINT'));
await app.listen({host:'0.0.0.0',port:env.PORT});
