-- ============================================================
-- 0015 — Telemetri koneksi streaming & pemulihan klien
-- ============================================================
-- Hanya metadata operasional. Tidak ada input tombol, audio, gambar, atau isi
-- gameplay yang dikirim/disimpan. Dipakai untuk reconnect dan diagnosis admin.

ALTER TABLE sesi ADD COLUMN client_state TEXT;
ALTER TABLE sesi ADD COLUMN client_last TEXT;
ALTER TABLE sesi ADD COLUMN client_route TEXT;
ALTER TABLE sesi ADD COLUMN client_latency_ms INTEGER;
ALTER TABLE sesi ADD COLUMN client_quality TEXT;
ALTER TABLE sesi ADD COLUMN client_disconnects INTEGER NOT NULL DEFAULT 0;
ALTER TABLE sesi ADD COLUMN client_reconnect_attempt INTEGER NOT NULL DEFAULT 0;
ALTER TABLE sesi ADD COLUMN client_reason TEXT;

CREATE INDEX IF NOT EXISTS idx_sesi_client_last ON sesi(client_last);
