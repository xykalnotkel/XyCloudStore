import test from 'node:test';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {setTimeout as jeda} from 'node:timers/promises';
import {harness} from './harness.mjs';
test('Verifikasi ulang tanpa OTP dan password penanda sosial tidak menerbitkan token',async()=>{
 const h=await harness();
 try{
  await h.db.prepare("INSERT INTO users(id,nama,email,password,email_verified) VALUES ('verified','V','v@example.invalid','test',1),('social','S','s@example.invalid','sosial:google',1)").run();
  const r=await h.call('/auth/verify','POST',{email:'v@example.invalid',kode:''});
  assert.equal(r.status,409);assert.ok(!JSON.stringify(r.json).includes('token'));
  const social=await h.call('/auth/login','POST',{email:'s@example.invalid',password:'sosial:google'});
  assert.equal(social.status,401);assert.ok(!JSON.stringify(social.json).includes('token'));
 }finally{await h.mf.dispose();}
});

test('Password baru memakai PBKDF2 dan hash warisan dimigrasikan saat login', {timeout:120000}, async()=>{
 const h=await harness();
 try{
  const device={'X-XY-Device':'f'.repeat(64),'X-XY-Device-Kind':'android'};
  let r=await h.call('/auth/register','POST',{nama:'Pengguna Aman',email:'aman@example.invalid',password:'tujuh77',phone:'08123456789'},device);
  assert.equal(r.status,400);
  r=await h.call('/auth/register','POST',{nama:'Pengguna Aman',email:'aman@example.invalid',password:'Aman-Sekali-2026',phone:'08123456789'},device);
  assert.equal(r.status,201,JSON.stringify(r.json));
  const baru=await h.db.prepare("SELECT password FROM users WHERE email='aman@example.invalid'").first('password');
  assert.match(baru,/^pbkdf2-sha256\$210000\$[a-f0-9]{32}\$[a-f0-9]{64}$/);
  assert.equal(baru.includes('Aman-Sekali-2026'),false);

  const sandiLama='warisan-yang-benar';
  const salt='0123456789abcdef';
  const hash=createHash('sha256').update(`${salt}:${sandiLama}`).digest('hex');
  await h.db.prepare("INSERT INTO users(id,nama,email,password,email_verified) VALUES('legacy','Legacy','legacy@example.invalid',?,1)").bind(`${salt}$${hash}`).run();
  r=await h.call('/auth/login','POST',{email:'legacy@example.invalid',password:sandiLama},device);
  assert.equal(r.status,200,JSON.stringify(r.json));
  await jeda(25);
  const upgraded=await h.db.prepare("SELECT password FROM users WHERE id='legacy'").first('password');
  assert.match(upgraded,/^pbkdf2-sha256\$210000\$/);
  assert.notEqual(upgraded,`${salt}$${hash}`);
  assert.equal((await h.call('/auth/login','POST',{email:'legacy@example.invalid',password:'salah-sekali'},device)).status,401);
 }finally{await h.mf.dispose();}
});
