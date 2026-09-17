import test from 'node:test';
import assert from 'node:assert/strict';
import {harness} from './harness.mjs';
import {securitySlot,newOAuthState,consumeOAuthState} from '../src/security.js';

test('Batas dua pendaftaran berlaku di server dan trigger; Sampah/pulihkan/permanen dilindungi',{timeout:120000},async()=>{
 const h=await harness();
 try{
  const device={'X-XY-Device':'a'.repeat(64),'X-XY-Device-Kind':'android'};
  for(const email of ['one@example.invalid','two@example.invalid']){
   const r=await h.call('/auth/register','POST',{nama:'Pengguna Uji',email,password:'safe-test-password'},device);assert.equal(r.status,201,JSON.stringify(r.json));
  }
  let r=await h.call('/auth/register','POST',{nama:'Akun Ketiga',email:'three@example.invalid',password:'safe-test-password'},device);
  assert.equal(r.status,429);assert.equal(r.json.code,'DEVICE_LIMIT');
  assert.equal(await h.db.prepare('SELECT COUNT(*) n FROM users').first('n'),2);
  const d=await h.db.prepare('SELECT * FROM security_devices').first();assert.equal(d.registrations,2);
  await assert.rejects(h.db.prepare("INSERT INTO users(id,nama,email,password,registration_device) VALUES('bypass','Test','direct@example.invalid','test',?)").bind(d.id).run(),/DEVICE_LIMIT/);
  // Counters remain consumed after deleting an account; a user cannot delete/recreate to bypass the cap.
  const user=await h.db.prepare("SELECT * FROM users WHERE email='one@example.invalid'").first();
  const admin={'x-admin-key':'test-admin'};
  r=await h.call('/admin/users/'+user.id+'/trash','POST',{konfirmasi:'HAPUS'},admin);assert.equal(r.status,200,JSON.stringify(r.json));
  r=await h.call('/auth/login','POST',{email:user.email,password:'safe-test-password'},device);assert.equal(r.status,403);
  r=await h.call('/admin/users/'+user.id+'/restore','POST',{},admin);assert.equal(r.status,200);
  r=await h.call('/admin/users/'+user.id+'/permanent','DELETE',{konfirmasi:'HAPUS PERMANEN',email:user.email},admin);assert.equal(r.status,409);
  await h.call('/admin/users/'+user.id+'/trash','POST',{konfirmasi:'HAPUS'},admin);
  r=await h.call('/admin/users/'+user.id+'/permanent','DELETE',{konfirmasi:'HAPUS PERMANEN',email:'wrong@example.invalid'},admin);assert.equal(r.status,400);
  r=await h.call('/admin/users/'+user.id+'/permanent','DELETE',{konfirmasi:'HAPUS PERMANEN',email:user.email},admin);assert.equal(r.status,200,JSON.stringify(r.json));
  assert.equal(await h.db.prepare('SELECT COUNT(*) n FROM users WHERE id=?').bind(user.id).first('n'),0);
  assert.equal(await h.db.prepare('SELECT registrations FROM security_devices WHERE id=?').bind(d.id).first('registrations'),2);
  await h.db.prepare("INSERT INTO users(id,nama,email,password) VALUES('owner','Owner','owner@example.invalid','test'),('funded','Funded','funded@example.invalid','test')").run();
  await h.db.prepare("UPDATE users SET saldo=10000 WHERE id='funded'").run();
  r=await h.call('/admin/users/owner/trash','POST',{konfirmasi:'HAPUS'},admin);assert.equal(r.status,409);
  r=await h.call('/admin/users/funded/trash','POST',{konfirmasi:'HAPUS'},admin);assert.equal(r.status,409);
  r=await h.call('/admin/devices/'+d.id+'/reset','POST',{konfirmasi:'RESET'},admin);assert.equal(r.status,200);
  assert.equal(await h.db.prepare('SELECT registrations FROM security_devices WHERE id=?').bind(d.id).first('registrations'),0);
 }finally{await h.mf.dispose();}
});

test('Batas permintaan atomik, OAuth state satu kali, dan token lama dicabut',{timeout:120000},async()=>{
 const h=await harness();
 try{
  const env={DB:h.db,JWT_SECRET:'local-tests-only-not-production'};
  const slots=await Promise.all(Array.from({length:12},()=>securitySlot(env,'parallel','subject',2,3600)));
  assert.equal(slots.filter(Boolean).length,2);
  const challenge='A'.repeat(43),oauthDevice='d'.repeat(64);
  await assert.rejects(newOAuthState(env,'google',null,challenge),/Identitas perangkat/);
  await assert.rejects(newOAuthState(env,'google',oauthDevice,'tidak-sah'),/Challenge/);
  const state=await newOAuthState(env,'google',oauthDevice,challenge);
  await assert.rejects(consumeOAuthState(env,new Request('https://api.example.invalid/api/auth/google/callback?state='+state),'google'),/Sesi login/);
  const request=new Request('https://api.example.invalid/api/auth/google/callback?state='+state,{headers:{Cookie:'xy_oauth_nonce='+state}});
  assert.deepEqual(await consumeOAuthState(env,request,'google'),{deviceId:oauthDevice,handoffChallenge:challenge});
  await assert.rejects(consumeOAuthState(env,request,'google'),/kedaluwarsa/);
  await h.db.prepare("INSERT INTO users(id,nama,email,password,email_verified) VALUES('u','U','u@example.invalid','test-password',1)").run();
  const old=await h.token('u',{v:1}),fresh=await h.token('u');
  assert.equal((await h.call('/me','GET',null,{Authorization:'Bearer '+old})).status,401);
  assert.equal((await h.call('/me','GET',null,{Authorization:'Bearer '+fresh})).status,200);
  await h.db.prepare("UPDATE users SET session_version=1 WHERE id='u'").run();
  assert.equal((await h.call('/me','GET',null,{Authorization:'Bearer '+fresh})).status,401);
 }finally{await h.mf.dispose();}
});
