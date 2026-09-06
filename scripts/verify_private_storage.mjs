// Isolated real local storage. Credentials exist only in child-process environments.
import { spawn } from 'node:child_process';
import { randomBytes } from 'node:crypto';
import { mkdtemp } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const root = fileURLToPath(new URL('..', import.meta.url));
const data = await mkdtemp(path.join(tmpdir(), 'fitcalgary-private-storage-'));
const access = randomBytes(16).toString('hex'), secret = randomBytes(32).toString('hex');
const env = { ...process.env, AWS_ACCESS_KEY_ID: access, AWS_SECRET_ACCESS_KEY: secret };
const storage = spawn(path.join(root,'.tooling/seaweedfs-4.45/weed'), ['mini',`-dir=${data}`,'-ip=127.0.0.1','-ip.bind=127.0.0.1','-s3.port=18333','-master.port=19333','-volume.port=19340','-filer.port=18888','-admin.ui=false','-webdav=false','-s3.port.iceberg=0','-s3.port.lance=0','-master.telemetry=false'], {cwd:data,env,stdio:'ignore'});
const testEnv={...process.env,STORAGE_TEST_ENDPOINT:'http://127.0.0.1:18333',STORAGE_TEST_ACCESS_KEY:access,STORAGE_TEST_SECRET_KEY:secret};
async function run(command,args,cwd,extra={}){
  const code=await new Promise((resolve,reject)=>{const child=spawn(command,args,{cwd,env:{...testEnv,...extra},stdio:'inherit'});child.on('error',reject);child.on('exit',resolve);});
  if(code!==0)throw new Error('Verification command failed');
}
try {
  let ready = false;
  for (let i=0;i<120;i++) {
    if (storage.exitCode !== null) throw new Error('Local storage stopped');
    try { const response=await fetch('http://127.0.0.1:18333/'); if(response.status===403){ready=true;break;} } catch {}
    await new Promise(resolve=>setTimeout(resolve,250));
  }
  if (!ready) throw new Error('Authenticated storage readiness timeout');
  const code = await new Promise((resolve,reject)=>{
    const child=spawn(path.join(root,'.tooling/go/bin/go'),['test','-p','1','./internal/storage','./internal/httpapi','-run','TestPrivateMultipartStorage|TestCompetitionDatabaseWorkflow','-count=1','-v'],{cwd:path.join(root,'services/api-go'),env:{...process.env,STORAGE_TEST_ENDPOINT:'http://127.0.0.1:18333',STORAGE_TEST_ACCESS_KEY:access,STORAGE_TEST_SECRET_KEY:secret},stdio:'inherit'});
    child.on('error',reject);child.on('exit',resolve);
  });
  if(code!==0) process.exitCode=1;
  if(code===0&&process.env.VERIFY_STORAGE_BROWSER==='true'){
    const harness=path.join(data,'fitcalgary-test-api'),video=path.join(data,'evidence-test-clip.mp4');
    await run(path.join(root,'.tooling/go/bin/go'),['build','-o',harness,'./cmd/phase1-harness'],path.join(root,'services/api-go'));
    await run(path.join(root,'.tooling/ffmpeg-arm64/bin/ffmpeg'),['-loglevel','error','-f','lavfi','-i','testsrc2=size=320x240:rate=15','-t','3','-c:v','libx264','-pix_fmt','yuv420p','-movflags','+faststart',video],data);
    await run(process.execPath,['--experimental-strip-types','test/admin-browser.mjs'],path.join(root,'apps/web'),{TEST_DATABASE_URL:process.env.DIRECTORY_TEST_DATABASE_URL,TEST_API_HARNESS:harness,TEST_EVIDENCE_VIDEO:video});
  }
} finally { storage.kill('SIGTERM'); }
