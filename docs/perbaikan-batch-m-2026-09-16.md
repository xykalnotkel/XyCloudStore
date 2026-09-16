# Batch M — 2026-09-16

Permintaan pemilik (update-terbaru-nih.txt): lanjutkan tugas agent sebelumnya;
streaming Sunshine di-custom (pilihan kontrol bawaan vs XyCloudStore, HUD
lengkap QWERTY/F1-F12/Win/numpad, posisi & ukuran custom, panel kontrol,
latency bagus, log jelas, **lock rasio landscape walau headless, lebar
auto-fit**); layar blokir & maintenance (sebelumnya "diarahkan ke onboarding");
angka onboarding 19k palsu → data nyata; profil lebih lengkap (pengaturan,
customize, badge, bingkai animasi banyak, tier animasi, layout berantakan,
foto profil ada lingkaran putih); kategori wallet jadi 1 card besar; komunitas
(view/visit profil orang, follow, bingkai tidak terlihat, alur, balas
komentar, "convert gif ga berjalan"); optimasi super lancar; admin dashboard
belum semua berfungsi; **Cloudinary eror saat update banner — tes**; keamanan
login ketat terutama daftar (blokir email temp); Terms/Legal/Policy + "login di
negara mana"; minimal 10+ saran; boleh tidak repo utama di-private + build di
repo lain.

## Streaming — kontrol XyCloudStore (aplikasi native, bukan webview)

- **HUD native Android** (`XyHud.java` ditulis ulang bersih, 5 bug lama
  diperbaiki): keyboard QWERTY 5 baris + 2 baris simbol opsional, panel F-key
  (Esc/Tab/F1-F12/Caps), numpad 4 kolom (7 8 9 / — 4 5 6 * — 1 2 3 - — 0 . + —
  Enter), tombol Win/Ctrl/Alt/Shift **toggle** (bisa Win+R, Win+D, Ctrl+C,
  dst. — state modifier ikut ke setiap tombol berikutnya), scale 0.7–1.4,
  posisi drag bebas, semua tersimpan di SharedPreferences `xy_hud_v1`,
  tombol melayang "XY" untuk memunculkan lagi saat disembunyikan.
- **Panel kontrol** (`XyPanel.java`, tombol ☰): pilih mode kontrol default
  XyCloudStore vs bawaan Moonlight (radio live, langsung disimpan), log
  streaming real-time (auto-refresh 1.5 dtk, Muat ulang / Salin / Bersihkan),
  catatan cara pakai, tombol "Akhiri Video" dengan konfirmasi.
- **Kirim kunci langsung** (`xySendKey`/`xySendText` di-patch ke Game.java
  Moonlight oleh `tools/siapkan_streaming.py`): bypass gate keyboard-grab,
  terjemahan scancode via KeyboardTranslator + fallback Unicode, modifier
  state dari HUD. Patch lama `xyTapKey` dihapus.
- **Pilihan mode di app**: `opsi_screen` + SwitchListTile "Kontrol bawaan
  (Moonlight)" → `NativeStream.setKontrolBawaan` → native (menyembunyikan
  HUD + pref `bawaan`); default = kontrol XyCloudStore. Catatan jujur di
  panel: kontrol layar bawaan Moonlight tetap ada (tidak ada toggle resmi di
  runtime).
- **Log jelas**: `XyLog.tulis` kini ikut `NativeStreaming.emitLog` → event
  `log` → sesi_screen menampilkan **panel log live** (8 baris terakhir, mono)
  di samping coaching error yang sudah ada (port 47984-47990 + 48010, NSG,
  LAN fallback, reset sertifikat BC).
- **Lock rasio landscape walau headless + lebar auto-fit** (dua sisi):
  - **Host (agent)**: `setup_otomatis` dapat **Langkah 5/5** —
    `kunci_lanskap_sunshine()` menulis opsi `dd_*` Sunshine lewat
    `POST /api/config`: `dd_configuration_option=ensure_primary`,
    `dd_resolution_option=manual`, `dd_manual_resolution=1920x1080`,
    `dd_refresh_rate_option=manual`, `dd_manual_refresh_rate=60`. Display
    virtual (PC headless) ikut dikunci landscape.
  - **Client (Game.java patch)**: permukaan video dipaksa
    `setDesiredAspectRatio(16.0/9.0)` (selain mode stretch) — lebar
    auto-fit ke layar, video di-letterbox di dalam permukaan 16:9;
    `prefConfig.optimizeGameSettings=true` agar Sunshine menerapkan
    resolusi manual-nya saat stream mulai.
- **Agent v1.5.4**: log headless tak lagi hilang —
  `tulis_log_headless()` menulis `%APPDATA%\XyCloudStore\Agent\agent.log`
  (stempel ISO-8601 UTC via `stempel_iso()`, rotasi 1MB → `agent.log.old`,
  error ditelan supaya loop tak pernah crash). `cargo check` bersih.
- Tes: `flutter analyze` 0 error, 17/17 widget test lulus, `npm test` API
  26/26, `cargo check` agent OK.

## Keamanan — blokir email disposable di pendaftaran

- `emailDisposable()` + list ~60 domain sekali-pakai (mailinator, tempmail,
  10minutemail, guerrillamail, yopmail, sharklasers, getnada, trashmail,
  dispostable, dll.) di `api/src/index.js`.
- `/auth/register`: setelah validasi format → **403** + log
  `catatLog(env,'keamanan',…)` (IP + email). Login akun lama tidak
  terpengaruh; password minimum tetap 6 (konsisten dengan validator app).
- Email `example.invalid`/`example.com` di test tidak kena — 26/26 tetap lulus.

## Cloudinary — hasil tes langsung (2026-09-16)

Tes end-to-end dengan kredensial produksi (cloud `jxjvz3qi`):

| Uji | Hasil |
|---|---|
| Upload gambar (signed) | ✅ 200, `secure_url` valid |
| Transformasi `f_webp,q_78,c_limit,w_800,h_800` (tanpa & dengan versi) | ✅ 200 `image/webp` |
| Route produksi `GET /img/…` via `api.xycloud.my.id` | ✅ 200 webp, byte identik |
| Upload GIF animasi (8 frame) → delivery | ✅ asli tersaji, 8 frame tetap (loop=0) |
| Upload MP4 → `f_gif,fps_12,w_480,c_limit` | ✅ 200 `image/gif` GIF89a valid |
| Destroy (pembersihan) | ✅ ok |

**Kesimpulan: pipeline banner/Cloudinary bekerja.** Eror "update banner" yang
rasa-rasanya terjadi karena **aset video terhapus dari akun Cloudinary** —
bukan karena upload-nya gagal. Bukti forensik:
- `media_assets` mencatat 6 MP4 banner profil (diunggah 1–2 hari terakhir);
  keenamnya kini **404** di Cloudinary (termasuk milik user VIP yang
  "convert gif ga berjalan" — URL `f_gif`-nya 404 → banner jadi gradasi).
- Kode worker **tidak pernah memanggil `destroy`**; antrian `media_hapus`
  kosong → penghapusan terjadi dari luar (dashboard Cloudinary atau
  project lain — akun ini dipakai bersama: xyspace, autoclipp, bio-link…).
- Asset uji `xycloudstore/banner-profil/tes-kekal-1789544414.mp4` (dititipkan
  2026-09-16) bertahan >1 jam → bukan purge cepat otomatis.
- Tindakan: worker kini **verifikasi HEAD setelah upload** banner — kalau
  aset tak bisa diakses, user dapat pesan jelas + bisa coba lagi (tidak
  diam-diam dapat banner mati). **Tolong cek dashboard Cloudinary**
  (Auto-delete unused assets / folder banner-profil) dan minta user VIP
  mengunggah ulang videonya.

## Layar blokir & maintenance — tidak lagi "ke onboarding"

- Layar `BlokirScreen` & `PerawatanScreen` sudah ada (sejak Batch J/L) dan
  terpasang di `main.dart`; celah yang membuat user masih melihat
  onboarding: **perangkat yang belum login tak pernah menerima 503**
  (selama pemeliharaan `auth/*` sengaja tetap terbuka).
- Perbaikan: `GET /api/config` kini membawa
  `pemeliharaan:{aktif,pesan}` (pakai `tertutupPemeliharaan()` yang sudah
  memahami cakupan platform + pengecualian staf `pemeliharaan_bebas`);
  `KonfigurasiApp.pemeliharaanAktif` + `muatKonfigurasi()` menyalakan
  `AppState.perawatan` → halaman perawatan tampil juga untuk user yang
  belum login (dengan jalan masuk login untuk staf internal).
- Login akun dibekukan tetap lolos (by design) → app langsung membuka
  BlokirScreen (hitung mundur, alasan, riwayat pelanggaran, form banding,
  chat CS).

## Komunitas & profil

- **Bingkai tidak terlihat di komunitas**: kartu daftar diskusi memakai
  `_Avatar` polos → kini `AvatarBingkai(bingkai: post.bingkai,…)` (sama
  seperti di detail & komentar). Server memang sudah mengirim `bingkai`
  di list/detail/balasan — yang kurang hanya di UI daftar.
- **Tier animasi**: `LencanaTier` PRO/VIP/ADMIN kini ber-shimmer (kilau
  menyapu lencana); BASIC statis. Hanya animasi saat `TickerMode` aktif —
  widget test (TickerMode nonaktif) tetap settle, GPU hemat.
- View/visit profil orang & follow: sudah ada (tap nama/avatar di forum →
  `ProfilPublikScreen`, tombol Ikuti dengan update optimis + rollback,
  lapor ke moderasi). Balas komentar (reply ke komentar) sudah ada.
- Layout profil: foto profil kini `ClipOval` polos (lingkaran putih
  dihapus; tanpa foto → inisial gradasi `_WadahInisial`); kolom nama
  diurutkan nama → @username → slogan → email → bio → chip.
- Statistik onboarding: widget `_StatistikReal` memakai angka nyata dari
  `/api/config` (`statistikPublik`): produksi kini menampilkan
  **37 pengguna** (bukan 19.000). Unit online tampil bila >0.
- Wallet/home: `_MenuCepat` kini **satu card besar** yang membungkus grid
  4 kolom (bukan card-per-item).

## Optimasi kelancaran

- Shimmer tier hanya untuk lencana premium + di-guard `TickerMode` (di
  atas) — daftar forum tak lagi penuh ticker yang tak diperlukan.
- Log live sesi streaming di-throttle (maks 30 entri, 8 baris ditampilkan).
- GIF chat/banner tetap memakai provider native Flutter (byte GIF animasi
  dari Cloudinary sudah diverifikasi utuh) — tidak perlu package tambahan.

## Yang perlu kamu cek/test (kredensial admin tidak di sini)

1. **Admin dashboard**: fungsi-fungsi admin hanya bisa diverifikasi dengan
   login admin — tolong test dari sisi kamu; laporkan fungsi mana yang
   masih error (nama halaman + tombol) agar bisa di-fix langsung.
2. **Cloudinary**: cek dashboard (apakah ada "auto delete unused assets"),
   dan konfirmasi user VIP mengunggah ulang video banner.
3. **Domain `xycloudstore.com`**: domain ini **NXDOMAIN total** sejak hari
   ini (bahkan NS-nya hilang) — app tidak terdampak (pakai
   `api.xycloud.my.id` yang aman), tapi cek di Cloudflare Registrar apakah
   kadaluarsa/terhapus. `xycloud.my.id` sehat (200).

## Saran tambahan (10+)

1. **Auto-screenshot bukti sesi**: agent menjepret layar 5 dtk sebelum
   sesi berakhir → attach di order (bukti main nyata) — kuat untuk sengketa.
2. **Mode low-latency**: preset tombol di opsi sesi (bitrate tinggi +
   AV1/HEVC + FPS 120) satu ketukan; Sunshine 2024 mendukung per-client.
3. **Auto-pairing QR**: QR pairing Sunshine di layar sesi (scan sekali,
   langsung nyambung) — mengurangi gagal pairing manual 4 digit.
4. **Notif agen ke admin (OneSignal)**: agen offline/PC host mati → push ke
   admin + auto-coba unit cadangan bila ada 2+ agen.
5. **Rating per unit (bintang + jumlah)** di kartu sewa, diambil dari order
   selesai (data sudah ada di `orders`) — sosial proof nyata.
6. **Ulasan video 15 dtk** di halaman unit (Cloudinary video ≤15MB sudah
   didukung) — diferensiasi vs marketplace akun.
7. **Cron backup D1 → R2** (dump sqlite harian) + tombol "uji restore" di
   admin — saat ini `cadangan` baru seadanya.
8. **Health-check publik** `https://api.xycloud.my.id/api/health` (status
   worker + D1 + OneSignal + Cloudinary) — bisa dipasang di status page
   sederhana, juga berguna untuk tes regression deploy.
9. **Referral tingkat (tier bonus)**: invite 5 teman → 1 jam sewa gratis
   (kolom `referral` sudah ada) — loop akuisisi organik.
10. **Paket langganan Pro/VIP bulanan** (auto-debit via payment gateway,
    bukan topup) — pendapatan berulang untuk fitur bingkai/tier.
11. **Widget "unit online" live di web landing** (`xycloud.my.id`) memakai
    endpoint statistik publik yang sudah ada — CTR lebih tinggi.
12. **Deteksi cheater/multi-akun**: fingerprint perangkat + IP + saldo
    transfer pola (sudah ada `security_devices`/`security_events`) —
    dashboard ringkasan risiko per akun.

## Jawaban: repo utama di-private, build di repo lain?

Bisa, dan tetap gratis — dengan catatan:

- **GitHub Actions gratis** untuk repo **privat** sejak 2020: 2.000 menit +
  2 GB storage/bulan. Build 2 APK (v7a+arm64) biasanya 10–20 menit →
  masih sangat aman.
- Skema yang rapi: repo `XyCloudStore` (source) di-**private**; repo baru
  `XyCloudStore-build` (public) berisi **hanya** pipeline: script yang
  `git clone` repo private lewat **GitHub App / Deploy Key** (bukan PAT
  lama), jalankan CI (flutter build, cargo, wrangler deploy), dan
  mem-publish **artifact APK** + versi. Token Deploy Key/secret tetap di
  Actions secrets — source tidak pernah terekspos.
- Alternatif tanpa repo kedua: tetap 1 repo private + CI di dalamnya;
  APK di-distribusikan lewat **releases private** (hanya member yang bisa
  lihat) atau langsung via `api.xycloud.my.id/unduh` (skema `rilis` D1)
  seperti sekarang. Ini lebih sederhana dan sama-enak.
- Yang **tidak** gratis: Actions di repo *fork* dari repo privat, dan
  menit yang melebihi kuota. Untuk pakai sendiri: aman.

## File yang berubah (ringkas)

- `native/xy_stream/.../XyHud.java` (baru), `XyPanel.java` (baru),
  `XyLog.java` (baru + emitLog), `XyGameActivity.java` (log + hud attach),
  `NativeStreaming.java` (emitLog, setKontrol).
- `tools/siapkan_streaming.py` (patch xySendKey/xySendText, patch
  xy_lanskap 16:9 + optimizeGameSettings).
- `agent-gui/src-tauri/src/agent.rs` (kunci_lanskap_sunshine,
  tulis_log_headless, stempel_iso, langkah 5/5),
  `agent-gui/src-native/src/main.rs` (logger headless ke file).
- `api/src/index.js` (blokir email disposable + log keamanan, verifikasi
  upload banner, field `pemeliharaan` di /api/config).
- `app/lib/...`: models (KonfigurasiApp pemeliharaan), app_state
  (muatKonfigurasi → perawatan), forum_screen (bingkai list + LencanaTier
  shimmer), profil_screen, welcome_screen, home_screen, opsi_screen,
  sesi_screen, blokir_screen (bersih), native_stream (setKontrolBawaan).
