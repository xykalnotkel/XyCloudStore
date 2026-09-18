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
  assert.match(baru,/^pbkdf2-sha256\$100000\$[a-f0-9]{32}\$[a-f0-9]{64}$/);
  assert.equal(baru.includes('Aman-Sekali-2026'),false);

  const sandiLama='warisan-yang-benar';
  const salt='0123456789abcdef';
  const hash=createHash('sha256').update(`${salt}:${sandiLama}`).digest('hex');
  await h.db.prepare("INSERT INTO users(id,nama,email,password,email_verified) VALUES('legacy','Legacy','legacy@example.invalid',?,1)").bind(`${salt}$${hash}`).run();
  r=await h.call('/auth/login','POST',{email:'legacy@example.invalid',password:sandiLama},device);
  assert.equal(r.status,200,JSON.stringify(r.json));
  await jeda(25);
  const upgraded=await h.db.prepare("SELECT password FROM users WHERE id='legacy'").first('password');
  assert.match(upgraded,/^pbkdf2-sha256\$100000\$/);
  assert.notEqual(upgraded,`${salt}$${hash}`);
  assert.equal((await h.call('/auth/login','POST',{email:'legacy@example.invalid',password:'salah-sekali'},device)).status,401);
 }finally{await h.mf.dispose();}
});

// REGRESI RUNTIME: Cloudflare Workers (workerd) menolak PBKDF2 dengan iterasi
// > 100.000 ("Iteration counts above 100000 are not supported"), sedangkan Node
// tidak membedakannya. Dua test ini mengunci: (1) hash baru selalu <= batas
// runtime Workers, (2) hash tersimpan yang melebihi batas ditolak sebagai 401,
// BUKAN melempar menjadi HTTP 500 yang mengunci semua login (insiden 2026-09-18).
test('Iterasi PBKDF2 hash baru tidak melebihi batas runtime Workers (100k)', {timeout:120000}, async()=>{
 const h=await harness();
 try{
  const device={'X-XY-Device':'e'.repeat(64),'X-XY-Device-Kind':'android'};
  const r=await h.call('/auth/register','POST',{nama:'Batas Runtime',email:'batas@example.invalid',password:'Aman-Sekali-2026',phone:'08123456789'},device);
  assert.equal(r.status,201,JSON.stringify(r.json));
  const hash=await h.db.prepare("SELECT password FROM users WHERE email='batas@example.invalid'").first('password');
  const iterasi=Number(String(hash).split('$')[1]);
  assert.ok(Number.isFinite(iterasi)&&iterasi<=100000,`iterasi ${iterasi} melebihi batas WebCrypto Workers (100000) - login produksi akan 500`);
 }finally{await h.mf.dispose();}
});

test('Hash tersimpan dengan iterasi di atas batas runtime ditolak 401, bukan 500', async()=>{
 const h=await harness();
 try{
  const over='pbkdf2-sha256$210000$'+'0'.repeat(32)+'$'+'0'.repeat(64);
  await h.db.prepare("INSERT INTO users(id,nama,email,password,email_verified) VALUES ('overcap','OC','overcap@example.invalid',?,1)").bind(over).run();
  const r=await h.call('/auth/login','POST',{email:'overcap@example.invalid',password:'apa-saja'});
  assert.equal(r.status,401,`diharapkan 401, dapat ${r.status}: ${JSON.stringify(r.json)}`);
 }finally{await h.mf.dispose();}
});
