-- Migration 0024: Aktifkan Livestreaming dan Tambah Tabel Stories untuk Feed Komunitas
-- Diperlukan untuk fitur Story 24 jam dan aktivasi permanen live streaming.

-- 1. Aktifkan livestreaming secara default
INSERT INTO setelan(kunci, nilai, diperbarui) 
VALUES('livestream_enabled', '1', CURRENT_TIMESTAMP)
ON CONFLICT(kunci) DO UPDATE SET nilai='1', diperbarui=CURRENT_TIMESTAMP;

-- 2. Buat tabel stories untuk posting story 24 jam antar teman/pengikut
CREATE TABLE IF NOT EXISTS stories (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  media_url TEXT,
  tipe TEXT NOT NULL DEFAULT 'teks', -- 'teks', 'gambar', 'video'
  teks TEXT,
  bg_gradient TEXT NOT NULL DEFAULT 'ungu', -- 'ungu', 'emas', 'neon', 'senja', 'cyber'
  privasi TEXT NOT NULL DEFAULT 'teman', -- 'teman', 'publik'
  dibuat TEXT NOT NULL,
  berakhir TEXT NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_stories_user_berakhir ON stories(user_id, berakhir);
CREATE INDEX IF NOT EXISTS idx_stories_berakhir ON stories(berakhir);
