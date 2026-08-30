import type { Role } from '@fitcalgary/contracts';
import type { Principal } from './oidc.js';
export class ForbiddenError extends Error { readonly statusCode=403; readonly code='FORBIDDEN'; }
export function requireRole(principal:Principal|undefined,...allowed:Role[]):Principal { if(!principal||!principal.roles.some((role)=>allowed.includes(role)))throw new ForbiddenError('You do not have permission for this operation');return principal; }
export function requireSubject(principal:Principal|undefined):Principal { if(!principal)throw new ForbiddenError('Authentication is required');return principal; }
