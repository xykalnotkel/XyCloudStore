import test from 'node:test';
import assert from 'node:assert/strict';
import {createHash, createHmac} from 'node:crypto';
import {harness} from './harness.mjs';

const secret='local-tests-only-not-production';
const rawDevice='d'.repeat(64);
const verifier='b'.repeat(64);
const challenge=createHash('sha256').update(verifier).digest('base64url');
const keyed=(purpose,value)=>createHmac('sha256',secret).update(`${purpose}:${value}`).digest('hex');

async function simpanHandoff(db,{code='c'.repeat(64),device=rawDevice,expires=120000}={}){
 const now=new Date().toISOString();
 await db.prepare(`INSERT INTO oauth_handoffs
  (id,provider,user_id,device_id,handoff_challenge,session_version,created_at,expires_at)
  VALUES(?,?,?,?,?,?,?,?)`).bind(
   keyed('oauth-handoff',code),'google','oauth-user',keyed('device',device),challenge,0,now,
   new Date(Date.now()+expires).toISOString(),
 ).run();
 return code;
}

const headers=(device=rawDevice)=>({'X-XY-Device':device,'X-XY-Device-Kind':'android'});

test('handoff OAuth memerlukan verifier dan device, replay identik deterministik, lalu habis pada batas lima',{timeout:120000},async()=>{
 const h=await harness();
 try{
  await h.db.prepare("INSERT INTO users(id,nama,email,password,email_verified) VALUES('oauth-user','OAuth User','oauth@example.invalid','sosial:google',1)").run();
  const code=await simpanHandoff(h.db);

  let r=await h.call('/auth/social/exchange','POST',{code,verifier:'a'.repeat(64)},headers());
  assert.equal(r.status,401);assert.ok(!JSON.stringify(r.json).includes('token'));
  r=await h.call('/auth/social/exchange','POST',{code,verifier},headers('e'.repeat(64)));
  assert.equal(r.status,401);assert.ok(!JSON.stringify(r.json).includes('token'));
  assert.equal(await h.db.prepare('SELECT exchange_count FROM oauth_handoffs').first('exchange_count'),0);

  r=await h.call('/auth/social/exchange','POST',{code,verifier},headers());
  assert.equal(r.status,200,JSON.stringify(r.json));
  const token=r.json.data.token;assert.match(token,/^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/);
  for(let i=1;i<5;i++){
   r=await h.call('/auth/social/exchange','POST',{code,verifier},headers());
   assert.equal(r.status,200,JSON.stringify(r.json));assert.equal(r.json.data.token,token);
  }
  r=await h.call('/auth/social/exchange','POST',{code,verifier},headers());
  assert.equal(r.status,401);assert.ok(!JSON.stringify(r.json).includes(token));
  assert.equal(await h.db.prepare('SELECT exchange_count FROM oauth_handoffs').first('exchange_count'),5);
 }finally{await h.mf.dispose();}
});

test('handoff OAuth menolak expiry dan perubahan session_version tanpa menerbitkan token',{timeout:120000},async()=>{
 const h=await harness();
 try{
  await h.db.prepare("INSERT INTO users(id,nama,email,password,email_verified) VALUES('oauth-user','OAuth User','oauth@example.invalid','sosial:google',1)").run();
  const expired=await simpanHandoff(h.db,{code:'1'.repeat(64),expires:-1000});
  let r=await h.call('/auth/social/exchange','POST',{code:expired,verifier},headers());
  assert.equal(r.status,401);assert.ok(!JSON.stringify(r.json).includes('token'));

  const stale=await simpanHandoff(h.db,{code:'2'.repeat(64)});
  await h.db.prepare("UPDATE users SET session_version=1 WHERE id='oauth-user'").run();
  r=await h.call('/auth/social/exchange','POST',{code:stale,verifier},headers());
  assert.equal(r.status,401);assert.ok(!JSON.stringify(r.json).includes('token'));
 }finally{await h.mf.dispose();}
});
