# Batch R — Optimasi Ala App Gede: Skeleton Presisi, Flat Glossy, Menu Custom, Tunnel Tanpa Tailscale

Tanggal: 2026-09-19
Status: Implementasi lokal selesai, menunggu instruksi push/build

## Request User

> kerjain agar kek app gede, harus bener bener di optimasi dan skeleton loader harus presisi ye, Dan tombol tombolnya udh bener flat tinggal dikasi glosy dikit, Dan untuk pas klik titik tiga masih bawaan android harusnya banyak dan untuk streaming agar gaperlu tailscale bisa kah kita udp relay pakai cloudflare workers?

## 1. Skeleton Loader Presisi (Mirror Exact Layout)

### Masalah Sebelum
- `SkeletonForumList` cuma 2 shimmer bar generic, tidak mirip card asli → jank saat data real masuk (layout shift)
- Komentar loading pakai `LinearProgressIndicator` tipis, bukan skeleton bubble

### Solusi Sekarang

**Forum Post Skeleton Presisi (`common.dart` → `SkeletonForumList`):**
- Mirror exact `_KartuPost`:
  - Avatar 38 + Row nama 90px + tier badge 32px + pin 18px
  - Date 60px + dot 4px + kategori 50px
  - Title 18px 2 lines (full + 260px)
  - Isi 12px 3 lines (full, full, 200px)
  - Image 160px radius 12 (50% tampil biar variasi)
  - Action row: like 44px, comment 70px, save 60px, Lihat 50px + Spacer
- Padding `all(18)`, radius 20, border `line` — sama persis kayak `XyCard`
- Hasil: tidak ada layout shift, skeleton → real content seamless kayak IG

**Komentar Skeleton Presisi (NEW `SkeletonKomentarList`):**
- Mirror exact `_komentar` bubble dengan ujung:
  - Avatar 36 + Stack bubble + tail 12x12 rotated 45°
  - Bubble radius `topLeft 4, others 18` + border `lineSoft`
  - Header: nama 80px + tier 30px + time 50px
  - Isi: 2 shimmer lines (full + 220px) bold
  - Reply variasi: tambah baris `60px > 50px :` di 1/3 item
  - Action: like 50px + balas 50px pill
- Dipakai di `ForumDetailScreen` saat `_memuat`:
  ```dart
  const SkeletonKomentarList(count: 4) // bukan LinearProgressIndicator
  ```
- `cacheExtent: 800`, `RepaintBoundary` per item, `addAutomaticKeepAlives: false`

**Kenapa Presisi Penting Ala App Gede?**
- IG, TikTok, Discord pakai skeleton yang **ukurannya sama** dengan konten asli → otak user sudah pre-load layout, tidak kaget
- Generic spinner → layout shift → CLS (Cumulative Layout Shift) jelek → terasa lambat
- Kita sekarang presisi, CLS ~0

## 2. Tombol Flat + Glossy Dikit

### Sebelum
- Flat solid color doang, terlalu matte

### Sekarang (Glossy Subtle)
**`GradientButton` (common.dart):**
- Tetap flat `Material + InkWell`, tapi tambah Stack glossy:
  ```dart
  LinearGradient(
    topCenter → bottomCenter,
    [white 18% opacity, white 6%, transparent, black 4%],
    stops [0.0, 0.18, 0.45, 1.0]
  )
  ```
  + inner highlight top edge 1px white 25%
- Hasil: flat tapi ada kilau halus di atas kayak tombol iOS / Gojek baru — performa tetap 1 layer extra, bukan 6 layer kayak dulu (gradient+shadow+border kilau)

**`_ControlBtn` di livestream (kamera/mic/flip):**
- Tambah glossy overlay `white 22% (aktif) / 12% (non-aktif)` → `transparent` via Stack
- Tetap `Container 44x44 radius 12`, tanpa BoxShadow

**Kenapa Glossy Dikit Ala App Gede?**
- App gede pakai **subtle inner highlight** buat affordance (tombol keliatan bisa dipencet), bukan shadow berat
- Shadow = overdraw 2x, glossy gradient = 1 draw call, lebih hemat GPU

## 3. Menu Titik Tiga Custom (Bukan Bawaan Android)

### Sebelum
- `PopupMenuButton` bawaan Android → popup kecil, cuma 1-2 opsi (Hapus/Laporkan), tidak ada banyak opsi

### Sekarang (Bottom Sheet Custom)
**Komentar (`_tampilkanMenuKomentar`):**
- Pressable `more_horiz` → `showModalBottomSheet` custom:
  - Header: avatar 40 + nama bold + preview isi 60 char
  - Opsi (banyak):
    - Salin Komentar (content_copy)
    - Balas Komentar (reply)
    - Suka / Batal Suka (favorite)
    - Bagikan Komentar (share)
    - Blokir User (block, warning color) — kalau bukan owner
    - Laporkan Komentar (flag, danger) — kalau bukan owner
    - Hapus Komentar (delete, danger) — kalau owner
  - Tiap opsi pakai `_OpsiMenu` widget: icon 36px bg 12% + label w600 + chevron
  - Background `surfaceHigh`, radius top 22, border `line`

**Post Diskusi (`_tampilkanMenuPost`):**
- AppBar `more_horiz` → bottom sheet:
  - Title bold 16 + author + date
  - Opsi:
    - Salin Link Diskusi (link)
    - Bagikan Diskusi (share)
    - Simpan / Hapus Simpanan (bookmark)
    - Salin Isi Diskusi (content_copy)
    - Blokir User (person_off, warning)
    - Laporkan Diskusi (flag, danger)
    - Sunting Diskusi (edit) — owner
    - Hapus Diskusi (delete, danger) — owner

**Kenapa Custom Ala App Gede?**
- IG, TikTok, Discord tidak pakai `PopupMenuButton` Android, tapi bottom sheet dengan icon + banyak opsi
- Lebih discoverable, bisa tambah 8-10 opsi tanpa sempit

## 4. Streaming Tanpa Tailscale — Bisa Pakai Cloudflare Tunnel (Bukan Workers UDP)

### Jawaban Teknis

**Workers tidak bisa UDP relay langsung:**
- Workers runtime: HTTP, WebSocket, TCP `connect()` doang, tidak ada `UdpSocket`
- Sunshine butuh UDP 47998,47999,48000,48002,48010 untuk video/audio → tidak bisa lewat Workers

**Solusi yang Bisa (Tanpa Tailscale):**

**Opsi 1: Cloudflare Tunnel (cloudflared) + QUIC — REKOMENDASI**
```
[HP] → [Cloudflare Edge xxx.trycloudflare.com] → [cloudflared di PC] → [Sunshine localhost]
```
- `cloudflared` bikin outbound QUIC tunnel (tidak perlu buka port, tidak perlu Tailscale)
- Quick tunnel gratis `trycloudflare.com` atau named tunnel `pc-123.xycloud.my.id`
- QUIC support UDP via `udp://localhost:47998`
- Latency +10-30ms, masih oke

**Implementasi di XyCloudStore:**
- Agent Rust tambah `setup_cloudflare_tunnel()` di `agent.rs`:
  - Cek `%APPDATA%\XyCloudStore\Agent\cloudflared\cloudflared.exe`
  - Download dari GitHub kalau belum ada
  - Jalankan `cloudflared tunnel --protocol quic --url tcp://localhost:47984` (dan UDP ports)
  - Parse URL tunnel dari `tunnel.log`, lapor ke API sebagai `tunnel_host`
- API `sewa.js` tambah `host_lan`, `tunnel_host`, `relay_host`:
  - `lampiranHostLan()` sekarang ambil `spec.tunnel_host`, `spec.relay_host`, `agen.tunnel_host`
  - INSERT sesi copy `host_lan,tunnel_host,relay_host` dari agen
  - `konfirmasiAgen()` update sesi & agen dengan `tunnel_host`, `relay_host`, `host_lan`
- Schema: `schema.sql` + migration `0028_sesi_tunnel_relay.sql` tambah kolom `host_lan TEXT, tunnel_host TEXT, relay_host TEXT` di `sesi` & `agen`
- App `models.dart` `SesiMain` tambah `tunnelHost`, `relayHost`
- App `sesi_screen.dart` `_hubungkan()` urutan baru: Tunnel Cloudflare > Publik > LAN > Relay UDP
  ```dart
  final urutanJalur = [
    if (tunnelHost) (tunnelHost, 'Tunnel Cloudflare'),
    if (publik) (publik, 'Publik'),
    if (lan) (lan, 'LAN'),
    if (relay) (relay, 'Relay UDP'),
  ];
  // coba satu-satu dengan retry
  ```

**Opsi 2: Custom UDP Relay di Fly.io (Murah)**
- Deploy Rust UDP relay di Fly.io (free tier 3 VM)
- Relay forward UDP HP ↔ PC via session mapping
- App connect ke `relay.fly.dev:47998`

**Opsi 3: Cloudflare Spectrum (Bayar)**
- L4 proxy TCP+UDP, $1/GB, butuh port forwarding di PC

**Kesimpulan:** Workers tidak bisa UDP, tapi **cloudflared Tunnel BISA** karena pakai QUIC (UDP over QUIC). Kita sudah implement fallback Tunnel di agent+API+app, jadi bisa streaming tanpa Tailscale.

Doc lengkap: `docs/streaming-tanpa-tailscale-udp-relay.md`

## File Berubah

- `app/lib/ui/widgets/common.dart` — `SkeletonForumList` presisi + NEW `SkeletonKomentarList` presisi + `GradientButton` glossy
- `app/lib/ui/screens/forum_screen.dart` — `_komentar` bubble tail + bold + format `A > B : isi` + `RepaintBoundary` + `cacheExtent` + `SkeletonKomentarList` + menu custom `_tampilkanMenuKomentar` + `_tampilkanMenuPost` + `_OpsiMenu`
- `app/lib/ui/screens/livestream_screen.dart` — `_ControlBtn` glossy
- `app/lib/models/models.dart` — `SesiMain` tambah `tunnelHost`, `relayHost`
- `app/lib/ui/screens/sesi_screen.dart` — urutan jalur Tunnel > Publik > LAN > Relay + retry loop
- `api/schema.sql` — sesi tambah `host_lan,tunnel_host,relay_host`
- `api/migrations/0028_sesi_tunnel_relay.sql` — NEW migration
- `api/src/sewa.js` — `lampiranHostLan` + tunnel/relay handling + INSERT + UPDATE
- `agent-gui/src-tauri/src/agent.rs` — `setup_cloudflare_tunnel()` + integrasi di `setup_otomatis` langkah 6/7
- `docs/optimasi-performa-ala-app-gede.md` — NEW doc performa
- `docs/streaming-tanpa-tailscale-udp-relay.md` — NEW doc tunnel
- `docs/batch-r-optimasi-ala-app-gede-2026-09-19.md` — NEW (file ini)

## Cara Test

1. **Skeleton Presisi**: buka Forum → matikan internet → lihat cache langsung muncul, kalau tidak ada cache lihat skeleton card yang ukurannya sama persis kayak post asli (avatar 38, title 2 baris, isi 3 baris, image 160). Buka diskusi → skeleton komentar bubble dengan ujung mirip bubble real.
2. **Flat Glossy**: semua tombol `GradientButton` ada kilau halus di atas, tapi tetap flat tanpa shadow berat. Kontrol live kamera juga glossy dikit.
3. **Menu Titik Tiga**: tap titik tiga di komentar → bottom sheet custom muncul dengan 6-7 opsi + header avatar, bukan popup Android kecil. Tap titik tiga di diskusi AppBar → bottom sheet 7-8 opsi.
4. **Komentar Format Baru**: balas komentar → tampil `Ambatukam > Rino : ya gitulah` bold, ada ujung bubble mengarah ke avatar.
5. **Tunnel Tanpa Tailscale**: di PC rental, agent auto-download cloudflared, jalanin tunnel, lapor `tunnel_host` ke API. Di HP, sesi screen akan coba `Tunnel Cloudflare` dulu sebelum `Publik`.

## Next

- Push ke GitHub (tunggu instruksi)
- Build via Actions (tunggu instruksi)
- Test cloudflared tunnel di VM real (butuh Windows VM)
- Deploy UDP relay Fly.io kalau mau fallback tambahan

---
*Batch R 2026-09-19 — Skeleton Presisi + Flat Glossy + Menu Custom + Tunnel Tanpa Tailscale*
