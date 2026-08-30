import { z } from 'zod';

const schema = z.object({
  NODE_ENV: z.enum(['development','test','production']).default('development'),
  PORT: z.coerce.number().int().min(1).max(65535).default(4000),
  DATABASE_URL: z.string().url(),
  KEYCLOAK_ISSUER: z.string().url(),
  KEYCLOAK_AUDIENCE: z.string().min(1).default('fitcalgary-api'),
  WEB_PUBLIC_URL: z.string().url().default('http://localhost:3000'),
  S3_ENDPOINT: z.string().url(), S3_REGION: z.string().min(1), S3_BUCKET: z.string().min(1),
  S3_ACCESS_KEY_ID: z.string().min(1), S3_SECRET_ACCESS_KEY: z.string().min(1),
  SIGNED_URL_TTL_SECONDS: z.coerce.number().int().min(30).max(900).default(300),
  MAX_EVIDENCE_BYTES: z.coerce.number().int().positive().max(4_294_967_296).default(4_294_967_296),
  EVIDENCE_RETENTION_DAYS: z.coerce.number().int().min(1).max(90).default(14),
  LOG_LEVEL: z.enum(['fatal','error','warn','info','debug','trace','silent']).default('info'),
});
export type Env = z.infer<typeof schema>;
export function loadEnv(source: NodeJS.ProcessEnv = process.env): Env { return schema.parse(source); }
