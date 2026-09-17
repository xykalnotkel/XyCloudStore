-- OAuth browser callback must never place a long-lived login token in a
-- custom-scheme URI. The app contributes a PKCE-style verifier; browser and
-- callback only see its SHA-256 challenge.
ALTER TABLE oauth_states ADD COLUMN handoff_challenge TEXT;

-- Store only a keyed hash of the short handoff code. Code exchange is bound to
-- both the install identity and the verifier challenge that initiated OAuth.
CREATE TABLE IF NOT EXISTS oauth_handoffs (
  id TEXT PRIMARY KEY,
  provider TEXT NOT NULL CHECK (provider IN ('google','facebook')),
  user_id TEXT NOT NULL,
  device_id TEXT NOT NULL,
  handoff_challenge TEXT NOT NULL CHECK (length(handoff_challenge) = 43),
  session_version INTEGER NOT NULL DEFAULT 0,
  exchange_count INTEGER NOT NULL DEFAULT 0 CHECK (exchange_count BETWEEN 0 AND 5),
  first_exchanged_at TEXT,
  created_at TEXT NOT NULL,
  expires_at TEXT NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_oauth_handoffs_expiry ON oauth_handoffs(expires_at);
