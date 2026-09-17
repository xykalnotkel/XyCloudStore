import test from 'node:test';
import assert from 'node:assert/strict';
import {harness} from './harness.mjs';

const auth=async(h,id)=>({Authorization:`Bearer ${await h.token(id)}`});
const admin={'x-admin-key':'test-admin'};

async function user(db,id,{saldo=0,notif=1}={}){
 await db.prepare(`INSERT INTO users(id,nama,email,password,email_verified,saldo,notif_live)
  VALUES(?,?,?,?,1,?,?)`).bind(id,`Nama ${id}`,`${id}@example.invalid`,'test-password',saldo,notif).run();
}

async function agent(db,id){
 await db.prepare("INSERT INTO agen(id,nama,kode,status,terakhir) VALUES(?,?,?,'online',?)")
  .bind(id,`Unit ${id}`,`secret-${id}`,new Date().toISOString()).run();
}

async function live(db,{id='live_contract_1',creator='creator',agentId='agent-1',status='live',enable=true}={}){
 const now=new Date().toISOString();
 if(enable) await db.prepare("UPDATE setelan SET nilai='1' WHERE kunci='livestream_enabled'").run();
 await db.prepare(`INSERT INTO livestream
  (id,user_id,creator_name,agen_id,title,game,status,recording_consent,safe_scene_ack,
   mic_consent,scheduled_end,started_at,created_at,updated_at)
  VALUES(?,?,?,?,?,?,?,1,1,0,?,?,?,?)`).bind(
   id,creator,`Nama ${creator}`,agentId,'Push rank kontrak','Game Uji',status,
   new Date(Date.now()+3600000).toISOString(),now,now,now,
 ).run();
 return id;
}

async function creatorProfile(db,id){
 const now=new Date().toISOString();
 await db.prepare(`INSERT INTO creator_profile
  (user_id,status,display_name,bio,age_18,terms_version,payout_verified,payout_label,applied_at,updated_at)
  VALUES(?,'approved',?,'',1,'live-creator-v1',1,'BCA •••• 1234',?,?)`)
  .bind(id,`Nama ${id}`,now,now).run();
}

test('URL player menukar handoff D1 sekali pakai menjadi cookie berbeda dan URL bersih',{timeout:120000},async()=>{
 const h=await harness();
 try{
  await user(h.db,'viewer');await user(h.db,'creator');await agent(h.db,'agent-1');
  const id=await live(h.db,{});
  const issued=await h.call(`/live/${id}/watch`,'POST',{},await auth(h,'viewer'));
  assert.equal(issued.status,201,JSON.stringify(issued.json));
  const watchUrl=new URL(issued.json.data.watch_url);
  const queryTicket=watchUrl.searchParams.get('t');
  assert.ok(queryTicket);assert.match(queryTicket,/^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/);
  assert.equal(await h.db.prepare('SELECT COUNT(*) n FROM livestream_watch_handoff').first('n'),1);

  const exchange=await h.mf.dispatchFetch(watchUrl.toString(),{redirect:'manual'});
  assert.equal(exchange.status,303);
  assert.equal(exchange.headers.get('location'),`/live/watch/${id}`);
  const setCookie=exchange.headers.get('set-cookie') || '';
  assert.match(setCookie,new RegExp(`^xy_live_${id}=`));
  assert.match(setCookie,new RegExp(`Path=/live/watch/${id}`));
  assert.match(setCookie,/HttpOnly/i);assert.match(setCookie,/Secure/i);assert.match(setCookie,/SameSite=Lax/i);
  const cookiePair=setCookie.split(';')[0];
  const capability=decodeURIComponent(cookiePair.slice(cookiePair.indexOf('=')+1));
  assert.notEqual(capability,queryTicket,'query handoff tidak boleh menjadi cookie player');
  assert.equal(await h.db.prepare('SELECT COUNT(*) n FROM livestream_watch_handoff').first('n'),0);

  const replay=await h.mf.dispatchFetch(watchUrl.toString(),{redirect:'manual'});
  assert.equal(replay.status,200);
  const replayHtml=await replay.text();
  assert.match(replayHtml,/Buka aplikasi untuk menonton/);
  assert.doesNotMatch(replayHtml,/<iframe src=/);

  const clean=new URL(exchange.headers.get('location'),watchUrl.origin);
  const player=await h.mf.dispatchFetch(clean.toString(),{headers:{Cookie:cookiePair}});
  assert.equal(player.status,200);
  assert.match(await player.text(),/Token player aman belum tersedia/);
  const beat=await h.mf.dispatchFetch(`${clean}/heartbeat`,{method:'POST',headers:{Cookie:cookiePair}});
  assert.equal(beat.status,204);
 }finally{await h.mf.dispose();}
});

test('tip, replay, reversal, payout reject/paid menjaga saldo dan ledger atomik',{timeout:120000},async()=>{
 const h=await harness({
  CF_STREAM_API_TOKEN:'dummy-secret',
  CF_STREAM_ACCOUNT_ID:'a'.repeat(32),
  CF_STREAM_CUSTOMER_HOST:'customer-abcdef.cloudflarestream.com',
 });
 try{
  await user(h.db,'viewer',{saldo:250000});await user(h.db,'creator');await agent(h.db,'agent-1');
  await creatorProfile(h.db,'creator');await live(h.db,{});
  await h.db.prepare("UPDATE setelan SET nilai='1' WHERE kunci='livestream_enabled'").run();
  const viewerAuth=await auth(h,'viewer');
  const tipId='tip_contract_0001';
  let r=await h.call('/live/live_contract_1/tip','POST',{amount:125000,client_id:tipId,message:'Permainan bagus'},viewerAuth);
  assert.equal(r.status,201,JSON.stringify(r.json));
  assert.equal(r.json.data.tip.gross,125000);assert.equal(r.json.data.tip.creator_net,100000);
  assert.equal(await h.db.prepare("SELECT saldo FROM users WHERE id='viewer'").first('saldo'),125000);
  assert.equal(await h.db.prepare('SELECT COUNT(*) n FROM livestream_tip').first('n'),1);
  assert.equal(await h.db.prepare('SELECT status FROM creator_earning').first('status'),'held');

  r=await h.call('/live/live_contract_1/tip','POST',{amount:125000,client_id:tipId,message:'Permainan bagus'},viewerAuth);
  assert.equal(r.status,200);assert.equal(r.json.data.replay,true);
  assert.equal(await h.db.prepare("SELECT saldo FROM users WHERE id='viewer'").first('saldo'),125000);
  r=await h.call('/live/live_contract_1/tip','POST',{amount:130000,client_id:tipId,message:'Permainan bagus'},viewerAuth);
  assert.equal(r.status,409);
  assert.equal(await h.db.prepare("SELECT saldo FROM users WHERE id='viewer'").first('saldo'),125000);
  r=await h.call('/live/live_contract_1/tip','POST',{amount:125000,client_id:'tip_contract_long_0003',message:'x'.repeat(121)},viewerAuth);
  assert.equal(r.status,422);
  assert.equal(await h.db.prepare('SELECT COUNT(*) n FROM livestream_tip').first('n'),1);

  const storedTip=await h.db.prepare('SELECT id FROM livestream_tip').first('id');
  r=await h.call(`/admin/livestream/tips/${storedTip}/reverse`,'POST',{confirmation:'KEMBALIKAN',reason:'Fraud pada transaksi uji'},admin);
  assert.equal(r.status,200,JSON.stringify(r.json));
  assert.equal(await h.db.prepare("SELECT saldo FROM users WHERE id='viewer'").first('saldo'),250000);
  assert.equal(await h.db.prepare('SELECT status FROM creator_earning').first('status'),'reversed');
  assert.equal(await h.db.prepare("SELECT gross_tip FROM livestream WHERE id='live_contract_1'").first('gross_tip'),0);
  r=await h.call(`/admin/livestream/tips/${storedTip}/reverse`,'POST',{confirmation:'KEMBALIKAN',reason:'Fraud pada transaksi uji'},admin);
  assert.equal(r.status,200);assert.equal(r.json.data.replay,true);

  // Buat earning kedua yang cukup untuk payout.
  r=await h.call('/live/live_contract_1/tip','POST',{amount:125000,client_id:'tip_contract_0002',message:''},viewerAuth);
  assert.equal(r.status,201,JSON.stringify(r.json));
  await h.db.prepare("UPDATE creator_earning SET status='available' WHERE status='held'").run();
  const creatorAuth=await auth(h,'creator');
  r=await h.call('/live/creator/payout','POST',{client_id:'payout_contract_0001'},creatorAuth);
  assert.equal(r.status,201,JSON.stringify(r.json));
  const payout1=r.json.data.id;
  assert.equal(r.json.data.amount,100000);
  assert.equal(await h.db.prepare("SELECT status FROM creator_earning WHERE status!='reversed'").first('status'),'reserved');
  r=await h.call('/live/creator/payout','POST',{client_id:'payout_contract_0001'},creatorAuth);
  assert.equal(r.status,200);assert.equal(r.json.data.replay,true);assert.equal(r.json.data.id,payout1);
  r=await h.call('/live/creator/payout','POST',{client_id:'payout_contract_other'},creatorAuth);
  assert.equal(r.status,409);assert.equal(r.json.code,'PAYOUT_ACTIVE');
  assert.equal(await h.db.prepare('SELECT COUNT(*) n FROM creator_payout').first('n'),1);

  r=await h.call(`/admin/livestream/payouts/${payout1}`,'PATCH',{status:'rejected',provider_ref:'',note:'Data payout perlu diperbaiki'},admin);
  assert.equal(r.status,200,JSON.stringify(r.json));
  assert.equal(await h.db.prepare("SELECT status FROM creator_earning WHERE status!='reversed'").first('status'),'available');
  r=await h.call(`/admin/livestream/payouts/${payout1}`,'PATCH',{status:'rejected',provider_ref:'',note:'Data payout perlu diperbaiki'},admin);
  assert.equal(r.status,200);assert.equal(r.json.data.replay,true);

  r=await h.call('/live/creator/payout','POST',{client_id:'payout_contract_0002'},creatorAuth);
  assert.equal(r.status,201,JSON.stringify(r.json));
  const payout2=r.json.data.id;
  r=await h.call(`/admin/livestream/payouts/${payout2}`,'PATCH',{status:'paid',provider_ref:'BANK-REF-123',note:'',confirmation:'BAYAR'},admin);
  assert.equal(r.status,200,JSON.stringify(r.json));
  assert.equal(await h.db.prepare("SELECT status FROM creator_earning WHERE status!='reversed'").first('status'),'paid');
 }finally{await h.mf.dispose();}
});

test('ACK mulai membuat satu outbox/target snapshot dan trigger kapasitas tetap fail-closed',{timeout:120000},async()=>{
 const h=await harness();
 try{
  for(const [id,notif] of [['creator',1],['follower-on',1],['follower-off',0],['creator-2',1]]) await user(h.db,id,{notif});
  await agent(h.db,'agent-1');await agent(h.db,'agent-2');
  await h.db.prepare("INSERT INTO follows(ikut_id,target_id) VALUES('follower-on','creator'),('follower-off','creator')").run();
  const id=await live(h.db,{status:'starting'});
  const command=`live_start_${id}`;
  await h.db.prepare("INSERT INTO perintah(id,agen_id,jenis,muatan) VALUES(?,?,'mulai_siaran',?)")
   .bind(command,'agent-1',JSON.stringify({live_id:id})).run();
  let r=await h.call(`/agen/perintah/${command}`,'POST',{ok:true,live_id:id,code:'OK'},{'x-agen-kode':'secret-agent-1'});
  assert.equal(r.status,200,JSON.stringify(r.json));
  assert.equal(await h.db.prepare('SELECT status FROM livestream WHERE id=?').bind(id).first('status'),'live');
  assert.equal(await h.db.prepare('SELECT COUNT(*) n FROM livestream_push_outbox').first('n'),1);
  assert.equal(await h.db.prepare('SELECT COUNT(*) n FROM livestream_push_target').first('n'),1);
  assert.equal(await h.db.prepare("SELECT user_id FROM livestream_push_target").first('user_id'),'follower-on');
  assert.equal(await h.db.prepare("SELECT COUNT(*) n FROM notifikasi WHERE jenis='livestream'").first('n'),1);
  r=await h.call(`/agen/perintah/${command}`,'POST',{ok:true,live_id:id,code:'OK'},{'x-agen-kode':'secret-agent-1'});
  assert.equal(r.status,200);assert.equal(await h.db.prepare('SELECT COUNT(*) n FROM livestream_push_outbox').first('n'),1);

  await h.db.prepare("UPDATE livestream SET last_health_at=datetime('now','-31 seconds') WHERE id=?").bind(id).run();
  r=await h.call('/agen/heartbeat','POST',{
   status:'nilai-payload-tidak-dipercaya',live_health:{live_id:id,active:null,safe:null,code:'OBS_MONITOR_UNAVAILABLE'},
  },{'x-agen-kode':'secret-agent-1'});
  assert.equal(r.status,200,JSON.stringify(r.json));
  assert.equal(await h.db.prepare("SELECT status FROM agen WHERE id='agent-1'").first('status'),'online');
  assert.equal(await h.db.prepare('SELECT status FROM livestream WHERE id=?').bind(id).first('status'),'ending');
  assert.equal(await h.db.prepare('SELECT failure_code FROM livestream WHERE id=?').bind(id).first('failure_code'),'OBS_MONITOR_TIMEOUT');

  await h.db.prepare("UPDATE setelan SET nilai='1' WHERE kunci='livestream_max_concurrent'").run();
  await h.db.prepare("UPDATE livestream SET status='failed',cleanup_pending=1 WHERE id=?").bind(id).run();
  r=await h.call('/agen/heartbeat','POST',{
   status:'online',live_health:{live_id:id,active:false,safe:true,cleanup_pending:false,code:'OBS_CLEANUP_COMPLETED'},
  },{'x-agen-kode':'secret-agent-1'});
  assert.equal(r.status,200,JSON.stringify(r.json));
  assert.equal(await h.db.prepare('SELECT cleanup_pending FROM livestream WHERE id=?').bind(id).first('cleanup_pending'),1);
  await assert.rejects(live(h.db,{id:'live_contract_2',creator:'creator-2',agentId:'agent-2',status:'starting'}),/LIVESTREAM_(CAPACITY|CLEANUP_PENDING)/);
  await h.db.prepare("UPDATE livestream SET cleanup_pending=0 WHERE id=?").bind(id).run();
  await live(h.db,{id:'live_contract_2',creator:'creator-2',agentId:'agent-2',status:'starting'});
  assert.equal(await h.db.prepare("SELECT COUNT(*) n FROM livestream WHERE status='starting'").first('n'),1);
  await h.db.prepare("UPDATE livestream SET status='ended' WHERE id='live_contract_2'").run();
  await h.db.prepare("UPDATE setelan SET nilai='0' WHERE kunci='livestream_enabled'").run();
  await assert.rejects(
   live(h.db,{id:'live_contract_3',creator:'creator-2',agentId:'agent-2',status:'starting',enable:false}),
   /LIVESTREAM_DISABLED/,
  );
 }finally{await h.mf.dispose();}
});

test('pembekuan mencabut view dan menghentikan livestream kreator tanpa menunggu cron',{timeout:120000},async()=>{
 const h=await harness();
 try{
  await user(h.db,'creator');await user(h.db,'viewer');await agent(h.db,'agent-1');
  const id=await live(h.db,{});
  const now=new Date().toISOString();
  await h.db.prepare(`INSERT INTO livestream_view(id,livestream_id,viewer_id,started_at,last_seen)
   VALUES('view-block-contract',?,?,?,?)`).bind(id,'viewer',now,now).run();
  let r=await h.call('/admin/users/viewer/kelola','PATCH',{diblokir:true,alasan:'Uji pencabutan player'},admin);
  assert.equal(r.status,200,JSON.stringify(r.json));
  assert.equal(await h.db.prepare("SELECT COUNT(*) n FROM livestream_view WHERE viewer_id='viewer'").first('n'),0);
  assert.equal(await h.db.prepare('SELECT status FROM livestream WHERE id=?').bind(id).first('status'),'live');

  r=await h.call('/admin/users/creator/kelola','PATCH',{diblokir:true,alasan:'Uji terminasi live'},admin);
  assert.equal(r.status,200,JSON.stringify(r.json));
  assert.equal(await h.db.prepare('SELECT status FROM livestream WHERE id=?').bind(id).first('status'),'ending');
  assert.equal(await h.db.prepare("SELECT COUNT(*) n FROM perintah WHERE id=? AND jenis='akhiri_siaran'").bind(`live_end_${id}`).first('n'),1);
 }finally{await h.mf.dispose();}
});

test('rekonsiliasi owner mempertahankan idempotency key dan counter retry',{timeout:120000},async()=>{
 const h=await harness();
 try{
  await user(h.db,'creator');await agent(h.db,'agent-1');
  const id=await live(h.db,{status:'ended'});
  const now=new Date().toISOString();
  const later=new Date(Date.now()+3600000).toISOString();
  const key='123e4567-e89b-42d3-a456-426614174000';
  await h.db.prepare(`INSERT INTO livestream_push_outbox
   (id,livestream_id,idempotency_key,status,attempts,next_attempt_at,created_at,updated_at)
   VALUES('outbox-reconcile',?,?,'pending',5,?,?,?)`).bind(id,key,later,now,now).run();
  await h.db.prepare(`INSERT INTO livestream_provider_cleanup
   (input_uid,live_id,status,reason,attempts,next_attempt_at,created_at,updated_at)
   VALUES(? ,?,'pending','uji kontrak',7,?,?,?)`).bind('a'.repeat(32),id,later,now,now).run();

  let r=await h.call('/admin/livestream/reconcile','POST',{confirmation:'SALAH'},admin);
  assert.equal(r.status,422);
  r=await h.call('/admin/livestream/reconcile','POST',{confirmation:'RETRY CLEANUP'},admin);
  assert.equal(r.status,202,JSON.stringify(r.json));
  assert.equal(r.json.data.queued,true);
  assert.equal(r.json.data.push_requeued,1);
  assert.equal(r.json.data.provider_requeued,1);
  const outbox=await h.db.prepare("SELECT idempotency_key,attempts FROM livestream_push_outbox WHERE id='outbox-reconcile'").first();
  assert.equal(outbox.idempotency_key,key);assert.ok(Number(outbox.attempts)>=5);
  const cleanup=await h.db.prepare("SELECT attempts FROM livestream_provider_cleanup WHERE input_uid=?").bind('a'.repeat(32)).first();
  assert.ok(Number(cleanup.attempts)>=7);
 }finally{await h.mf.dispose();}
});
