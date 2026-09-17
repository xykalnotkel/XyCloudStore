import test from 'node:test';
import assert from 'node:assert/strict';
import {webcrypto} from 'node:crypto';
import {execFileSync} from 'node:child_process';
import {build} from 'esbuild';
import {Miniflare,convertV4MiniflareOptions} from 'miniflare';

test('Sewa nyata: saldo/host atomik, idempotensi, ACL agen, akhir sesi dan CS 7 hari',{timeout:120000},async()=>{
 const js=await build({entryPoints:['src/index.js'],bundle:true,format:'esm',loader:{'.html':'text','.png':'binary'},write:false});
 const secret='test-signature-only';
 const mf=new Miniflare(convertV4MiniflareOptions({modules:true,script:js.outputFiles[0].text,compatibilityDate:'2025-01-01',d1Databases:['DB'],durableObjects:{HUB:'RealtimeHub'},bindings:{JWT_SECRET:secret,ADMIN_KEY:'test-admin'}}));
 try{
  const db=await mf.getD1Database('DB');
  const statements=JSON.parse(execFileSync('python3',['-c',"import json,sqlite3\na=[];b=''\nfor c in open('schema.sql').read():\n b+=c\n if c==';' and sqlite3.complete_statement(b):a.append(b);b=''\nprint(json.dumps(a))"],{encoding:'utf8'}));
  for(const q of statements)await db.prepare(q).run();
  await db.prepare("INSERT INTO users(id,nama,email,password,saldo) VALUES('u','U','u@example.invalid','test',50000),('v','V','v@example.invalid','test',50000)").run();
  await db.prepare("INSERT INTO pc_plans(id,nama,gpu,cpu,ram_gb,storage_gb,harga_per_jam,harga_per_hari,region,total_unit,unit_tersedia) VALUES('p','PC test','Test GPU','Test CPU',16,100,10000,100000,'test',1,1)").run();
  await db.prepare("INSERT INTO agen(id,nama,kode,plan_id,host,versi,spec,terakhir) VALUES('a','Unit test','test-agent','p','192.0.2.1','1.1.0',?,?)").bind(JSON.stringify({sunshine:{siap:true}}),new Date().toISOString()).run();
  const token=async id=>{const b=Buffer.from(JSON.stringify({v:2,sv:0,sub:id,exp:Date.now()+3600000})).toString('base64url');const k=await webcrypto.subtle.importKey('raw',new TextEncoder().encode(secret),{name:'HMAC',hash:'SHA-256'},false,['sign']);return b+'.'+Buffer.from(await webcrypto.subtle.sign('HMAC',k,new TextEncoder().encode(b))).toString('base64url')};
  const auth=await token('u'),other=await token('v');
  const api=async(path,method='GET',body,token=auth,extra={})=>{const r=await mf.dispatchFetch('https://api.example.invalid/api'+path,{method,headers:{'Content-Type':'application/json',Authorization:'Bearer '+token,...extra},...(body?{body:JSON.stringify(body)}:{})});return {status:r.status,data:await r.json()}};
  let r=await api('/orders','POST',{plan_id:'p',durasi_jam:1,metode:'qris'});assert.equal(r.status,400);
  r=await api('/orders','POST',{plan_id:'p',durasi_jam:-1,metode:'saldo'});assert.equal(r.status,400);
  r=await api('/orders/estimasi','POST',{plan_id:'p',durasi_jam:1});assert.equal(r.data.data.total,11000);
  const request={plan_id:'p',durasi_jam:1,metode:'saldo',request_id:'request-test-0001',total_disetujui:11000};
  r=await api('/orders','POST',request);assert.equal(r.status,201,JSON.stringify(r.data));const order=r.data.data;
  assert.equal(await db.prepare("SELECT saldo FROM users WHERE id='u'").first('saldo'),39000);
  assert.equal(await db.prepare("SELECT sesi_aktif FROM agen WHERE id='a'").first('sesi_aktif'),'order:'+order.id);
  r=await api('/orders','POST',request);assert.equal(r.status,200);assert.equal(r.data.data.id,order.id);
  assert.equal(await db.prepare("SELECT saldo FROM users WHERE id='u'").first('saldo'),39000);
  r=await api('/orders','POST',{...request,request_id:'request-test-0002'},other);assert.equal(r.status,409);
  assert.equal(await db.prepare("SELECT saldo FROM users WHERE id='v'").first('saldo'),50000);
  r=await api('/sesi/mulai','POST',{order_id:order.id});assert.equal(r.status,201,JSON.stringify(r.data));const session=r.data.data;
  r=await api('/sesi/mulai','POST',{order_id:order.id});assert.equal(r.data.data.id,session.id);
  assert.equal(await db.prepare("SELECT COUNT(*) n FROM perintah WHERE jenis='mulai_sesi'").first('n'),1);
  const cmd=await db.prepare("SELECT * FROM perintah WHERE jenis='mulai_sesi'").first();
  r=await api('/agen/perintah/'+cmd.id,'POST',{ok:true,sesi_id:'wrong'},auth,{'x-agen-kode':'test-agent'});assert.equal(r.status,403);
  r=await api('/agen/perintah/'+cmd.id,'POST',{ok:true,sesi_id:session.id,host:'192.0.2.1'},auth,{'x-agen-kode':'test-agent'});assert.equal(r.status,200,JSON.stringify(r.data));
  assert.equal(await db.prepare('SELECT status FROM orders WHERE id=?').bind(order.id).first('status'),'aktif');
  r=await api('/sesi/'+session.id);assert.ok(r.data.data.berakhir);assert.equal(r.data.data.status,'siap');
  r=await api('/sesi/'+session.id+'/akhiri','POST',{});assert.equal(r.status,200);
  assert.equal(await db.prepare("SELECT sesi_aktif FROM agen WHERE id='a'").first('sesi_aktif'),session.id,'host stays locked until cleanup ACK');
  r=await api('/agen/perintah/end_'+session.id,'POST',{ok:true,sesi_id:session.id},auth,{'x-agen-kode':'test-agent'});assert.equal(r.status,200);
  assert.equal(await db.prepare("SELECT sesi_aktif FROM agen WHERE id='a'").first('sesi_aktif'),null);
  assert.equal(await db.prepare("SELECT unit_tersedia FROM pc_plans WHERE id='p'").first('unit_tersedia'),1);
  assert.equal(await db.prepare("SELECT saldo FROM users WHERE id='u'").first('saldo'),39000,'no refund after host was ready');
  // Unused paid reservation is cancelable and refunds exactly once.
  r=await api('/orders','POST',{...request,request_id:'request-test-0003'});const cancelled=r.data.data;
  r=await api('/orders/'+cancelled.id+'/batal','POST',{});assert.equal(r.status,200);
  r=await api('/orders/'+cancelled.id+'/batal','POST',{});assert.equal(r.status,409);
  assert.equal(await db.prepare("SELECT saldo FROM users WHERE id='u'").first('saldo'),39000);
  // User cannot impersonate an operator, nor resurrect old/deleted messages.
  r=await api('/cs/reply','POST',{room:'user:v',teks:'fake admin'});assert.equal(r.status,403);
  await db.prepare("INSERT INTO cs_messages(id,room,user_id,dari,teks,waktu) VALUES('expired','user:u','u','cs','old',datetime('now','-8 days')),('fresh','user:u','u','cs','fresh',datetime('now'))").run();
  r=await api('/cs/messages');assert.equal(r.data.data.length,1);assert.equal(r.data.data[0].id,'fresh');
  const message={teks:'same delivery',client_id:'message-test-001'};
  const first=await api('/cs/messages','POST',message),again=await api('/cs/messages','POST',message);
  assert.equal(first.data.data.id,again.data.data.id);
  assert.equal(await db.prepare("SELECT COUNT(*) n FROM cs_messages WHERE client_id='message-test-001'").first('n'),1);
  const ws=await mf.dispatchFetch('https://api.example.invalid/ws/user:v',{headers:{Upgrade:'websocket'}});assert.equal(ws.status,401);
 }finally{await mf.dispose();}
});
