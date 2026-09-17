import { hapusMediaChat } from './upload.js';
/**
 * ============================================================
 *  XyCloudStore - Pemeliharaan dan statistik sistem
 * ============================================================
 *  Berisi tiga hal:
 *    1. Mode pemeliharaan (menutup layanan sementara)
 *    2. Pemeliharaan otomatis (dijalankan penjadwal Cloudflare)
 *    3. Statistik lengkap untuk dashboard admin
 */

/** Baca satu setelan sistem. */
export async function setelan(env, kunci, bawaan = null) {
  try {
    const r = await env.DB.prepare('SELECT nilai FROM setelan WHERE kunci = ?').bind(kunci).first();
    return r ? r.nilai : bawaan;
  } catch (_) {
    return bawaan;
  }
}

/** Simpan satu setelan sistem. */
export async function simpanSetelan(env, kunci, nilai) {
  await env.DB.prepare(
    `INSERT INTO setelan (kunci,nilai,diperbarui) VALUES (?,?,?)
     ON CONFLICT(kunci) DO UPDATE SET nilai=excluded.nilai, diperbarui=excluded.diperbarui`
  ).bind(kunci, String(nilai), new Date().toISOString()).run();
}

export async function catatLog(env, jenis, pesan) {
  try {
    const id = 'lg_' + crypto.randomUUID().replace(/-/g, '').slice(0, 12);
    await env.DB.prepare('INSERT INTO log_sistem (id,jenis,pesan,waktu) VALUES (?,?,?,?)')
      .bind(id, jenis, pesan, new Date().toISOString()).run();
  } catch (_) { /* diabaikan */ }
}

/**
 * Pemeliharaan otomatis. Dipanggil penjadwal setiap jam dan bisa juga
 * dijalankan manual dari dashboard.
 */
export async function jalankanPemeliharaan(env) {
  const hasil = {};
  const sekarang = new Date().toISOString();

  try {
    // kode verifikasi yang sudah lewat masanya
    const otp = await env.DB.prepare('DELETE FROM otp WHERE kadaluarsa < ?').bind(sekarang).run();
    hasil.otpDibersihkan = otp.meta?.changes ?? 0;

    // penghitung pembatas laju yang sudah tidak berlaku
    const batas = await env.DB.prepare('DELETE FROM batas WHERE sampai < ?').bind(sekarang).run();
    hasil.batasDibersihkan = batas.meta?.changes ?? 0;

    // Retensi CS disetujui pemilik: tujuh hari, bukan reset tiap membuka layar.
    await env.DB.prepare("INSERT OR IGNORE INTO media_hapus(url) SELECT DISTINCT gambar FROM cs_messages WHERE gambar IS NOT NULL AND gambar!='' AND datetime(waktu)<datetime('now','-7 days')").run();
    const chat = await env.DB.prepare("DELETE FROM cs_messages WHERE datetime(waktu)<datetime('now','-7 days')").run();
    hasil.chatDihapus = chat.meta?.changes ?? 0;
    const expired=await env.DB.prepare('SELECT url FROM media_hapus ORDER BY percobaan,dibuat LIMIT 15').all();
    for(const m of expired.results){
      if(await hapusMediaChat(env,m.url))await env.DB.prepare('DELETE FROM media_hapus WHERE url=?').bind(m.url).run();
      else await env.DB.prepare('UPDATE media_hapus SET percobaan=percobaan+1 WHERE url=?').bind(m.url).run();
    }
    hasil.sesiDitutup = 0; // lifecycle sesi dikelola sewa.js dan ACK agen

    // unit yang tidak melapor lebih dari 5 menit ditandai mati
    const mati = new Date(Date.now() - 300000).toISOString();
    const agen = await env.DB.prepare(
      "UPDATE agen SET status='offline' WHERE status != 'offline' AND (terakhir IS NULL OR terakhir < ?)"
    ).bind(mati).run();
    hasil.unitOffline = agen.meta?.changes ?? 0;

    // permintaan top up manual yang menggantung lebih dari 24 jam
    const tpAmbang = new Date(Date.now() - 24 * 3600 * 1000).toISOString().replace('T', ' ').slice(0, 19);
    const tp = await env.DB.prepare(
      "UPDATE topup SET status='ditolak', catatan='Kedaluwarsa otomatis, tidak ada pembayaran masuk' WHERE status='menunggu' AND dibuat < ?"
    ).bind(tpAmbang).run();
    hasil.topupKedaluwarsa = tp.meta?.changes ?? 0;

    await env.DB.prepare("DELETE FROM security_events WHERE datetime(last_seen)<datetime('now','-30 days')").run();
    await env.DB.prepare("DELETE FROM oauth_states WHERE expires_at<?").bind(sekarang).run();
    await env.DB.prepare("DELETE FROM oauth_handoffs WHERE expires_at<?").bind(sekarang).run();

    // catatan sistem lama
    const logLama = new Date(Date.now() - 30 * 24 * 3600 * 1000).toISOString();
    await env.DB.prepare('DELETE FROM log_sistem WHERE waktu < ?').bind(logLama).run();

    // ---- pengaman mode pemeliharaan ----
    // Kalau mode pemeliharaan masih menyala melewati batas waktunya, matikan
    // otomatis. Ini mencegah layanan terkunci diam-diam berjam-jam ketika
    // operator/agen AI error setelah menyalakannya (kasus 16:40-17:20 UTC).
    // Batas bawaan 720 menit (12 jam), bisa diubah lewat setelan
    // `pemeliharaan_maks_menit` (0 = tanpa batas).
    const modePemeliharaan = await setelan(env, 'mode_pemeliharaan', '0');
    if (modePemeliharaan === '1') {
      const kini = Date.now();
      const sampai = await setelan(env, 'mode_pemeliharaan_sampai', '');
      const maksMenit = Number(await setelan(env, 'pemeliharaan_maks_menit', '720')) || 0;
      const mulaiRaw = await setelan(env, 'mode_pemeliharaan_mulai', '');
      let lewat = false;
      if (sampai) {
        const t = Date.parse(sampai);
        lewat = Number.isFinite(t) && t <= kini;
      } else if (maksMenit > 0) {
        if (mulaiRaw) {
          const t = Date.parse(mulaiRaw);
          lewat = Number.isFinite(t) && kini - t >= maksMenit * 60000;
        } else {
          lewat = true; // menyala tanpa catatan mulai -> aman dimatikan
        }
      }
      if (lewat) {
        await simpanSetelan(env, 'mode_pemeliharaan', '0');
        await simpanSetelan(env, 'mode_pemeliharaan_sampai', '');
        hasil.pemeliharaanAutoMati = true;
        await catatLog(env, 'pemeliharaan', 'Mode pemeliharaan dimatikan otomatis karena lewat batas waktunya');
      } else {
        hasil.pemeliharaanMenyalakan = true;
      }
    }

    await simpanSetelan(env, 'pemeliharaan_terakhir', sekarang);
    await catatLog(env, 'pemeliharaan', JSON.stringify(hasil));
  } catch (e) {
    hasil.galat = String(e);
    await catatLog(env, 'galat', `Pemeliharaan gagal: ${e}`);
  }

  return { waktu: sekarang, ...hasil };
}

/** Statistik lengkap untuk dashboard. */
export async function statistikLengkap(env) {
  const ambil = async (sql, ...bind) => {
    try {
      return await env.DB.prepare(sql).bind(...bind).first();
    } catch (_) {
      return null;
    }
  };
  const semua = async (sql, ...bind) => {
    try {
      const { results } = await env.DB.prepare(sql).bind(...bind).all();
      return results;
    } catch (_) {
      return [];
    }
  };

  const [pengguna, order, saldo, produk, sesiAktif, unit, forum, topup] = await Promise.all([
    ambil('SELECT COUNT(*) n, SUM(CASE WHEN created_at > date("now","-7 day") THEN 1 ELSE 0 END) baru FROM users'),
    ambil(`SELECT COUNT(*) n,
                  SUM(CASE WHEN status='aktif' THEN 1 ELSE 0 END) aktif,
                  SUM(CASE WHEN status IN ('dibayar','provisioning','aktif','selesai') THEN total ELSE 0 END) omzet
           FROM orders`),
    ambil('SELECT SUM(saldo) total FROM users'),
    ambil('SELECT COUNT(*) n, SUM(stok) stok, SUM(terjual) terjual FROM akun_produk'),
    ambil("SELECT COUNT(*) n FROM sesi WHERE status NOT IN ('selesai','gagal')"),
    ambil("SELECT COUNT(*) n, SUM(CASE WHEN terakhir > datetime('now','-90 second') THEN 1 ELSE 0 END) hidup FROM agen"),
    ambil('SELECT (SELECT COUNT(*) FROM forum_post) post, (SELECT COUNT(*) FROM forum_balasan) balasan'),
    ambil("SELECT SUM(CASE WHEN status='disetujui' THEN nominal ELSE 0 END) masuk, SUM(CASE WHEN status IN ('menunggu','diperiksa') THEN 1 ELSE 0 END) tertunda FROM topup"),
  ]);

  const harian = await semua(
    `SELECT substr(dibuat,1,10) d, COUNT(*) n, SUM(total) v
     FROM orders WHERE dibuat > date('now','-30 day') GROUP BY d ORDER BY d`
  );
  const penggunaHarian = await semua(
    `SELECT substr(created_at,1,10) d, COUNT(*) n
     FROM users WHERE created_at > date('now','-30 day') GROUP BY d ORDER BY d`
  );
  const produkTeratas = await semua(
    'SELECT nama, terjual, rating, jumlah_ulasan FROM akun_produk ORDER BY terjual DESC LIMIT 5'
  );
  const paketTeratas = await semua(
    `SELECT plan_nama nama, COUNT(*) n, SUM(total) v FROM orders
     GROUP BY plan_nama ORDER BY n DESC LIMIT 5`
  );
  const logTerakhir = await semua('SELECT * FROM log_sistem ORDER BY waktu DESC LIMIT 12');

  return {
    pengguna: { total: pengguna?.n ?? 0, baru7Hari: pengguna?.baru ?? 0 },
    order: { total: order?.n ?? 0, aktif: order?.aktif ?? 0, omzet: order?.omzet ?? 0 },
    saldoBeredar: saldo?.total ?? 0,
    produk: { total: produk?.n ?? 0, stok: produk?.stok ?? 0, terjual: produk?.terjual ?? 0 },
    sesiAktif: sesiAktif?.n ?? 0,
    unit: { total: unit?.n ?? 0, hidup: unit?.hidup ?? 0 },
    forum: { post: forum?.post ?? 0, balasan: forum?.balasan ?? 0 },
    topup: { masuk: topup?.masuk ?? 0, tertunda: topup?.tertunda ?? 0 },
    harian,
    penggunaHarian,
    produkTeratas,
    paketTeratas,
    log: logTerakhir,
    pemeliharaanTerakhir: await setelan(env, 'pemeliharaan_terakhir'),
    modePemeliharaan: (await setelan(env, 'mode_pemeliharaan', '0')) === '1',
    cakupanPemeliharaan: await setelan(env, 'pemeliharaan_cakupan', 'semua') || 'semua',
    pesanPemeliharaan: await setelan(env, 'pesan_pemeliharaan',
      'Kami sedang melakukan perawatan singkat. Silakan coba lagi beberapa menit lagi.'),
  };
}

/** Pemantau kesehatan: kirim email kalau ada yang bermasalah. */
export async function pantauKesehatan(env, kirimEmail) {
  const masalah = [];

  const mulai = Date.now();
  try {
    await env.DB.prepare('SELECT 1').first();
    const jeda = Date.now() - mulai;
    if (jeda > 3000) masalah.push(`Basis data lambat merespons, ${jeda} milidetik.`);
  } catch (e) {
    masalah.push(`Basis data tidak bisa dihubungi: ${e}`);
  }

  try {
    const menggantung = await env.DB.prepare(
      "SELECT COUNT(*) n FROM sesi WHERE status NOT IN ('selesai','gagal') AND dibuat < datetime('now','-6 hour')"
    ).first();
    if ((menggantung?.n ?? 0) > 0) masalah.push(`${menggantung.n} sesi main menggantung lebih dari enam jam.`);
  } catch (_) { /* diabaikan */ }

  if (!masalah.length) return { ok: true, sehat: true };

  // Kooldown: masalah yang sama tidak perlu dikirim tiap jam. Maksimal satu
  // email peringatan per enam jam, sisanya cukup dicatat ke log_sistem.
  let terkirim = false;
  if (env.EMAIL_ADMIN) {
    const terakhir = await setelan(env, 'peringatan_terakhir', '');
    const lewat = terakhir ? Date.now() - Date.parse(terakhir) : Infinity;
    if (!Number.isFinite(lewat) || lewat >= 6 * 3600 * 1000) {
      await kirimEmail(env, {
        to: env.EMAIL_ADMIN,
        template: 'peringatanSistem',
        data: { judul: 'Ada yang perlu dicek', rincian: masalah.join('<br>') },
      });
      await simpanSetelan(env, 'peringatan_terakhir', new Date().toISOString());
      terkirim = true;
    }
  }
  await catatLog(env, 'peringatan', (terkirim ? '' : '(ditekan, menunggu kooldown) ') + masalah.join(' | '));
  return { ok: true, sehat: false, masalah, terkirim };
}
