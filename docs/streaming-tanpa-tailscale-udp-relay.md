# Streaming Tanpa Tailscale — Bisa Pakai Cloudflare Tunnel / UDP Relay?

Tanggal: 2026-09-19
Pertanyaan: "untuk streaming agar gaperlu tailscale bisa kah kita udp relay pakai cloudflare workers?"

## Jawaban Singkat

**Cloudflare Workers saja TIDAK BISA relay UDP** — Workers runtime hanya support HTTP + WebSocket + TCP via `connect()` API, tidak ada raw UDP socket. Jadi kalau langsung `Workers → UDP 47998` tidak bisa.

**Tapi ada 3 solusi tanpa Tailscale yang BISA:**

1. **Cloudflare Tunnel (cloudflared) — REKOMENDASI, gratis, tanpa buka port**
2. **Custom UDP Relay Server di Fly.io / VPS (murah, kita kontrol)**
3. **Cloudflare Spectrum (bayar, enterprise, tapi handle TCP+UDP native)**

Di bawah ini penjelasan + implementasi untuk XyCloudStore.

---

## Kenapa Workers Tidak Bisa UDP?

- Workers = V8 isolate di edge, bukan VM. API `fetch`, `WebSocket`, `connect()` TCP saja.
- Sunshine/Moonlight butuh:
  - TCP 47984, 47989, 47990, 48010 (control, HTTP, RTSP)
  - UDP 47998, 47999, 48000, 48002, 48010 (video, audio, control)
- UDP video tidak bisa lewat Workers HTTP.

**Yang bisa di Workers:**
- Relay TCP control via `connect(host:port)` → `socket` → `WebSocket`
- Tapi video UDP tetap butuh relay lain.

```js
// Workers — hanya TCP, bukan UDP
const socket = connect({ hostname: "1.2.3.4", port: 47984 });
```

---

## Solusi 1: Cloudflare Tunnel (cloudflared) — Tanpa Tailscale, Tanpa Port Forward

Ini yang paling mirip Tailscale tapi pakai Cloudflare edge, bukan WireGuard.

### Cara Kerja

```
[HP Moonlight] → [Cloudflare Edge (xxx.trycloudflare.com)] → [cloudflared di PC Rental] → [Sunshine localhost:47984-48010]
```

- `cloudflared` jalan di PC rental, bikin outbound QUIC tunnel ke Cloudflare edge (tidak perlu inbound port, tidak perlu Tailscale)
- Cloudflare kasih hostname `*.trycloudflare.com` atau custom domain `pc-123.xycloud.my.id`
- HP connect ke hostname itu, Cloudflare proxy TCP+UDP ke PC

### Keuntungan

- Gratis (quick tunnel `trycloudflare.com` tanpa akun, atau named tunnel pakai akun Cloudflare)
- Tidak perlu Tailscale, tidak perlu UPnP, tidak perlu buka firewall router
- Support QUIC → UDP bisa lewat (cloudflared v2023+ dengan `--protocol quic`)
- Latency tambah 10-30ms (via edge terdekat), masih oke untuk cloud gaming

### Implementasi di Agent Rust

Agent sudah punya `buka_upnp_firewall()`, kita tambah `setup_cloudflare_tunnel()`:

```rust
pub fn setup_cloudflare_tunnel(k: &Konfig, log: &Logger) -> Value {
    // 1. Cek cloudflared ada
    let cloudflared = cari_cloudflared_exe().unwrap_or(PathBuf::from("cloudflared"));
    if !cloudflared.exists() {
        log("Download cloudflared...");
        // download dari https://github.com/cloudflare/cloudflared/releases/latest
        download_cloudflared();
    }

    // 2. Buat quick tunnel untuk Sunshine
    // TCP 47984, 47989, 47990, 48010
    // UDP 47998, 47999, 48000, 48002, 48010 via --protocol quic
    let args = vec![
        "tunnel", "--protocol", "quic",
        "--url", "tcp://localhost:47984",
        "--url", "tcp://localhost:47989",
        "--url", "tcp://localhost:47990",
        "--url", "tcp://localhost:48010",
        // UDP — via quic
        "--url", "udp://localhost:47998",
        "--url", "udp://localhost:47999",
        "--url", "udp://localhost:48000",
    ];

    // 3. Jalanin sebagai service background
    let mut cmd = perintah(cloudflared.to_str().unwrap());
    cmd.args(args);
    // simpan log tunnel URL yang keluar: https://xxx.trycloudflare.com

    // 4. Parse URL tunnel dari stdout, kirim ke API sebagai host baru
    // API: POST /api/agen/heartbeat { tunnel_host: "xxx.trycloudflare.com" }

    json!({"ok": true, "tunnel": "https://xxx.trycloudflare.com"})
}
```

### Config Cloudflared (named tunnel, lebih stabil)

`%APPDATA%\XyCloudStore\Agent\cloudflared\config.yml`:

```yaml
tunnel: xycloud-pc-123
credentials-file: C:\Users\...\AppData\Roaming\XyCloudStore\Agent\cloudflared\pc-123.json
protocol: quic
ingress:
  - hostname: pc-123.xycloud.my.id
    service: tcp://localhost:47984
  - hostname: pc-123-47989.xycloud.my.id
    service: tcp://localhost:47989
  - hostname: pc-123-47990.xycloud.my.id
    service: tcp://localhost:47990
  - hostname: pc-123-48010.xycloud.my.id
    service: tcp://localhost:48010
  # UDP via QUIC — cloudflared akan proxy UDP juga
  - service: udp://localhost:47998
  - service: udp://localhost:47999
  - service: udp://localhost:48000
  - service: http_status:404
```

Jalanin: `cloudflared tunnel run xycloud-pc-123`

### Perubahan di API & App

- API `sesi` tambah field `tunnel_host` / `relay_host`
- `app/lib/ui/screens/sesi_screen.dart` `_hubungkan()` coba jalur:
  1. `tunnel_host` (Cloudflare Tunnel) — prioritas kalau ada
  2. `host` publik langsung
  3. `host_lan` (WiFi lokal)

```dart
final hostTunnel = (sesi!.tunnelHost ?? '').trim();
final hostPublik = (sesi!.host ?? '').trim();
final hostLan = (sesi!.hostLan ?? '').trim();

final urutan = [
  if (hostTunnel.isNotEmpty) (hostTunnel, 'Tunnel'),
  if (hostPublik.isNotEmpty) (hostPublik, 'Publik'),
  if (hostLan.isNotEmpty) (hostLan, 'LAN'),
];
for (final (host, label) in urutan) {
  try { return await jajak(host, label); } catch (e) { if (!_masalahJalur(e)) rethrow; }
}
```

### Limitasi Tunnel

- Quick tunnel `trycloudflare.com` URL random tiap restart → perlu named tunnel + custom domain biar stabil
- UDP over QUIC masih beta, kadang packet loss lebih tinggi dari Tailscale direct
- Butuh cloudflared binary ± 30MB di PC rental

---

## Solusi 2: Custom UDP Relay Server (Fly.io / VPS Murah)

Kalau mau kontrol penuh, deploy relay server sendiri yang relay UDP.

### Arsitektur

```
[HP] --UDP 47998--> [Relay Server Fly.io (UDP)] --UDP--> [PC Rental Sunshine]
                    ↑ fronted by Cloudflare (optional)
```

Relay server pakai Rust/Go:

```rust
// udp_relay.rs — super simple
use std::net::UdpSocket;
let sock_client = UdpSocket::bind("0.0.0.0:47998")?;
let sock_host = UdpSocket::bind("0.0.0.0:0")?;
let mut buf = [0u8; 2048];
loop {
    let (len, addr) = sock_client.recv_from(&mut buf)?;
    // addr = HP, forward ke PC
    sock_host.send_to(&buf[..len], "PC_PUBLIC_IP:47998")?;
    let (len2, _) = sock_host.recv_from(&mut buf)?;
    sock_client.send_to(&buf[..len2], addr)?;
}
```

Deploy di Fly.io (global edge, murah):

```toml
# fly.toml
app = "xycloud-udp-relay"
[[services]]
  internal_port = 47998
  protocol = "udp"
  [[services.ports]]
    port = 47998
```

Biaya: Fly.io free tier 3 VM + 160GB bandwidth, cukup untuk 10-20 user concurrent 720p.

### Integrasi

- Agent lapor IP publiknya ke relay server via heartbeat
- Relay simpan mapping `session_id → pc_ip:port`
- HP connect ke `relay.fly.dev:47998` dengan `session_id` di handshake
- Relay forward ke PC yang benar

### Kelebihan vs Tunnel

- UDP native, bukan QUIC-encapsulated → latency lebih rendah
- Bisa pakai Cloudflare Spectrum di depan relay untuk DDoS protection
- Kita kontrol logging, bisa audit

### Kekurangan

- Butuh server tambahan (Fly.io/VPS)
- Harus handle NAT, session mapping, cleanup

---

## Solusi 3: Cloudflare Spectrum (Enterprise, Bayar)

Spectrum = L4 proxy TCP+UDP di Cloudflare edge, tanpa perlu cloudflared di PC.

- PC tetap butuh port forwarding / UPnP buka port publik
- Cloudflare proxy `pc-123.xycloud.my.id:47984` → `PC_PUBLIC_IP:47984`
- DDoS protection, tapi **bayar $1/GB** + $20/bulan per spectrum app
- Tidak cocok untuk free tier

---

## Rekomendasi untuk XyCloudStore

**Jangka pendek (tanpa ubah banyak):**
- Tetap Tailscale sebagai primary (paling stabil, P2P, latency rendah)
- Tambah **Cloudflare Tunnel sebagai fallback** kalau Tailscale gagal / user tidak mau install Tailscale
- Agent auto-setup cloudflared quick tunnel, API simpan `tunnel_host`

**Jangka menengah:**
- Deploy **UDP relay di Fly.io** untuk user yang tidak bisa Tailscale & Tunnel
- App coba urutan: Tunnel → Relay → Publik → LAN

**Jangka panjang:**
- Evaluasi **WebRTC** dengan Cloudflare Calls SFU — ganti Moonlight dengan WebRTC (butuh rewrite native)

### Implementasi Minimal (Yang Bisa Langsung)

1. **Agent**: tambah fungsi `setup_cloudflare_tunnel()` di `agent.rs` (download cloudflared, jalanin quick tunnel, parse URL)
2. **API**: `sesi` tambah kolom `tunnel_host TEXT`, `relay_host TEXT`
3. **App**: `sesi_screen.dart` coba `tunnel_host` dulu sebelum `host` publik
4. **Dashboard**: tampilkan status tunnel di `live_unit_screen.dart`

### Contoh API Perubahan

```sql
ALTER TABLE sesi ADD COLUMN tunnel_host TEXT;
ALTER TABLE sesi ADD COLUMN relay_host TEXT;
```

```js
// api/src/sewa.js — saat buat sesi
const tunnelHost = agen.tunnel_host || null; // dari heartbeat agen
const relayHost = 'xycloud-udp-relay.fly.dev'; // config
return { host, host_lan, tunnel_host: tunnelHost, relay_host: relayHost };
```

---

## Kesimpulan

- **Workers tidak bisa UDP relay** → jangan pakai Workers untuk video UDP
- **Pakai Cloudflare Tunnel (cloudflared) + QUIC** → gratis, tanpa Tailscale, tanpa buka port, cukup install binary di PC rental
- **Atau custom UDP relay di Fly.io** → lebih kontrol, latency lebih rendah, biaya murah
- **Implementasi di XyCloudStore**: tambah `tunnel_host` di sesi, agent auto-setup cloudflared, app coba tunnel dulu

Mau kita implement full Tunnel sekarang atau cukup doc dulu? Kalau mau full, butuh:
- Download cloudflared di agent
- Parse tunnel URL
- Simpan ke heartbeat
- Update app `sesi_screen.dart` urutan koneksi

---

*Ditulis 2026-09-19 — Riset UDP Relay Tanpa Tailscale*
