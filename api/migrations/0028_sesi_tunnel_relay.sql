-- Migration 0028: Tambah jalur streaming tanpa Tailscale via Cloudflare Tunnel & UDP Relay
-- Batch Q+ : support tunnel_host (Cloudflare Tunnel) & relay_host (custom UDP relay Fly.io)
-- Untuk streaming tanpa perlu Tailscale / port forward

ALTER TABLE sesi ADD COLUMN host_lan TEXT;
ALTER TABLE sesi ADD COLUMN tunnel_host TEXT;
ALTER TABLE sesi ADD COLUMN relay_host TEXT;

-- Agen juga bisa simpan tunnel_host
ALTER TABLE agen ADD COLUMN tunnel_host TEXT;
ALTER TABLE agen ADD COLUMN relay_host TEXT;

CREATE INDEX IF NOT EXISTS idx_sesi_tunnel_host ON sesi(tunnel_host);
CREATE INDEX IF NOT EXISTS idx_sesi_relay_host ON sesi(relay_host);
CREATE INDEX IF NOT EXISTS idx_agen_tunnel_host ON agen(tunnel_host);
