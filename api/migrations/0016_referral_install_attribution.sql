-- Batch R: referral berbasis atribusi unduh + pembukaan aplikasi.
-- Token mentah tidak pernah disimpan; kolom id berisi HMAC/hash token.
-- Tetap gelap sampai APK yang memuat ReferralActivity benar-benar dirilis.
INSERT OR IGNORE INTO setelan (kunci,nilai) VALUES ('referral_install_aktif','0');
CREATE TABLE IF NOT EXISTS referral_attribution (
  id TEXT PRIMARY KEY,
  pengundang TEXT NOT NULL,
  kode TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'diklik',
  clicked_at TEXT NOT NULL,
  expires_at TEXT NOT NULL,
  downloaded_at TEXT,
  download_variant TEXT,
  installed_at TEXT,
  package_installed_at TEXT,
  package_updated_at TEXT,
  device_id TEXT,
  claimed_by TEXT,
  claimed_at TEXT,
  click_ip_hash TEXT,
  click_ua_hash TEXT,
  claim_ip_hash TEXT,
  risiko TEXT,
  FOREIGN KEY (pengundang) REFERENCES users(id),
  FOREIGN KEY (claimed_by) REFERENCES users(id)
);

CREATE INDEX IF NOT EXISTS idx_referral_attr_pengundang
  ON referral_attribution(pengundang, clicked_at DESC);
CREATE INDEX IF NOT EXISTS idx_referral_attr_status
  ON referral_attribution(status, expires_at);
CREATE UNIQUE INDEX IF NOT EXISTS idx_referral_attr_claimed_by
  ON referral_attribution(claimed_by) WHERE claimed_by IS NOT NULL;

ALTER TABLE referral ADD COLUMN attribution_id TEXT;
ALTER TABLE referral ADD COLUMN kode TEXT;
ALTER TABLE referral ADD COLUMN sumber TEXT NOT NULL DEFAULT 'legacy';
ALTER TABLE referral ADD COLUMN device_id TEXT;
ALTER TABLE referral ADD COLUMN risiko TEXT;

-- Satu akun undangan hanya boleh menerima satu referral, termasuk endpoint
-- yang terpanggil ulang atau dua permintaan yang berlomba.
CREATE UNIQUE INDEX IF NOT EXISTS idx_referral_diundang_unique
  ON referral(diundang);
CREATE UNIQUE INDEX IF NOT EXISTS idx_referral_attribution_unique
  ON referral(attribution_id) WHERE attribution_id IS NOT NULL;

-- Pertahanan terakhir di lapisan basis data: endpoint tidak boleh membuat
-- referral diri sendiri atau memberi bonus dua kali.
CREATE TRIGGER IF NOT EXISTS referral_guard_before_insert
BEFORE INSERT ON referral
BEGIN
  SELECT RAISE(ABORT, 'REFERRAL_SELF')
    WHERE NEW.pengundang = NEW.diundang;
  SELECT RAISE(ABORT, 'REFERRAL_INVITEE_USED')
    WHERE EXISTS (SELECT 1 FROM referral WHERE diundang = NEW.diundang)
       OR EXISTS (SELECT 1 FROM users WHERE id = NEW.diundang AND diundang_oleh IS NOT NULL);
  SELECT RAISE(ABORT, 'REFERRAL_USER_MISSING')
    WHERE NOT EXISTS (SELECT 1 FROM users WHERE id = NEW.pengundang)
       OR NOT EXISTS (SELECT 1 FROM users WHERE id = NEW.diundang);
  SELECT RAISE(ABORT, 'REFERRAL_ATTRIBUTION_REQUIRED')
    WHERE NEW.status = 'selesai' AND NOT EXISTS (
      SELECT 1 FROM referral_attribution a
       WHERE a.id = NEW.attribution_id AND a.pengundang = NEW.pengundang
         AND a.kode = NEW.kode AND a.device_id = NEW.device_id
         AND a.downloaded_at IS NOT NULL AND a.installed_at IS NOT NULL
         AND a.package_installed_at IS NOT NULL AND a.claimed_by IS NULL AND datetime(a.expires_at) > datetime('now')
    );
END;

-- Reward, buku besar, relasi akun, dan konsumsi tiket terjadi dalam transaksi
-- INSERT yang sama. ID transaksi deterministik membuat retry tetap idempoten.
CREATE TRIGGER IF NOT EXISTS referral_reward_after_insert
AFTER INSERT ON referral
WHEN NEW.status = 'selesai'
BEGIN
  UPDATE users SET saldo = saldo + NEW.bonus_pengundang
    WHERE id = NEW.pengundang;
  UPDATE users SET saldo = saldo + NEW.bonus_diundang,
                   diundang_oleh = NEW.pengundang
    WHERE id = NEW.diundang AND diundang_oleh IS NULL;

  INSERT OR IGNORE INTO transaksi (id,user_id,judul,tipe,nominal,status)
    VALUES ('ref_inviter_' || NEW.id, NEW.pengundang,
            'Bonus undang teman', 'topup', NEW.bonus_pengundang, 'sukses');
  INSERT OR IGNORE INTO transaksi (id,user_id,judul,tipe,nominal,status)
    VALUES ('ref_invitee_' || NEW.id, NEW.diundang,
            'Bonus dari teman', 'topup', NEW.bonus_diundang, 'sukses');

  UPDATE referral_attribution
     SET status = 'diklaim', claimed_by = NEW.diundang,
         claimed_at = COALESCE(NEW.selesai, datetime('now')),
         risiko = COALESCE(NEW.risiko, risiko)
   WHERE id = NEW.attribution_id AND claimed_by IS NULL;
END;
