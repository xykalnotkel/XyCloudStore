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
, email_verified INTEGER NOT NULL DEFAULT 0, foto TEXT, notif_forum INTEGER NOT NULL DEFAULT 1, badge TEXT, diblokir INTEGER NOT NULL DEFAULT 0, alasan_blokir TEXT, peringatan INTEGER NOT NULL DEFAULT 0, total_belanja INTEGER NOT NULL DEFAULT 0, kode_referral TEXT, diundang_oleh TEXT, bio TEXT, banner TEXT, bisu_notif TEXT, notif_dm INTEGER NOT NULL DEFAULT 1, username TEXT, bingkai TEXT, banner_media TEXT, nama_diubah_pada TEXT, username_diubah_pada TEXT, pin_transfer TEXT, slogan TEXT, bio_link TEXT, gaya_nama TEXT, notif_live INTEGER NOT NULL DEFAULT 1 CHECK (notif_live IN (0,1)));

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
  detail     TEXT,
  terpakai   INTEGER NOT NULL DEFAULT 0,
  user_id    TEXT,
  dibuat     TEXT
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
CREATE TABLE admin_kunci (id TEXT PRIMARY KEY, nama TEXT NOT NULL, kunci TEXT NOT NULL UNIQUE, kunci_preview TEXT, peran TEXT NOT NULL DEFAULT 'cs', aktif INTEGER NOT NULL DEFAULT 1, terakhir TEXT, dibuat TEXT NOT NULL DEFAULT (datetime('now')));

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
--  referral + atribusi instalasi (Batch R)
-- ------------------------------------------------------------
DROP TABLE IF EXISTS referral;
DROP TABLE IF EXISTS referral_attribution;
CREATE TABLE referral_attribution (
  id TEXT PRIMARY KEY,
  pengundang TEXT NOT NULL,
  kode TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'diklik',
  clicked_at TEXT NOT NULL,
  expires_at TEXT NOT NULL,
  downloaded_at TEXT,
  download_variant TEXT,
  installed_at TEXT,
  package_installed_at TEXT,
  package_updated_at TEXT,
  device_id TEXT,
  claimed_by TEXT,
  claimed_at TEXT,
  click_ip_hash TEXT,
  click_ua_hash TEXT,
  claim_ip_hash TEXT,
  risiko TEXT,
  FOREIGN KEY (pengundang) REFERENCES users(id),
  FOREIGN KEY (claimed_by) REFERENCES users(id)
);
CREATE TABLE referral (
  id TEXT PRIMARY KEY,
  pengundang TEXT NOT NULL,
  diundang TEXT NOT NULL,
  bonus_pengundang INTEGER NOT NULL DEFAULT 0,
  bonus_diundang INTEGER NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'menunggu',
  dibuat TEXT NOT NULL DEFAULT (datetime('now')),
  selesai TEXT,
  attribution_id TEXT,
  kode TEXT,
  sumber TEXT NOT NULL DEFAULT 'legacy',
  device_id TEXT,
  risiko TEXT
);
CREATE INDEX idx_referral_attr_pengundang ON referral_attribution(pengundang, clicked_at DESC);
CREATE INDEX idx_referral_attr_status ON referral_attribution(status, expires_at);
CREATE UNIQUE INDEX idx_referral_attr_claimed_by ON referral_attribution(claimed_by) WHERE claimed_by IS NOT NULL;
CREATE UNIQUE INDEX idx_referral_diundang_unique ON referral(diundang);
CREATE UNIQUE INDEX idx_referral_attribution_unique ON referral(attribution_id) WHERE attribution_id IS NOT NULL;
CREATE TRIGGER referral_guard_before_insert BEFORE INSERT ON referral BEGIN
  SELECT RAISE(ABORT, 'REFERRAL_SELF') WHERE NEW.pengundang = NEW.diundang;
  SELECT RAISE(ABORT, 'REFERRAL_INVITEE_USED')
    WHERE EXISTS (SELECT 1 FROM referral WHERE diundang = NEW.diundang)
       OR EXISTS (SELECT 1 FROM users WHERE id = NEW.diundang AND diundang_oleh IS NOT NULL);
  SELECT RAISE(ABORT, 'REFERRAL_USER_MISSING')
    WHERE NOT EXISTS (SELECT 1 FROM users WHERE id = NEW.pengundang)
       OR NOT EXISTS (SELECT 1 FROM users WHERE id = NEW.diundang);
  SELECT RAISE(ABORT, 'REFERRAL_ATTRIBUTION_REQUIRED')
    WHERE NEW.status = 'selesai' AND NOT EXISTS (
      SELECT 1 FROM referral_attribution a
       WHERE a.id = NEW.attribution_id AND a.pengundang = NEW.pengundang
         AND a.kode = NEW.kode AND a.device_id = NEW.device_id
         AND a.downloaded_at IS NOT NULL AND a.installed_at IS NOT NULL
         AND a.package_installed_at IS NOT NULL AND a.claimed_by IS NULL AND datetime(a.expires_at) > datetime('now')
    );
END;
CREATE TRIGGER referral_reward_after_insert AFTER INSERT ON referral
WHEN NEW.status = 'selesai' BEGIN
  UPDATE users SET saldo = saldo + NEW.bonus_pengundang WHERE id = NEW.pengundang;
  UPDATE users SET saldo = saldo + NEW.bonus_diundang, diundang_oleh = NEW.pengundang
    WHERE id = NEW.diundang AND diundang_oleh IS NULL;
  INSERT OR IGNORE INTO transaksi (id,user_id,judul,tipe,nominal,status)
    VALUES ('ref_inviter_' || NEW.id, NEW.pengundang, 'Bonus undang teman', 'topup', NEW.bonus_pengundang, 'sukses');
  INSERT OR IGNORE INTO transaksi (id,user_id,judul,tipe,nominal,status)
    VALUES ('ref_invitee_' || NEW.id, NEW.diundang, 'Bonus dari teman', 'topup', NEW.bonus_diundang, 'sukses');
  UPDATE referral_attribution SET status='diklaim', claimed_by=NEW.diundang,
    claimed_at=COALESCE(NEW.selesai,datetime('now')), risiko=COALESCE(NEW.risiko,risiko)
    WHERE id=NEW.attribution_id AND claimed_by IS NULL;
END;

-- ------------------------------------------------------------
--  rilis
-- ------------------------------------------------------------
DROP TABLE IF EXISTS rilis;
CREATE TABLE rilis (id INTEGER PRIMARY KEY CHECK (id = 1), versi TEXT NOT NULL, tanggal TEXT, catatan TEXT, berkas TEXT NOT NULL, diperbarui TEXT NOT NULL DEFAULT (datetime('now')), gambar TEXT);

-- ------------------------------------------------------------
--  sesi
-- ------------------------------------------------------------
DROP TABLE IF EXISTS sesi;
CREATE TABLE sesi (id TEXT PRIMARY KEY, order_id TEXT, user_id TEXT NOT NULL, agen_id TEXT, status TEXT NOT NULL DEFAULT 'menyiapkan', pin TEXT, host TEXT, catatan TEXT, durasi_menit INTEGER NOT NULL DEFAULT 60, mulai TEXT, berakhir TEXT, dibuat TEXT NOT NULL DEFAULT (datetime('now')), client_state TEXT, client_last TEXT, client_route TEXT, client_latency_ms INTEGER, client_quality TEXT, client_disconnects INTEGER NOT NULL DEFAULT 0, client_reconnect_attempt INTEGER NOT NULL DEFAULT 0, client_reason TEXT);

-- ------------------------------------------------------------
--  setelan
-- ------------------------------------------------------------
DROP TABLE IF EXISTS setelan;
CREATE TABLE setelan (kunci TEXT PRIMARY KEY, nilai TEXT, diperbarui TEXT NOT NULL DEFAULT (datetime('now')));
INSERT INTO setelan(kunci,nilai) VALUES ('referral_install_aktif','0');

-- ------------------------------------------------------------
--  topup
-- ------------------------------------------------------------
DROP TABLE IF EXISTS topup;
CREATE TABLE topup (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  nominal INTEGER NOT NULL,
  kode_unik INTEGER NOT NULL DEFAULT 0,
  total INTEGER NOT NULL,
  metode TEXT NOT NULL,
  bukti TEXT,
  status TEXT NOT NULL DEFAULT 'menunggu',
  catatan TEXT,
  dibuat TEXT NOT NULL DEFAULT (datetime('now')),
  diproses TEXT,
  provider TEXT NOT NULL DEFAULT 'manual',
  provider_ref TEXT,
  provider_status TEXT,
  provider_method TEXT,
  provider_amount INTEGER,
  provider_fee INTEGER,
  provider_checked_at TEXT,
  provider_expires_at TEXT,
  checkout_url TEXT,
  payment_qr TEXT,
  payment_code TEXT,
  webhook_count INTEGER NOT NULL DEFAULT 0
);

DROP TABLE IF EXISTS topup_credit;
CREATE TABLE topup_credit (
  topup_id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  nominal INTEGER NOT NULL CHECK (nominal > 0),
  sumber TEXT NOT NULL,
  created_at TEXT NOT NULL,
  credited_at TEXT
);
CREATE INDEX idx_topup_credit_user ON topup_credit(user_id, credited_at);

DROP TABLE IF EXISTS payment_webhook_event;
CREATE TABLE payment_webhook_event (
  id TEXT PRIMARY KEY,
  provider TEXT NOT NULL,
  topup_id TEXT,
  event_status TEXT,
  amount INTEGER,
  verified INTEGER NOT NULL DEFAULT 0,
  outcome TEXT NOT NULL,
  source_hash TEXT,
  received_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX idx_payment_webhook_recent ON payment_webhook_event(provider, received_at);
CREATE INDEX idx_payment_webhook_topup ON payment_webhook_event(topup_id, received_at);
CREATE INDEX idx_topup_provider_status ON topup(provider, status, dibuat);
CREATE INDEX idx_topup_provider_ref ON topup(provider, provider_ref);

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
 id TEXT PRIMARY KEY, provider TEXT NOT NULL, device_id TEXT,
 handoff_challenge TEXT, expires_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS oauth_handoffs (
  id TEXT PRIMARY KEY,
  provider TEXT NOT NULL CHECK (provider IN ('google','facebook')),
  user_id TEXT NOT NULL,
  device_id TEXT NOT NULL,
  handoff_challenge TEXT NOT NULL CHECK (length(handoff_challenge) = 43),
  session_version INTEGER NOT NULL DEFAULT 0,
  exchange_count INTEGER NOT NULL DEFAULT 0 CHECK (exchange_count BETWEEN 0 AND 5),
  first_exchanged_at TEXT,
  created_at TEXT NOT NULL,
  expires_at TEXT NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_oauth_handoffs_expiry ON oauth_handoffs(expires_at);
CREATE TABLE IF NOT EXISTS social_identity (
 provider TEXT NOT NULL, provider_user_hash TEXT NOT NULL, user_id TEXT NOT NULL,
 email_at_link TEXT, created_at TEXT NOT NULL DEFAULT (datetime('now')),
 last_login TEXT NOT NULL DEFAULT (datetime('now')),
 PRIMARY KEY(provider,provider_user_hash), UNIQUE(provider,user_id)
);
CREATE INDEX IF NOT EXISTS idx_social_identity_user ON social_identity(user_id);
CREATE TABLE IF NOT EXISTS social_deletion_request (
 id TEXT PRIMARY KEY, provider TEXT NOT NULL, user_id TEXT,
 status TEXT NOT NULL DEFAULT 'menunggu', requested_at TEXT NOT NULL DEFAULT (datetime('now')),
 completed_at TEXT, note TEXT
);
CREATE INDEX IF NOT EXISTS idx_social_deletion_status ON social_deletion_request(status,requested_at);
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
CREATE INDEX IF NOT EXISTS idx_dm_percakapan ON dm(dari_id, ke_id, waktu DESC);
CREATE INDEX IF NOT EXISTS idx_dm_percakapan_balik ON dm(ke_id, dari_id, waktu DESC);
CREATE TABLE IF NOT EXISTS simpan_post (
  post_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  waktu   TEXT NOT NULL DEFAULT (datetime('now')),
  PRIMARY KEY (post_id, user_id)
);

-- ---- 0014: preset HUD streaming lokal + galeri komunitas ----
CREATE TABLE IF NOT EXISTS hud_preset (
  id        TEXT PRIMARY KEY,
  user_id   TEXT NOT NULL,
  nama      TEXT NOT NULL,
  deskripsi TEXT NOT NULL DEFAULT '',
  game      TEXT NOT NULL DEFAULT '',
  data      TEXT NOT NULL,
  publik    INTEGER NOT NULL DEFAULT 1,
  suka      INTEGER NOT NULL DEFAULT 0,
  dipakai   INTEGER NOT NULL DEFAULT 0,
  dibuat    TEXT NOT NULL DEFAULT (datetime('now')),
  diubah    TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_hud_preset_publik
  ON hud_preset(publik, suka DESC, dipakai DESC, dibuat DESC);
CREATE INDEX IF NOT EXISTS idx_hud_preset_user ON hud_preset(user_id, dibuat DESC);
CREATE TABLE IF NOT EXISTS hud_preset_suka (
  preset_id TEXT NOT NULL,
  user_id   TEXT NOT NULL,
  waktu     TEXT NOT NULL DEFAULT (datetime('now')),
  PRIMARY KEY (preset_id, user_id)
);
CREATE INDEX IF NOT EXISTS idx_hud_preset_suka_user ON hud_preset_suka(user_id);

CREATE UNIQUE INDEX IF NOT EXISTS idx_users_username ON users(username) WHERE username IS NOT NULL;

-- ---- 0019: moderasi AI privacy-preserving (tanpa konten mentah) ----
CREATE TABLE IF NOT EXISTS ai_moderation_cache (
  content_hash TEXT PRIMARY KEY,
  verdict TEXT NOT NULL CHECK (verdict IN ('allow','review','block')),
  kategori TEXT NOT NULL,
  severity INTEGER NOT NULL CHECK (severity BETWEEN 0 AND 4),
  confidence REAL NOT NULL CHECK (confidence BETWEEN 0 AND 1),
  reason_code TEXT NOT NULL,
  model TEXT NOT NULL,
  created_at TEXT NOT NULL,
  expires_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_ai_moderation_cache_expires ON ai_moderation_cache(expires_at);
CREATE TABLE IF NOT EXISTS ai_moderation_event (
  id TEXT PRIMARY KEY,
  user_id TEXT,
  konteks TEXT NOT NULL,
  content_hash TEXT NOT NULL,
  mode TEXT NOT NULL,
  sumber TEXT NOT NULL CHECK (sumber IN ('local','ai')),
  verdict TEXT NOT NULL CHECK (verdict IN ('allow','review','block','error')),
  kategori TEXT,
  severity INTEGER CHECK (severity IS NULL OR severity BETWEEN 0 AND 4),
  confidence REAL CHECK (confidence IS NULL OR (confidence BETWEEN 0 AND 1)),
  latency_ms INTEGER CHECK (latency_ms IS NULL OR latency_ms >= 0),
  cached INTEGER NOT NULL DEFAULT 0 CHECK (cached IN (0,1)),
  prompt_tokens INTEGER CHECK (prompt_tokens IS NULL OR prompt_tokens >= 0),
  completion_tokens INTEGER CHECK (completion_tokens IS NULL OR completion_tokens >= 0),
  error_code TEXT,
  model TEXT,
  waktu TEXT NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
);
CREATE INDEX IF NOT EXISTS idx_ai_moderation_event_waktu ON ai_moderation_event(waktu DESC);
CREATE INDEX IF NOT EXISTS idx_ai_moderation_event_verdict ON ai_moderation_event(verdict,waktu DESC);
CREATE INDEX IF NOT EXISTS idx_ai_moderation_event_user ON ai_moderation_event(user_id,waktu DESC);
INSERT OR IGNORE INTO setelan(kunci,nilai,diperbarui)
VALUES('ai_moderation_mode','off',CURRENT_TIMESTAMP);

-- ---- 0020: livestream PC rental + monetisasi kreator ----
-- Batch V: control-plane livestream PC rental dan monetisasi kreator.
-- Stream key/provider secret tidak pernah disimpan di D1.

CREATE TABLE IF NOT EXISTS creator_profile (
  user_id TEXT PRIMARY KEY,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected','suspended')),
  display_name TEXT NOT NULL CHECK (length(trim(display_name)) BETWEEN 3 AND 40),
  bio TEXT NOT NULL DEFAULT '' CHECK (length(bio) <= 240),
  age_18 INTEGER NOT NULL CHECK (age_18 IN (0,1)),
  terms_version TEXT NOT NULL,
  revenue_share_bps INTEGER NOT NULL DEFAULT 8000 CHECK (revenue_share_bps BETWEEN 0 AND 10000),
  payout_verified INTEGER NOT NULL DEFAULT 0 CHECK (payout_verified IN (0,1)),
  payout_label TEXT CHECK (payout_label IS NULL OR length(payout_label) BETWEEN 1 AND 80),
  applied_at TEXT NOT NULL,
  reviewed_at TEXT,
  reviewed_by TEXT,
  review_note TEXT CHECK (review_note IS NULL OR length(review_note) <= 300),
  updated_at TEXT NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_creator_profile_status ON creator_profile(status,applied_at);

CREATE TABLE IF NOT EXISTS livestream (
  id TEXT PRIMARY KEY,
  user_id TEXT,
  creator_name TEXT NOT NULL,
  sesi_id TEXT,
  agen_id TEXT NOT NULL,
  title TEXT NOT NULL CHECK (length(trim(title)) BETWEEN 5 AND 100),
  game TEXT NOT NULL CHECK (length(trim(game)) BETWEEN 2 AND 60),
  status TEXT NOT NULL DEFAULT 'queued' CHECK (status IN ('queued','starting','live','ending','ended','failed','rejected')),
  visibility TEXT NOT NULL DEFAULT 'public' CHECK (visibility IN ('public')),
  provider TEXT NOT NULL DEFAULT 'cloudflare_stream',
  provider_input_uid TEXT UNIQUE,
  provider_disabled_at TEXT,
  provider_deleted_at TEXT,
  recording_consent INTEGER NOT NULL CHECK (recording_consent IN (0,1)),
  safe_scene_ack INTEGER NOT NULL CHECK (safe_scene_ack IN (0,1)),
  mic_consent INTEGER NOT NULL DEFAULT 0 CHECK (mic_consent IN (0,1)),
  scheduled_end TEXT NOT NULL,
  credential_issued_at TEXT,
  started_at TEXT,
  ended_at TEXT,
  failure_code TEXT,
  end_reason TEXT,
  last_health_at TEXT,
  health_code TEXT,
  output_reconnecting INTEGER NOT NULL DEFAULT 0 CHECK (output_reconnecting IN (0,1)),
  cleanup_pending INTEGER NOT NULL DEFAULT 0 CHECK (cleanup_pending IN (0,1)),
  output_congestion REAL,
  output_bytes INTEGER NOT NULL DEFAULT 0 CHECK (output_bytes >= 0),
  output_duration_ms INTEGER NOT NULL DEFAULT 0 CHECK (output_duration_ms >= 0),
  output_skipped_frames INTEGER NOT NULL DEFAULT 0 CHECK (output_skipped_frames >= 0),
  output_total_frames INTEGER NOT NULL DEFAULT 0 CHECK (output_total_frames >= 0),
  viewer_peak INTEGER NOT NULL DEFAULT 0 CHECK (viewer_peak >= 0),
  gross_tip INTEGER NOT NULL DEFAULT 0 CHECK (gross_tip >= 0),
  creator_net INTEGER NOT NULL DEFAULT 0 CHECK (creator_net >= 0),
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
  FOREIGN KEY (sesi_id) REFERENCES sesi(id) ON DELETE SET NULL,
  FOREIGN KEY (agen_id) REFERENCES agen(id) ON DELETE RESTRICT
);
CREATE INDEX IF NOT EXISTS idx_livestream_public ON livestream(status,created_at DESC);
CREATE INDEX IF NOT EXISTS idx_livestream_creator ON livestream(user_id,created_at DESC);
CREATE UNIQUE INDEX IF NOT EXISTS idx_livestream_active_user ON livestream(user_id)
  WHERE status IN ('queued','starting','live','ending') OR (status='failed' AND cleanup_pending=1);
CREATE UNIQUE INDEX IF NOT EXISTS idx_livestream_active_session ON livestream(sesi_id)
  WHERE status IN ('queued','starting','live','ending') OR (status='failed' AND cleanup_pending=1);
CREATE UNIQUE INDEX IF NOT EXISTS idx_livestream_active_agent ON livestream(agen_id)
  WHERE status IN ('queued','starting','live','ending') OR (status='failed' AND cleanup_pending=1);

-- Transactional outbox for the one logical follower push emitted by the
-- starting -> live transition. The persisted RFC UUID is reused on every
-- OneSignal retry, so a lost HTTP response cannot duplicate the notification.
CREATE TABLE IF NOT EXISTS livestream_push_outbox (
  id TEXT PRIMARY KEY,
  livestream_id TEXT NOT NULL UNIQUE,
  idempotency_key TEXT NOT NULL UNIQUE,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','sending','sent','cancelled')),
  attempts INTEGER NOT NULL DEFAULT 0 CHECK (attempts >= 0),
  next_attempt_at TEXT NOT NULL,
  lease_until TEXT,
  provider_id TEXT,
  last_error TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  sent_at TEXT,
  FOREIGN KEY (livestream_id) REFERENCES livestream(id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_livestream_push_due
  ON livestream_push_outbox(status,next_attempt_at,lease_until);

-- Snapshot at the exact transition: later follow/unfollow activity must not
-- change the recipient set between retries of the same idempotent request.
CREATE TABLE IF NOT EXISTS livestream_push_target (
  outbox_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  PRIMARY KEY (outbox_id,user_id),
  FOREIGN KEY (outbox_id) REFERENCES livestream_push_outbox(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_livestream_push_target_user
  ON livestream_push_target(user_id,outbox_id);

-- Kompensasi side-effect provider bila pembuatan Live Input sukses tetapi
-- transaksi D1 kalah race/constraint. UID bukan stream key dan aman diaudit;
-- worker akan terus mencoba disable+delete sampai provider mengonfirmasi.
CREATE TABLE IF NOT EXISTS livestream_provider_cleanup (
  input_uid TEXT PRIMARY KEY,
  live_id TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','deleted')),
  reason TEXT NOT NULL,
  attempts INTEGER NOT NULL DEFAULT 0 CHECK (attempts >= 0),
  next_attempt_at TEXT NOT NULL,
  last_error TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT
);
CREATE INDEX IF NOT EXISTS idx_livestream_provider_cleanup_due
  ON livestream_provider_cleanup(status,next_attempt_at);

-- The trigger runs only for the first outbox insert, making recipient and inbox
-- creation part of the same D1 transaction as the live-state transition.
CREATE TRIGGER IF NOT EXISTS livestream_push_snapshot
AFTER INSERT ON livestream_push_outbox
BEGIN
  INSERT OR IGNORE INTO livestream_push_target(outbox_id,user_id)
  SELECT NEW.id,f.ikut_id
  FROM follows f JOIN users u ON u.id=f.ikut_id
  JOIN livestream l ON l.id=NEW.livestream_id
  WHERE f.target_id=l.user_id AND f.ikut_id!=l.user_id
    AND u.notif_live=1 AND COALESCE(u.diblokir,0)=0 AND u.deleted_at IS NULL
  ORDER BY f.waktu DESC LIMIT 10000;

  INSERT OR IGNORE INTO notifikasi(id,user_id,jenis,judul,pesan,aktor,ref_jenis,ref_id,dibuat)
  SELECT 'nl_'||NEW.livestream_id||'_'||t.user_id,t.user_id,'livestream',
         COALESCE(l.creator_name,'Kreator')||' sedang live',
         l.title||' · '||l.game||'. Ketuk untuk menonton dari aplikasi.',
         COALESCE(l.creator_name,'Kreator'),'livestream',l.id,NEW.created_at
  FROM livestream_push_target t JOIN livestream l ON l.id=NEW.livestream_id
  WHERE t.outbox_id=NEW.id;
END;

CREATE TRIGGER IF NOT EXISTS livestream_capacity_guard
BEFORE INSERT ON livestream
WHEN NEW.status IN ('queued','starting','live','ending')
BEGIN
  SELECT RAISE(ABORT,'LIVESTREAM_CAPACITY') WHERE (
    SELECT COUNT(*) FROM livestream
    WHERE status IN ('queued','starting','live','ending') OR (status='failed' AND cleanup_pending=1)
  ) >= COALESCE((SELECT CAST(nilai AS INTEGER) FROM setelan WHERE kunci='livestream_max_concurrent'),2);
END;

-- Menutup race ketika owner mematikan flag setelah request membaca config tetapi
-- sebelum Live Input yang berbiaya dicatat. Worker mengompensasi resource yang
-- telanjur dibuat bila trigger ini membatalkan INSERT.
CREATE TRIGGER IF NOT EXISTS livestream_enabled_guard
BEFORE INSERT ON livestream
WHEN NEW.status IN ('queued','starting','live','ending')
BEGIN
  SELECT RAISE(ABORT,'LIVESTREAM_DISABLED')
  WHERE COALESCE((SELECT nilai FROM setelan WHERE kunci='livestream_enabled'),'0')!='1';
  SELECT RAISE(ABORT,'LIVESTREAM_CLEANUP_PENDING') WHERE
    EXISTS(SELECT 1 FROM livestream_provider_cleanup WHERE status='pending') OR
    EXISTS(SELECT 1 FROM livestream WHERE cleanup_pending=1);
END;

CREATE TABLE IF NOT EXISTS livestream_view (
  id TEXT PRIMARY KEY,
  livestream_id TEXT NOT NULL,
  viewer_id TEXT NOT NULL,
  started_at TEXT NOT NULL,
  last_seen TEXT NOT NULL,
  watched_seconds INTEGER NOT NULL DEFAULT 0 CHECK (watched_seconds >= 0),
  FOREIGN KEY (livestream_id) REFERENCES livestream(id) ON DELETE CASCADE,
  FOREIGN KEY (viewer_id) REFERENCES users(id) ON DELETE CASCADE
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_livestream_view_once ON livestream_view(livestream_id,viewer_id);
CREATE INDEX IF NOT EXISTS idx_livestream_view_active ON livestream_view(livestream_id,last_seen DESC);
CREATE INDEX IF NOT EXISTS idx_livestream_view_user ON livestream_view(viewer_id,started_at DESC);

-- Query URL hanya membawa handoff 2 menit. Hash dihapus atomik ketika ditukar
-- menjadi capability cookie HttpOnly, sehingga URL yang tersalin tidak dapat
-- dipakai lagi setelah redirect pertama.
CREATE TABLE IF NOT EXISTS livestream_watch_handoff (
  id TEXT PRIMARY KEY,
  livestream_id TEXT NOT NULL,
  viewer_id TEXT NOT NULL,
  view_id TEXT NOT NULL,
  expires_at TEXT NOT NULL,
  created_at TEXT NOT NULL,
  FOREIGN KEY (livestream_id) REFERENCES livestream(id) ON DELETE CASCADE,
  FOREIGN KEY (viewer_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (view_id) REFERENCES livestream_view(id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_livestream_watch_handoff_expiry ON livestream_watch_handoff(expires_at);

CREATE TABLE IF NOT EXISTS livestream_tip (
  id TEXT PRIMARY KEY,
  livestream_id TEXT NOT NULL,
  viewer_id TEXT,
  creator_id TEXT,
  gross INTEGER NOT NULL CHECK (gross > 0),
  platform_fee INTEGER NOT NULL CHECK (platform_fee >= 0),
  creator_net INTEGER NOT NULL CHECK (creator_net >= 0 AND gross=platform_fee+creator_net),
  client_id TEXT NOT NULL CHECK (length(client_id) BETWEEN 12 AND 80),
  message TEXT NOT NULL DEFAULT '' CHECK (length(message) <= 120),
  status TEXT NOT NULL DEFAULT 'charged' CHECK (status IN ('charged','reversed')),
  reversed_at TEXT,
  reversed_by TEXT,
  reverse_reason TEXT,
  created_at TEXT NOT NULL,
  UNIQUE(viewer_id,client_id),
  FOREIGN KEY (livestream_id) REFERENCES livestream(id) ON DELETE RESTRICT,
  FOREIGN KEY (viewer_id) REFERENCES users(id) ON DELETE SET NULL,
  FOREIGN KEY (creator_id) REFERENCES users(id) ON DELETE SET NULL
);
CREATE INDEX IF NOT EXISTS idx_livestream_tip_live ON livestream_tip(livestream_id,created_at DESC);
CREATE INDEX IF NOT EXISTS idx_livestream_tip_creator ON livestream_tip(creator_id,created_at DESC);

CREATE TABLE IF NOT EXISTS creator_earning (
  id TEXT PRIMARY KEY,
  user_id TEXT,
  livestream_id TEXT NOT NULL,
  tip_id TEXT NOT NULL UNIQUE,
  gross INTEGER NOT NULL,
  platform_fee INTEGER NOT NULL,
  net INTEGER NOT NULL,
  status TEXT NOT NULL DEFAULT 'held' CHECK (status IN ('held','available','reserved','paid','reversed')),
  available_at TEXT NOT NULL,
  payout_id TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
  FOREIGN KEY (livestream_id) REFERENCES livestream(id) ON DELETE RESTRICT,
  FOREIGN KEY (tip_id) REFERENCES livestream_tip(id) ON DELETE RESTRICT
);
CREATE INDEX IF NOT EXISTS idx_creator_earning_status ON creator_earning(user_id,status,available_at);

CREATE TABLE IF NOT EXISTS creator_payout (
  id TEXT PRIMARY KEY,
  user_id TEXT,
  amount INTEGER NOT NULL CHECK (amount > 0),
  client_id TEXT NOT NULL CHECK (length(client_id) BETWEEN 12 AND 80),
  status TEXT NOT NULL DEFAULT 'requested' CHECK (status IN ('requested','processing','paid','rejected')),
  payout_label TEXT NOT NULL CHECK (length(payout_label) BETWEEN 1 AND 80),
  requested_at TEXT NOT NULL,
  processed_at TEXT,
  processed_by TEXT,
  provider_ref TEXT CHECK (provider_ref IS NULL OR length(provider_ref) <= 100),
  note TEXT CHECK (note IS NULL OR length(note) <= 300),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
);
CREATE INDEX IF NOT EXISTS idx_creator_payout_status ON creator_payout(status,requested_at);
CREATE INDEX IF NOT EXISTS idx_creator_payout_user ON creator_payout(user_id,requested_at DESC);
CREATE UNIQUE INDEX IF NOT EXISTS idx_creator_payout_client ON creator_payout(user_id,client_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_creator_payout_active_user ON creator_payout(user_id)
  WHERE status IN ('requested','processing');

CREATE TRIGGER IF NOT EXISTS livestream_tip_apply
AFTER INSERT ON livestream_tip
BEGIN
  SELECT RAISE(ABORT,'LIVE_NOT_ACTIVE') WHERE
    COALESCE((SELECT nilai FROM setelan WHERE kunci='livestream_enabled'),'0')!='1' OR
    NOT EXISTS(SELECT 1 FROM livestream WHERE id=NEW.livestream_id AND user_id=NEW.creator_id AND status='live') OR
    NOT EXISTS(SELECT 1 FROM users WHERE id=NEW.creator_id AND deleted_at IS NULL AND COALESCE(diblokir,0)=0) OR
    NOT EXISTS(SELECT 1 FROM users WHERE id=NEW.viewer_id AND deleted_at IS NULL AND COALESCE(diblokir,0)=0);
  SELECT RAISE(ABORT,'SELF_TIP') WHERE NEW.viewer_id=NEW.creator_id;
  SELECT RAISE(ABORT,'BALANCE_LOW')
    WHERE COALESCE((SELECT saldo FROM users WHERE id=NEW.viewer_id),0)<NEW.gross;
  UPDATE users SET saldo=saldo-NEW.gross WHERE id=NEW.viewer_id;
  INSERT INTO transaksi(id,user_id,judul,tipe,nominal,status,waktu)
    VALUES('livetip_out_'||NEW.id,NEW.viewer_id,'Dukungan livestream','live_tip',-NEW.gross,'sukses',NEW.created_at);
  INSERT INTO creator_earning(id,user_id,livestream_id,tip_id,gross,platform_fee,net,status,available_at,created_at,updated_at)
    VALUES('earn_'||NEW.id,NEW.creator_id,NEW.livestream_id,NEW.id,NEW.gross,NEW.platform_fee,NEW.creator_net,
           'held',datetime(NEW.created_at,'+7 days'),NEW.created_at,NEW.created_at);
  UPDATE livestream SET gross_tip=gross_tip+NEW.gross,creator_net=creator_net+NEW.creator_net,updated_at=NEW.created_at
    WHERE id=NEW.livestream_id;
END;

CREATE TRIGGER IF NOT EXISTS livestream_tip_reverse_guard
BEFORE UPDATE OF status ON livestream_tip
WHEN OLD.status != NEW.status
BEGIN
  SELECT RAISE(ABORT,'INVALID_TIP_TRANSITION')
    WHERE OLD.status!='charged' OR NEW.status!='reversed';
  SELECT RAISE(ABORT,'TIP_ALREADY_IN_PAYOUT') WHERE NOT EXISTS(
    SELECT 1 FROM creator_earning WHERE tip_id=OLD.id AND status IN ('held','available')
  );
  SELECT RAISE(ABORT,'TIP_REVERSE_REASON_REQUIRED')
    WHERE length(trim(COALESCE(NEW.reverse_reason,''))) NOT BETWEEN 8 AND 200
       OR length(trim(COALESCE(NEW.reversed_by,'')))<1;
END;

CREATE TRIGGER IF NOT EXISTS livestream_tip_reverse_apply
AFTER UPDATE OF status ON livestream_tip
WHEN OLD.status='charged' AND NEW.status='reversed'
BEGIN
  UPDATE users SET saldo=saldo+OLD.gross WHERE id=OLD.viewer_id;
  INSERT INTO transaksi(id,user_id,judul,tipe,nominal,status,waktu)
    SELECT 'livetip_refund_'||OLD.id,id,'Pengembalian dukungan livestream','live_tip_refund',OLD.gross,'sukses',NEW.reversed_at
    FROM users WHERE id=OLD.viewer_id;
  UPDATE creator_earning SET status='reversed',updated_at=NEW.reversed_at
    WHERE tip_id=OLD.id AND status IN ('held','available');
  UPDATE livestream SET gross_tip=MAX(0,gross_tip-OLD.gross),creator_net=MAX(0,creator_net-OLD.creator_net),updated_at=NEW.reversed_at
    WHERE id=OLD.livestream_id;
END;

CREATE TRIGGER IF NOT EXISTS creator_payout_reserve
BEFORE INSERT ON creator_payout
BEGIN
  SELECT RAISE(ABORT,'CREATOR_NOT_VERIFIED') WHERE NOT EXISTS(
    SELECT 1 FROM creator_profile WHERE user_id=NEW.user_id AND status='approved' AND payout_verified=1
  );
  SELECT RAISE(ABORT,'PAYOUT_BELOW_MINIMUM') WHERE NEW.amount < COALESCE(
    (SELECT CAST(nilai AS INTEGER) FROM setelan WHERE kunci='livestream_min_payout'),100000
  );
  SELECT RAISE(ABORT,'PAYOUT_AMOUNT_CHANGED') WHERE NEW.amount != COALESCE((
    SELECT SUM(net) FROM creator_earning WHERE user_id=NEW.user_id AND status='available'
  ),0);
END;

CREATE TRIGGER IF NOT EXISTS creator_payout_reserve_after
AFTER INSERT ON creator_payout
BEGIN
  UPDATE creator_earning SET status='reserved',payout_id=NEW.id,updated_at=NEW.requested_at
    WHERE user_id=NEW.user_id AND status='available';
END;

CREATE TRIGGER IF NOT EXISTS creator_payout_transition
BEFORE UPDATE OF status ON creator_payout
WHEN OLD.status != NEW.status
BEGIN
  SELECT RAISE(ABORT,'INVALID_PAYOUT_TRANSITION') WHERE NOT (
    (OLD.status='requested' AND NEW.status IN ('processing','paid','rejected')) OR
    (OLD.status='processing' AND NEW.status IN ('paid','rejected'))
  );
  SELECT RAISE(ABORT,'PAYOUT_LEDGER_MISMATCH') WHERE NEW.status IN ('paid','rejected')
    AND OLD.amount != COALESCE((SELECT SUM(net) FROM creator_earning WHERE payout_id=OLD.id AND status='reserved'),0);
  SELECT RAISE(ABORT,'PAYOUT_REFERENCE_REQUIRED')
    WHERE NEW.status='paid' AND length(trim(COALESCE(NEW.provider_ref,'')))<4;
  SELECT RAISE(ABORT,'PAYOUT_REJECTION_REASON_REQUIRED')
    WHERE NEW.status='rejected' AND length(trim(COALESCE(NEW.note,'')))<8;
END;

CREATE TRIGGER IF NOT EXISTS creator_payout_complete
AFTER UPDATE OF status ON creator_payout
WHEN OLD.status != NEW.status
BEGIN
  UPDATE creator_earning SET status='paid',updated_at=NEW.processed_at
    WHERE payout_id=NEW.id AND status='reserved' AND NEW.status='paid';
  UPDATE creator_earning SET status='available',payout_id=NULL,updated_at=NEW.processed_at
    WHERE payout_id=NEW.id AND status='reserved' AND NEW.status='rejected';
END;

INSERT OR IGNORE INTO setelan(kunci,nilai,diperbarui) VALUES('livestream_enabled','1',CURRENT_TIMESTAMP);
INSERT OR IGNORE INTO setelan(kunci,nilai,diperbarui) VALUES('livestream_platform_fee_bps','2000',CURRENT_TIMESTAMP);
INSERT OR IGNORE INTO setelan(kunci,nilai,diperbarui) VALUES('livestream_min_tip','5000',CURRENT_TIMESTAMP);
INSERT OR IGNORE INTO setelan(kunci,nilai,diperbarui) VALUES('livestream_max_tip','500000',CURRENT_TIMESTAMP);
INSERT OR IGNORE INTO setelan(kunci,nilai,diperbarui) VALUES('livestream_min_payout','100000',CURRENT_TIMESTAMP);
INSERT OR IGNORE INTO setelan(kunci,nilai,diperbarui) VALUES('livestream_max_minutes','240',CURRENT_TIMESTAMP);
INSERT OR IGNORE INTO setelan(kunci,nilai,diperbarui) VALUES('livestream_max_concurrent','2',CURRENT_TIMESTAMP);

CREATE TABLE IF NOT EXISTS antrean_sewa (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  plan_id TEXT NOT NULL,
  durasi_jam INTEGER NOT NULL DEFAULT 1,
  prioritas INTEGER NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'menunggu',
  estimasi_menit INTEGER NOT NULL DEFAULT 30,
  dibuat TEXT NOT NULL DEFAULT (datetime('now')),
  dipanggil_pada TEXT
);

CREATE INDEX IF NOT EXISTS idx_antrean_sewa_plan_status ON antrean_sewa(plan_id, status, prioritas DESC, dibuat ASC);

CREATE TABLE IF NOT EXISTS stories (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  media_url TEXT,
  tipe TEXT NOT NULL DEFAULT 'teks',
  teks TEXT,
  bg_gradient TEXT NOT NULL DEFAULT 'ungu',
  privasi TEXT NOT NULL DEFAULT 'teman',
  likes INTEGER NOT NULL DEFAULT 0,
  reposts INTEGER NOT NULL DEFAULT 0,
  dibuat TEXT NOT NULL,
  berakhir TEXT NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_stories_user_berakhir ON stories(user_id, berakhir);
CREATE INDEX IF NOT EXISTS idx_stories_berakhir ON stories(berakhir);

CREATE TABLE IF NOT EXISTS story_likes (
  story_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  dibuat TEXT NOT NULL,
  PRIMARY KEY (story_id, user_id),
  FOREIGN KEY (story_id) REFERENCES stories(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

