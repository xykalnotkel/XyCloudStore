-- Batch U: moderasi AI privacy-preserving. Tidak menyimpan teks/prompt/response mentah.

CREATE TABLE IF NOT EXISTS ai_moderation_cache (
  content_hash TEXT PRIMARY KEY,
  verdict TEXT NOT NULL CHECK (verdict IN ('allow','review','block')),
  kategori TEXT NOT NULL,
  severity INTEGER NOT NULL CHECK (severity BETWEEN 0 AND 4),
  confidence REAL NOT NULL CHECK (confidence BETWEEN 0 AND 1),
  reason_code TEXT NOT NULL,
  model TEXT NOT NULL,
  created_at TEXT NOT NULL,
  expires_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_ai_moderation_cache_expires
  ON ai_moderation_cache(expires_at);

CREATE TABLE IF NOT EXISTS ai_moderation_event (
  id TEXT PRIMARY KEY,
  user_id TEXT,
  konteks TEXT NOT NULL,
  content_hash TEXT NOT NULL,
  mode TEXT NOT NULL,
  sumber TEXT NOT NULL CHECK (sumber IN ('local','ai')),
  verdict TEXT NOT NULL CHECK (verdict IN ('allow','review','block','error')),
  kategori TEXT,
  severity INTEGER CHECK (severity IS NULL OR severity BETWEEN 0 AND 4),
  confidence REAL CHECK (confidence IS NULL OR (confidence BETWEEN 0 AND 1)),
  latency_ms INTEGER CHECK (latency_ms IS NULL OR latency_ms >= 0),
  cached INTEGER NOT NULL DEFAULT 0 CHECK (cached IN (0,1)),
  prompt_tokens INTEGER CHECK (prompt_tokens IS NULL OR prompt_tokens >= 0),
  completion_tokens INTEGER CHECK (completion_tokens IS NULL OR completion_tokens >= 0),
  error_code TEXT,
  model TEXT,
  waktu TEXT NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_ai_moderation_event_waktu
  ON ai_moderation_event(waktu DESC);
CREATE INDEX IF NOT EXISTS idx_ai_moderation_event_verdict
  ON ai_moderation_event(verdict, waktu DESC);
CREATE INDEX IF NOT EXISTS idx_ai_moderation_event_user
  ON ai_moderation_event(user_id, waktu DESC);

INSERT OR IGNORE INTO setelan(kunci,nilai,diperbarui)
VALUES('ai_moderation_mode','off',CURRENT_TIMESTAMP);
