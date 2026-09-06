// Isolated real local storage. Credentials exist only in child-process environments.
import { spawn } from 'node:child_process';
import { randomBytes } from 'node:crypto';
import { mkdtemp, readFile, writeFile } from 'node:fs/promises';
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
  if(code===0&&(process.env.VERIFY_STORAGE_BROWSER==='true'||process.env.VERIFY_STORAGE_FLUTTER)){
    const harness=path.join(data,'fitcalgary-test-api'),video=path.join(data,'evidence-test-clip.mp4');
    await run(path.join(root,'.tooling/go/bin/go'),['build','-o',harness,'./cmd/phase1-harness'],path.join(root,'services/api-go'));
    await run(path.join(root,'.tooling/ffmpeg-arm64/bin/ffmpeg'),['-loglevel','error','-f','lavfi','-i','testsrc2=size=320x240:rate=15','-t','3','-c:v','libx264','-pix_fmt','yuv420p','-movflags','+faststart',video],data);
    if(process.env.VERIFY_STORAGE_BROWSER==='true')await run(process.execPath,['--experimental-strip-types','test/admin-browser.mjs'],path.join(root,'apps/web'),{TEST_DATABASE_URL:process.env.DIRECTORY_TEST_DATABASE_URL,TEST_API_HARNESS:harness,TEST_EVIDENCE_VIDEO:video});
    if(process.env.VERIFY_STORAGE_FLUTTER){
      const user=randomBytes(32).toString('hex'),admin=randomBytes(32).toString('hex');
      const api=spawn(harness,[],{cwd:path.join(root,'services/api-go'),env:{...testEnv,APP_ENV:'development',PHASE1_HARNESS_ENABLED:'true',DATABASE_URL:process.env.DIRECTORY_TEST_DATABASE_URL,PHASE1_USER_TOKEN:user,PHASE1_ADMIN_TOKEN:admin,PHASE1_TOKEN_CIPHER_KEY:randomBytes(16).toString('hex'),PORT:'4404'},stdio:'ignore'});
      try{
        let ready=false;
        for(let i=0;i<100;i++) {try{if((await fetch('http://127.0.0.1:4404/health')).ok){ready=true;break;}}catch{}await new Promise(resolve=>setTimeout(resolve,200));}
        if(!ready)throw new Error('Mobile test API unavailable');
        const config=path.join(data,'mobile-test.json');
        await writeFile(config,JSON.stringify({API_BASE_URL:'http://127.0.0.1:4404/api/v1',TEST_USER_TOKEN:user,TEST_ADMIN_TOKEN:admin,TEST_EVIDENCE_BASE64:(await readFile(video)).toString('base64')}),{mode:0o600});
        for(const device of process.env.VERIFY_STORAGE_FLUTTER.split(',')){
          if(device.startsWith('emulator-')){
            await run('/Users/sahlshafiq/.fitcalgary-tooling/android-sdk/platform-tools/adb',['-s',device,'wait-for-device'],root);
            for(const port of ['4404','18333'])await run('/Users/sahlshafiq/.fitcalgary-tooling/android-sdk/platform-tools/adb',['-s',device,'reverse',`tcp:${port}`,`tcp:${port}`],root);
          }
          await run(path.join(root,'.tooling/flutter/bin/flutter'),['test','integration_test/private_evidence_flow_test.dart','-d',device,'--dart-define-from-file='+config],path.join(root,'apps/fitcalgary_app'));
        }
      }finally{api.kill('SIGTERM');}
    }
  }
} finally { storage.kill('SIGTERM'); }
