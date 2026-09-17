-- Batch V: control-plane livestream PC rental dan monetisasi kreator.
-- Stream key/provider secret tidak pernah disimpan di D1.

ALTER TABLE users ADD COLUMN notif_live INTEGER NOT NULL DEFAULT 1 CHECK (notif_live IN (0,1));

CREATE TABLE IF NOT EXISTS creator_profile (
  user_id TEXT PRIMARY KEY,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected','suspended')),
  display_name TEXT NOT NULL CHECK (length(trim(display_name)) BETWEEN 3 AND 40),
  bio TEXT NOT NULL DEFAULT '' CHECK (length(bio) <= 240),
  age_18 INTEGER NOT NULL CHECK (age_18 IN (0,1)),
  terms_version TEXT NOT NULL,
  revenue_share_bps INTEGER NOT NULL DEFAULT 8000 CHECK (revenue_share_bps BETWEEN 0 AND 10000),
  payout_verified INTEGER NOT NULL DEFAULT 0 CHECK (payout_verified IN (0,1)),
  payout_label TEXT CHECK (payout_label IS NULL OR length(payout_label) BETWEEN 1 AND 80),
  applied_at TEXT NOT NULL,
  reviewed_at TEXT,
  reviewed_by TEXT,
  review_note TEXT CHECK (review_note IS NULL OR length(review_note) <= 300),
  updated_at TEXT NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_creator_profile_status ON creator_profile(status,applied_at);

CREATE TABLE IF NOT EXISTS livestream (
  id TEXT PRIMARY KEY,
  user_id TEXT,
  creator_name TEXT NOT NULL,
  sesi_id TEXT,
  agen_id TEXT NOT NULL,
  title TEXT NOT NULL CHECK (length(trim(title)) BETWEEN 5 AND 100),
  game TEXT NOT NULL CHECK (length(trim(game)) BETWEEN 2 AND 60),
  status TEXT NOT NULL DEFAULT 'queued' CHECK (status IN ('queued','starting','live','ending','ended','failed','rejected')),
  visibility TEXT NOT NULL DEFAULT 'public' CHECK (visibility IN ('public')),
  provider TEXT NOT NULL DEFAULT 'cloudflare_stream',
  provider_input_uid TEXT UNIQUE,
  provider_disabled_at TEXT,
  provider_deleted_at TEXT,
  recording_consent INTEGER NOT NULL CHECK (recording_consent IN (0,1)),
  safe_scene_ack INTEGER NOT NULL CHECK (safe_scene_ack IN (0,1)),
  mic_consent INTEGER NOT NULL DEFAULT 0 CHECK (mic_consent IN (0,1)),
  scheduled_end TEXT NOT NULL,
  credential_issued_at TEXT,
  started_at TEXT,
  ended_at TEXT,
  failure_code TEXT,
  end_reason TEXT,
  last_health_at TEXT,
  health_code TEXT,
  output_reconnecting INTEGER NOT NULL DEFAULT 0 CHECK (output_reconnecting IN (0,1)),
  cleanup_pending INTEGER NOT NULL DEFAULT 0 CHECK (cleanup_pending IN (0,1)),
  output_congestion REAL,
  output_bytes INTEGER NOT NULL DEFAULT 0 CHECK (output_bytes >= 0),
  output_duration_ms INTEGER NOT NULL DEFAULT 0 CHECK (output_duration_ms >= 0),
  output_skipped_frames INTEGER NOT NULL DEFAULT 0 CHECK (output_skipped_frames >= 0),
  output_total_frames INTEGER NOT NULL DEFAULT 0 CHECK (output_total_frames >= 0),
  viewer_peak INTEGER NOT NULL DEFAULT 0 CHECK (viewer_peak >= 0),
  gross_tip INTEGER NOT NULL DEFAULT 0 CHECK (gross_tip >= 0),
  creator_net INTEGER NOT NULL DEFAULT 0 CHECK (creator_net >= 0),
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
  FOREIGN KEY (sesi_id) REFERENCES sesi(id) ON DELETE SET NULL,
  FOREIGN KEY (agen_id) REFERENCES agen(id) ON DELETE RESTRICT
);
CREATE INDEX IF NOT EXISTS idx_livestream_public ON livestream(status,created_at DESC);
CREATE INDEX IF NOT EXISTS idx_livestream_creator ON livestream(user_id,created_at DESC);
CREATE UNIQUE INDEX IF NOT EXISTS idx_livestream_active_user ON livestream(user_id)
  WHERE status IN ('queued','starting','live','ending') OR (status='failed' AND cleanup_pending=1);
CREATE UNIQUE INDEX IF NOT EXISTS idx_livestream_active_session ON livestream(sesi_id)
  WHERE status IN ('queued','starting','live','ending') OR (status='failed' AND cleanup_pending=1);
CREATE UNIQUE INDEX IF NOT EXISTS idx_livestream_active_agent ON livestream(agen_id)
  WHERE status IN ('queued','starting','live','ending') OR (status='failed' AND cleanup_pending=1);

-- Transactional outbox for the one logical follower push emitted by the
-- starting -> live transition. The persisted RFC UUID is reused on every
-- OneSignal retry, so a lost HTTP response cannot duplicate the notification.
CREATE TABLE IF NOT EXISTS livestream_push_outbox (
  id TEXT PRIMARY KEY,
  livestream_id TEXT NOT NULL UNIQUE,
  idempotency_key TEXT NOT NULL UNIQUE,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','sending','sent','cancelled')),
  attempts INTEGER NOT NULL DEFAULT 0 CHECK (attempts >= 0),
  next_attempt_at TEXT NOT NULL,
  lease_until TEXT,
  provider_id TEXT,
  last_error TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  sent_at TEXT,
  FOREIGN KEY (livestream_id) REFERENCES livestream(id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_livestream_push_due
  ON livestream_push_outbox(status,next_attempt_at,lease_until);

-- Snapshot at the exact transition: later follow/unfollow activity must not
-- change the recipient set between retries of the same idempotent request.
CREATE TABLE IF NOT EXISTS livestream_push_target (
  outbox_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  PRIMARY KEY (outbox_id,user_id),
  FOREIGN KEY (outbox_id) REFERENCES livestream_push_outbox(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_livestream_push_target_user
  ON livestream_push_target(user_id,outbox_id);

-- Kompensasi side-effect provider bila pembuatan Live Input sukses tetapi
-- transaksi D1 kalah race/constraint. UID bukan stream key dan aman diaudit;
-- worker akan terus mencoba disable+delete sampai provider mengonfirmasi.
CREATE TABLE IF NOT EXISTS livestream_provider_cleanup (
  input_uid TEXT PRIMARY KEY,
  live_id TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','deleted')),
  reason TEXT NOT NULL,
  attempts INTEGER NOT NULL DEFAULT 0 CHECK (attempts >= 0),
  next_attempt_at TEXT NOT NULL,
  last_error TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT
);
CREATE INDEX IF NOT EXISTS idx_livestream_provider_cleanup_due
  ON livestream_provider_cleanup(status,next_attempt_at);

-- The trigger runs only for the first outbox insert, making recipient and inbox
-- creation part of the same D1 transaction as the live-state transition.
CREATE TRIGGER IF NOT EXISTS livestream_push_snapshot
AFTER INSERT ON livestream_push_outbox
BEGIN
  INSERT OR IGNORE INTO livestream_push_target(outbox_id,user_id)
  SELECT NEW.id,f.ikut_id
  FROM follows f JOIN users u ON u.id=f.ikut_id
  JOIN livestream l ON l.id=NEW.livestream_id
  WHERE f.target_id=l.user_id AND f.ikut_id!=l.user_id
    AND u.notif_live=1 AND COALESCE(u.diblokir,0)=0 AND u.deleted_at IS NULL
  ORDER BY f.waktu DESC LIMIT 10000;

  INSERT OR IGNORE INTO notifikasi(id,user_id,jenis,judul,pesan,aktor,ref_jenis,ref_id,dibuat)
  SELECT 'nl_'||NEW.livestream_id||'_'||t.user_id,t.user_id,'livestream',
         COALESCE(l.creator_name,'Kreator')||' sedang live',
         l.title||' · '||l.game||'. Ketuk untuk menonton dari aplikasi.',
         COALESCE(l.creator_name,'Kreator'),'livestream',l.id,NEW.created_at
  FROM livestream_push_target t JOIN livestream l ON l.id=NEW.livestream_id
  WHERE t.outbox_id=NEW.id;
END;

CREATE TRIGGER IF NOT EXISTS livestream_capacity_guard
BEFORE INSERT ON livestream
WHEN NEW.status IN ('queued','starting','live','ending')
BEGIN
  SELECT RAISE(ABORT,'LIVESTREAM_CAPACITY') WHERE (
    SELECT COUNT(*) FROM livestream
    WHERE status IN ('queued','starting','live','ending') OR (status='failed' AND cleanup_pending=1)
  ) >= COALESCE((SELECT CAST(nilai AS INTEGER) FROM setelan WHERE kunci='livestream_max_concurrent'),2);
END;

-- Menutup race ketika owner mematikan flag setelah request membaca config tetapi
-- sebelum Live Input yang berbiaya dicatat. Worker mengompensasi resource yang
-- telanjur dibuat bila trigger ini membatalkan INSERT.
CREATE TRIGGER IF NOT EXISTS livestream_enabled_guard
BEFORE INSERT ON livestream
WHEN NEW.status IN ('queued','starting','live','ending')
BEGIN
  SELECT RAISE(ABORT,'LIVESTREAM_DISABLED')
  WHERE COALESCE((SELECT nilai FROM setelan WHERE kunci='livestream_enabled'),'0')!='1';
  SELECT RAISE(ABORT,'LIVESTREAM_CLEANUP_PENDING') WHERE
    EXISTS(SELECT 1 FROM livestream_provider_cleanup WHERE status='pending') OR
    EXISTS(SELECT 1 FROM livestream WHERE cleanup_pending=1);
END;

CREATE TABLE IF NOT EXISTS livestream_view (
  id TEXT PRIMARY KEY,
  livestream_id TEXT NOT NULL,
  viewer_id TEXT NOT NULL,
  started_at TEXT NOT NULL,
  last_seen TEXT NOT NULL,
  watched_seconds INTEGER NOT NULL DEFAULT 0 CHECK (watched_seconds >= 0),
  FOREIGN KEY (livestream_id) REFERENCES livestream(id) ON DELETE CASCADE,
  FOREIGN KEY (viewer_id) REFERENCES users(id) ON DELETE CASCADE
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_livestream_view_once ON livestream_view(livestream_id,viewer_id);
CREATE INDEX IF NOT EXISTS idx_livestream_view_active ON livestream_view(livestream_id,last_seen DESC);
CREATE INDEX IF NOT EXISTS idx_livestream_view_user ON livestream_view(viewer_id,started_at DESC);

-- Query URL hanya membawa handoff 2 menit. Hash dihapus atomik ketika ditukar
-- menjadi capability cookie HttpOnly, sehingga URL yang tersalin tidak dapat
-- dipakai lagi setelah redirect pertama.
CREATE TABLE IF NOT EXISTS livestream_watch_handoff (
  id TEXT PRIMARY KEY,
  livestream_id TEXT NOT NULL,
  viewer_id TEXT NOT NULL,
  view_id TEXT NOT NULL,
  expires_at TEXT NOT NULL,
  created_at TEXT NOT NULL,
  FOREIGN KEY (livestream_id) REFERENCES livestream(id) ON DELETE CASCADE,
  FOREIGN KEY (viewer_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (view_id) REFERENCES livestream_view(id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_livestream_watch_handoff_expiry ON livestream_watch_handoff(expires_at);

CREATE TABLE IF NOT EXISTS livestream_tip (
  id TEXT PRIMARY KEY,
  livestream_id TEXT NOT NULL,
  viewer_id TEXT,
  creator_id TEXT,
  gross INTEGER NOT NULL CHECK (gross > 0),
  platform_fee INTEGER NOT NULL CHECK (platform_fee >= 0),
  creator_net INTEGER NOT NULL CHECK (creator_net >= 0 AND gross=platform_fee+creator_net),
  client_id TEXT NOT NULL CHECK (length(client_id) BETWEEN 12 AND 80),
  message TEXT NOT NULL DEFAULT '' CHECK (length(message) <= 120),
  status TEXT NOT NULL DEFAULT 'charged' CHECK (status IN ('charged','reversed')),
  reversed_at TEXT,
  reversed_by TEXT,
  reverse_reason TEXT,
  created_at TEXT NOT NULL,
  UNIQUE(viewer_id,client_id),
  FOREIGN KEY (livestream_id) REFERENCES livestream(id) ON DELETE RESTRICT,
  FOREIGN KEY (viewer_id) REFERENCES users(id) ON DELETE SET NULL,
  FOREIGN KEY (creator_id) REFERENCES users(id) ON DELETE SET NULL
);
CREATE INDEX IF NOT EXISTS idx_livestream_tip_live ON livestream_tip(livestream_id,created_at DESC);
CREATE INDEX IF NOT EXISTS idx_livestream_tip_creator ON livestream_tip(creator_id,created_at DESC);

CREATE TABLE IF NOT EXISTS creator_earning (
  id TEXT PRIMARY KEY,
  user_id TEXT,
  livestream_id TEXT NOT NULL,
  tip_id TEXT NOT NULL UNIQUE,
  gross INTEGER NOT NULL,
  platform_fee INTEGER NOT NULL,
  net INTEGER NOT NULL,
  status TEXT NOT NULL DEFAULT 'held' CHECK (status IN ('held','available','reserved','paid','reversed')),
  available_at TEXT NOT NULL,
  payout_id TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
  FOREIGN KEY (livestream_id) REFERENCES livestream(id) ON DELETE RESTRICT,
  FOREIGN KEY (tip_id) REFERENCES livestream_tip(id) ON DELETE RESTRICT
);
CREATE INDEX IF NOT EXISTS idx_creator_earning_status ON creator_earning(user_id,status,available_at);

CREATE TABLE IF NOT EXISTS creator_payout (
  id TEXT PRIMARY KEY,
  user_id TEXT,
  amount INTEGER NOT NULL CHECK (amount > 0),
  client_id TEXT NOT NULL CHECK (length(client_id) BETWEEN 12 AND 80),
  status TEXT NOT NULL DEFAULT 'requested' CHECK (status IN ('requested','processing','paid','rejected')),
  payout_label TEXT NOT NULL CHECK (length(payout_label) BETWEEN 1 AND 80),
  requested_at TEXT NOT NULL,
  processed_at TEXT,
  processed_by TEXT,
  provider_ref TEXT CHECK (provider_ref IS NULL OR length(provider_ref) <= 100),
  note TEXT CHECK (note IS NULL OR length(note) <= 300),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
);
CREATE INDEX IF NOT EXISTS idx_creator_payout_status ON creator_payout(status,requested_at);
CREATE INDEX IF NOT EXISTS idx_creator_payout_user ON creator_payout(user_id,requested_at DESC);
CREATE UNIQUE INDEX IF NOT EXISTS idx_creator_payout_client ON creator_payout(user_id,client_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_creator_payout_active_user ON creator_payout(user_id)
  WHERE status IN ('requested','processing');

CREATE TRIGGER IF NOT EXISTS livestream_tip_apply
AFTER INSERT ON livestream_tip
BEGIN
  SELECT RAISE(ABORT,'LIVE_NOT_ACTIVE') WHERE
    COALESCE((SELECT nilai FROM setelan WHERE kunci='livestream_enabled'),'0')!='1' OR
    NOT EXISTS(SELECT 1 FROM livestream WHERE id=NEW.livestream_id AND user_id=NEW.creator_id AND status='live') OR
    NOT EXISTS(SELECT 1 FROM users WHERE id=NEW.creator_id AND deleted_at IS NULL AND COALESCE(diblokir,0)=0) OR
    NOT EXISTS(SELECT 1 FROM users WHERE id=NEW.viewer_id AND deleted_at IS NULL AND COALESCE(diblokir,0)=0);
  SELECT RAISE(ABORT,'SELF_TIP') WHERE NEW.viewer_id=NEW.creator_id;
  SELECT RAISE(ABORT,'BALANCE_LOW')
    WHERE COALESCE((SELECT saldo FROM users WHERE id=NEW.viewer_id),0)<NEW.gross;
  UPDATE users SET saldo=saldo-NEW.gross WHERE id=NEW.viewer_id;
  INSERT INTO transaksi(id,user_id,judul,tipe,nominal,status,waktu)
    VALUES('livetip_out_'||NEW.id,NEW.viewer_id,'Dukungan livestream','live_tip',-NEW.gross,'sukses',NEW.created_at);
  INSERT INTO creator_earning(id,user_id,livestream_id,tip_id,gross,platform_fee,net,status,available_at,created_at,updated_at)
    VALUES('earn_'||NEW.id,NEW.creator_id,NEW.livestream_id,NEW.id,NEW.gross,NEW.platform_fee,NEW.creator_net,
           'held',datetime(NEW.created_at,'+7 days'),NEW.created_at,NEW.created_at);
  UPDATE livestream SET gross_tip=gross_tip+NEW.gross,creator_net=creator_net+NEW.creator_net,updated_at=NEW.created_at
    WHERE id=NEW.livestream_id;
END;

CREATE TRIGGER IF NOT EXISTS livestream_tip_reverse_guard
BEFORE UPDATE OF status ON livestream_tip
WHEN OLD.status != NEW.status
BEGIN
  SELECT RAISE(ABORT,'INVALID_TIP_TRANSITION')
    WHERE OLD.status!='charged' OR NEW.status!='reversed';
  SELECT RAISE(ABORT,'TIP_ALREADY_IN_PAYOUT') WHERE NOT EXISTS(
    SELECT 1 FROM creator_earning WHERE tip_id=OLD.id AND status IN ('held','available')
  );
  SELECT RAISE(ABORT,'TIP_REVERSE_REASON_REQUIRED')
    WHERE length(trim(COALESCE(NEW.reverse_reason,''))) NOT BETWEEN 8 AND 200
       OR length(trim(COALESCE(NEW.reversed_by,'')))<1;
END;

CREATE TRIGGER IF NOT EXISTS livestream_tip_reverse_apply
AFTER UPDATE OF status ON livestream_tip
WHEN OLD.status='charged' AND NEW.status='reversed'
BEGIN
  UPDATE users SET saldo=saldo+OLD.gross WHERE id=OLD.viewer_id;
  INSERT INTO transaksi(id,user_id,judul,tipe,nominal,status,waktu)
    SELECT 'livetip_refund_'||OLD.id,id,'Pengembalian dukungan livestream','live_tip_refund',OLD.gross,'sukses',NEW.reversed_at
    FROM users WHERE id=OLD.viewer_id;
  UPDATE creator_earning SET status='reversed',updated_at=NEW.reversed_at
    WHERE tip_id=OLD.id AND status IN ('held','available');
  UPDATE livestream SET gross_tip=MAX(0,gross_tip-OLD.gross),creator_net=MAX(0,creator_net-OLD.creator_net),updated_at=NEW.reversed_at
    WHERE id=OLD.livestream_id;
END;

CREATE TRIGGER IF NOT EXISTS creator_payout_reserve
BEFORE INSERT ON creator_payout
BEGIN
  SELECT RAISE(ABORT,'CREATOR_NOT_VERIFIED') WHERE NOT EXISTS(
    SELECT 1 FROM creator_profile WHERE user_id=NEW.user_id AND status='approved' AND payout_verified=1
  );
  SELECT RAISE(ABORT,'PAYOUT_BELOW_MINIMUM') WHERE NEW.amount < COALESCE(
    (SELECT CAST(nilai AS INTEGER) FROM setelan WHERE kunci='livestream_min_payout'),100000
  );
  SELECT RAISE(ABORT,'PAYOUT_AMOUNT_CHANGED') WHERE NEW.amount != COALESCE((
    SELECT SUM(net) FROM creator_earning WHERE user_id=NEW.user_id AND status='available'
  ),0);
END;

CREATE TRIGGER IF NOT EXISTS creator_payout_reserve_after
AFTER INSERT ON creator_payout
BEGIN
  UPDATE creator_earning SET status='reserved',payout_id=NEW.id,updated_at=NEW.requested_at
    WHERE user_id=NEW.user_id AND status='available';
END;

CREATE TRIGGER IF NOT EXISTS creator_payout_transition
BEFORE UPDATE OF status ON creator_payout
WHEN OLD.status != NEW.status
BEGIN
  SELECT RAISE(ABORT,'INVALID_PAYOUT_TRANSITION') WHERE NOT (
    (OLD.status='requested' AND NEW.status IN ('processing','paid','rejected')) OR
    (OLD.status='processing' AND NEW.status IN ('paid','rejected'))
  );
  SELECT RAISE(ABORT,'PAYOUT_LEDGER_MISMATCH') WHERE NEW.status IN ('paid','rejected')
    AND OLD.amount != COALESCE((SELECT SUM(net) FROM creator_earning WHERE payout_id=OLD.id AND status='reserved'),0);
  SELECT RAISE(ABORT,'PAYOUT_REFERENCE_REQUIRED')
    WHERE NEW.status='paid' AND length(trim(COALESCE(NEW.provider_ref,'')))<4;
  SELECT RAISE(ABORT,'PAYOUT_REJECTION_REASON_REQUIRED')
    WHERE NEW.status='rejected' AND length(trim(COALESCE(NEW.note,'')))<8;
END;

CREATE TRIGGER IF NOT EXISTS creator_payout_complete
AFTER UPDATE OF status ON creator_payout
WHEN OLD.status != NEW.status
BEGIN
  UPDATE creator_earning SET status='paid',updated_at=NEW.processed_at
    WHERE payout_id=NEW.id AND status='reserved' AND NEW.status='paid';
  UPDATE creator_earning SET status='available',payout_id=NULL,updated_at=NEW.processed_at
    WHERE payout_id=NEW.id AND status='reserved' AND NEW.status='rejected';
END;

INSERT OR IGNORE INTO setelan(kunci,nilai,diperbarui) VALUES('livestream_enabled','0',CURRENT_TIMESTAMP);
INSERT OR IGNORE INTO setelan(kunci,nilai,diperbarui) VALUES('livestream_platform_fee_bps','2000',CURRENT_TIMESTAMP);
INSERT OR IGNORE INTO setelan(kunci,nilai,diperbarui) VALUES('livestream_min_tip','5000',CURRENT_TIMESTAMP);
INSERT OR IGNORE INTO setelan(kunci,nilai,diperbarui) VALUES('livestream_max_tip','500000',CURRENT_TIMESTAMP);
INSERT OR IGNORE INTO setelan(kunci,nilai,diperbarui) VALUES('livestream_min_payout','100000',CURRENT_TIMESTAMP);
INSERT OR IGNORE INTO setelan(kunci,nilai,diperbarui) VALUES('livestream_max_minutes','240',CURRENT_TIMESTAMP);
INSERT OR IGNORE INTO setelan(kunci,nilai,diperbarui) VALUES('livestream_max_concurrent','2',CURRENT_TIMESTAMP);
