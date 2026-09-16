import test from 'node:test';
import assert from 'node:assert/strict';
import { createHmac, webcrypto } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import {
  ambilProfil,
  facebookGraphVersion,
  halamanKembali,
  providerSiap,
  urlMulai,
  verifikasiSignedRequestFacebook,
} from '../src/oauth.js';

if (!globalThis.crypto) Object.defineProperty(globalThis, 'crypto', { value: webcrypto });
if (!globalThis.atob) globalThis.atob = (v) => Buffer.from(v, 'base64').toString('binary');

const env = {
  PUBLIC_URL: 'https://api.example.invalid',
  FACEBOOK_APP_ID: 'app-123',
  FACEBOOK_APP_SECRET: 'secret-only-on-server',
  FACEBOOK_GRAPH_VERSION: 'v26.0',
};

const response = (value, status = 200) => new Response(JSON.stringify(value), {
  status,
  headers: { 'Content-Type': 'application/json' },
});

test('provider Facebook hanya siap bila App ID dan App Secret tersedia', () => {
  assert.equal(providerSiap(env).facebook, true);
  assert.equal(providerSiap({ FACEBOOK_APP_ID: 'x' }).facebook, false);
  assert.equal(facebookGraphVersion({ FACEBOOK_GRAPH_VERSION: 'tidak-sah' }), 'v26.0');
  const mulai = new URL(urlMulai(env, 'facebook', 'state-uji'));
  assert.equal(mulai.pathname, '/v26.0/dialog/oauth');
  assert.equal(mulai.searchParams.get('redirect_uri'), 'https://api.example.invalid/api/auth/facebook/callback');
  assert.equal(mulai.searchParams.get('scope'), 'email,public_profile');
  assert.equal(mulai.searchParams.get('state'), 'state-uji');
  const ulang = new URL(urlMulai(env, 'facebook', 'state-uji', { rerequestEmail: true }));
  assert.equal(ulang.searchParams.get('auth_type'), 'rerequest');
});

test('signed_request penghapusan Meta diverifikasi dengan HMAC-SHA256', async () => {
  const payload = Buffer.from(JSON.stringify({ algorithm: 'HMAC-SHA256', user_id: '99887766' })).toString('base64url');
  const signature = createHmac('sha256', env.FACEBOOK_APP_SECRET).update(payload).digest('base64url');
  const sah = await verifikasiSignedRequestFacebook(env, `${signature}.${payload}`);
  assert.deepEqual(sah, { ok: true, userId: '99887766' });

  const palsu = await verifikasiSignedRequestFacebook(env, `AAAA.${payload}`);
  assert.equal(palsu.ok, false);
});

test('Facebook memakai code exchange resmi, lalu Bearer dan appsecret_proof tanpa access token di URL profil', async () => {
  const calls = [];
  const lama = globalThis.fetch;
  globalThis.fetch = async (url, options = {}) => {
    calls.push({ url: String(url), options });
    if (String(url).includes('/oauth/access_token')) return response({ access_token: 'user-access-token', token_type: 'bearer', expires_in: 3600 });
    if (String(url).includes('/me?')) return response({
      id: 'fb-user-1', name: 'Pengguna Uji', email: 'USER@EXAMPLE.COM', picture: { data: { url: 'https://x.fbcdn.net/avatar.jpg' } },
    });
    throw new Error('URL tidak diduga');
  };
  try {
    const profil = await ambilProfil(env, 'facebook', 'authorization-code');
    assert.equal(profil.ok, true);
    assert.equal(profil.id, 'fb-user-1');
    assert.equal(profil.email, 'user@example.com');
    assert.equal(calls.length, 2);

    assert.equal(calls[0].options.method, undefined);
    assert.equal(new URL(calls[0].url).searchParams.get('client_secret'), env.FACEBOOK_APP_SECRET);
    assert.equal(new URL(calls[0].url).searchParams.get('code'), 'authorization-code');
    assert.equal(calls[1].options.headers.Authorization, 'Bearer user-access-token');
    assert.match(new URL(calls[1].url).searchParams.get('appsecret_proof') || '', /^[a-f0-9]{64}$/);
    assert.ok(!calls[1].url.includes('user-access-token'));
  } finally {
    globalThis.fetch = lama;
  }
});

test('Facebook tanpa email ditolak dan tidak membuat alamat @facebook.local', async () => {
  const lama = globalThis.fetch;
  globalThis.fetch = async (url) => {
    if (String(url).includes('/oauth/access_token')) return response({ access_token: 'token', token_type: 'bearer' });
    return response({ id: 'fb-no-email', name: 'Tanpa Email' });
  };
  try {
    const profil = await ambilProfil(env, 'facebook', 'code');
    assert.equal(profil.ok, false);
    assert.match(profil.alasan, /email/i);
    assert.ok(!JSON.stringify(profil).includes('@facebook.local'));
  } finally {
    globalThis.fetch = lama;
  }
});

test('halaman callback meng-escape nama dan tujuan HTML', () => {
  const html = halamanKembali('xycloudstore://auth?error=</script><script>x</script>', '<img src=x onerror=x>');
  assert.ok(!html.includes('<img src=x onerror=x>'));
  assert.ok(!html.includes('location.href="xycloudstore://auth?error=</script>'));
  assert.match(html, /&lt;img/);
});

test('kontrak D1 identity stabil, deletion callback, dan cleanup akun tetap ada', async () => {
  const [migration, index, akun] = await Promise.all([
    readFile(new URL('../migrations/0017_social_identity_facebook.sql', import.meta.url), 'utf8'),
    readFile(new URL('../src/index.js', import.meta.url), 'utf8'),
    readFile(new URL('../src/akun.js', import.meta.url), 'utf8'),
  ]);
  assert.match(migration, /PRIMARY KEY \(provider, provider_user_hash\)/);
  assert.match(migration, /UNIQUE \(provider, user_id\)/);
  assert.match(index, /auth\/facebook\/data-deletion/);
  assert.match(index, /auth\/facebook\/deauthorize/);
  assert.match(index, /confirmation_code/);
  assert.match(index, /infoHapusAkun\(env, u\)/);
  assert.match(index, /bersihkanAkun\(env, u\)/);
  assert.match(akun, /DELETE FROM social_identity WHERE user_id=\?/);
  assert.match(akun, /DELETE FROM referral_attribution WHERE pengundang=\? OR claimed_by=\?/);
  assert.match(akun, /DELETE FROM follows WHERE ikut_id=\? OR target_id=\?/);
  assert.match(akun, /DELETE FROM dm WHERE dari_id=\? OR ke_id=\?/);
  assert.match(akun, /UPDATE transfer SET dari_id=/);
  assert.match(akun, /UPDATE topup SET user_id='dihapus',bukti=NULL/);
  assert.ok(!index.includes('@facebook.local'));
});
