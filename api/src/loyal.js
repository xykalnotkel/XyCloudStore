/**
 * ============================================================
 *  XyCloudStore - Voucher, tier, dan cadangan basis data
 * ============================================================
 */

/** Manfaat nyata untuk tiap tingkat keanggotaan. */
export const TIER = {
  basic: { nama: 'Basic', diskon: 0, minBelanja: 0, warna: '#7C7391',
    manfaat: ['Akses semua paket dan produk', 'Chat admin tanpa batas'] },
  pro: { nama: 'Pro', diskon: 3, minBelanja: 300000, warna: '#8B5CF6',
    manfaat: ['Diskon 3 persen tiap transaksi', 'Antrean unit lebih dulu', 'Lencana Pro di komunitas'] },
  vip: { nama: 'VIP', diskon: 7, minBelanja: 1500000, warna: '#C08A2E',
    manfaat: ['Diskon 7 persen tiap transaksi', 'Prioritas tertinggi saat unit penuh',
              'Bantuan admin didahulukan', 'Lencana VIP di komunitas'] },
};

export function diskonTier(tier) {
  return TIER[(tier || 'basic').toLowerCase()]?.diskon ?? 0;
}

/** Naikkan tier otomatis mengikuti total belanja. */
export async function segarkanTier(env, userId) {
  try {
    const u = await env.DB.prepare('SELECT tier, total_belanja FROM users WHERE id = ?').bind(userId).first();
    if (!u) return null;

    const belanja = u.total_belanja || 0;
    const seharusnya = belanja >= TIER.vip.minBelanja ? 'vip' : belanja >= TIER.pro.minBelanja ? 'pro' : 'basic';
    const urutan = { basic: 0, pro: 1, vip: 2 };

    // tier hanya naik otomatis, tidak pernah turun sendiri
    if (urutan[seharusnya] > urutan[(u.tier || 'basic').toLowerCase()]) {
      await env.DB.prepare('UPDATE users SET tier = ? WHERE id = ?').bind(seharusnya, userId).run();
      return seharusnya;
    }
  } catch (_) { /* diabaikan */ }
  return null;
}

/**
 * Periksa voucher lalu hitung potongannya.
 * Mengembalikan { ok, potongan, alasan, voucher }.
 */
export async function cekVoucher(env, { kode, userId, jenis, total }) {
  const k = String(kode || '').trim().toUpperCase();
  if (!k) return { ok: false, alasan: 'Kode voucher kosong' };

  const v = await env.DB.prepare('SELECT * FROM voucher WHERE upper(kode) = ?').bind(k).first();
  if (!v) return { ok: false, alasan: 'Kode voucher tidak ditemukan' };
  if (!v.aktif) return { ok: false, alasan: 'Voucher sedang tidak aktif' };

  if (v.berlaku_sampai && new Date(v.berlaku_sampai) < new Date()) {
    return { ok: false, alasan: 'Voucher sudah kedaluwarsa' };
  }
  if (v.kuota > 0 && v.terpakai >= v.kuota) {
    return { ok: false, alasan: 'Kuota voucher sudah habis' };
  }
  if (v.untuk !== 'semua' && v.untuk !== jenis) {
    const label = { sewa: 'sewa PC', akun: 'pembelian akun', topup: 'isi saldo' }[v.untuk] || v.untuk;
    return { ok: false, alasan: `Voucher ini hanya untuk ${label}` };
  }
  if (total < (v.min_belanja || 0)) {
    return { ok: false, alasan: `Minimal transaksi Rp${Number(v.min_belanja).toLocaleString('id-ID')}` };
  }

  const sudah = await env.DB
    .prepare('SELECT 1 FROM voucher_pakai WHERE upper(kode) = ? AND user_id = ?')
    .bind(k, userId).first();
  if (sudah) return { ok: false, alasan: 'Kamu sudah pernah memakai voucher ini' };

  let potongan = v.jenis === 'nominal' ? v.nilai : Math.floor((total * v.nilai) / 100);
  if (v.maks_potongan > 0) potongan = Math.min(potongan, v.maks_potongan);
  potongan = Math.min(potongan, total);

  return { ok: true, potongan, voucher: v };
}

/** Catat pemakaian voucher setelah transaksi berhasil — atomic single-use + kuota guard. */
export async function pakaiVoucher(env, { kode, userId, refId, potongan }) {
  if (!kode) return { ok: true };
  const k = String(kode).toUpperCase();
  try {
    // cek sudah pernah pakai (prevent double)
    const already = await env.DB.prepare('SELECT 1 FROM voucher_pakai WHERE upper(kode)=? AND user_id=?').bind(k, userId).first();
    if (already) return { ok: false, alasan: 'Voucher sudah dipakai' };

    // klaim kuota atomik: hanya increment jika kuota masih tersedia
    const claim = await env.DB.prepare(
      'UPDATE voucher SET terpakai=terpakai+1 WHERE upper(kode)=? AND (kuota=0 OR terpakai < kuota) RETURNING kode'
    ).bind(k).first();

    if (!claim) {
      const v = await env.DB.prepare('SELECT kuota, terpakai FROM voucher WHERE upper(kode)=?').bind(k).first();
      if (!v) return { ok: false, alasan: 'Voucher tidak ditemukan' };
      if (v.kuota > 0 && v.terpakai >= v.kuota) return { ok: false, alasan: 'Kuota voucher habis' };
      return { ok: false, alasan: 'Gagal klaim voucher' };
    }

    // catat pemakaian — jika race insert duplikat, rollback terpakai
    try {
      await env.DB.prepare('INSERT INTO voucher_pakai (id,kode,user_id,ref_id,potongan) VALUES (?,?,?,?,?)')
        .bind('vp_' + crypto.randomUUID().replace(/-/g, '').slice(0, 12), k, userId, refId || null, potongan || 0).run();
    } catch (e) {
      // rollback increment karena insert gagal (duplikat)
      await env.DB.prepare('UPDATE voucher SET terpakai=MAX(0,terpakai-1) WHERE upper(kode)=?').bind(k).run();
      return { ok: false, alasan: 'Voucher sudah dipakai (race)' };
    }

    return { ok: true };
  } catch (e) {
    return { ok: false, alasan: String(e.message || e).slice(0, 120) };
  }
}

/** Versi strict yang melempar KontenError jika gagal — untuk dipakai di jalur akun/beli */
export async function pakaiVoucherStrict(env, { kode, userId, refId, potongan }) {
  const r = await pakaiVoucher(env, { kode, userId, refId, potongan });
  if (!r.ok) {
    const { KontenError } = await import('./engagement.js');
    throw new KontenError(r.alasan || 'Voucher tidak bisa dipakai', 409);
  }
  return r;
}

/**
 * Buat cadangan isi basis data dalam bentuk JSON terpadat.
 * Disimpan di tabel cadangan, tujuh salinan terakhir dipertahankan.
 */
export async function buatCadangan(env) {
  const tabel = ['users', 'pc_plans', 'akun_produk', 'akun_stok', 'orders', 'transaksi',
                 'topup', 'banners', 'forum_post', 'forum_balasan', 'ulasan', 'voucher', 'agen',
                 'hud_preset', 'hud_preset_suka'];

  const isi = {};
  let baris = 0;

  for (const t of tabel) {
    try {
      const { results } = await env.DB.prepare(`SELECT * FROM ${t} LIMIT 5000`).all();
      // password tidak ikut dicadangkan
      isi[t] = results.map((r) => {
        const salin = { ...r };
        delete salin.password;
        // Kode VA/QR dan checkout yang masih aktif tidak diperlukan untuk
        // pemulihan buku besar, jadi tidak ikut ke salinan cadangan.
        if (t === 'topup') {
          delete salin.payment_code;
          delete salin.payment_qr;
          delete salin.checkout_url;
        }
        return salin;
      });
      baris += results.length;
    } catch (_) {
      isi[t] = [];
    }
  }

  const teks = JSON.stringify({ dibuat: new Date().toISOString(), isi });
  const id = 'bk_' + new Date().toISOString().slice(0, 19).replace(/[:T-]/g, '');

  await env.DB.prepare('INSERT OR REPLACE INTO cadangan (id,ukuran,jumlah_baris,isi) VALUES (?,?,?,?)')
    .bind(id, teks.length, baris, teks).run();

  // sisakan tujuh cadangan terakhir saja
  await env.DB.prepare(
    'DELETE FROM cadangan WHERE id NOT IN (SELECT id FROM cadangan ORDER BY dibuat DESC LIMIT 7)'
  ).run();

  return { id, ukuran: teks.length, baris, tabel: tabel.length };
}
