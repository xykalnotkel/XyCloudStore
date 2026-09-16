-- ============================================================
--  0013 — Batch N: dedup media + banner video jadi GIF (hapus MP4)
-- ============================================================
--  Permintaan pemilik 2026-09-16:
--  1. Tidak ada aset duplikat: hash isi berkas dicatat di media_assets
--     supaya unggahan identik tidak menambah aset baru.
--  2. Banner video: MP4 diubah menjadi GIF mandiri, lalu MP4 dihapus
--     dari penyimpanan (tidak ada penyimpanan dobel).
--  Catatan: bersifat ADITIF — data lama tetap utuh; hash terisi saat
--  unggahan berikutnya.

ALTER TABLE media_assets ADD COLUMN hash TEXT;
CREATE INDEX IF NOT EXISTS idx_media_hash ON media_assets(hash);
