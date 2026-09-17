import { setelan, simpanSetelan } from './sistem.js';
import { KontenError } from './engagement.js';

export class SecurityError extends KontenError {
  constructor(message, status=429, code='RATE_LIMIT') { super(message,status); this.code=code; }
}
export const SECURITY_DEFAULTS={device_accounts:2,register_ip_hour:6,otp_email_hour:3,otp_email_day:8,email_daily:100};
export async function securityConfig(env){
  const out={};for(const [k,v] of Object.entries(SECURITY_DEFAULTS))out[k]=Math.max(1,Number(await setelan(env,'security_'+k,String(v)))||v);
  out.email_daily=Math.min(out.email_daily,Number(env.EMAIL_BATAS_HARIAN)||100);
  return out;
}
export async function securityHash(env, purpose, value){
  if(!env.JWT_SECRET)throw new SecurityError('Pemeriksaan keamanan sementara tidak tersedia.',503,'SECURITY_UNAVAILABLE');
  const key=await crypto.subtle.importKey('raw',new TextEncoder().encode(env.SECURITY_HASH_SECRET||env.JWT_SECRET),{name:'HMAC',hash:'SHA-256'},false,['sign']);
  const bytes=await crypto.subtle.sign('HMAC',key,new TextEncoder().encode(purpose+':'+value));
  return [...new Uint8Array(bytes)].map(b=>b.toString(16).padStart(2,'0')).join('');
}
/** Atomic fixed-window counter. Storage failure never grants unlimited requests. */
export async function securitySlot(env, lane, subject, limit, seconds){
  const bucket=Math.floor(Date.now()/1000/seconds);
  const digest=await securityHash(env,lane,String(subject));
  const key=`sec:${lane}:${digest}:${bucket}`;
  const end=new Date((bucket+1)*seconds*1000).toISOString();
  const row=await env.DB.prepare(`INSERT INTO batas(kunci,jumlah,sampai) VALUES(?,1,?)
    ON CONFLICT(kunci) DO UPDATE SET jumlah=batas.jumlah+1 WHERE batas.jumlah<? RETURNING jumlah`).bind(key,end,limit).first();
  return !!row;
}
export async function auditSecurity(env,kind,subject='',note='',route=''){
  try{
    const digest=await securityHash(env,'audit',subject),t=new Date().toISOString();
    const id=kind+':'+digest+':'+Math.floor(Date.now()/60000);
    await env.DB.prepare(`INSERT INTO security_events(id,kind,subject,route,note,created_at,last_seen) VALUES(?,?,?,?,?,?,?)
      ON CONFLICT(id) DO UPDATE SET count=count+1,last_seen=excluded.last_seen`).bind(id,kind,digest,route,String(note).slice(0,240),t,t).run();
  }catch{/* audit errors must not disclose request secrets */}
}
export async function requireRate(env,lane,subject,limit,seconds){
  if(!await securitySlot(env,lane,subject,limit,seconds)){
    await auditSecurity(env,'rate_limit',subject,lane);
    throw new SecurityError('Terlalu banyak percobaan. Tunggu sebentar sebelum mencoba lagi.');
  }
}
export async function deviceFromRequest(env,req,{required=false,raw=null}={}){
  const value=raw||req.headers.get('x-xy-device')||'';
  if(!/^[a-f0-9]{64}$/i.test(value)){
    if(required)throw new SecurityError('Identitas perangkat diperlukan. Gunakan aplikasi terbaru atau aktifkan penyimpanan browser.',400,'DEVICE_REQUIRED');
    return null;
  }
  const id=await securityHash(env,'device',value.toLowerCase()),time=new Date().toISOString();
  const type=req.headers.get('x-xy-device-kind')||'unknown';
  let model=String(req.headers.get('x-xy-device-model')||'');try{model=decodeURIComponent(model);}catch{}model=model.replace(/[\r\n]/g,'').slice(0,80);
  await env.DB.prepare(`INSERT INTO security_devices(id,kind,model,created_at,last_seen) VALUES(?,?,?,?,?)
    ON CONFLICT(id) DO UPDATE SET last_seen=excluded.last_seen,
      kind=CASE WHEN security_devices.kind='unknown' AND excluded.kind!='unknown' THEN excluded.kind ELSE security_devices.kind END,
      model=COALESCE(NULLIF(excluded.model,''),security_devices.model)`)
    .bind(id,['android','install','browser'].includes(type)?type:'unknown',model,time,time).run();
  const device=await env.DB.prepare('SELECT * FROM security_devices WHERE id=?').bind(id).first();
  if(device.blocked)throw new SecurityError('Perangkat ini dibatasi. Hubungi pengelola layanan.',403,'DEVICE_BLOCKED');
  return id;
}
export async function linkDevice(env,deviceId,userId){
  if(!deviceId)return;
  await env.DB.prepare(`INSERT INTO security_device_users(device_id,user_id) VALUES(?,?)
    ON CONFLICT(device_id,user_id) DO UPDATE SET last_seen=datetime('now')`).bind(deviceId,userId).run();
}
export async function beforeRegistration(env,req,deviceId){
  if(!deviceId)throw new SecurityError('Identitas perangkat diperlukan untuk akun baru. Perbarui aplikasi.',400,'DEVICE_REQUIRED');
  const cfg=await securityConfig(env);
  await requireRate(env,'signup-ip',req.headers.get('cf-connecting-ip')||'unknown',cfg.register_ip_hour,3600);
  const device=await env.DB.prepare('SELECT * FROM security_devices WHERE id=?').bind(deviceId).first();
  if(!device||device.blocked)throw new SecurityError('Perangkat dibatasi.',403,'DEVICE_BLOCKED');
  if(device.registrations >= (device.max_accounts??cfg.device_accounts)){
    await auditSecurity(env,'registration_denied',deviceId,'device quota');
    throw new SecurityError(`Perangkat ini sudah mencapai batas ${device.max_accounts??cfg.device_accounts} pendaftaran akun. Hubungi admin jika perlu peninjauan.`,429,'DEVICE_LIMIT');
  }
}
export function translateRegistrationError(e){
  if(String(e).includes('DEVICE_LIMIT'))throw new SecurityError('Batas pendaftaran perangkat tercapai. Tidak ada akun baru dibuat.',429,'DEVICE_LIMIT');
  if(String(e).includes('DEVICE_BLOCKED'))throw new SecurityError('Perangkat dibatasi.',403,'DEVICE_BLOCKED');
  throw e;
}
export function assertAccountEnabled(user,{izinkanBlokir=false}={}){
  if(user?.deleted_at)throw new SecurityError('Akun dinonaktifkan. Hubungi pengelola untuk pemulihan.',403,'ACCOUNT_TRASHED');
  // izinkanBlokir: akun dibekukan tetap boleh memegang token terbatas supaya
  // app bisa langsung menampilkan layar Akun Dibekukan (alasan, pelanggaran,
  // banding, CS). Endpoint lain tetap dikunci di gerbang permintaan.
  if(user?.diblokir&&!izinkanBlokir)throw new SecurityError(user.alasan_blokir||'Akun diblokir. Hubungi pengelola layanan.',403,'ACCOUNT_BLOCKED');
}
export async function otpAllowed(env,email){
  const cfg=await securityConfig(env),id=email.trim().toLowerCase();
  if(!await securitySlot(env,'otp-minute',id,1,60)||!await securitySlot(env,'otp-hour',id,cfg.otp_email_hour,3600)||!await securitySlot(env,'otp-day',id,cfg.otp_email_day,86400)){
    await auditSecurity(env,'email_throttled',id,'OTP email limit');return false;
  }
  return true;
}
export async function otpDigest(env,email,type,code){return 'v2:'+await securityHash(env,'otp',email.toLowerCase()+':'+type+':'+String(code).trim());}

export async function newOAuthState(env,provider,deviceId,handoffChallenge){
  if(!/^[a-f0-9]{64}$/.test(String(deviceId||'')))throw new SecurityError('Identitas perangkat OAuth tidak valid.',400,'DEVICE_REQUIRED');
  if(!/^[A-Za-z0-9_-]{43}$/.test(String(handoffChallenge||'')))throw new SecurityError('Challenge penyelesaian OAuth tidak valid.',400,'OAUTH_CHALLENGE');
  const value=[...crypto.getRandomValues(new Uint8Array(24))].map(x=>x.toString(16).padStart(2,'0')).join('');
  const id=await securityHash(env,'oauth',value);
  await env.DB.prepare('INSERT INTO oauth_states(id,provider,device_id,handoff_challenge,expires_at) VALUES(?,?,?,?,?)')
    .bind(id,provider,deviceId,handoffChallenge,new Date(Date.now()+600000).toISOString()).run();
  return value;
}
export async function consumeOAuthState(env,req,provider){
  const value=new URL(req.url).searchParams.get('state')||'';
  const cookie=(req.headers.get('cookie')||'').split(';').map(x=>x.trim()).find(x=>x.startsWith('xy_oauth_nonce='))?.slice(15);
  if(!/^[a-f0-9]{48}$/.test(value)||cookie!==value)throw new SecurityError('Sesi login tidak cocok. Mulai login ulang.',400,'OAUTH_STATE');
  const id=await securityHash(env,'oauth',value);
  const row=await env.DB.prepare('DELETE FROM oauth_states WHERE id=? AND provider=? AND expires_at>? RETURNING device_id,handoff_challenge').bind(id,provider,new Date().toISOString()).first();
  if(!row||!/^[a-f0-9]{64}$/.test(String(row.device_id||''))
      ||!/^[A-Za-z0-9_-]{43}$/.test(String(row.handoff_challenge||'')))throw new SecurityError('Sesi login kedaluwarsa atau sudah dipakai.',400,'OAUTH_STATE');
  return {deviceId:row.device_id,handoffChallenge:row.handoff_challenge};
}

export async function saveSecurityConfig(env,body){
  const maximum={device_accounts:20,register_ip_hour:100,otp_email_hour:10,otp_email_day:30,email_daily:Number(env.EMAIL_BATAS_HARIAN)||100};
  for(const k of Object.keys(SECURITY_DEFAULTS))if(body[k]!=null){
    const v=Number(body[k]);if(!Number.isInteger(v)||v<1||v>maximum[k])throw new SecurityError(`Nilai ${k} harus 1–${maximum[k]}.`,400,'CONFIG_INVALID');
    await simpanSetelan(env,'security_'+k,v);
  }
  return securityConfig(env);
}
