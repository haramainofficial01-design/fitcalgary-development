import { readFile, readdir } from 'node:fs/promises';
import { join } from 'node:path';
import { createPool } from '../db/pool.js';
import { loadEnv } from '../config/env.js';
const env=loadEnv();const db=createPool(env.DATABASE_URL);await db.query('CREATE TABLE IF NOT EXISTS schema_migrations (name text PRIMARY KEY, applied_at timestamptz NOT NULL DEFAULT now())');
const directory=new URL('../../migrations/',import.meta.url);for(const name of (await readdir(directory)).filter((file)=>file.endsWith('.sql')).sort()){const applied=await db.query('SELECT 1 FROM schema_migrations WHERE name=$1',[name]);if(applied.rowCount)continue;const sql=await readFile(join(directory.pathname,name),'utf8');const statements=sql.split('-- statement-breakpoint').map((item)=>item.trim()).filter(Boolean);const client=await db.connect();try{await client.query('BEGIN');for(const statement of statements)await client.query(statement);await client.query('INSERT INTO schema_migrations(name) VALUES($1)',[name]);await client.query('COMMIT');console.info(`Applied ${name}`);}catch(error){await client.query('ROLLBACK');throw error;}finally{client.release();}}
await db.end();
