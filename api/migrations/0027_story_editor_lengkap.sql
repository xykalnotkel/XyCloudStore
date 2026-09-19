-- Migration 0027: Lengkapi editor story — gaya teks, background, label, dan trimming video
-- Batch Q: story editor ala Instagram (teks style, background, label) + video trim native

ALTER TABLE stories ADD COLUMN gaya_teks TEXT DEFAULT 'normal'; -- normal, bold, italic, bold_italic, neon, pelangi, ketik, ombak
ALTER TABLE stories ADD COLUMN warna_teks TEXT DEFAULT '#FFFFFF';
ALTER TABLE stories ADD COLUMN ukuran_teks INTEGER DEFAULT 21; -- 14-32
ALTER TABLE stories ADD COLUMN align_teks TEXT DEFAULT 'center'; -- left, center, right
ALTER TABLE stories ADD COLUMN bg_type TEXT DEFAULT 'gradient'; -- gradient, solid, image, video
ALTER TABLE stories ADD COLUMN bg_warna TEXT DEFAULT ''; -- hex solid jika bg_type=solid
ALTER TABLE stories ADD COLUMN bg_image_url TEXT DEFAULT NULL;
ALTER TABLE stories ADD COLUMN teks_bg INTEGER DEFAULT 1; -- 0/1 pakai background hitam transparan di teks
ALTER TABLE stories ADD COLUMN teks_bg_warna TEXT DEFAULT '#00000073'; -- warna bg teks
ALTER TABLE stories ADD COLUMN label TEXT DEFAULT ''; -- JSON array label: location, mention, hashtag, countdown, etc
ALTER TABLE stories ADD COLUMN trim_start REAL DEFAULT 0; -- detik awal trim video
ALTER TABLE stories ADD COLUMN trim_end REAL DEFAULT 0; -- detik akhir trim video (0 = sampai habis)
ALTER TABLE stories ADD COLUMN filter TEXT DEFAULT 'normal'; -- normal, bw, sepia, vintage, vivid, etc
ALTER TABLE stories ADD COLUMN durasi_video REAL DEFAULT 0; -- durasi asli video

-- Index untuk pencarian label (opsional)
CREATE INDEX IF NOT EXISTS idx_stories_tipe ON stories(tipe);
CREATE INDEX IF NOT EXISTS idx_stories_bg_type ON stories(bg_type);
