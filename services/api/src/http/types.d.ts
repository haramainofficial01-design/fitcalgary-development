import type { Principal } from '../auth/oidc.js';
declare module 'fastify' { interface FastifyRequest { principal?:Principal; profileId?:string; } }
