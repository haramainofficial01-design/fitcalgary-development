import test from 'node:test';import assert from 'node:assert/strict';import { requireRole } from '../src/auth/authorize.ts';
const principal={subject:'user-a',email:null,emailVerified:true,roles:['USER'] as const,token:{}};test('client role spoofing cannot satisfy server authorization',()=>assert.throws(()=>requireRole(principal as never,'ADMIN'),/permission/));
