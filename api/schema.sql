-- ============================================================
-- XyCloud — skema Cloudflare D1
-- Inisialisasi database LOKAL saja: wrangler d1 execute xycloud --local --file=./schema.sql
-- Produksi: gunakan wrangler d1 migrations apply xycloud --remote (tanpa DROP tabel).
--
-- PERINGATAN: berkas ini MEMBUANG SEMUA DATA lalu membuat ulang dari nol.
-- Ini berkas inisialisasi/riset, bukan migrasi. Jangan jalankan di atas
-- basis data produksi yang masih dipakai tanpa cadangan dulu.
--
-- Definisi tabel di bawah ini disinkronkan otomatis dari basis data
-- produksi per 2026-09-07 (rilis v2.2.0). Kalau ada tabel baru, taruh
-- DDL-nya di sini juga supaya repo bisa mereproduksi skema yang sama.
-- ============================================================

-- ------------------------------------------------------------
--  users
-- ------------------------------------------------------------
DROP TABLE IF EXISTS users;
CREATE TABLE users (
  id        TEXT PRIMARY KEY,
  nama      TEXT NOT NULL,
  email     TEXT NOT NULL UNIQUE,
  password  TEXT NOT NULL,          -- simpan hash (SHA-256 + salt)
  phone     TEXT,
  saldo     INTEGER NOT NULL DEFAULT 0,
  tier      TEXT NOT NULL DEFAULT 'basic',
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
, email_verified INTEGER NOT NULL DEFAULT 0, foto TEXT, notif_forum INTEGER NOT NULL DEFAULT 1, badge TEXT, diblokir INTEGER NOT NULL DEFAULT 0, alasan_blokir TEXT, peringatan INTEGER NOT NULL DEFAULT 0, total_belanja INTEGER NOT NULL DEFAULT 0, kode_referral TEXT, diundang_oleh TEXT, bio TEXT, banner TEXT, bisu_notif TEXT, notif_dm INTEGER NOT NULL DEFAULT 1, username TEXT, bingkai TEXT, banner_media TEXT, nama_diubah_pada TEXT, username_diubah_pada TEXT, pin_transfer TEXT, slogan TEXT, bio_link TEXT, gaya_nama TEXT);

-- ------------------------------------------------------------
--  pc_plans
-- ------------------------------------------------------------
DROP TABLE IF EXISTS pc_plans;
CREATE TABLE pc_plans (
  id             TEXT PRIMARY KEY,
  nama           TEXT NOT NULL,
  gpu            TEXT NOT NULL,
  cpu            TEXT NOT NULL,
  ram_gb         INTEGER NOT NULL,
  storage_gb     INTEGER NOT NULL,
  harga_per_jam  INTEGER NOT NULL,
  harga_per_hari INTEGER NOT NULL,
  region         TEXT NOT NULL,
  tag            TEXT,
  total_unit     INTEGER NOT NULL,
  unit_tersedia  INTEGER NOT NULL,
  gambar         TEXT
, rating REAL NOT NULL DEFAULT 5, jumlah_ulasan INTEGER NOT NULL DEFAULT 0);

-- ------------------------------------------------------------
--  akun_produk
-- ------------------------------------------------------------
DROP TABLE IF EXISTS akun_produk;
CREATE TABLE akun_produk (
  id          TEXT PRIMARY KEY,
  nama        TEXT NOT NULL,
  kategori    TEXT NOT NULL,
  deskripsi   TEXT,
  harga       INTEGER NOT NULL,
  harga_coret INTEGER DEFAULT 0,
  stok        INTEGER NOT NULL DEFAULT 0,
  rating      REAL DEFAULT 5,
  terjual     INTEGER DEFAULT 0,
  gambar      TEXT,
  fitur       TEXT,               -- JSON array
  garansi     TEXT DEFAULT '7 hari'
, detail TEXT, jumlah_ulasan INTEGER NOT NULL DEFAULT 0);

-- ------------------------------------------------------------
--  akun_stok
-- ------------------------------------------------------------
DROP TABLE IF EXISTS akun_stok;
CREATE TABLE akun_stok (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  produk_id  TEXT NOT NULL,
  email      TEXT NOT NULL,
  password   TEXT NOT NULL,
  terpakai   INTEGER NOT NULL DEFAULT 0,
  user_id    TEXT
);

-- ------------------------------------------------------------
--  orders
-- ------------------------------------------------------------
DROP TABLE IF EXISTS orders;
CREATE TABLE orders (
  id         TEXT PRIMARY KEY,
  kode       TEXT NOT NULL,
  user_id    TEXT NOT NULL,
  plan_id    TEXT NOT NULL,
  plan_nama  TEXT NOT NULL,
  durasi_jam INTEGER NOT NULL,
  total      INTEGER NOT NULL,
  status     TEXT NOT NULL DEFAULT 'pending',
  progress   INTEGER NOT NULL DEFAULT 0,
  host       TEXT,
  username   TEXT,
  password   TEXT,
  dibuat     TEXT NOT NULL DEFAULT (datetime('now')),
  mulai      TEXT,
  berakhir   TEXT
, voucher TEXT, potongan INTEGER NOT NULL DEFAULT 0);

-- ------------------------------------------------------------
--  transaksi
-- ------------------------------------------------------------
DROP TABLE IF EXISTS transaksi;
CREATE TABLE transaksi (
  id      TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  judul   TEXT NOT NULL,
  tipe    TEXT NOT NULL,
  nominal INTEGER NOT NULL,
  status  TEXT NOT NULL DEFAULT 'sukses',
  waktu   TEXT NOT NULL DEFAULT (datetime('now'))
);

-- ------------------------------------------------------------
--  transfer (Batch I: buku besar transfer saldo antar pengguna)
-- ------------------------------------------------------------
DROP TABLE IF EXISTS transfer;
CREATE TABLE transfer (
  id      TEXT PRIMARY KEY,
  dari_id TEXT NOT NULL,
  ke_id   TEXT NOT NULL,
  nominal INTEGER NOT NULL,
  catatan TEXT,
  dibuat  TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_transfer_dari ON transfer(dari_id, dibuat);
CREATE INDEX IF NOT EXISTS idx_transfer_ke   ON transfer(ke_id, dibuat);

-- ------------------------------------------------------------
--  cs_messages
-- ------------------------------------------------------------
DROP TABLE IF EXISTS cs_messages;
CREATE TABLE cs_messages (
  id      TEXT PRIMARY KEY,
  room    TEXT NOT NULL,
  user_id TEXT NOT NULL,
  dari    TEXT NOT NULL,          -- user | cs | system
  teks    TEXT NOT NULL,
  waktu   TEXT NOT NULL DEFAULT (datetime('now'))
, gambar TEXT, audio TEXT, durasi REAL,
  tipe TEXT NOT NULL DEFAULT 'teks',
  reply_to TEXT, reply_teks TEXT, reply_tipe TEXT NOT NULL DEFAULT 'teks',
  dibaca INTEGER NOT NULL DEFAULT 0, dihapus INTEGER NOT NULL DEFAULT 0);

-- ------------------------------------------------------------
--  banners
-- ------------------------------------------------------------
DROP TABLE IF EXISTS banners;
CREATE TABLE banners (
  id        TEXT PRIMARY KEY,
  judul     TEXT NOT NULL,
  subjudul  TEXT,
  label     TEXT,              -- teks kecil di atas judul
  cta       TEXT,              -- teks tombol
  aksi      TEXT,              -- sewa | akun | topup | url
  target    TEXT,              -- id produk / url
  warna1    TEXT DEFAULT '#2F5BFF',
  warna2    TEXT DEFAULT '#6A4BFF',
  ikon      TEXT DEFAULT 'bolt',
  urutan    INTEGER DEFAULT 0,
  aktif     INTEGER DEFAULT 1
, gambar TEXT);

-- ------------------------------------------------------------
--  otp
-- ------------------------------------------------------------
DROP TABLE IF EXISTS otp;
CREATE TABLE otp (id TEXT PRIMARY KEY, email TEXT NOT NULL, kode TEXT NOT NULL, tipe TEXT NOT NULL, kadaluarsa TEXT NOT NULL, dipakai INTEGER NOT NULL DEFAULT 0, dibuat TEXT NOT NULL DEFAULT (datetime('now')));

-- ------------------------------------------------------------
--  admin_kunci
-- ------------------------------------------------------------
DROP TABLE IF EXISTS admin_kunci;
CREATE TABLE admin_kunci (id TEXT PRIMARY KEY, nama TEXT NOT NULL, kunci TEXT NOT NULL UNIQUE, peran TEXT NOT NULL DEFAULT 'cs', aktif INTEGER NOT NULL DEFAULT 1, terakhir TEXT, dibuat TEXT NOT NULL DEFAULT (datetime('now')));

-- ------------------------------------------------------------
--  agen
-- ------------------------------------------------------------
DROP TABLE IF EXISTS agen;
CREATE TABLE agen (id TEXT PRIMARY KEY, nama TEXT NOT NULL, kode TEXT NOT NULL UNIQUE, plan_id TEXT, host TEXT, spec TEXT, status TEXT NOT NULL DEFAULT 'offline', sesi_aktif TEXT, versi TEXT, terakhir TEXT, dibuat TEXT NOT NULL DEFAULT (datetime('now')));

-- ------------------------------------------------------------
--  batas
-- ------------------------------------------------------------
DROP TABLE IF EXISTS batas;
CREATE TABLE batas (kunci TEXT PRIMARY KEY, jumlah INTEGER NOT NULL DEFAULT 0, sampai TEXT NOT NULL);

-- ------------------------------------------------------------
--  cadangan
-- ------------------------------------------------------------
DROP TABLE IF EXISTS cadangan;
CREATE TABLE cadangan (id TEXT PRIMARY KEY, ukuran INTEGER NOT NULL, jumlah_baris INTEGER NOT NULL, isi TEXT NOT NULL, dibuat TEXT NOT NULL DEFAULT (datetime('now')));

-- ------------------------------------------------------------
--  favorit
-- ------------------------------------------------------------
DROP TABLE IF EXISTS favorit;
CREATE TABLE favorit (user_id TEXT NOT NULL, produk_id TEXT NOT NULL, dibuat TEXT NOT NULL DEFAULT (datetime('now')), PRIMARY KEY (user_id, produk_id));

-- ------------------------------------------------------------
--  forum_balasan
-- ------------------------------------------------------------
DROP TABLE IF EXISTS forum_balasan;
CREATE TABLE forum_balasan (id TEXT PRIMARY KEY, post_id TEXT NOT NULL, user_id TEXT NOT NULL, nama TEXT NOT NULL, foto TEXT, isi TEXT NOT NULL, admin INTEGER NOT NULL DEFAULT 0, dibuat TEXT NOT NULL DEFAULT (datetime('now')), balas_ke TEXT, suka INTEGER NOT NULL DEFAULT 0);

-- ------------------------------------------------------------
--  forum_balasan_suka
-- ------------------------------------------------------------
DROP TABLE IF EXISTS forum_balasan_suka;
CREATE TABLE forum_balasan_suka (balasan_id TEXT NOT NULL, user_id TEXT NOT NULL, PRIMARY KEY (balasan_id, user_id));

-- ------------------------------------------------------------
--  forum_post
-- ------------------------------------------------------------
DROP TABLE IF EXISTS forum_post;
CREATE TABLE forum_post (id TEXT PRIMARY KEY, user_id TEXT NOT NULL, nama TEXT NOT NULL, foto TEXT, kategori TEXT NOT NULL DEFAULT 'Umum', judul TEXT NOT NULL, isi TEXT NOT NULL, gambar TEXT, suka INTEGER NOT NULL DEFAULT 0, balasan INTEGER NOT NULL DEFAULT 0, disematkan INTEGER NOT NULL DEFAULT 0, dibuat TEXT NOT NULL DEFAULT (datetime('now')), diubah TEXT, sensitif INTEGER NOT NULL DEFAULT 0);

-- ------------------------------------------------------------
--  forum_suka
-- ------------------------------------------------------------
DROP TABLE IF EXISTS forum_suka;
CREATE TABLE forum_suka (post_id TEXT NOT NULL, user_id TEXT NOT NULL, PRIMARY KEY (post_id, user_id));

-- ------------------------------------------------------------
--  galat
-- ------------------------------------------------------------
DROP TABLE IF EXISTS galat;
CREATE TABLE galat (id TEXT PRIMARY KEY, user_id TEXT, versi TEXT, perangkat TEXT, android TEXT, pesan TEXT NOT NULL, jejak TEXT, layar TEXT, jumlah INTEGER NOT NULL DEFAULT 1, status TEXT NOT NULL DEFAULT 'baru', dibuat TEXT NOT NULL DEFAULT (datetime('now')), terakhir TEXT);

-- ------------------------------------------------------------
--  kunjungan
-- ------------------------------------------------------------
DROP TABLE IF EXISTS kunjungan;
CREATE TABLE kunjungan (id TEXT PRIMARY KEY, jenis TEXT NOT NULL, halaman TEXT, referer TEXT, negara TEXT, perangkat TEXT, waktu TEXT NOT NULL DEFAULT (datetime('now')));

-- ------------------------------------------------------------
--  laporan
-- ------------------------------------------------------------
DROP TABLE IF EXISTS laporan;
CREATE TABLE laporan (id TEXT PRIMARY KEY, jenis TEXT NOT NULL, ref_id TEXT NOT NULL, url TEXT, pelapor TEXT NOT NULL, alasan TEXT, status TEXT NOT NULL DEFAULT 'baru', dibuat TEXT NOT NULL DEFAULT (datetime('now')));

-- ------------------------------------------------------------
--  log_admin
-- ------------------------------------------------------------
DROP TABLE IF EXISTS log_admin;
CREATE TABLE log_admin (id TEXT PRIMARY KEY, admin TEXT NOT NULL, peran TEXT, aksi TEXT NOT NULL, target TEXT, waktu TEXT NOT NULL DEFAULT (datetime('now')));

-- ------------------------------------------------------------
--  log_sistem
-- ------------------------------------------------------------
DROP TABLE IF EXISTS log_sistem;
CREATE TABLE log_sistem (id TEXT PRIMARY KEY, jenis TEXT NOT NULL, pesan TEXT, waktu TEXT NOT NULL DEFAULT (datetime('now')));

-- ------------------------------------------------------------
--  notifikasi
-- ------------------------------------------------------------
DROP TABLE IF EXISTS notifikasi;
CREATE TABLE notifikasi (id TEXT PRIMARY KEY, user_id TEXT NOT NULL, jenis TEXT NOT NULL, judul TEXT NOT NULL, pesan TEXT, aktor TEXT, ref_jenis TEXT, ref_id TEXT, dibaca INTEGER NOT NULL DEFAULT 0, dibuat TEXT NOT NULL DEFAULT (datetime('now')));

-- ------------------------------------------------------------
--  perintah
-- ------------------------------------------------------------
DROP TABLE IF EXISTS perintah;
CREATE TABLE perintah (id TEXT PRIMARY KEY, agen_id TEXT NOT NULL, jenis TEXT NOT NULL, muatan TEXT, status TEXT NOT NULL DEFAULT 'antre', hasil TEXT, dibuat TEXT NOT NULL DEFAULT (datetime('now')), diproses TEXT);

-- ------------------------------------------------------------
--  referral
-- ------------------------------------------------------------
DROP TABLE IF EXISTS referral;
CREATE TABLE referral (id TEXT PRIMARY KEY, pengundang TEXT NOT NULL, diundang TEXT NOT NULL, bonus_pengundang INTEGER NOT NULL DEFAULT 0, bonus_diundang INTEGER NOT NULL DEFAULT 0, status TEXT NOT NULL DEFAULT 'menunggu', dibuat TEXT NOT NULL DEFAULT (datetime('now')), selesai TEXT);

-- ------------------------------------------------------------
--  rilis
-- ------------------------------------------------------------
DROP TABLE IF EXISTS rilis;
CREATE TABLE rilis (id INTEGER PRIMARY KEY CHECK (id = 1), versi TEXT NOT NULL, tanggal TEXT, catatan TEXT, berkas TEXT NOT NULL, diperbarui TEXT NOT NULL DEFAULT (datetime('now')), gambar TEXT);

-- ------------------------------------------------------------
--  sesi
-- ------------------------------------------------------------
DROP TABLE IF EXISTS sesi;
CREATE TABLE sesi (id TEXT PRIMARY KEY, order_id TEXT, user_id TEXT NOT NULL, agen_id TEXT, status TEXT NOT NULL DEFAULT 'menyiapkan', pin TEXT, host TEXT, catatan TEXT, durasi_menit INTEGER NOT NULL DEFAULT 60, mulai TEXT, berakhir TEXT, dibuat TEXT NOT NULL DEFAULT (datetime('now')));

-- ------------------------------------------------------------
--  setelan
-- ------------------------------------------------------------
DROP TABLE IF EXISTS setelan;
CREATE TABLE setelan (kunci TEXT PRIMARY KEY, nilai TEXT, diperbarui TEXT NOT NULL DEFAULT (datetime('now')));

-- ------------------------------------------------------------
--  topup
-- ------------------------------------------------------------
DROP TABLE IF EXISTS topup;
CREATE TABLE topup (id TEXT PRIMARY KEY, user_id TEXT NOT NULL, nominal INTEGER NOT NULL, kode_unik INTEGER NOT NULL DEFAULT 0, total INTEGER NOT NULL, metode TEXT NOT NULL, bukti TEXT, status TEXT NOT NULL DEFAULT 'menunggu', catatan TEXT, dibuat TEXT NOT NULL DEFAULT (datetime('now')), diproses TEXT);

-- ------------------------------------------------------------
--  ulasan
-- ------------------------------------------------------------
DROP TABLE IF EXISTS ulasan;
CREATE TABLE ulasan (id TEXT PRIMARY KEY, produk_id TEXT NOT NULL, user_id TEXT NOT NULL, nama TEXT NOT NULL, rating INTEGER NOT NULL, komentar TEXT, gambar TEXT, balasan TEXT, waktu TEXT NOT NULL DEFAULT (datetime('now')), sensitif INTEGER NOT NULL DEFAULT 0);

-- ------------------------------------------------------------
--  ulasan_pc
-- ------------------------------------------------------------
DROP TABLE IF EXISTS ulasan_pc;
CREATE TABLE ulasan_pc (id TEXT PRIMARY KEY, plan_id TEXT NOT NULL, order_id TEXT, user_id TEXT NOT NULL, nama TEXT NOT NULL, rating INTEGER NOT NULL, komentar TEXT, balasan TEXT, waktu TEXT NOT NULL DEFAULT (datetime('now')));

-- ------------------------------------------------------------
--  voucher
-- ------------------------------------------------------------
DROP TABLE IF EXISTS voucher;
CREATE TABLE voucher (kode TEXT PRIMARY KEY, jenis TEXT NOT NULL DEFAULT 'persen', nilai INTEGER NOT NULL, min_belanja INTEGER NOT NULL DEFAULT 0, maks_potongan INTEGER NOT NULL DEFAULT 0, untuk TEXT NOT NULL DEFAULT 'semua', kuota INTEGER NOT NULL DEFAULT 0, terpakai INTEGER NOT NULL DEFAULT 0, berlaku_sampai TEXT, aktif INTEGER NOT NULL DEFAULT 1, keterangan TEXT, dibuat TEXT NOT NULL DEFAULT (datetime('now')));

-- ------------------------------------------------------------
--  voucher_pakai
-- ------------------------------------------------------------
DROP TABLE IF EXISTS voucher_pakai;
CREATE TABLE voucher_pakai (id TEXT PRIMARY KEY, kode TEXT NOT NULL, user_id TEXT NOT NULL, ref_id TEXT, potongan INTEGER NOT NULL DEFAULT 0, waktu TEXT NOT NULL DEFAULT (datetime('now')));

-- ------------------------- INDEX -------------------------
DROP INDEX IF EXISTS idx_cs_room;
CREATE INDEX idx_cs_room ON cs_messages(room);

DROP INDEX IF EXISTS idx_forum_balasan;
CREATE INDEX idx_forum_balasan ON forum_balasan (post_id, dibuat);

DROP INDEX IF EXISTS idx_forum_waktu;
CREATE INDEX idx_forum_waktu ON forum_post (disematkan DESC, dibuat DESC);

DROP INDEX IF EXISTS idx_galat;
CREATE INDEX idx_galat ON galat (status, terakhir);

DROP INDEX IF EXISTS idx_kunjungan;
CREATE INDEX idx_kunjungan ON kunjungan (waktu);

DROP INDEX IF EXISTS idx_log_admin;
CREATE INDEX idx_log_admin ON log_admin (waktu);

DROP INDEX IF EXISTS idx_notif_user;
CREATE INDEX idx_notif_user ON notifikasi (user_id, dibaca, dibuat);

DROP INDEX IF EXISTS idx_orders_user;
CREATE INDEX idx_orders_user ON orders(user_id);

DROP INDEX IF EXISTS idx_otp_email;
CREATE INDEX idx_otp_email ON otp (email, tipe);

DROP INDEX IF EXISTS idx_perintah_agen;
CREATE INDEX idx_perintah_agen ON perintah (agen_id, status);

DROP INDEX IF EXISTS idx_referral;
CREATE INDEX idx_referral ON referral (pengundang, status);

DROP INDEX IF EXISTS idx_sesi_user;
CREATE INDEX idx_sesi_user ON sesi (user_id, status);

DROP INDEX IF EXISTS idx_topup_user;
CREATE INDEX idx_topup_user ON topup (user_id, status);

DROP INDEX IF EXISTS idx_trx_user;
CREATE INDEX idx_trx_user ON transaksi(user_id);

DROP INDEX IF EXISTS idx_ulasan_pc;
CREATE INDEX idx_ulasan_pc ON ulasan_pc (plan_id);

DROP INDEX IF EXISTS idx_ulasan_produk;
CREATE INDEX idx_ulasan_produk ON ulasan (produk_id);

DROP INDEX IF EXISTS idx_voucher_pakai;
CREATE INDEX idx_voucher_pakai ON voucher_pakai (kode, user_id);

-- Tidak ada data contoh yang otomatis dimasukkan.

-- Tambahan skema v2.4.0 (inisialisasi database baru)
-- Migrasi non-destruktif v2.4.0: tidak menghapus tabel/data pengguna.
ALTER TABLE forum_balasan ADD COLUMN stiker TEXT;
CREATE TABLE IF NOT EXISTS promo_overlay (
 id TEXT PRIMARY KEY, nama TEXT NOT NULL DEFAULT 'Promo', jenis TEXT NOT NULL DEFAULT 'floating',
 gambar TEXT NOT NULL, aksi TEXT NOT NULL DEFAULT 'url', target TEXT NOT NULL DEFAULT '',
 posisi TEXT NOT NULL DEFAULT 'kanan', platform TEXT NOT NULL DEFAULT 'semua',
 aktif INTEGER NOT NULL DEFAULT 1, urutan INTEGER NOT NULL DEFAULT 0, revisi INTEGER NOT NULL DEFAULT 1,
 konten TEXT NOT NULL DEFAULT '',
 dibuat TEXT NOT NULL DEFAULT (datetime('now')), diubah TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_promo_aktif ON promo_overlay(aktif,urutan);
CREATE INDEX IF NOT EXISTS idx_balasan_induk ON forum_balasan(post_id,balas_ke,dibuat);
CREATE TRIGGER IF NOT EXISTS sinkron_identitas_pengguna
AFTER UPDATE OF nama,foto ON users BEGIN
 UPDATE forum_post SET nama=NEW.nama,foto=NEW.foto WHERE user_id=NEW.id;
 UPDATE forum_balasan SET nama=NEW.nama,foto=NEW.foto WHERE user_id=NEW.id;
 UPDATE ulasan SET nama=NEW.nama WHERE user_id=NEW.id;
 UPDATE ulasan_pc SET nama=NEW.nama WHERE user_id=NEW.id;
END;
UPDATE forum_post SET nama=(SELECT nama FROM users WHERE id=forum_post.user_id), foto=(SELECT foto FROM users WHERE id=forum_post.user_id) WHERE user_id IN (SELECT id FROM users);
UPDATE forum_balasan SET nama=(SELECT nama FROM users WHERE id=forum_balasan.user_id), foto=(SELECT foto FROM users WHERE id=forum_balasan.user_id) WHERE user_id IN (SELECT id FROM users);
UPDATE ulasan SET nama=(SELECT nama FROM users WHERE id=ulasan.user_id) WHERE user_id IN (SELECT id FROM users);
UPDATE ulasan_pc SET nama=(SELECT nama FROM users WHERE id=ulasan_pc.user_id) WHERE user_id IN (SELECT id FROM users);

-- Migration v2.5.0 for new local databases
-- Additive upgrade. No fabricated orders, hosts, or credentials.
ALTER TABLE orders ADD COLUMN request_id TEXT;
ALTER TABLE orders ADD COLUMN metode TEXT NOT NULL DEFAULT 'legacy';
ALTER TABLE orders ADD COLUMN agen_id TEXT;
ALTER TABLE orders ADD COLUMN stok_kembali INTEGER NOT NULL DEFAULT 0;
ALTER TABLE orders ADD COLUMN dikembalikan INTEGER NOT NULL DEFAULT 0;
ALTER TABLE cs_messages ADD COLUMN client_id TEXT;
CREATE UNIQUE INDEX IF NOT EXISTS idx_order_request ON orders(user_id,request_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_cs_client ON cs_messages(room,client_id);
CREATE INDEX IF NOT EXISTS idx_cs_room_time ON cs_messages(room,waktu);
CREATE INDEX IF NOT EXISTS idx_sesi_order_status ON sesi(order_id,status);

-- Charge, stock and physical-host reservation are one SQLite transaction.
CREATE TRIGGER IF NOT EXISTS order_saldo_baru AFTER INSERT ON orders
WHEN NEW.metode='saldo' BEGIN
 SELECT RAISE(ABORT,'ORDER_INVALID') WHERE NEW.total<0 OR NEW.durasi_jam<1 OR NEW.durasi_jam>24;
 SELECT RAISE(ABORT,'SALDO_TIDAK_CUKUP') WHERE NOT EXISTS(SELECT 1 FROM users WHERE id=NEW.user_id AND saldo>=NEW.total);
 SELECT RAISE(ABORT,'UNIT_PENUH') WHERE NOT EXISTS(SELECT 1 FROM pc_plans WHERE id=NEW.plan_id AND unit_tersedia>0);
 SELECT RAISE(ABORT,'UNIT_PENUH') WHERE NOT EXISTS(SELECT 1 FROM agen WHERE id=NEW.agen_id AND (sesi_aktif IS NULL OR sesi_aktif=''));
 SELECT RAISE(ABORT,'VOUCHER_TIDAK_TERSEDIA') WHERE NEW.voucher IS NOT NULL AND (
   NOT EXISTS(SELECT 1 FROM voucher WHERE kode=NEW.voucher AND aktif=1 AND (kuota=0 OR terpakai<kuota))
   OR EXISTS(SELECT 1 FROM voucher_pakai WHERE kode=NEW.voucher AND user_id=NEW.user_id));
 UPDATE users SET saldo=saldo-NEW.total,total_belanja=total_belanja+NEW.total WHERE id=NEW.user_id;
 UPDATE pc_plans SET unit_tersedia=unit_tersedia-1 WHERE id=NEW.plan_id;
 UPDATE agen SET sesi_aktif='order:'||NEW.id WHERE id=NEW.agen_id;
 UPDATE voucher SET terpakai=terpakai+1 WHERE kode=NEW.voucher;
 INSERT INTO voucher_pakai(id,kode,user_id,ref_id,potongan)
   SELECT 'vp_'||NEW.id,NEW.voucher,NEW.user_id,NEW.id,NEW.potongan WHERE NEW.voucher IS NOT NULL;
END;

CREATE TRIGGER IF NOT EXISTS order_saldo_selesai AFTER UPDATE OF status ON orders
WHEN NEW.metode='saldo' AND NEW.status IN ('selesai','batal') AND OLD.status NOT IN ('selesai','batal') BEGIN
 UPDATE pc_plans SET unit_tersedia=MIN(total_unit,unit_tersedia+1) WHERE id=NEW.plan_id AND NEW.stok_kembali=0;
 UPDATE orders SET stok_kembali=1 WHERE id=NEW.id;
 -- Unstarted reservations can be released immediately; started machines stay locked until cleanup ACK.
 UPDATE agen SET sesi_aktif=NULL WHERE sesi_aktif='order:'||NEW.id;
 UPDATE users SET saldo=saldo+NEW.total,total_belanja=MAX(0,total_belanja-NEW.total)
   WHERE id=NEW.user_id AND NEW.status='batal' AND OLD.status IN ('dibayar','provisioning') AND NEW.dikembalikan=0;
 INSERT INTO transaksi(id,user_id,judul,tipe,nominal,status,waktu)
   SELECT 'refund_'||NEW.id,NEW.user_id,'Pengembalian sewa gagal/batal sebelum siap','refund',NEW.total,'sukses',datetime('now')
   WHERE NEW.status='batal' AND OLD.status IN ('dibayar','provisioning') AND NEW.dikembalikan=0;
 UPDATE voucher SET terpakai=MAX(0,terpakai-1) WHERE kode=NEW.voucher
   AND NEW.status='batal' AND OLD.status IN ('dibayar','provisioning') AND NEW.dikembalikan=0;
 DELETE FROM voucher_pakai WHERE ref_id=NEW.id AND NEW.status='batal' AND OLD.status IN ('dibayar','provisioning') AND NEW.dikembalikan=0;
 UPDATE orders SET dikembalikan=1 WHERE id=NEW.id AND NEW.status='batal' AND OLD.status IN ('dibayar','provisioning');
END;

CREATE TABLE IF NOT EXISTS media_hapus (url TEXT PRIMARY KEY, dibuat TEXT NOT NULL DEFAULT (datetime('now')), percobaan INTEGER NOT NULL DEFAULT 0);
-- Additive: existing accounts are not assigned a guessed device.
ALTER TABLE users ADD COLUMN registration_device TEXT;
ALTER TABLE users ADD COLUMN deleted_at TEXT;
ALTER TABLE users ADD COLUMN blocked_before_trash INTEGER NOT NULL DEFAULT 0;
ALTER TABLE users ADD COLUMN session_version INTEGER NOT NULL DEFAULT 0;
CREATE TABLE IF NOT EXISTS security_devices (
 id TEXT PRIMARY KEY, kind TEXT NOT NULL DEFAULT 'unknown', model TEXT NOT NULL DEFAULT '',
 registrations INTEGER NOT NULL DEFAULT 0, max_accounts INTEGER, blocked INTEGER NOT NULL DEFAULT 0,
 reason TEXT, created_at TEXT NOT NULL, last_seen TEXT NOT NULL, reset_at TEXT
);
CREATE TABLE IF NOT EXISTS security_device_users (
 device_id TEXT NOT NULL, user_id TEXT NOT NULL, signup INTEGER NOT NULL DEFAULT 0,
 created_at TEXT NOT NULL DEFAULT (datetime('now')), last_seen TEXT NOT NULL DEFAULT (datetime('now')),
 PRIMARY KEY(device_id,user_id)
);
CREATE TABLE IF NOT EXISTS security_events (
 id TEXT PRIMARY KEY, kind TEXT NOT NULL, subject TEXT, route TEXT, note TEXT, count INTEGER NOT NULL DEFAULT 1,
 created_at TEXT NOT NULL, last_seen TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_security_events_time ON security_events(last_seen);
CREATE INDEX IF NOT EXISTS idx_users_trash ON users(deleted_at);
CREATE TABLE IF NOT EXISTS oauth_states (
 id TEXT PRIMARY KEY, provider TEXT NOT NULL, device_id TEXT, expires_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS media_assets (
 id TEXT PRIMARY KEY, url TEXT NOT NULL UNIQUE, folder TEXT NOT NULL, format TEXT,
 width INTEGER, height INTEGER, bytes INTEGER, animated INTEGER NOT NULL DEFAULT 0, created_at TEXT NOT NULL DEFAULT (datetime('now')),
 hash TEXT
);
CREATE TRIGGER IF NOT EXISTS register_device_quota AFTER INSERT ON users
WHEN NEW.registration_device IS NOT NULL BEGIN
 SELECT RAISE(ABORT,'DEVICE_UNKNOWN') WHERE NOT EXISTS(SELECT 1 FROM security_devices WHERE id=NEW.registration_device);
 SELECT RAISE(ABORT,'DEVICE_BLOCKED') WHERE EXISTS(SELECT 1 FROM security_devices WHERE id=NEW.registration_device AND blocked=1);
 SELECT RAISE(ABORT,'DEVICE_LIMIT') WHERE EXISTS(
  SELECT 1 FROM security_devices d WHERE d.id=NEW.registration_device AND d.registrations>=COALESCE(d.max_accounts,
    (SELECT CAST(nilai AS INTEGER) FROM setelan WHERE kunci='security_device_accounts'),2));
 UPDATE security_devices SET registrations=registrations+1,last_seen=datetime('now') WHERE id=NEW.registration_device;
 INSERT INTO security_device_users(device_id,user_id,signup) VALUES(NEW.registration_device,NEW.id,1);
END;

-- ---- 0007: sosial (follow, DM, bookmark, bisukan notifikasi) ----
CREATE TABLE IF NOT EXISTS follows (
  ikut_id   TEXT NOT NULL,
  target_id TEXT NOT NULL,
  waktu     TEXT NOT NULL DEFAULT (datetime('now')),
  PRIMARY KEY (ikut_id, target_id)
);
CREATE INDEX IF NOT EXISTS idx_follows_target ON follows(target_id);
CREATE TABLE IF NOT EXISTS dm (
  id      TEXT PRIMARY KEY,
  dari_id TEXT NOT NULL,
  ke_id   TEXT NOT NULL,
  teks    TEXT NOT NULL DEFAULT '',
  audio   TEXT,
  durasi  REAL,
  gambar  TEXT,
  tipe    TEXT NOT NULL DEFAULT 'teks',
  dibaca  INTEGER NOT NULL DEFAULT 0,
  waktu   TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_dm_dari ON dm(dari_id, waktu);
CREATE INDEX IF NOT EXISTS idx_dm_ke   ON dm(ke_id, waktu);
CREATE TABLE IF NOT EXISTS simpan_post (
  post_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  waktu   TEXT NOT NULL DEFAULT (datetime('now')),
  PRIMARY KEY (post_id, user_id)
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_users_username ON users(username) WHERE username IS NOT NULL;
