-- ============================================================
--  0013 — Batch N: dedup media (hash isi berkas)
-- ============================================================
--  Permintaan pemilik 2026-09-16: tidak ada aset duplikat.
--  Hash SHA-256 isi berkas dicatat di media_assets supaya unggahan
--  identik tidak menambah aset baru. Berkas ini sudah diterapkan
--  mandiri di produksi (medium hash + index) sebelum masuk repo;
--  kini dicatat agar pelacakan migrasi tetap rapi.

ALTER TABLE media_assets ADD COLUMN hash TEXT;
CREATE INDEX IF NOT EXISTS idx_media_assets_hash ON media_assets(hash);
