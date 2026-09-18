-- ============================================================
--  0022 — Optimasi performa & indeks query DM & CS chat
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_dm_percakapan ON dm(dari_id, ke_id, waktu DESC);
CREATE INDEX IF NOT EXISTS idx_dm_percakapan_balik ON dm(ke_id, dari_id, waktu DESC);
CREATE INDEX IF NOT EXISTS idx_cs_messages_room_waktu ON cs_messages(room, waktu DESC, id DESC);
