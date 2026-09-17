## Unduh siap pakai

- **Permanent:** https://github.com/xykalnotkel/XyCloudStore-build/releases/download/agent-windows/XyCloudStore-Agent-Windows.zip
- Actions artifact: workflow **Build Agen Windows**

> EXE lama yang error `localhost refused to connect` = build Tauri tanpa UI embed.
> Mulai **v1.5** agen dibangun **native (egui/eframe)** — masalah WebView tidak mungkin terjadi lagi.

# Agen PC Host XyCloudStore (Rust + egui native, v1.5)

Program kecil di setiap PC/VM sewa. Menyambungkan mesin ke server XyCloudStore supaya
sesi **dinyalakan, dipasangkan, dan ditutup otomatis** dari aplikasi HP.

**v1.5** — GUI **native egui/eframe**: satu exe mandiri, **tanpa Tauri, tanpa WebView2,
tanpa jendela terminal**. Logika inti (`agent.rs`) tetap sama persis dengan build lama
(dipakai ulang lewat `#[path]`), jadi perilaku heartbeat/perintah/auto-setup tidak berubah.
Konfigurasi juga tetap dibaca dari lokasi lama — upgrade cukup timpa exe.

```
Aplikasi (HP)          Server Cloudflare            Agen (Rust) di PC        Sunshine
     |  Mulai Main  ->        |                          |                       |
     |                        |  simpan sesi + perintah  |                       |
     |                        |  <-- heartbeat 20 dtk    |                       |
     |                        |  --> perintah mulai      |                       |
     |                        |                          |  bersihkan mesin     |
     |                        |                          |  cek API 47990  -->  |
     |  status: siap  <--     |  <-- lapor siap          |                       |
     |  kirim PIN     ->      |  --> perintah pasangkan  |                       |
     |                        |                          |  POST /api/pin  -->  |
     |  status: berjalan <--  |  <-- lapor berhasil      |                       |
```

Agen hanya keluar ke server + API lokal Sunshine. Port streaming Sunshine
(47984/47989 TCP, 48010 TCP, 47998–48002 UDP) tetap dibuka ke internet bila perlu.

## Struktur

| Path | Isi |
|---|---|
| `agent-gui/src-native/src/main.rs` | **GUI native egui** (pengaturan, uji koneksi, setup engine, mulai/stop, log, autostart) |
| `agent-gui/src-tauri/src/agent.rs` | Inti agen: heartbeat, perintah, `sunshine --creds`, winget, autostart — **dipakai ulang build native** |
| `agent-gui/src-tauri/` + `agent-gui/ui/` | Build Tauri lama (legacy, tidak lagi dipakai CI) |

## Setup di PC (3 klik)

1. **Admin** → [Unit PC](https://admin.xycloud.my.id/unit) → Daftarkan unit → **salin kode**.
2. Unduh `XyCloudStore-Agent.exe` (artifact CI / rilis) → jalankan (dobel klik, tanpa terminal).
3. Jendela agen:
   - **1 · Unit** — tempel kode unit (+ server bila bukan default) → **Simpan**
   - **2 · Engine** — **Setup Engine** (winget + `sunshine --creds`, tanpa web UI)
   - **3 · Jalan** — **Mulai Agen** (+ centang autostart Windows bila mau)

Opsi lanjutan (username/password Sunshine) hanya jika mau pakai akun yang sudah ada.

## CLI

```powershell
.\XyCloudStore-Agent.exe --veri          # cek versi (smoke-test CI)
.\XyCloudStore-Agent.exe -Jalankan       # headless loop (dipakai entri autostart registry)
```

## Hasil uji Engine

| Status | Arti |
|---|---|
| `API_SIAP` | Kredensial OK, API 47990 merespons |
| `API_TIDAK_SESUAI` | Sunshine hidup tapi auth ditolak — ulang auto-setup |
| `KREDENSIAL_KOSONG` | Belum setup — klik *Setup Engine* |
| `TIDAK_TERHUBUNG` | Service/exe belum jalan |

## Keamanan

- API Sunshine hanya `127.0.0.1:47990` (self-signed, diterima longgar).
- Server hanya memerintahkan agen dengan **kode unit** valid.
- Sandi lokal di `%APPDATA%\XyCloudStore\Agent\config.json` (akun Windows itu saja).

## Build

CI: `.github/workflows/agent-windows.yml` → artifact `XyCloudStore-Agent-Windows.zip`
(runs-on `windows-latest`, cukup `cargo build --release` — tanpa tauri-cli).

```powershell
cd agent-gui/src-native
cargo build --release --locked
# hasil: target/release/xycloud-agent.exe  → didistribusikan sebagai XyCloudStore-Agent.exe
```

Build legacy Tauri (masih ada di repo untuk referensi):

```powershell
cd agent-gui/src-tauri
cargo tauri build --no-bundle --ci
```
