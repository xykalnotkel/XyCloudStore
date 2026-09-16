-- Batch S: identitas OAuth stabil + permintaan penghapusan data Meta.
-- ID akun penyedia disimpan sebagai HMAC, bukan ID Facebook/Google mentah.
CREATE TABLE IF NOT EXISTS social_identity (
  provider TEXT NOT NULL,
  provider_user_hash TEXT NOT NULL,
  user_id TEXT NOT NULL,
  email_at_link TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  last_login TEXT NOT NULL DEFAULT (datetime('now')),
  PRIMARY KEY (provider, provider_user_hash),
  UNIQUE (provider, user_id)
);
CREATE INDEX IF NOT EXISTS idx_social_identity_user
  ON social_identity(user_id);

CREATE TABLE IF NOT EXISTS social_deletion_request (
  id TEXT PRIMARY KEY,
  provider TEXT NOT NULL,
  user_id TEXT,
  status TEXT NOT NULL DEFAULT 'menunggu',
  requested_at TEXT NOT NULL DEFAULT (datetime('now')),
  completed_at TEXT,
  note TEXT
);
CREATE INDEX IF NOT EXISTS idx_social_deletion_status
  ON social_deletion_request(status, requested_at);

-- Versi lama menyimpan URL avatar Google/Facebook langsung. Hilangkan URL
-- lintas-domain; login berikutnya mengimpor avatar ke Cloudinary milik layanan.
UPDATE users SET foto = NULL
 WHERE lower(COALESCE(foto, '')) LIKE 'https://%googleusercontent.com/%'
    OR lower(COALESCE(foto, '')) LIKE 'https://%fbcdn.net/%'
    OR lower(COALESCE(foto, '')) LIKE 'https://%fbsbx.com/%';
