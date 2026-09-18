/**
 * ============================================================
 *  XyCloudStore - Unggah & sajikan media (Cloudinary, tanda tangan server)
 * ============================================================
 *  Dipakai untuk gambar produk, bukti transfer, lampiran chat,
 *  foto ulasan, dan banner profil.
 *
 *  Prinsip (Batch N, 2026-09-16):
 *  * Kunci rahasia TIDAK PERNAH keluar dari Worker.
 *  * URL Cloudinary mentah TIDAK PERNAH keluar ke klien — semua
 *    respons disamarkan jadi jalur domain sendiri (/img/ atau /media/).
 *  * Unggahan di-dedup memakai hash isi berkas (SHA-256). Konten
 *    identik tidak diunggah ulang → tidak ada aset duplikat.
 *  * Video banner diubah MENJADI GIF asli (aset mandiri), lalu MP4
 *    dihapus dari Cloudinary — tidak ada penyimpanan dobel.
 *  * GIF selalu disimpan dengan ekstensi `.gif` pada public_id supaya
 *    jalur proxy /img/ mengenalinya sebagai animasi (tetap bergerak).
 */

const hex = (buf) => [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, '0')).join('');

async function sha1(teks) {
  return hex(await crypto.subtle.digest('SHA-1', new TextEncoder().encode(teks)));
}

/** Hash isi berkas (untuk dedup). */
async function sha256Buf(buf) {
  return hex(await crypto.subtle.digest('SHA-256', buf));
}

/** Uint8Array → base64 dengan potongan aman (tidak melampaui batas argumen). */
function keBase64(bytes) {
  const potong = [];
  for (let i = 0; i < bytes.length; i += 0x8000) {
    potong.push(String.fromCharCode.apply(
        null, bytes.subarray(i, Math.min(i + 0x8000, bytes.length))));
  }
  return btoa(potong.join(''));
}

/** Decode base64 standar (dengan/tanpa padding) → Uint8Array. */
function b64Decode(b64) {
  const s = b64.replace(/-/g, '+').replace(/_/g, '/');
  const pad = s.length % 4 === 0 ? '' : '='.repeat(4 - (s.length % 4));
  const bin = atob(s + pad);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

const cloudOk = (env) => !!(env && env.CLOUDINARY_CLOUD && env.CLOUDINARY_KEY && env.CLOUDINARY_SECRET);

/**
 * Tanda tangan Cloudinary: parameter (sudah berisi timestamp) diurutkan
 * abjad lalu digabung + secret. `file`, `api_key`, dan `resource_type`
 * TIDAK ikut ditandatangani (konvensi Cloudinary).
 */
async function tandaTangan(params, secret) {
  const keys = Object.keys(params).sort();
  const dasar = keys.map((k) => `${k}=${params[k]}`).join('&');
  return sha1(`${dasar}${secret}`);
}

/**
 * Pengirim unggah Cloudinary bertanda-tangan.
 * `signParams` = parameter yang ikut ditandatangani (mis. folder, format, public_id);
 * timestamp otomatis ikut ditandatangani.
 */
async function kirimUnggah(env, endpoint, { folder, timestamp, signParams = {}, file, resourceType, extra = {} }) {
  const waktu = String(timestamp ?? Math.floor(Date.now() / 1000));
  const params = { ...signParams, timestamp: waktu };
  const signature = await tandaTangan(params, env.CLOUDINARY_SECRET);
  const form = new FormData();
  form.append('file', file);
  form.append('api_key', env.CLOUDINARY_KEY);
  form.append('timestamp', waktu);
  for (const k of Object.keys(params)) form.append(k, String(params[k]));
  form.append('signature', signature);
  if (resourceType) form.append('resource_type', resourceType);
  // Parameter tak bertanda tangan (mis. eager) untuk permintaan khusus.
  for (const [k, v] of Object.entries(extra)) form.append(k, String(v));
  return fetch(endpoint, { method: 'POST', body: form });
}

/** Catat / perbarui baris media_assets (idempoten). */
async function catatMedia(env, { id, url, folder, format, width, height, bytes, animated, hash }) {
  try {
    await env.DB.prepare(
      `INSERT INTO media_assets(id,url,folder,format,width,height,bytes,animated,hash)
       VALUES(?,?,?,?,?,?,?,?,?)
       ON CONFLICT(id) DO UPDATE SET
         url=excluded.url, folder=excluded.folder, format=excluded.format,
         width=excluded.width, height=excluded.height, bytes=excluded.bytes,
         animated=excluded.animated, hash=excluded.hash`
    ).bind(id, url, folder, format || null, width || null, height || null, bytes || null, animated ? 1 : 0, hash || null).run();
  } catch (_) { /* media_assets boleh gagal diam-diam; bukan jalur kritis akun */ }
}

/** Cari aset dengan hash sama yang URL-nya masih hidup. */
async function cariDuplikat(env, hash) {
  if (!hash || !env.DB) return null;
  const item = await env.DB.prepare('SELECT * FROM media_assets WHERE hash=? LIMIT 1').bind(hash).first();
  if (!item || !item.url) return null;
  try {
    const cek = await fetch(item.url, { method: 'HEAD' });
    if (cek.ok) return item;
  } catch (_) {}
  return null;
}

/**
 * Unggah gambar. `dataUri` wajib `data:image/*;base64,...`.
 * Konten identik (hash sama) dikembalikan dari aset lama tanpa unggah ulang.
 * GIF diberi public_id berakhiran `.gif` agar animasi selalu dikenal.
 */
export async function unggahGambar(env, { dataUri, folder = 'xycloudstore', dedup = true }) {
  if (!cloudOk(env)) return { ok: false, alasan: 'Kredensial Cloudinary belum diatur' };
  if (typeof dataUri !== 'string' || !dataUri.startsWith('data:')) {
    return { ok: false, alasan: 'Format berkas tidak dikenal' };
  }
  const m = dataUri.match(/^data:([^;]+);base64,/i);
  if (!m) return { ok: false, alasan: 'Format data URI tidak valid' };
  const mime = (m[1] || '').toLowerCase();
  const allowed = ['image/png','image/jpeg','image/jpg','image/webp','image/gif'];
  if (!allowed.includes(mime)) {
    return { ok: false, alasan: `Tipe berkas tidak diizinkan: ${mime || 'unknown'}. Hanya png/jpeg/webp/gif` };
  }
  const b64 = dataUri.split(',')[1] || '';
  if (Math.floor(b64.length * 0.75) > 5 * 1024 * 1024) {
    return { ok: false, alasan: 'Berkas terlalu besar, maksimal 5MB' };
  }
  const bytes = b64Decode(b64);
  const hash = await sha256Buf(bytes);

  const duplikat = dedup ? await cariDuplikat(env, hash) : null;
  if (duplikat) {
    return { ok: true, url: duplikat.url, id: duplikat.id, format: duplikat.format, bytes: duplikat.bytes, duplikat: true };
  }

  // GIF dibiarkan apa adanya agar animasi tetap; selainnya diubah ke WebP
  // + kualitas otomatis di sisi Cloudinary supaya ringan & cepat.
  const isGif = mime === 'image/gif';
  const timestamp = Math.floor(Date.now() / 1000);
  const signParams = { folder };
  if (!isGif) {
    signParams.format = 'webp';
    signParams.quality = 'auto';
  } else {
    // Ekstensi eksplisit agar jalur /img/ mengenalinya sebagai animasi.
    let rid = crypto.randomUUID().replace(/-/g, '');
    signParams.public_id = `${folder}/${rid}.gif`;
  }

  try {
    const r = await kirimUnggah(env, `https://api.cloudinary.com/v1_1/${env.CLOUDINARY_CLOUD}/image/upload`, {
      folder, timestamp, signParams, file: dataUri,
    });
    const j = await r.json();
    if (!r.ok || j.error) return { ok: false, alasan: j.error?.message || `HTTP ${r.status}` };
    await catatMedia(env, {
      id: j.public_id, url: j.secure_url, folder, format: j.format || null,
      width: j.width || null, height: j.height || null, bytes: j.bytes || null,
      animated: j.pages > 1 || j.format === 'gif' ? 1 : 0, hash,
    });
    return { ok: true, url: j.secure_url, id: j.public_id, lebar: j.width, tinggi: j.height, format: j.format, bytes: j.bytes, hash };
  } catch (e) {
    return { ok: false, alasan: String(e) };
  }
}

/**
 * Salin foto profil dari endpoint resmi OAuth ke penyimpanan sendiri. Host
 * dibatasi ketat dan setiap redirect divalidasi untuk mencegah SSRF. URL
 * bertoken milik penyedia tidak pernah disimpan atau dikirim ke klien.
 */
export async function imporFotoSosial(env, url, provider) {
  const hostDiizinkan = (host) => {
    const h = String(host || '').toLowerCase();
    if (provider === 'google') return h === 'lh3.googleusercontent.com' || h.endsWith('.googleusercontent.com');
    if (provider === 'facebook') {
      return h === 'graph.facebook.com' || h.endsWith('.fbcdn.net') || h.endsWith('.fbsbx.com');
    }
    return false;
  };
  try {
    let target = new URL(String(url || ''));
    let response = null;
    for (let i = 0; i < 3; i++) {
      if (target.protocol !== 'https:' || !hostDiizinkan(target.hostname)) return null;
      response = await fetch(target, {
        redirect: 'manual',
        headers: { Accept: 'image/webp,image/jpeg,image/png' },
        signal: typeof AbortSignal !== 'undefined' && typeof AbortSignal.timeout === 'function'
          ? AbortSignal.timeout(8_000) : undefined,
      });
      if (response.status >= 300 && response.status < 400) {
        const lokasi = response.headers.get('location');
        if (!lokasi) return null;
        response.body?.cancel().catch(() => {});
        target = new URL(lokasi, target);
        continue;
      }
      break;
    }
    if (!response?.ok) return null;
    const panjang = Number(response.headers.get('content-length') || 0);
    if (panjang > 2 * 1024 * 1024) return null;
    const mime = String(response.headers.get('content-type') || '').split(';')[0].toLowerCase();
    if (!['image/png', 'image/jpeg', 'image/jpg', 'image/webp'].includes(mime)) return null;
    const data = new Uint8Array(await response.arrayBuffer());
    if (!data.length || data.length > 2 * 1024 * 1024) return null;
    const uploaded = await unggahGambar(env, {
      dataUri: `data:${mime};base64,${keBase64(data)}`,
      folder: 'xycloudstore/profil/sosial',
      // Setiap akun punya lifecycle penghapusan sendiri; jangan berbagi satu
      // public_id lewat dedup lintas pengguna.
      dedup: false,
    });
    return uploaded.ok ? uploaded.url : null;
  } catch (_) {
    return null;
  }
}

/**
 * Unggah suara (voice note). Cloudinary menyimpan audio sebagai resource
 * "video"; endpoint video/upload menerima data:audio/*.base64.
 */
export async function unggahAudio(env, { dataUri, folder = 'xycloudstore/chat' }) {
  if (!cloudOk(env)) return { ok: false, alasan: 'Kredensial Cloudinary belum diatur' };
  if (typeof dataUri !== 'string' || !dataUri.startsWith('data:')) {
    return { ok: false, alasan: 'Format berkas tidak dikenal' };
  }
  const m = dataUri.match(/^data:([^;]+);base64,/i);
  if (!m) return { ok: false, alasan: 'Format data URI tidak valid' };
  const mime = (m ? m[1] : '').toLowerCase();
  const allowed = ['audio/mp4', 'audio/x-m4a', 'audio/m4a', 'audio/aac',
    'audio/mpeg', 'audio/wav', 'audio/webm', 'audio/ogg'];
  if (!allowed.includes(mime)) {
    return { ok: false, alasan: `Tipe suara tidak didukung: ${mime || 'unknown'}` };
  }
  const b64 = dataUri.split(',')[1] || '';
  if (Math.floor(b64.length * 0.75) > 3 * 1024 * 1024) {
    return { ok: false, alasan: 'Pesan suara terlalu besar, maksimal 3MB' };
  }
  const timestamp = Math.floor(Date.now() / 1000);
  try {
    const r = await kirimUnggah(env, `https://api.cloudinary.com/v1_1/${env.CLOUDINARY_CLOUD}/video/upload`, {
      folder, timestamp, signParams: { folder }, file: dataUri, resourceType: 'video',
    });
    const j = await r.json();
    if (!r.ok || j.error) return { ok: false, alasan: j.error?.message || `HTTP ${r.status}` };
    return { ok: true, url: j.secure_url, id: j.public_id, format: j.format, bytes: j.bytes };
  } catch (e) {
    return { ok: false, alasan: String(e) };
  }
}

/** Hapus aset Cloudinary (resource_type image atau video) dengan tanda tangan server. */
export async function hapusCloudinary(env, publicId, resourceType = 'image') {
  if (!cloudOk(env) || !publicId) return false;
  const timestamp = Math.floor(Date.now() / 1000);
  const signature = await tandaTangan({ public_id: publicId, timestamp: String(timestamp) }, env.CLOUDINARY_SECRET);
  const form = new FormData();
  form.set('public_id', publicId);
  form.set('timestamp', String(timestamp));
  form.set('signature', signature);
  form.set('api_key', env.CLOUDINARY_KEY);
  if (resourceType === 'video') form.set('resource_type', 'video');
  try {
    const r = await fetch(`https://api.cloudinary.com/v1_1/${env.CLOUDINARY_CLOUD}/${resourceType === 'video' ? 'video' : 'image'}/destroy`, {
      method: 'POST',
      body: form,
    });
    const j = await r.json().catch(() => ({}));
    return r.ok && ['ok', 'not found'].includes(j.result);
  } catch (_) { return false; }
}

/**
 * Unggah banner video (Batch N, v2): MP4 diunggah, GIF mandiri dibuat
 * (transform lalu diunggah ulang sebagai aset image/gif), kemudian MP4
 * DIHAPUS dari Cloudinary — tidak ada penyimpanan dobel.
 */
export async function unggahVideoBanner(env, { dataUri, folder = 'xycloudstore/banner-profil' }) {
  if (!cloudOk(env)) return { ok: false, alasan: 'Kredensial Cloudinary belum diatur' };
  if (typeof dataUri !== 'string' || !dataUri.startsWith('data:')) {
    return { ok: false, alasan: 'Format berkas tidak dikenal' };
  }
  const m = dataUri.match(/^data:([^;]+);base64,/i);
  if (!m) return { ok: false, alasan: 'Format data URI tidak valid' };
  const mime = (m ? m[1] : '').toLowerCase();
  const allowed = ['video/mp4', 'video/quicktime', 'video/webm'];
  if (!allowed.includes(mime)) {
    return { ok: false, alasan: `Tipe video tidak didukung: ${mime || 'unknown'}. Pakai MP4.` };
  }
  const b64 = dataUri.split(',')[1] || '';
  if (Math.floor(b64.length * 0.75) > 15 * 1024 * 1024) {
    return { ok: false, alasan: 'Video terlalu besar, maksimal 15MB' };
  }
  const bytes = b64Decode(b64);
  const hash = await sha256Buf(bytes);

  const duplikat = await cariDuplikat(env, hash);
  if (duplikat) {
    // Aset lama yang tersimpan sudah berupa GIF jadi langsung dipakai.
    return { ok: true, url: duplikat.url, gif: duplikat.url, id: duplikat.id, format: 'gif', duplikat: true };
  }

  const timestamp = Math.floor(Date.now() / 1000);
  let mp4Id = null;
  try {
    // Transformasi GIF banner: 20 FPS (halus, tidak lambat/patah-patah),
    // dipotong 6 detik awal (looping ringkas & mulus tanpa jeda akhir menit),
    // lebar 480px batas proporsional, dan kompresi lossy agar ringan.
    const transformBannerGif = 'f_gif,fps_20,du_6.0,so_0,w_480,c_limit,fl_lossy';

    // 1) Unggah video (resource video; format asli dipertahankan).
    const r = await kirimUnggah(env, `https://api.cloudinary.com/v1_1/${env.CLOUDINARY_CLOUD}/video/upload`, {
      folder, timestamp, signParams: { folder }, file: dataUri, resourceType: 'video',
      // GIF derivasi dibuat EAGER saat unggah, sehingga fase konversi tidak
      // menunggu derivasi on-demand yang bisa memakan puluhan detik
      // (penyebab UI klien terlihat mentok di 90%).
      extra: { eager: transformBannerGif },
    });
    const j = await r.json();
    if (!r.ok || j.error) return { ok: false, alasan: j.error?.message || `HTTP ${r.status}` };
    mp4Id = j.public_id;

    // 2) Verifikasi MP4 bisa diakses.
    try {
      const cek = await fetch(j.secure_url, { method: 'HEAD' });
      if (!cek.ok) return { ok: false, alasan: 'Video gagal tersimpan di cloud (verifikasi gagal).' };
    } catch (_) {
      return { ok: false, alasan: 'Video gagal tersimpan di cloud.' };
    }

    // 3) Ambil byte GIF hasil transformasi f_gif, lalu unggah ulang sebagai
    //    aset image/gif mandiri (public_id berakhiran .gif). Utamakan URL
    //    eager (sudah jadi saat unggah); fallback ke derivasi on-demand.
    const eagerUrl = Array.isArray(j.eager) && j.eager[0]?.secure_url ? String(j.eager[0].secure_url) : '';
    const gifSumber = eagerUrl.startsWith('http')
      ? eagerUrl
      : String(j.secure_url).replace('/video/upload/', `/video/upload/${transformBannerGif}/`);
    let gifBytes = null;
    // Derivasi f_gif dibuat on-demand oleh Cloudinary; permintaan pertama
    // bisa datang sebelum aset siap. Coba ulang sebentar dan validasi
    // magic-byte "GIF" supaya byte salah tidak pernah tersimpan sebagai gif.
    for (let coba = 0; coba < 3 && !gifBytes; coba++) {
      if (coba) await new Promise((r) => setTimeout(r, 1200 * coba));
      try {
        const rg = await fetch(gifSumber);
        if (rg.ok) {
          const b = new Uint8Array(await rg.arrayBuffer());
          if (b.length >= 12 && b[0] === 0x47 && b[1] === 0x49 && b[2] === 0x46) gifBytes = b;
        }
      } catch (_) {}
    }
    if (!gifBytes || gifBytes.length < 12) {
      // Fallback: pakai GIF turunan (transform) dan biarkan MP4 tersimpan.
      await catatMedia(env, { id: j.public_id, url: j.secure_url, folder, format: j.format || 'mp4', width: j.width, height: j.height, bytes: j.bytes, animated: 1, hash });
      return { ok: true, url: j.secure_url, gif: gifSumber, id: j.public_id, format: j.format, sisaMp4: true };
    }

    const gifBase64 = keBase64(gifBytes);
    const ts2 = Math.floor(Date.now() / 1000);
    const rid = crypto.randomUUID().replace(/-/g, '');
    const r2 = await kirimUnggah(env, `https://api.cloudinary.com/v1_1/${env.CLOUDINARY_CLOUD}/image/upload`, {
      folder, timestamp: ts2,
      signParams: { folder, public_id: `${folder}/${rid}.gif` },
      file: `data:image/gif;base64,${gifBase64}`,
    });
    const jg = await r2.json();
    if (!r2.ok || jg.error) {
      // Fallback: GIF turunan tetap dipakai, MP4 dibiarkan.
      await catatMedia(env, { id: j.public_id, url: j.secure_url, folder, format: j.format || 'mp4', width: j.width, height: j.height, bytes: j.bytes, animated: 1, hash });
      return { ok: true, url: j.secure_url, gif: gifSumber, id: j.public_id, format: j.format, sisaMp4: true };
    }

    // 4) Hapus MP4 asli — GIF mandiri sudah tersimpan.
    const terhapus = await hapusCloudinary(env, mp4Id, 'video');

    // 5) Catat aset akhir (GIF).
    await catatMedia(env, {
      id: jg.public_id, url: jg.secure_url, folder, format: 'gif',
      width: jg.width || null, height: jg.height || null, bytes: jg.bytes || null,
      animated: 1, hash,
    });

    return {
      ok: true,
      url: jg.secure_url,
      gif: jg.secure_url,
      id: jg.public_id,
      format: 'gif',
      bytes: jg.bytes,
      hash,
      mp4Terhapus: terhapus,
    };
  } catch (e) {
    return { ok: false, alasan: String(e) };
  }
}

/**
 * Ubah URL Cloudinary menjadi tautan milik domain sendiri.
 *
 *   https://res.cloudinary.com/awan/image/upload/v123/xycloudstore/produk/abc.png
 *   -> https://api.xycloud.my.id/img/m/xycloudstore/produk/abc.png
 *
 * Selain menyembunyikan penyedia penyimpanan, jalur ini juga
 * memampatkan gambar otomatis lewat transformasi Cloudinary.
 */
export function samarkanGambar(env, url, ukuran = 'm') {
  if(!url||typeof url!=='string')return url;
  try{
    const u=new URL(url),base=env.PUBLIC_URL||'https://api.xycloud.my.id';
    let path;
    if(u.origin===new URL(base).origin&&u.pathname.startsWith('/img/')){
      const p=u.pathname.slice(5).split('/');if(UKURAN_GAMBAR[p[0]])p.shift();path=p.join('/');
    }else if(u.hostname==='res.cloudinary.com'){
      const prefix=`/${env.CLOUDINARY_CLOUD}/image/upload/`;
      if(!u.pathname.startsWith(prefix))return url;
      path=u.pathname.slice(prefix.length);
      const start=path.indexOf('xycloudstore/');if(start<0)return url;
      const before=path.slice(0,start).split('/').filter(Boolean);const version=before.find(v=>/^v\d+$/.test(v));
      path=(version?version+'/':'')+path.slice(start);
    }else return url;
    return `${base}/img/${UKURAN_GAMBAR[ukuran]?ukuran:'m'}/${path}?v=26`;
  }catch{return url;}
}

/**
 * Samarkan media APAPUN (gambar ATAU video/audio): jalur `image/upload`
 * ke /img/, jalur `video/upload` ke /media/. URL non-Cloudinary dibiarkan.
 */
export function samarkanKMedia(env, url, ukuran = 'm') {
  if (!url || typeof url !== 'string') return url;
  try {
    const u = new URL(url);
    const base = env.PUBLIC_URL || 'https://api.xycloud.my.id';
    if (u.origin === new URL(base).origin && (u.pathname.startsWith('/img/') || u.pathname.startsWith('/media/'))) return url;
    if (u.hostname !== 'res.cloudinary.com') return url;
    if (u.pathname.includes('/image/upload/')) return samarkanGambar(env, url, ukuran);
    const idx = u.pathname.indexOf('/video/upload/');
    if (idx < 0) return url;
    const rest = u.pathname.slice(idx + '/video/upload/'.length); // transform?/v123/xycloudstore/.../x.mp4
    if (!rest.includes('xycloudstore/')) return url;
    if (!/^[A-Za-z0-9_,.%+=\/-]+$/.test(rest)) return url;
    return `${base}/media/${rest}`;
  } catch { return url; }
}

/**
 * Samarkan JSON `users.banner_media` ({tipe,url,gif}) supaya
 * tidak ada URL Cloudinary yang bocor ke aplikasi.
 */
export function samarkanBannerMedia(env, raw) {
  if (!raw) return raw;
  try {
    const obj = JSON.parse(raw);
    if (!obj || typeof obj !== 'object') return raw;
    if (obj.url) obj.url = samarkanKMedia(env, obj.url);
    if (obj.gif) obj.gif = samarkanKMedia(env, obj.gif);
    return JSON.stringify(obj);
  } catch (_) {
    return raw;
  }
}

/** Pixel-sized variants, not doubled by device-pixel-ratio on the server. */
export const UKURAN_GAMBAR={s:160,t:360,m:800,l:1280,o:2048,blur:420};
export function imageVariant(env,path,accept='',animated=false){
  const chunks=path.replace(/^\/img\//,'').split('/');
  const size=UKURAN_GAMBAR[chunks[0]]?chunks.shift():'m';
  const id=chunks.join('/');
  if(!/^(?:v\d+\/)?xycloudstore\/[A-Za-z0-9_./%-]+$/.test(id)||id.split('/').some(x=>x==='..'||x==='.')||/%2e/i.test(id))return null;
  const format=animated?'original':accept.includes('image/avif')?'avif':'webp';
  const transform=animated?'':`${format==='avif'?'f_avif,q_62':'f_webp,q_78'},c_limit,w_${UKURAN_GAMBAR[size]},h_${UKURAN_GAMBAR[size]}${size==='blur'?',e_blur:1600':''}/`;
  return {format,size,id,url:`https://res.cloudinary.com/${env.CLOUDINARY_CLOUD}/image/upload/${transform}${id}`};
}

/** Edge + browser cache. Animated uploads retain original frames/transparency. */
export async function layaniGambar(env,jalur,req,ctx){
  if(!env.CLOUDINARY_CLOUD)return new Response('Media belum tersedia',{status:503});
  const accept=req?.headers.get('accept')||'';
  // Regex escape tunggal: `/\\.gif$/` (backslash ganda) tidak pernah cocok
  // sehingga GIF animasi ikut tertransformasi f_webp,q_78 dan kehilangan
  // seluruh frame kecuali yang pertama — bug "video convert to gif diam".
  const first=imageVariant(env,jalur,accept,/\.(gif|webp)$/i.test(jalur));
  if(!first)return new Response('Not found',{status:404});
  const key=new URL(req.url);key.search='v=26&format='+(accept.includes('image/avif')?'avif':'webp');
  const cache=typeof caches!=='undefined'?caches.default:null;
  const cacheKey=new Request(key.toString(),{method:'GET'});
  const hit=cache?await cache.match(cacheKey):null;
  if(hit)return hit;
  let animated=/\.gif$/i.test(jalur);
  if(/\.webp$/i.test(jalur)){
    const id=first.id.replace(/^v\d+\//,'').replace(/\\.[^.]+$/,'');
    try{const item=await env.DB.prepare('SELECT animated FROM media_assets WHERE id=?').bind(id).first();animated=item?!!item.animated:true;}catch{animated=true;}
  }
  const variant=imageVariant(env,jalur,accept,animated);
  const response=await fetch(variant.url,{headers:{Accept:animated?'image/webp,image/gif,image/*':`image/${variant.format}`},cf:{cacheTtl:604800,cacheEverything:true}});
  if(!response.ok)return new Response('Media tidak tersedia',{status:response.status===404?404:502});
  const headers=new Headers();
  headers.set('Content-Type',response.headers.get('Content-Type')||'image/'+variant.format);
  headers.set('Cache-Control','public, max-age=604800, immutable');headers.set('Vary','Accept');
  headers.set('X-Content-Type-Options','nosniff');headers.set('X-XY-Media',variant.format+':'+variant.size);
  headers.set('Access-Control-Allow-Origin','*');
  const result=new Response(response.body,{status:200,headers});
  if(cache){const save=cache.put(cacheKey,result.clone()).catch(()=>{});if(ctx)ctx.waitUntil(save);else await save;}
  return result;
}

/**
 * Sajikan media video/audio melalui domain sendiri (`/media/...`).
 * `rest` = sisa jalur setelah `/video/upload/` di Cloudinary
 * (opsional transform, lalu v123, lalu folder xycloudstore).
 */
export async function layaniMedia(env, rest, req, ctx) {
  if (!env.CLOUDINARY_CLOUD) return new Response('Media belum tersedia', { status: 503 });
  // Keamanan: hanya jalur dalam folder xycloudstore, tanpa '..'.
  if (!/^(?:[A-Za-z0-9_,.-]+\/)?v\d+\/xycloudstore\/[A-Za-z0-9_.\/%-]+$/.test(rest) ||
      rest.split('/').some((x) => x === '..' || x === '.') || /%2e/i.test(rest)) {
    return new Response('Not found', { status: 404 });
  }
  const url = `https://res.cloudinary.com/${env.CLOUDINARY_CLOUD}/video/upload/${rest}`;
  const cache = typeof caches !== 'undefined' ? caches.default : null;
  const key = new URL((req && req.url) ? req.url : 'https://api.xycloud.my.id/media/' + rest);
  key.search = 'v=26';
  const cacheKey = new Request(key.toString(), { method: 'GET' });
  if (cache) {
    const hit = await cache.match(cacheKey);
    if (hit) return hit;
  }
  const response = await fetch(url, { headers: { Range: req.headers.get('range') || '' }, cf: { cacheTtl: 604800, cacheEverything: true } });
  if (!response.ok) return new Response('Media tidak tersedia', { status: response.status === 404 ? 404 : 502 });
  const headers = new Headers();
  headers.set('Content-Type', response.headers.get('Content-Type') || 'application/octet-stream');
  headers.set('Cache-Control', 'public, max-age=604800, immutable');
  headers.set('X-Content-Type-Options', 'nosniff');
  headers.set('Access-Control-Allow-Origin', '*');
  if (response.headers.get('Content-Length')) headers.set('Content-Length', response.headers.get('Content-Length'));
  const result = response.status === 206
    ? new Response(response.body, { status: 206, headers })
    : new Response(response.body, { status: 200, headers });
  if (cache) { const save = cache.put(cacheKey, result.clone()).catch(() => {}); if (ctx) ctx.waitUntil(save); else await save; }
  return result;
}

/** Delete only expired CS uploads; never product/profile/other people's media. */
export async function hapusMediaChat(env, url) {
  try {
    const u = new URL(url);
    const prefix = `/${env.CLOUDINARY_CLOUD}/image/upload/`;
    if (u.hostname !== 'res.cloudinary.com' || !u.pathname.startsWith(prefix)) return true;
    // Queue hanya boleh memusnahkan aset privat yang lifecycle-nya jelas:
    // lampiran chat dan avatar OAuth unik (dedup dimatikan untuk folder ini).
    const match = u.pathname.match(/\/(xycloudstore\/(?:chat|profil\/sosial)\/[^?]+)\.[a-zA-Z0-9]+$/);
    if (!match) return true;
    const publicId = decodeURIComponent(match[1]);
    if (!/^xycloudstore\/(?:chat|profil\/sosial)\/[A-Za-z0-9_./-]+$/.test(publicId)) return true;
    const timestamp = Math.floor(Date.now() / 1000);
    const signature = await sha1(`invalidate=true&public_id=${publicId}&timestamp=${timestamp}${env.CLOUDINARY_SECRET}`);
    const form = new FormData();
    form.set('public_id', publicId);
    form.set('invalidate', 'true');
    form.set('timestamp', String(timestamp));
    form.set('signature', signature);
    form.set('api_key', env.CLOUDINARY_KEY);
    const r = await fetch(`https://api.cloudinary.com/v1_1/${env.CLOUDINARY_CLOUD}/image/destroy`, { method: 'POST', body: form });
    const j = await r.json().catch(() => ({}));
    const ok = r.ok && ['ok', 'not found'].includes(j.result);
    if (ok && env.DB) {
      await env.DB.prepare('DELETE FROM media_assets WHERE id=? OR url=?').bind(publicId, url).run().catch(() => {});
    }
    return ok;
  } catch (_) { return false; }
}
