-- ============================================================
--  0023 — Antrean dan booking unit sewa PC
-- ============================================================

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
