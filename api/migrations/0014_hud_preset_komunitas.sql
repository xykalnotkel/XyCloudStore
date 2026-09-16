-- ============================================================
--  0014 — Editor HUD streaming + preset komunitas
-- ============================================================
-- Layout tombol tetap tersimpan lokal untuk penggunaan offline. Tabel ini
-- hanya menampung salinan yang sengaja diterbitkan pengguna, statistik suka,
-- dan jumlah pemakaian/import oleh anggota lain.

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
