-- Batch T: pembayaran Pakasir, rekonsiliasi, audit webhook, dan kredit idempoten.
-- Default "legacy" menjaga kompatibilitas Worker lama selama rollout migrasi;
-- Worker baru selalu menulis provider secara eksplisit.
ALTER TABLE topup ADD COLUMN provider TEXT NOT NULL DEFAULT 'legacy';
ALTER TABLE topup ADD COLUMN provider_ref TEXT;
ALTER TABLE topup ADD COLUMN provider_status TEXT;
ALTER TABLE topup ADD COLUMN provider_method TEXT;
ALTER TABLE topup ADD COLUMN provider_amount INTEGER;
ALTER TABLE topup ADD COLUMN provider_fee INTEGER;
ALTER TABLE topup ADD COLUMN provider_checked_at TEXT;
ALTER TABLE topup ADD COLUMN provider_expires_at TEXT;
ALTER TABLE topup ADD COLUMN checkout_url TEXT;
ALTER TABLE topup ADD COLUMN payment_qr TEXT;
ALTER TABLE topup ADD COLUMN payment_code TEXT;
ALTER TABLE topup ADD COLUMN webhook_count INTEGER NOT NULL DEFAULT 0;

UPDATE topup
   SET provider = CASE WHEN kode_unik = 0 THEN 'legacy' ELSE 'manual' END,
       provider_ref = CASE WHEN kode_unik = 0 THEN id ELSE NULL END
 WHERE provider = 'legacy';

CREATE INDEX IF NOT EXISTS idx_topup_provider_status
  ON topup(provider, status, dibuat);
CREATE INDEX IF NOT EXISTS idx_topup_provider_ref
  ON topup(provider, provider_ref);

-- Satu baris klaim per top up. Semua langkah kredit dijalankan dalam satu
-- DB.batch D1 sehingga saldo, buku besar, dan status commit atau rollback bersama.
CREATE TABLE IF NOT EXISTS topup_credit (
  topup_id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  nominal INTEGER NOT NULL CHECK (nominal > 0),
  sumber TEXT NOT NULL,
  created_at TEXT NOT NULL,
  credited_at TEXT
);
CREATE INDEX IF NOT EXISTS idx_topup_credit_user
  ON topup_credit(user_id, credited_at);

-- Payload mentah dan secret tidak disimpan. Tabel ini cukup untuk audit sinyal,
-- hasil verifikasi server-to-server, serta deteksi webhook yang ditolak.
CREATE TABLE IF NOT EXISTS payment_webhook_event (
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
CREATE INDEX IF NOT EXISTS idx_payment_webhook_recent
  ON payment_webhook_event(provider, received_at);
CREATE INDEX IF NOT EXISTS idx_payment_webhook_topup
  ON payment_webhook_event(topup_id, received_at);

-- Admin tambahan baru disimpan sebagai HMAC satu arah. Kolom ini hanya preview
-- teredaksi; baris plaintext lama dimigrasikan saat key tersebut login berikutnya.
ALTER TABLE admin_kunci ADD COLUMN kunci_preview TEXT;
