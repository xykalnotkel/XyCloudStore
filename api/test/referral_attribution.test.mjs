import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { harness } from './harness.mjs';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const read = (p) => readFileSync(resolve(root, p), 'utf8');
const api = read('api/src/index.js');
const migration = read('api/migrations/0016_referral_install_attribution.sql');
const schema = read('api/schema.sql');
const web = read('api/src/web.html');
const legal = read('api/src/legal.js');
const nativeManifest = read('native/xy_stream/src/main/AndroidManifest.xml');
const referralActivity = read('native/xy_stream/src/main/java/id/xycloud/stream/ReferralActivity.java');
const settings = read('native/xy_stream/src/main/java/id/xycloud/stream/NotificationSettings.java');
const patchManifest = read('tools/patch_manifest.py');
const dartAttribution = read('app/lib/data/referral_attribution.dart');
const appState = read('app/lib/providers/app_state.dart');
const referralUi = read('app/lib/ui/screens/referral_screen.dart');
const dashboard = read('dashboard/app/referral/page.tsx');

for (const ddl of [migration, schema]) {
  test(`skema atribusi lengkap: ${ddl === migration ? 'migration' : 'baseline'}`, () => {
    assert.match(ddl, /CREATE TABLE(?: IF NOT EXISTS)? referral_attribution/);
    assert.match(ddl, /downloaded_at TEXT/);
    assert.match(ddl, /installed_at TEXT/);
    assert.match(ddl, /package_installed_at TEXT/);
    assert.match(ddl, /device_id TEXT/);
    assert.match(ddl, /claimed_by TEXT/);
    assert.match(ddl, /CREATE UNIQUE INDEX(?: IF NOT EXISTS)? idx_referral_diundang_unique/);
    assert.match(ddl, /CREATE TRIGGER(?: IF NOT EXISTS)? referral_reward_after_insert/);
    assert.match(ddl, /INSERT OR IGNORE INTO transaksi/);
    assert.doesNotMatch(ddl, /raw_ticket|ticket_raw|ticket TEXT/);
  });
}

test('server menyimpan hash tiket dan menyediakan tiga tahap publik', () => {
  assert.match(api, /securityHash\(env, 'referral-ticket', raw\)/);
  assert.match(api, /p === 'referral\/klik'/);
  assert.match(api, /referral_install_aktif/);
  assert.match(api, /p === 'referral\/unduh'/);
  assert.match(api, /p === 'referral\/buka'/);
  assert.match(api, /Berkas APK tidak ada pada rilis aktif/);
  assert.match(api, /downloaded_at=COALESCE/);
  assert.match(api, /installed_at=COALESCE/);
  assert.match(api, /packageInstalledMs < clickMs/);
  assert.match(api, /aplikasi_sudah_terpasang/);
});

test('klaim terautentikasi menolak jalan pintas dan fraud utama', () => {
  assert.match(api, /p === 'referral\/atribusi' \|\| p === 'referral\/pakai'/);
  assert.match(api, /klaimAtribusiReferral\(env, ctx, req, me\.sub, b\)/);
  assert.match(api, /email_verified/);
  assert.match(api, /registration_device !== deviceId/);
  assert.match(api, /akun_mendahului_klik/);
  assert.match(api, /perangkat_sama_pengundang/);
  assert.match(api, /attr\.claimed_by/);
  assert.match(api, /waktuReferral\(attr\.expires_at\) <= Date\.now\(\)/);
  const route = api.slice(api.indexOf("if ((p === 'referral/atribusi'"), api.indexOf('// ---- favorit produk'));
  assert.doesNotMatch(route, /UPDATE users SET saldo/);
  assert.doesNotMatch(route, /env\.DB\.batch/);
});

test('landing mempertahankan rantai klik, unduh, dan explicit deep link', () => {
  assert.match(web, /\/api\/referral\/klik/);
  assert.match(web, /\/api\/referral\/unduh\?ticket=/);
  assert.match(web, /xycloudstore:\/\/referral\?ticket=/);
  assert.match(web, /Buka aplikasi &amp; aktifkan undangan/);
  assert.match(web, /app yang sudah terpasang, atau akun lama tidak menghasilkan bonus/);
  assert.match(legal, /waktu pemasangan paket Android/);
});

test('Android memisahkan callback auth dan penerima referral', () => {
  assert.match(patchManifest, /android:scheme=\"xycloudstore\" android:host=\"auth\"/);
  assert.match(nativeManifest, /id\.xycloud\.stream\.ReferralActivity/);
  assert.match(nativeManifest, /android:host="referral"/);
  assert.match(referralActivity, /Context\.MODE_PRIVATE/);
  assert.match(referralActivity, /\^\[a-fA-F0-9\]\{64\}\$/);
  assert.match(settings, /referralAttribution/);
  assert.match(settings, /clearReferralAttribution/);
  assert.match(settings, /firstInstallTime/);
});

test('aplikasi mengonfirmasi instalasi dan klaim otomatis setelah autentikasi', () => {
  assert.match(dartAttribution, /MethodChannel\('xycloud\/settings'\)/);
  assert.match(dartAttribution, /referralAttribution/);
  assert.match(appState, /\/referral\/buka/);
  assert.match(appState, /\/referral\/atribusi/);
  assert.ok((appState.match(/await sinkronAtribusiReferral\(\);/g) || []).length >= 6);
  assert.match(appState, /AppLifecycleState\.resumed/);
  assert.match(referralUi, /Kode yang diketik tanpa mengunduh/);
  assert.match(referralUi, /Salin Tautan/);
});

test('dashboard menampilkan funnel serta status anti-fraud', () => {
  assert.match(dashboard, /Klik bertiket/);
  assert.match(dashboard, /APK diunduh/);
  assert.match(dashboard, /App dibuka/);
  assert.match(dashboard, /Ditolak \/ expired/);
  assert.match(dashboard, /r\.risiko/);
});

const rawDevice = (digit) => String(digit).repeat(64);

async function buatRantaiTerpasang({ db, call }, kode, raw) {
  await db.prepare("INSERT INTO setelan(kunci,nilai) VALUES('referral_install_aktif','1') ON CONFLICT(kunci) DO UPDATE SET nilai='1'").run();
  const klik = await call('/referral/klik', 'POST', { kode });
  assert.equal(klik.status, 201);
  const ticket = klik.json.data.ticket;
  const attr = await db.prepare(
    'SELECT id FROM referral_attribution WHERE kode=? ORDER BY clicked_at DESC LIMIT 1'
  ).bind(kode).first();
  await db.prepare(
    "UPDATE referral_attribution SET downloaded_at=datetime('now'),status='diunduh' WHERE id=?"
  ).bind(attr.id).run();
  const sekarang = Date.now();
  const buka = await call('/referral/buka', 'POST', {
    ticket, package_installed_at: sekarang, package_updated_at: sekarang,
  }, { 'x-xy-device': raw, 'x-xy-device-kind': 'android' });
  assert.equal(buka.status, 200);
  const terpasang = await db.prepare('SELECT * FROM referral_attribution WHERE id=?').bind(attr.id).first();
  assert.equal(terpasang.status, 'terpasang');
  return { ticket, attr: terpasang };
}

test('alur klaim memberi dua reward tepat sekali dan retry idempoten', async () => {
  const h = await harness();
  try {
    await h.db.prepare(
      "INSERT INTO users(id,nama,email,password,email_verified,kode_referral) VALUES('inv','Pengundang','inv@ref.invalid','x',1,'INV123')"
    ).run();
    const chain = await buatRantaiTerpasang(h, 'INV123', rawDevice(1));
    await h.db.prepare(
      "INSERT INTO users(id,nama,email,password,email_verified,registration_device) VALUES('new','Teman Baru','new@ref.invalid','x',1,?)"
    ).bind(chain.attr.device_id).run();
    const jwt = await h.token('new', { dv: chain.attr.device_id });
    const headers = { Authorization: `Bearer ${jwt}`, 'x-xy-device': rawDevice(1), 'x-xy-device-kind': 'android' };

    const claim = await h.call('/referral/atribusi', 'POST', { ticket: chain.ticket, kode: 'INV123' }, headers);
    assert.equal(claim.status, 200);
    assert.equal(claim.json.data.sudah, false);
    const saldo = await h.db.prepare("SELECT id,saldo,diundang_oleh FROM users WHERE id IN ('inv','new') ORDER BY id").all();
    assert.deepEqual(saldo.results.map((x) => [x.id, x.saldo, x.diundang_oleh]), [
      ['inv', 10000, null], ['new', 5000, 'inv'],
    ]);
    assert.equal((await h.db.prepare('SELECT COUNT(*) n FROM transaksi').first()).n, 2);

    const retry = await h.call('/referral/atribusi', 'POST', { ticket: chain.ticket }, headers);
    assert.equal(retry.status, 200);
    assert.equal(retry.json.data.sudah, true);
    assert.equal((await h.db.prepare('SELECT COUNT(*) n FROM transaksi').first()).n, 2);
  } finally { await h.mf.dispose(); }
});

test('akun yang dibuat sebelum klik ditolak tanpa membakar tiket perangkat sah', async () => {
  const h = await harness();
  try {
    await h.db.prepare(
      "INSERT INTO users(id,nama,email,password,email_verified,kode_referral) VALUES('inv','Pengundang','inv-old@ref.invalid','x',1,'TIME123')"
    ).run();
    const chain = await buatRantaiTerpasang(h, 'TIME123', rawDevice(4));
    await h.db.prepare(
      "INSERT INTO users(id,nama,email,password,email_verified,registration_device,created_at) VALUES('old','Akun Lama','old@ref.invalid','x',1,?,datetime('now','-2 days'))"
    ).bind(chain.attr.device_id).run();
    const jwt = await h.token('old', { dv: chain.attr.device_id });
    const claim = await h.call('/referral/atribusi', 'POST', { ticket: chain.ticket }, {
      Authorization: `Bearer ${jwt}`, 'x-xy-device': rawDevice(4),
    });
    assert.equal(claim.status, 409);
    assert.match(claim.json.error, /akun baru/i);
    assert.equal((await h.db.prepare('SELECT status FROM referral_attribution WHERE id=?').bind(chain.attr.id).first()).status, 'terpasang');
    assert.equal((await h.db.prepare('SELECT COUNT(*) n FROM referral').first()).n, 0);
  } finally { await h.mf.dispose(); }
});

test('kode tanpa tiket dan perangkat pengundang tidak bisa memperoleh reward', async () => {
  const h = await harness();
  try {
    await h.db.prepare(
      "INSERT INTO users(id,nama,email,password,email_verified,kode_referral) VALUES('inv','Pengundang','inv2@ref.invalid','x',1,'SAFE123')"
    ).run();
    await h.db.prepare(
      "INSERT INTO users(id,nama,email,password,email_verified) VALUES('shortcut','Jalan Pintas','shortcut@ref.invalid','x',1)"
    ).run();
    const paused = await h.call('/referral/klik', 'POST', { kode: 'SAFE123' });
    assert.equal(paused.status, 503);
    await h.db.prepare("UPDATE setelan SET nilai='1' WHERE kunci='referral_install_aktif'").run();
    const shortcutJwt = await h.token('shortcut');
    const shortcut = await h.call('/referral/pakai', 'POST', { kode: 'SAFE123' }, {
      Authorization: `Bearer ${shortcutJwt}`, 'x-xy-device': rawDevice(2),
    });
    assert.equal(shortcut.status, 400);

    const chain = await buatRantaiTerpasang(h, 'SAFE123', rawDevice(3));
    await h.db.prepare(
      "INSERT INTO security_device_users(device_id,user_id,signup) VALUES(?,'inv',0)"
    ).bind(chain.attr.device_id).run();
    await h.db.prepare(
      "INSERT INTO users(id,nama,email,password,email_verified,registration_device) VALUES('fraud','Akun Kedua','fraud@ref.invalid','x',1,?)"
    ).bind(chain.attr.device_id).run();
    const fraudJwt = await h.token('fraud', { dv: chain.attr.device_id });
    const fraud = await h.call('/referral/atribusi', 'POST', { ticket: chain.ticket }, {
      Authorization: `Bearer ${fraudJwt}`, 'x-xy-device': rawDevice(3),
    });
    assert.equal(fraud.status, 403);
    assert.equal((await h.db.prepare("SELECT status FROM referral_attribution WHERE id=?").bind(chain.attr.id).first()).status, 'ditolak');
    assert.equal((await h.db.prepare('SELECT COUNT(*) n FROM referral').first()).n, 0);
    assert.equal((await h.db.prepare("SELECT SUM(saldo) n FROM users").first()).n, 0);
  } finally { await h.mf.dispose(); }
});
