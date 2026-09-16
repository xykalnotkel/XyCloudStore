/**
 * ============================================================
 *  XyCloudStore - Login sosial (OAuth 2.0)
 * ============================================================
 *  Alur:
 *    aplikasi  ->  /api/auth/{provider}/start
 *              ->  halaman izin Google / Facebook
 *              ->  /api/auth/{provider}/callback
 *              ->  balik ke aplikasi lewat xycloudstore://auth?token=...
 *
 *  Pertukaran kode dan App Secret hanya berlangsung di Worker. APK tidak
 *  pernah membawa FACEBOOK_APP_SECRET maupun GOOGLE_CLIENT_SECRET.
 */

export const SKEMA_APLIKASI = 'xycloudstore';
const FACEBOOK_VERSION_BAWAAN = 'v26.0';

export function facebookGraphVersion(env) {
  const value = String(env.FACEBOOK_GRAPH_VERSION || FACEBOOK_VERSION_BAWAAN).trim();
  return /^v\d{1,2}\.\d$/.test(value) ? value : FACEBOOK_VERSION_BAWAAN;
}

export function providerSiap(env) {
  return {
    google: Boolean(String(env.GOOGLE_CLIENT_ID || '').trim() && String(env.GOOGLE_CLIENT_SECRET || '').trim()),
    facebook: Boolean(String(env.FACEBOOK_APP_ID || '').trim() && String(env.FACEBOOK_APP_SECRET || '').trim()),
  };
}

export const alamatCallback = (env, provider) =>
  `${env.PUBLIC_URL || 'https://api.xycloud.my.id'}/api/auth/${provider}/callback`;

const signalTimeout = () => typeof AbortSignal !== 'undefined' && typeof AbortSignal.timeout === 'function'
  ? AbortSignal.timeout(15_000) : undefined;

async function ambilJson(url, options = {}) {
  try {
    const r = await fetch(url, { ...options, signal: options.signal || signalTimeout() });
    const data = await r.json().catch(() => ({}));
    return { ok: r.ok, status: r.status, data };
  } catch (_) {
    return { ok: false, status: 0, data: {} };
  }
}

function namaAman(value, fallback = 'Pengguna') {
  const valueAman = String(value || '').replace(/[\u0000-\u001f\u007f<>]/g, '').replace(/\s+/g, ' ').trim();
  return Array.from(valueAman || fallback).slice(0, 80).join('');
}

function alasanFacebook(data, fallback) {
  const code = Number(data?.error?.code || 0);
  if (code === 190) return 'Sesi Facebook kedaluwarsa. Silakan mulai login ulang.';
  if (code === 101 || code === 102) return 'Konfigurasi Facebook belum cocok. Hubungi admin.';
  if (code === 200 || code === 10) return 'Izin Facebook yang diperlukan belum diberikan.';
  return fallback;
}

async function hmacHex(secret, value) {
  const key = await crypto.subtle.importKey(
    'raw', new TextEncoder().encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign'],
  );
  const bytes = new Uint8Array(await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(value)));
  return [...bytes].map((x) => x.toString(16).padStart(2, '0')).join('');
}

function base64UrlBytes(value) {
  const normalized = String(value || '').replace(/-/g, '+').replace(/_/g, '/');
  const padded = normalized + '='.repeat((4 - normalized.length % 4) % 4);
  const binary = atob(padded);
  return Uint8Array.from(binary, (c) => c.charCodeAt(0));
}

/** Verifikasi callback penghapusan data yang ditandatangani App Secret Meta. */
export async function verifikasiSignedRequestFacebook(env, signedRequest) {
  try {
    if (!providerSiap(env).facebook) return { ok: false, alasan: 'FACEBOOK_NOT_CONFIGURED' };
    const [signaturePart, payloadPart, lebih] = String(signedRequest || '').split('.');
    if (!signaturePart || !payloadPart || lebih) return { ok: false, alasan: 'SIGNED_REQUEST_FORMAT' };
    const payloadBytes = base64UrlBytes(payloadPart);
    const payload = JSON.parse(new TextDecoder().decode(payloadBytes));
    if (String(payload.algorithm || '').toUpperCase() !== 'HMAC-SHA256') {
      return { ok: false, alasan: 'SIGNED_REQUEST_ALGORITHM' };
    }
    const key = await crypto.subtle.importKey(
      'raw', new TextEncoder().encode(env.FACEBOOK_APP_SECRET),
      { name: 'HMAC', hash: 'SHA-256' }, false, ['verify'],
    );
    const sah = await crypto.subtle.verify(
      'HMAC', key, base64UrlBytes(signaturePart), new TextEncoder().encode(payloadPart),
    );
    const userId = String(payload.user_id || '');
    if (!sah || !/^[A-Za-z0-9_-]{1,128}$/.test(userId)) {
      return { ok: false, alasan: 'SIGNED_REQUEST_INVALID' };
    }
    return { ok: true, userId };
  } catch (_) {
    return { ok: false, alasan: 'SIGNED_REQUEST_INVALID' };
  }
}

/** URL halaman izin milik penyedia. */
export function urlMulai(env, provider, state, { rerequestEmail = false } = {}) {
  if (provider === 'google') {
    const q = new URLSearchParams({
      client_id: env.GOOGLE_CLIENT_ID,
      redirect_uri: alamatCallback(env, 'google'),
      response_type: 'code',
      scope: 'openid email profile',
      access_type: 'online',
      include_granted_scopes: 'true',
      prompt: 'select_account',
      state,
    });
    return `https://accounts.google.com/o/oauth2/v2/auth?${q}`;
  }
  if (provider === 'facebook') {
    const q = new URLSearchParams({
      client_id: env.FACEBOOK_APP_ID,
      redirect_uri: alamatCallback(env, 'facebook'),
      response_type: 'code',
      scope: 'email,public_profile',
      return_scopes: 'true',
      state,
    });
    // Hanya setelah aplikasi menjelaskan bahwa email wajib dan pengguna
    // mencoba lagi; jangan memaksa prompt ulang pada setiap login normal.
    if (rerequestEmail) q.set('auth_type', 'rerequest');
    return `https://www.facebook.com/${facebookGraphVersion(env)}/dialog/oauth?${q}`;
  }
  return null;
}

/** Tukar kode dengan profil pengguna: { id, email, nama, foto }. */
export async function ambilProfil(env, provider, code) {
  if (provider === 'google') {
    const token = await ambilJson('https://oauth2.googleapis.com/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        code,
        client_id: env.GOOGLE_CLIENT_ID,
        client_secret: env.GOOGLE_CLIENT_SECRET,
        redirect_uri: alamatCallback(env, 'google'),
        grant_type: 'authorization_code',
      }),
    });
    const t = token.data;
    if (!token.ok || !t.access_token) {
      return { ok: false, alasan: t.error_description || 'Google gagal menukar kode.' };
    }

    const profil = await ambilJson('https://openidconnect.googleapis.com/v1/userinfo', {
      headers: { Authorization: `Bearer ${t.access_token}` },
    });
    const p = profil.data;
    if (!profil.ok || !p.sub || !p.email) return { ok: false, alasan: 'Akun Google tidak membagikan identitas lengkap.' };
    if (p.email_verified !== true && p.email_verified !== 'true') {
      return { ok: false, alasan: 'Email Google belum terverifikasi.' };
    }
    return {
      ok: true,
      id: String(p.sub),
      email: String(p.email).trim().toLowerCase(),
      nama: namaAman(p.name, String(p.email).split('@')[0]),
      foto: p.picture,
    };
  }

  if (provider === 'facebook') {
    const versi = facebookGraphVersion(env);
    // Meta mendokumentasikan endpoint pertukaran ini sebagai GET. Secret tetap
    // hanya berada pada subrequest HTTPS Worker -> Meta dan tidak pernah dicatat.
    const tokenQuery = new URLSearchParams({
      client_id: env.FACEBOOK_APP_ID,
      client_secret: env.FACEBOOK_APP_SECRET,
      redirect_uri: alamatCallback(env, 'facebook'),
      code,
    });
    const token = await ambilJson(
      `https://graph.facebook.com/${versi}/oauth/access_token?${tokenQuery}`,
      { headers: { 'Cache-Control': 'no-store' } },
    );
    const t = token.data;
    if (!token.ok || !t.access_token) {
      return { ok: false, alasan: alasanFacebook(t, 'Facebook gagal menukar kode. Coba login ulang.') };
    }

    // Code hanya dapat ditukar oleh App ID + Secret + redirect URI yang sama.
    // Validitas token kemudian dibuktikan lagi lewat /me. Kami sengaja tidak
    // memakai /debug_token karena kontrak resminya menaruh input_token di URL.
    if (t.token_type && String(t.token_type).toLowerCase() !== 'bearer') {
      return { ok: false, alasan: 'Facebook mengembalikan jenis token yang tidak didukung.' };
    }
    if (t.expires_in != null && (!Number.isFinite(Number(t.expires_in)) || Number(t.expires_in) <= 0)) {
      return { ok: false, alasan: 'Token Facebook sudah kedaluwarsa.' };
    }

    const proof = await hmacHex(env.FACEBOOK_APP_SECRET, t.access_token);
    const profil = await ambilJson(
      `https://graph.facebook.com/${versi}/me?fields=id,name,email,picture.width(256)&appsecret_proof=${proof}`,
      { headers: { Authorization: `Bearer ${t.access_token}` } },
    );
    const p = profil.data;
    if (!profil.ok || !p.id || !/^[A-Za-z0-9_-]{1,128}$/.test(String(p.id))) {
      return { ok: false, alasan: alasanFacebook(p, 'Facebook tidak mengembalikan profil yang valid.') };
    }
    const email = String(p.email || '').trim().toLowerCase();
    if (!/^[^@\s]+@[^@\s]+\.[^@\s]{2,}$/.test(email) || email.length > 254) {
      return {
        ok: false,
        alasan: 'Facebook tidak membagikan email. Izinkan akses email atau masuk memakai email dan password.',
      };
    }
    return {
      ok: true,
      id: String(p.id),
      email,
      nama: namaAman(p.name, email.split('@')[0]),
      foto: p.picture?.data?.url,
    };
  }

  return { ok: false, alasan: 'Penyedia tidak dikenal.' };
}

/** Diagnostik aman untuk dashboard; tidak pernah mengembalikan secret/token. */
export async function diagnostikFacebook(env) {
  const configured = providerSiap(env).facebook;
  const versi = facebookGraphVersion(env);
  const result = {
    configured,
    graphVersion: versi,
    callback: alamatCallback(env, 'facebook'),
    dataDeletionCallback: `${env.PUBLIC_URL || 'https://api.xycloud.my.id'}/api/auth/facebook/data-deletion`,
    deauthorizeCallback: `${env.PUBLIC_URL || 'https://api.xycloud.my.id'}/api/auth/facebook/deauthorize`,
    privacy: `${env.WEB_URL || 'https://xycloud.my.id'}/legal/privasi`,
    credentialsValid: false,
  };
  if (!configured) return result;
  const appToken = `${env.FACEBOOK_APP_ID}|${env.FACEBOOK_APP_SECRET}`;
  const cek = await ambilJson(
    `https://graph.facebook.com/${versi}/${encodeURIComponent(env.FACEBOOK_APP_ID)}?fields=id,name`,
    { headers: { Authorization: `Bearer ${appToken}` } },
  );
  if (cek.ok && String(cek.data?.id) === String(env.FACEBOOK_APP_ID)) {
    return { ...result, credentialsValid: true, appName: String(cek.data.name || '').slice(0, 80) };
  }
  return { ...result, errorCode: Number(cek.data?.error?.code || cek.status || 0) };
}

const escapeHtml = (value) => String(value ?? '').replace(/[&<>"']/g, (c) => ({
  '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
}[c]));

/** Halaman kecil yang melempar pengguna kembali ke aplikasi. */
export function halamanKembali(tujuan, pesan) {
  const tujuanAttr = escapeHtml(tujuan);
  const tujuanJs = JSON.stringify(String(tujuan)).replace(/</g, '\\u003c');
  return `<!DOCTYPE html><html lang="id"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="referrer" content="no-referrer"><title>XyCloudStore</title>
<meta http-equiv="refresh" content="0;url=${tujuanAttr}"></head>
<body style="margin:0;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;
  background:linear-gradient(135deg,#6C2BE2,#4A12B8);color:#fff;display:flex;align-items:center;
  justify-content:center;height:100vh;text-align:center">
  <div>
    <div style="font-size:19px;font-weight:800;letter-spacing:-.4px">${escapeHtml(pesan)}</div>
    <div style="opacity:.8;font-size:13.5px;margin-top:10px">Kembali ke aplikasi XyCloudStore...</div>
    <a href="${tujuanAttr}" rel="noreferrer" style="display:inline-block;margin-top:22px;background:#fff;color:#6C2BE2;
      text-decoration:none;font-weight:800;font-size:14px;padding:12px 24px;border-radius:99px">Buka Aplikasi</a>
  </div>
  <script>setTimeout(function(){location.href=${tujuanJs}},250)</script>
</body></html>`;
}

/**
 * Verifikasi ID token dari Google Sign-In native (aplikasi Android).
 * Token diperiksa langsung ke Google, lalu dipastikan audiensnya milik kita.
 */
export async function verifikasiIdTokenGoogle(env, idToken) {
  if (!idToken) return { ok: false, alasan: 'Token kosong' };
  try {
    const r = await fetch(`https://oauth2.googleapis.com/tokeninfo?id_token=${encodeURIComponent(idToken)}`, {
      signal: signalTimeout(),
    });
    const p = await r.json();
    if (!r.ok || p.error_description) {
      return { ok: false, alasan: p.error_description || 'Token Google tidak valid' };
    }

    const diizinkan = [env.GOOGLE_CLIENT_ID, env.GOOGLE_CLIENT_ID_ANDROID]
      .filter(Boolean)
      .map((x) => x.trim());
    if (!diizinkan.length || !diizinkan.includes(p.aud)) {
      return { ok: false, alasan: 'Aplikasi tidak dikenali oleh server' };
    }
    const penerbitSah = p.iss === 'accounts.google.com' || p.iss === 'https://accounts.google.com';
    if (!penerbitSah) return { ok: false, alasan: 'Penerbit token tidak sah' };
    if (!Number.isFinite(Number(p.exp)) || Number(p.exp) * 1000 <= Date.now()) return { ok: false, alasan: 'Token sudah kedaluwarsa' };
    if (!p.sub || !p.email) return { ok: false, alasan: 'Akun Google tidak membagikan identitas lengkap' };
    if (p.email_verified !== true && p.email_verified !== 'true') return { ok: false, alasan: 'Email Google belum terverifikasi' };

    return {
      ok: true,
      id: String(p.sub),
      email: String(p.email).trim().toLowerCase(),
      nama: namaAman(p.name, String(p.email).split('@')[0]),
      foto: p.picture,
    };
  } catch (_) {
    return { ok: false, alasan: 'Google tidak dapat dihubungi. Coba lagi.' };
  }
}
