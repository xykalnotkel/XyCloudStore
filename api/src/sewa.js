import { setInputLivestream } from './livestream.js';

/**
 * Host streaming harus alamat yang bisa dijangkau HP penyewa — IP publik, IPv6,
 * atau FQDN. Nama PC Windows (COMPUTERNAME, tanpa titik) ditolak karena hanya
 * berlaku di jaringan lokal host itu.
 *
 * Port OPSIONAL dan memang didukung: lapisan native Android
 * (`native/xy_stream/.../NativeStreaming.java#address`) mengurai `host:port`,
 * membungkus IPv6 dengan kurung siku, dan memakai port bawaan Sunshine bila
 * tidak disebut. Validator lama menolak apa pun yang mengandung ':' sekaligus
 * '.', jadi isian sah seperti `103.10.20.30:47989` ditolak dan penyewa mendapat
 * pesan "Host bukan IP/DNS publik" padahal isian admin benar.
 *
 * @returns {string|null} host (dengan port bila disebut) atau null bila tidak ada calon sah
 */
export function normalisasiHostStream(raw, fallback){
  const portSah=p=>{if(p==null)return true;const n=Number(p);return Number.isInteger(n)&&n>=1&&n<=65535;};
  /**
   * Pisahkan `host` dan `:port` opsional.
   * Tiga bentuk diterima: `host`, `host:port`, dan `[ipv6]:port` / `ipv6` polos.
   * Bentuk yang dikembalikan selalu bisa diurai `NativeStreaming.address()`.
   */
  const pisah=v=>{
    const t=String(v||'').trim();
    if(!t||/\s/.test(t))return null;
    // [ipv6] atau [ipv6]:port — kurung siku dipertahankan supaya tidak ambigu
    const siku=/^\[([0-9a-fA-F:]{2,})\](?::(\d{1,5}))?$/.exec(t);
    if(siku)return portSah(siku[2])?{host:siku[1],port:siku[2]||null,siku:true}:null;
    // IPv6 polos: lebih dari satu titik dua, hanya heksadesimal + ':' (tanpa port,
    // karena tidak bisa dibedakan dari bagian alamat). Klien membungkusnya sendiri.
    if((t.match(/:/g)||[]).length>1)return /^[0-9a-fA-F:]{2,}$/.test(t)?{host:t,port:null}:null;
    // host atau host:port
    const m=/^([^\s:]+)(?::(\d{1,5}))?$/.exec(t);
    if(!m||!portSah(m[2]))return null;
    return {host:m[1],port:m[2]||null};
  };
  /** Host saja (tanpa port) harus IP atau FQDN, bukan nama mesin lokal. */
  const okHost=h=>{
    if(!h)return false;
    if(/^\d{1,3}(\.\d{1,3}){3}$/.test(h))return h.split('.').every(o=>Number(o)<=255);   // IPv4
    if(h.includes(':'))return /^[0-9a-fA-F:]{2,}$/.test(h);                              // IPv6
    return h.includes('.')&&h.length<253&&/^[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?)+$/.test(h); // FQDN
  };
  for(const calon of [raw,fallback]){
    const p=pisah(calon);
    if(!p||!okHost(p.host))continue;
    const host=p.siku?`[${p.host}]`:p.host;
    return p.port?`${host}:${p.port}`:host;
  }
  return null;
}

import { cekVoucher, diskonTier } from './loyal.js';
import { KontenError } from './engagement.js';
const id=p=>p+crypto.randomUUID().replace(/-/g,'').slice(0,20);
const now=()=>new Date().toISOString();
const fail=(message,status=409)=>{throw new KontenError(message,status)};
const READY="(CAST(versi AS INTEGER)>1 OR (CAST(versi AS INTEGER)=1 AND CAST(substr(versi,instr(versi,'.')+1) AS INTEGER)>=1)) AND terakhir IS NOT NULL AND datetime(terakhir)>datetime('now','-90 seconds') AND json_valid(spec) AND json_extract(spec,'$.sunshine.siap')=1";

// Probe TCP sederhana dari sisi Cloudflare (dinamis agar npm test di Node tidak pecah).
export async function probePortTcp(host,port,ms=6000){
  try{
    const {connect}=await import('cloudflare:sockets');
    const sock=connect({hostname:host,port});
    const terbuka=await Promise.race([
      sock.opened.then(()=>true).catch(()=>false),
      new Promise((r)=>setTimeout(()=>r(false),ms)),
    ]);
    try{sock.close();}catch(_){}
    return terbuka;
  }catch(_){return false;}
}
// Lampirkan IP LAN agen (dari spec.ip_lan) ke baris sesi agar app bisa fallback
// bila host publik tertutup firewall/NAT saat penyewa satu jaringan dengan unit.
async function lampirkanHostLan(env,s){
  if(!s||!s.agen_id)return s;
  try{
    const ag=await env.DB.prepare('SELECT spec FROM agen WHERE id=?').bind(s.agen_id).first();
    const spec=ag&&ag.spec?JSON.parse(ag.spec):{};
    const lan=String(spec.ip_lan||'').split(',')[0].trim();
    if(lan)s.host_lan=lan;
  }catch(_){}
  return s;
}

export async function estimasiSewa(env,userId,b){
  const jam=Number(b.durasi_jam);
  if(!Number.isInteger(jam)||jam<1||jam>24)fail('Durasi harus 1 sampai 24 jam.',400);
  const plan=await env.DB.prepare('SELECT * FROM pc_plans WHERE id=?').bind(String(b.plan_id||'')).first();
  if(!plan)fail('Paket tidak ditemukan.',404);
  if(!Number.isSafeInteger(plan.harga_per_jam)||plan.harga_per_jam<0)fail('Harga paket belum valid.',409);
  const user=await env.DB.prepare('SELECT saldo,tier FROM users WHERE id=?').bind(userId).first();
  const subtotal=plan.harga_per_jam*jam;
  const durasi=jam>=8?Math.floor(subtotal*.1):0;
  const member=Math.floor(subtotal*diskonTier(user.tier)/100);
  let voucher=0,kode=null;
  if(b.voucher){const v=await cekVoucher(env,{kode:b.voucher,userId,jenis:'sewa',total:subtotal});if(!v.ok)fail(v.alasan,400);voucher=v.potongan;kode=v.voucher.kode;}
  return {plan,jam,kode,subtotal,potongan_durasi:durasi,potongan_member:member,potongan_voucher:voucher,biaya_layanan:1000,
    total:Math.max(0,subtotal-durasi-member-voucher+1000)};
}
export async function buatSewa(env,userId,b){
  if(b.metode!=='saldo')fail('Sewa dibayar dari saldo. Top up terlebih dahulu; QRIS/VA tidak langsung dianggap lunas.',400);
  const request=String(b.request_id||'');
  if(request&&!/^[A-Za-z0-9_-]{12,100}$/.test(request))fail('ID permintaan tidak valid.',400);
  if(request){const old=await env.DB.prepare('SELECT * FROM orders WHERE user_id=? AND request_id=?').bind(userId,request).first();if(old)return {order:old,baru:false};}
  const q=await estimasiSewa(env,userId,b);
  if(b.total_disetujui!=null&&Number(b.total_disetujui)!==q.total)fail('Harga berubah. Muat ulang rincian sebelum membayar.',409);
  const host=await env.DB.prepare(`SELECT * FROM agen WHERE (sesi_aktif IS NULL OR sesi_aktif='') AND (${READY}) AND (plan_id IS NULL OR plan_id=?) ORDER BY terakhir DESC LIMIT 1`).bind(q.plan.id).first();
  if(!host)fail('Belum ada agen 1.1+ dengan Sunshine siap. Perbarui/jalankan agen; saldo belum dipotong.',409);
  const key=id('o_'),kode='XY-'+crypto.randomUUID().replace(/-/g,'').slice(0,8).toUpperCase();
  try{
    await env.DB.batch([
      env.DB.prepare(`INSERT INTO orders(id,kode,user_id,plan_id,plan_nama,durasi_jam,total,status,progress,voucher,potongan,request_id,metode,agen_id)
        VALUES(?,?,?,?,?,?,?,'dibayar',0,?,?,?,'saldo',?) ON CONFLICT(user_id,request_id) DO NOTHING`)
        .bind(key,kode,userId,q.plan.id,q.plan.nama,q.jam,q.total,q.kode,q.potongan_voucher,request||null,host.id),
      env.DB.prepare("INSERT INTO transaksi(id,user_id,judul,tipe,nominal,status) SELECT ?,user_id,?,'sewa',-total,'sukses' FROM orders WHERE id=?")
        .bind(id('t_'),`Sewa ${q.plan.nama} ${q.jam} jam`,key),
    ]);
  }catch(e){
    const m=String(e);if(m.includes('SALDO_TIDAK_CUKUP'))fail('Saldo tidak cukup. Tidak ada pemotongan.',402);
    if(m.includes('UNIT_PENUH'))fail('Unit baru saja dipakai. Tidak ada pemotongan saldo.',409);
    if(m.includes('VOUCHER_TIDAK_TERSEDIA'))fail('Voucher sudah digunakan/kuota habis. Muat ulang total.',409);
    throw e;
  }
  const order=await env.DB.prepare('SELECT * FROM orders WHERE id=? OR (user_id=? AND request_id=?) LIMIT 1').bind(key,userId,request||null).first();
  return {order,baru:order.id===key};
}
export async function mulaiSewa(env,userId,orderId){
  const o=await env.DB.prepare('SELECT * FROM orders WHERE id=? AND user_id=?').bind(orderId,userId).first();
  if(!o)fail('Pesanan tidak ditemukan.',404);
  if(!['dibayar','provisioning','aktif'].includes(o.status))fail('Pesanan tidak dapat dimulai.',409);
  if(o.berakhir&&Date.parse(o.berakhir)<=Date.now())fail('Waktu pesanan sudah habis.',409);
  const existing=await env.DB.prepare("SELECT * FROM sesi WHERE order_id=? AND status NOT IN ('selesai','gagal') ORDER BY dibuat DESC LIMIT 1").bind(o.id).first();
  if(existing)return lampirkanHostLan(env,existing);
  const host=await env.DB.prepare(`SELECT * FROM agen WHERE (${READY}) AND (sesi_aktif='order:'||? OR ((sesi_aktif IS NULL OR sesi_aktif='') AND (plan_id IS NULL OR plan_id=?))) AND (? IS NULL OR id=?) ORDER BY terakhir DESC LIMIT 1`)
    .bind(o.id,o.plan_id,o.agen_id,o.agen_id).first();
  if(!host)fail('Unit belum bisa dihubungi. Tunggu agen online atau batalkan pesanan yang belum siap.',409);
  const key=id('s_');const menit=o.mulai&&o.berakhir?Math.max(1,Math.ceil((Date.parse(o.berakhir)-Date.now())/60000)):o.durasi_jam*60;
  await env.DB.batch([
    env.DB.prepare(`INSERT INTO sesi(id,order_id,user_id,agen_id,status,durasi_menit,host)
      SELECT ?,?,?,id,'menyiapkan',?,host FROM agen WHERE id=? AND (sesi_aktif IS NULL OR sesi_aktif='' OR sesi_aktif='order:'||?)
      AND NOT EXISTS(SELECT 1 FROM sesi WHERE order_id=? AND status NOT IN ('selesai','gagal'))`).bind(key,o.id,userId,menit,host.id,o.id,o.id),
    env.DB.prepare('UPDATE agen SET sesi_aktif=? WHERE id=? AND EXISTS(SELECT 1 FROM sesi WHERE id=?)').bind(key,host.id,key),
    env.DB.prepare("UPDATE orders SET status='provisioning',agen_id=? WHERE id=? AND EXISTS(SELECT 1 FROM sesi WHERE id=?)").bind(host.id,o.id,key),
    env.DB.prepare("INSERT INTO perintah(id,agen_id,jenis,muatan) SELECT ?,?,'mulai_sesi',? WHERE EXISTS(SELECT 1 FROM sesi WHERE id=?)")
      .bind(id('c_'),host.id,JSON.stringify({sesi_id:key,order_id:o.id,user_id:userId,durasi_menit:menit,valid_sampai:new Date(Date.now()+120000).toISOString()}),key),
  ]);
  const s=await env.DB.prepare("SELECT * FROM sesi WHERE order_id=? AND status NOT IN ('selesai','gagal') ORDER BY dibuat DESC LIMIT 1").bind(o.id).first();
  if(!s)fail('Unit sedang dipakai. Coba lagi.',409);
  return lampirkanHostLan(env,s);
}
export async function antreAkhir(env,s,alasan='Sesi diakhiri pengguna'){
  if(['selesai','gagal'].includes(s.status))return s;
  // Livestream publik tidak boleh bertahan melewati lease PC. Putus ingress
  // lebih dahulu, lalu minta agen menghentikan OBS dan Sunshine secara lokal.
  const live=await env.DB.prepare(
    "SELECT * FROM livestream WHERE sesi_id=? AND (status IN ('queued','starting','live','ending') OR (status='failed' AND cleanup_pending=1)) LIMIT 1",
  ).bind(s.id).first();
  const now=new Date().toISOString();
  const jobs=[
    env.DB.prepare("UPDATE sesi SET status='mengakhiri',catatan=? WHERE id=? AND status NOT IN ('selesai','gagal')").bind(alasan,s.id),
  ];
  if(live){
    jobs.push(env.DB.prepare("UPDATE livestream SET status='ending',end_reason=?,updated_at=? WHERE id=?").bind('Sesi PC berakhir: '+String(alasan).slice(0,120),now,live.id));
    jobs.push(env.DB.prepare("INSERT OR IGNORE INTO perintah(id,agen_id,jenis,muatan) VALUES(?,?,'akhiri_siaran',?)").bind('live_end_'+live.id,s.agen_id,JSON.stringify({live_id:live.id})));
  }
  jobs.push(env.DB.prepare("INSERT OR IGNORE INTO perintah(id,agen_id,jenis,muatan) VALUES(?,?,'akhiri_sesi',?)").bind('end_'+s.id,s.agen_id,JSON.stringify({sesi_id:s.id})));
  await env.DB.batch(jobs);
  if(live?.provider_input_uid){
    const blocked=await setInputLivestream(env,live.provider_input_uid,false);
    if(blocked.ok||blocked.code==='NOT_FOUND'){
      await env.DB.prepare('UPDATE livestream SET provider_disabled_at=COALESCE(provider_disabled_at,?) WHERE id=?')
        .bind(now,live.id).run();
    }
  }
  return {...s,status:'mengakhiri',catatan:alasan};
}
export async function bacaSewa(env,userId,key){
  const s=await env.DB.prepare('SELECT * FROM sesi WHERE id=? AND user_id=?').bind(key,userId).first();
  if(!s)fail('Sesi tidak ditemukan.',404);
  if(!s.berakhir&&s.order_id){const o=await env.DB.prepare('SELECT mulai,berakhir FROM orders WHERE id=?').bind(s.order_id).first();if(o?.berakhir){s.mulai=s.mulai||o.mulai;s.berakhir=o.berakhir;}}
  if(s.berakhir&&Date.parse(s.berakhir)<=Date.now())return antreAkhir(env,s,'Waktu sewa habis');
  if(s.status==='menyiapkan'&&Date.parse(s.dibuat.replace(' ','T')+(s.dibuat.endsWith('Z')?'':'Z'))<Date.now()-120000){
    await env.DB.prepare("UPDATE orders SET status='batal' WHERE id=? AND status='provisioning'").bind(s.order_id).run();
    return antreAkhir(env,s,'Persiapan terlalu lama; pembayaran saldo dikembalikan dan unit sedang dibersihkan.');
  }
  if(s.host && !normalisasiHostStream(s.host,null)){
    s.catatan=(s.catatan?s.catatan+' · ':'')+'Host "'+s.host+'" bukan IP/DNS publik. Admin harus isi host unit (IP publik / domain).';
  }
  await lampirkanHostLan(env,s);
  return s;
}
export async function konfirmasiAgen(env,agent,command,b){
  if(!command)fail('Perintah bukan milik agen ini.',403);
  const muatan=JSON.parse(command.muatan||'{}');
  if(b.sesi_id!==muatan.sesi_id)fail('ID sesi tidak sesuai perintah.',403);
  const s=await env.DB.prepare('SELECT * FROM sesi WHERE id=? AND agen_id=?').bind(muatan.sesi_id,agent.id).first();
  if(!s)fail('Sesi bukan milik agen ini.',403);
  if(command.status==='selesai')return s;
  const ok=b.ok===true;const waktu=now();let status=s.status;
  if(command.jenis==='mulai_sesi'){
    if(s.status!=='menyiapkan'){
      await antreAkhir(env,s,'Perintah mulai terlambat; unit dibersihkan.');return s;
    }
    if(ok){
      status='siap';const o=await env.DB.prepare('SELECT mulai,berakhir FROM orders WHERE id=?').bind(s.order_id).first();
      const mulai=o.mulai||waktu,sampai=o.berakhir||new Date(Date.now()+s.durasi_menit*60000).toISOString();
      const hostStream=normalisasiHostStream(b.host, agent.host);
      if(hostStream){
        await env.DB.batch([
          env.DB.prepare("UPDATE sesi SET status='siap',mulai=?,berakhir=?,host=?,catatan='Host siap untuk koneksi streaming' WHERE id=?").bind(mulai,sampai,hostStream,s.id),
          env.DB.prepare("UPDATE orders SET status='aktif',progress=100,mulai=?,berakhir=?,host=? WHERE id=? AND status IN ('dibayar','provisioning','aktif')").bind(mulai,sampai,hostStream,s.order_id),
          env.DB.prepare('UPDATE agen SET host=? WHERE id=?').bind(hostStream, agent.id),
        ]);
      } else {
        await env.DB.batch([
          env.DB.prepare("UPDATE sesi SET status='siap',mulai=?,berakhir=?,host=COALESCE(host, ?),catatan=? WHERE id=?").bind(mulai,sampai,agent.host||null,'Host siap. Set IP/host publik di Unit (bukan nama PC Windows).',s.id),
          env.DB.prepare("UPDATE orders SET status='aktif',progress=100,mulai=?,berakhir=?,host=COALESCE(host, ?) WHERE id=? AND status IN ('dibayar','provisioning','aktif')").bind(mulai,sampai,agent.host||null,s.order_id),
        ]);
      }
    
    }else{
      status='gagal';await env.DB.batch([
        env.DB.prepare("UPDATE sesi SET status='gagal',catatan=? WHERE id=?").bind(String(b.catatan||'Host gagal disiapkan'),s.id),
        env.DB.prepare("UPDATE orders SET status='batal' WHERE id=? AND status IN ('dibayar','provisioning')").bind(s.order_id),
        env.DB.prepare("UPDATE sesi SET status='mengakhiri' WHERE id=?").bind(s.id),
        env.DB.prepare("INSERT OR IGNORE INTO perintah(id,agen_id,jenis,muatan) VALUES(?,?,'akhiri_sesi',?)").bind('end_'+s.id,agent.id,JSON.stringify({sesi_id:s.id})),
      ]);
    }
  }else if(command.jenis==='pasangkan'){
    if(!['siap','pairing','berjalan'].includes(s.status))fail('Sesi sudah tidak menerima pairing.',409);
    status='siap';await env.DB.prepare("UPDATE sesi SET status='siap',catatan=?,pin=NULL WHERE id=?").bind(ok?'Pairing berhasil; pilih aplikasi streaming.':String(b.catatan||'Pairing gagal. Coba ulang.'),s.id).run();
  }else if(command.jenis==='akhiri_sesi'){
    if(ok)await tutupSewa(env,s);else await env.DB.prepare("UPDATE sesi SET status='mengakhiri',catatan=? WHERE id=?").bind(String(b.catatan||'Pembersihan host belum selesai; agen akan mencoba ulang.'),s.id).run();
  }
  await env.DB.prepare('UPDATE perintah SET status=?,hasil=?,diproses=? WHERE id=?').bind(ok?'selesai':'gagal',JSON.stringify({ok,status,catatan:b.catatan||''}),waktu,command.id).run();
  return env.DB.prepare('SELECT * FROM sesi WHERE id=?').bind(s.id).first();
}
export async function tutupSewa(env,s){
  await env.DB.batch([
    env.DB.prepare("UPDATE sesi SET status='selesai',pin=NULL,catatan='Sesi ditutup dan host dilepas' WHERE id=?").bind(s.id),
    env.DB.prepare("UPDATE orders SET status=CASE WHEN status IN ('dibayar','provisioning') THEN 'batal' ELSE 'selesai' END WHERE id=? AND status NOT IN ('selesai','batal')").bind(s.order_id),
    env.DB.prepare('UPDATE agen SET sesi_aktif=NULL WHERE id=? AND sesi_aktif=?').bind(s.agen_id,s.id),
  ]);
}
/**
 * Pembersih sewa — dipanggil cron tiap jam, tiap heartbeat agen, dan tiap baca sesi.
 *
 * Aturan lama hanya menutup dua keadaan: sesi yang punya `berakhir` dan sudah
 * lewat, serta sesi 'menyiapkan' yang berumur lebih dari 2 menit. Akibatnya ada
 * dua jalan buntu yang mengunci unit PC **permanen** (keduanya terjadi di
 * produksi, audit 2026-09-13):
 *
 *   1. sesi berstatus 'siap' dengan `berakhir` NULL — agen melaporkan siap tanpa
 *      batas waktu, tidak cocok dengan aturan mana pun, jadi `agen.sesi_aktif`
 *      tidak pernah dilepas dan unit hilang dari kolam selamanya;
 *   2. sesi 'mengakhiri' yang tidak pernah di-ACK agen (agen offline) —
 *      `tutupSewa()` hanya jalan lewat `konfirmasiAgen()`, jadi tanpa ACK
 *      unit tetap terkunci.
 *
 * Ditambah lagi order 'aktif' yang sudah lewat `berakhir` tidak pernah ditutup.
 */
export async function rawatSewa(env){
  // 1. Reservasi berbayar yang tidak pernah dipakai kedaluwarsa → batal.
  //    Trigger D1 `order_saldo_selesai` yang mengembalikan saldo dan menulis
  //    baris transaksi 'refund', jadi di sini cukup mengubah status.
  await env.DB.prepare("UPDATE orders SET status='batal' WHERE metode='saldo' AND status='dibayar' AND datetime(dibuat)<datetime('now','-15 minutes')").run();

  // 2. Sesi yang harus ditutup.
  const {results}=await env.DB.prepare(
    "SELECT * FROM sesi WHERE status NOT IN ('selesai','gagal') AND ("
    +" (berakhir IS NOT NULL AND datetime(berakhir)<=datetime('now'))"
    +" OR (status='menyiapkan' AND datetime(dibuat)<datetime('now','-2 minutes'))"
    // jalan buntu (1): tidak punya batas waktu padahal sudah lama dibuat
    +" OR (berakhir IS NULL AND status<>'menyiapkan' AND datetime(dibuat)<datetime('now','-10 minutes'))"
    // jalan buntu (2): pembersihan tidak pernah dikonfirmasi agen
    +" OR (status='mengakhiri' AND datetime(COALESCE(berakhir,dibuat))<datetime('now','-10 minutes'))"
    +")").all();
  for(const s of results||[]){
    if(s.status==='mengakhiri'){
      await tutupSewa(env,s);
      await env.DB.prepare("UPDATE sesi SET catatan=? WHERE id=? AND status='selesai'")
        .bind('Pembersihan host tidak dikonfirmasi agen; unit dilepas otomatis oleh pembersih. Mesin mungkin perlu dibersihkan manual.',s.id).run();
      continue;
    }
    if(!s.berakhir&&s.status!=='menyiapkan'){
      await antreAkhir(env,s,'Sesi berjalan tanpa batas waktu lebih dari 10 menit; unit dibersihkan dan dilepas.');
      continue;
    }
    await bacaSewa(env,s.user_id,s.id);
  }

  // 3. Order 'aktif'/'provisioning' yang waktunya sudah habis → 'selesai'.
  //    Sesi terkait ikut ditutup. Untuk metode='saldo' trigger D1 mengembalikan
  //    unit_tersedia dan melepas agen; langkah 4 menangkap sisanya (legacy).
  const {results:lewat}=await env.DB.prepare(
    "SELECT id FROM orders WHERE status IN ('aktif','provisioning') AND berakhir IS NOT NULL AND datetime(berakhir)<=datetime('now')").all();
  for(const o of lewat||[]){
    await env.DB.batch([
      env.DB.prepare("UPDATE orders SET status='selesai' WHERE id=? AND status IN ('aktif','provisioning')").bind(o.id),
      env.DB.prepare("UPDATE sesi SET status='selesai',pin=NULL,catatan=COALESCE(catatan,'')||' · Ditutup pembersih: waktu sewa habis.' WHERE order_id=? AND status NOT IN ('selesai','gagal')").bind(o.id),
      env.DB.prepare("UPDATE agen SET sesi_aktif=NULL WHERE sesi_aktif=?").bind('order:'+o.id),
    ]);
  }

  // 4. Lepas kunci unit yang menunjuk ke sesi/order yang sudah final, atau yang
  //    yatim (barisnya sudah tidak ada). `agen.sesi_aktif` punya dua bentuk:
  //    id sesi (`s_…`) setelah sesi dimulai, atau `order:<id>` sejak order dibuat
  //    (trigger `order_saldo_baru`). Bentuk kedua HARUS dipertahankan selama
  //    ordernya masih terbuka, kalau tidak reservasi unit bisa direbut order lain.
  await env.DB.prepare(
    "UPDATE agen SET sesi_aktif=NULL WHERE sesi_aktif IS NOT NULL AND sesi_aktif<>'' AND ("
    +" EXISTS(SELECT 1 FROM sesi WHERE id=agen.sesi_aktif AND status IN ('selesai','gagal'))"
    +" OR EXISTS(SELECT 1 FROM orders WHERE 'order:'||id=agen.sesi_aktif AND status IN ('selesai','batal'))"
    +" OR (NOT EXISTS(SELECT 1 FROM sesi WHERE id=agen.sesi_aktif)"
    +"     AND NOT EXISTS(SELECT 1 FROM orders WHERE 'order:'||id=agen.sesi_aktif))"
    +")").run();
}

