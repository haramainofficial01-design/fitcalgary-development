import pg from 'pg';
const { Pool } = pg;
export type Db = pg.Pool;
export function createPool(connectionString:string):Db { return new Pool({connectionString,max:20,idleTimeoutMillis:30_000,connectionTimeoutMillis:5_000,ssl:process.env.NODE_ENV==='production'?{rejectUnauthorized:true}:undefined}); }
export async function transaction<T>(db:Db,work:(client:pg.PoolClient)=>Promise<T>):Promise<T>{const client=await db.connect();try{await client.query('BEGIN');const value=await work(client);await client.query('COMMIT');return value;}catch(error){await client.query('ROLLBACK');throw error;}finally{client.release();}}
