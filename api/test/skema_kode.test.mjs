/**
 * Penjaga kesesuaian skema ↔ kode.
 *
 * Latar belakang (audit 2026-09-13):
 *   `schema.sql` selalu diperbarui ke bentuk terbaru, sedangkan basis data
 *   produksi hanya menerima `migrations/*.sql` yang dijalankan manual.
 *   Migrasi 0004 (kolom `rilis.gambar`) pernah terlewat, sehingga
 *   `simpanRilis()` menulis kolom yang tidak ada dan SELURUH pendaftaran
 *   rilis APK gagal diam-diam selama lima hari tanpa satu pun uji yang merah.
 *
 * Uji ini menutup celah itu dari sisi kode: setiap kolom yang ditulis Worker
 * lewat INSERT/UPDATE harus benar-benar ada di skema hasil
 * `schema.sql` + seluruh `migrations/*.sql`. Kalau seseorang menambah kolom
 * di kode tetapi lupa menambahkannya ke skema DAN ke migrasi, uji ini merah.
 *
 * Untuk memeriksa basis data PRODUKSI (bukan skema lokal) jalankan:
 *     python3 tools/cek_skema_d1.py
 */
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync, readdirSync} from 'node:fs';
import {harness} from './harness.mjs';

/** Kumpulkan nama kolom setiap tabel dari D1 miniflare. */
async function skemaAktif(db){
  const tabel = await db.prepare(
    "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE '\\_%' ESCAPE '\\'"
  ).all();
  const hasil = {};
  for (const {name} of tabel.results || []) {
    const info = await db.prepare(`SELECT name AS kolom FROM pragma_table_info('${name}')`).all();
    hasil[name] = new Set((info.results || []).map((r) => r.kolom));
  }
  return hasil;
}

/** Baca seluruh sumber Worker jadi satu teks. */
function sumberWorker(){
  let teks = '';
  for (const f of readdirSync(new URL('../src/', import.meta.url).pathname)) {
    if (f.endsWith('.js')) teks += readFileSync(new URL('../src/' + f, import.meta.url), 'utf8') + '\n';
  }
  return teks;
}

/** Pecah daftar SET pada UPDATE, hormati tanda kurung (COALESCE(a,b) dsb). */
function pecahSet(teks){
  const out = []; let buf = ''; let depth = 0;
  for (const ch of teks) {
    if (ch === '(') depth++;
    else if (ch === ')') depth--;
    if (ch === ',' && depth === 0) { out.push(buf); buf = ''; } else buf += ch;
  }
  if (buf.trim()) out.push(buf);
  return out;
}

test('Skema: schema.sql + semua migrasi diterapkan harness tanpa galat', async () => {
  const {mf, db} = await harness();
  try {
    const s = await skemaAktif(db);
    // Tabel inti yang dipakai seluruh alur harus ada.
    for (const t of ['users','orders','sesi','agen','pc_plans','akun_produk','akun_stok','transaksi',
                     'topup','cs_messages','rilis','setelan','batas','perintah','voucher','voucher_pakai',
                     'forum_post','forum_balasan','ulasan','security_devices','log_admin','log_sistem','galat',
                     'hud_preset','hud_preset_suka']) {
      assert.ok(s[t], `tabel inti "${t}" hilang dari skema hasil migrasi`);
    }
    // Kolom yang dulu pernah terlewat di produksi — dijaga supaya tidak hilang lagi.
    assert.ok(s.rilis.has('gambar'), 'rilis.gambar hilang (migrasi 0004)');
    for (const c of ['tipe','audio','durasi','reply_to','reply_teks','reply_tipe']) {
      assert.ok(s.cs_messages.has(c), `cs_messages.${c} hilang (migrasi 0005)`);
    }
    // Trigger keuangan harus tetap terpasang; tanpa ini saldo tidak terpotong/terkembalikan.
    const trg = await db.prepare("SELECT name FROM sqlite_master WHERE type='trigger'").all();
    const nama = new Set((trg.results || []).map((r) => r.name));
    for (const t of ['order_saldo_baru','order_saldo_selesai','register_device_quota']) {
      assert.ok(nama.has(t), `trigger "${t}" hilang — potongan/refund saldo tidak akan jalan`);
    }
  } finally { await mf.dispose(); }
});

test('Skema: setiap kolom yang ditulis Worker ada di skema hasil migrasi', async () => {
  const {mf, db} = await harness();
  try {
    const s = await skemaAktif(db);
    const src = sumberWorker();
    const masalah = [];
    let diperiksa = 0;

    // INSERT INTO <tabel> (<kolom>, …)
    const polaInsert = /INSERT\s+(?:OR\s+\w+\s+)?INTO\s+(\w+)\s*\(([^)]*)\)/gi;
    for (const m of src.matchAll(polaInsert)) {
      const tabel = m[1];
      if (!s[tabel]) { masalah.push(`INSERT INTO ${tabel}: tabel tidak ada di skema`); continue; }
      for (let kolom of m[2].split(',')) {
        kolom = kolom.trim().replace(/^"|"$/g, '');
        if (!kolom || kolom === '?' || kolom.includes('$')) continue;
        diperiksa++;
        if (!s[tabel].has(kolom)) masalah.push(`INSERT INTO ${tabel}: kolom "${kolom}" tidak ada di skema`);
      }
    }

    // UPDATE <tabel> SET <kolom>=…
    const polaUpdate = /UPDATE\s+(\w+)\s+SET\s+([\s\S]+?)(?:\s+WHERE\b|`|'|"|$)/gi;
    for (const m of src.matchAll(polaUpdate)) {
      const tabel = m[1];
      if (!s[tabel]) continue; // nama tabel dinamis / bukan SQL sungguhan
      for (const bagian of pecahSet(m[2])) {
        const mm = /^\s*"?(\w+)"?\s*=/.exec(bagian);
        if (!mm) continue;
        diperiksa++;
        if (!s[tabel].has(mm[1])) masalah.push(`UPDATE ${tabel} SET ${mm[1]}: kolom tidak ada di skema`);
      }
    }

    assert.ok(diperiksa > 200, `hanya ${diperiksa} kolom terperiksa — pemindai SQL mungkin rusak`);
    assert.deepEqual([...new Set(masalah)].sort(), [],
      'Kode Worker menulis kolom yang tidak ada di skema. Tambahkan ke schema.sql DAN buat migrations/000X_*.sql.');
  } finally { await mf.dispose(); }
});

test('Skema: setiap berkas migrasi tercatat idempoten-toleran', async () => {
  const berkas = readdirSync(new URL('../migrations/', import.meta.url).pathname)
    .filter((f) => f.endsWith('.sql')).sort();
  assert.ok(berkas.length >= 5, `diharapkan minimal 5 berkas migrasi, ketemu ${berkas.length}`);
  // Penomoran harus rapat dan unik supaya tidak ada migrasi yang terlewat diam-diam.
  const nomor = berkas.map((f) => Number(f.slice(0, 4)));
  assert.deepEqual(nomor, nomor.slice().sort((a, b) => a - b), 'urutan berkas migrasi tidak rapi');
  assert.deepEqual([...new Set(nomor)], nomor, 'ada nomor migrasi ganda');
  for (let i = 0; i < nomor.length; i++) {
    assert.equal(nomor[i], i + 1, `nomor migrasi melompat: diharapkan ${i + 1}, ketemu ${nomor[i]} (${berkas[i]})`);
  }
});
