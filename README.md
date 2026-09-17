# XyCloudStore — Premium Edition

Aplikasi **Flutter (Android)** untuk layanan XyCloud: **Sewa PC Cloud**, **Beli Akun Digital**, **Customer Service realtime**, **Riwayat Order**, dan **Dompet** — terhubung ke backend **Cloudflare Workers + D1 + Durable Objects**.

Desain: modern, clean, quick. Tanpa satu pun emoji — seluruh ikon memakai sistem ikon vektor (Material Icons di Flutter, SVG kustom di preview).

**Preview interaktif:** buka `preview/xycloudorder-preview.html` di browser. Alurnya lengkap: Splash → Onboarding → Welcome → Login → Aplikasi.

---

## Pembaruan v3.8.0 (menunggu build final)

Streaming game end-to-end dengan reconnect adaptif dan diagnostik, editor HUD/preset komunitas, atribusi instalasi referral anti-fraud, Facebook OAuth bertiket, Pakasir terverifikasi, moderasi Groq privacy-gated, direct message realtime, serta control-plane livestream kreator PC rental. Seluruh workflow build/deploy bersifat manual.

APK dan Agen Windows dipublikasikan melalui repo source-free [`XyCloudStore-build`](https://github.com/xykalnotkel/XyCloudStore-build); source utama akan diprivatkan setelah rilis publik pengganti terverifikasi.

## Pembaruan v2.6.0

Quiet Surface (tanpa neon/glow), batas 2 pendaftaran per identitas perangkat, OTP/email atomik, sesi akun yang dapat dicabut, pengelolaan pengguna/Sampah/permanen, menu audit/media/perangkat, sajian gambar WebP/AVIF dan cache stiker terenkripsi di folder internal aplikasi.

Panduan dan batas perlindungan: [docs/rilis-2.6.0.md](docs/rilis-2.6.0.md). Pengguna perlu masuk ulang setelah hardening sesi; saldo dan riwayat tetap ada. Package APK dan signing key tidak diubah.

## Pembaruan v2.5.1

**Streaming native dalam satu APK**, pairing otomatis ke Sunshine melalui agen 1.1.0, alur sewa nyata/idempoten, timestamp komentar relatif, stiker transparan, retensi CS 7 hari, serta pengaturan streaming dan channel/nada Android.

Panduan dan batas verifikasi: [docs/rilis-2.5.1.md](docs/rilis-2.5.1.md). Aplikasi terintegrasi memakai GPLv3; source lengkap menyertai rilis. Lihat [native/README.md](native/README.md).

## Pembaruan v2.4.0

Tema gelap menyeluruh, perbaikan keluar/hapus akun, banner lebih tinggi, komentar bertingkat dengan stiker terenkripsi di koleksi lokal, sinkronisasi nama, serta floating promo/pop-up untuk aplikasi dan web. Email laporan harian sudah dihapus.

Panduan penggunaan, batas stiker, dan aktivasi GIPHY: **[docs/rilis-2.4.0.md](docs/rilis-2.4.0.md)**. Pencarian GIPHY membutuhkan API key di menu **Stiker & GIPHY**; galeri/koleksi tetap berjalan tanpanya.

## Isi Repository

```
xycloud/
├─ app/                              Aplikasi Flutter
│  ├─ pubspec.yaml                   deps + config icon & native splash
│  ├─ assets/brand/                  logo, adaptive icon, splash mark (PNG)
│  ├─ test/app_test.dart
│  └─ lib/
│     ├─ main.dart
│     ├─ core/     config, theme (design system), motion, prefs, format
│     ├─ models/   UserProfile, PcPlan, RentOrder, AkunProduk, ChatMessage
│     ├─ data/     api_client, realtime_service, repository, mock_data
│     ├─ providers/app_state.dart
│     └─ ui/
│        ├─ widgets/common.dart      XyCard, GradientButton, Pill, LiveDot,
│        │                           ProgressRing, Shimmer, AuroraBackground,
│        │                           DotGrid, FadeInUp, XyLogo, GradientThumb
│        └─ screens/                 splash, onboarding, welcome, login,
│                                    flow_gate, shell, home, sewa_pc, checkout,
│                                    order_detail, order_list, akun, cs, wallet
├─ api/                              Backend Cloudflare
│  ├─ src/index.js                   Worker REST + Durable Object RealtimeHub
│  ├─ schema.sql                     tabel D1 + seed
│  └─ wrangler.toml
├─ preview/xycloudorder-preview.html
└─ .github/workflows/                deploy/bootstrap manual (build berada di repo publik)
```

---

## Alur Layar

| Tahap | Isi |
|---|---|
| **Splash** | Logo beranimasi, orbit partikel, progress bar, label PREMIUM EDITION. Native splash (`flutter_native_splash`) tampil lebih dulu supaya tidak ada layar putih. |
| **Onboarding** | 3 slide dengan ilustrasi digambar sendiri (rig PC dengan meter GPU/CPU/RAM, kartu akun bertumpuk, gelombang realtime). Indikator dinamis, tombol Lewati, status disimpan di `SharedPreferences` sehingga hanya muncul sekali. |
| **Welcome** | Latar midnight + konstelasi animatif, headline, statistik sosial, CTA Masuk / Daftar. |
| **Login / Daftar** | Satu layar dua mode, validasi form, toggle password, ingat email, serta OAuth Google/Facebook dengan handoff bertiket. |
| **Aplikasi** | Bottom nav 5 tab dengan pill indikator beranimasi. |

## Fitur Aplikasi

| Modul | Isi |
|---|---|
| **Beranda** | Kartu saldo midnight dengan angka menghitung naik, menu cepat, kartu sesi berjalan, carousel PC, banner promo, akun terlaris |
| **Sewa PC** | 4 paket, filter region/ready, bar okupansi realtime, spesifikasi lengkap |
| **Checkout** | Pilihan durasi 1–24 jam, diskon 10% untuk 8 jam ke atas, 3 metode bayar, ringkasan biaya |
| **Detail Order** | Kartu status, ring progres provisioning, timeline 5 langkah, countdown per detik, kredensial RDP dengan tombol salin |
| **Beli Akun** | Grid produk, badge diskon, kategori + pencarian, bottom sheet detail, dialog kredensial |
| **Customer Service** | Live chat, indikator mengetik, quick reply, badge notifikasi |
| **Dompet** | Top up cepat, riwayat transaksi berkategori |

## Realtime

`RealtimeService` menukar bearer HTTPS dengan capability WebSocket room-bound berumur 60 detik, lalu membuka Durable Object dengan **reconnect exponential backoff + jitter** dan **ping/pong** tiap 25 detik. Bearer sesi tidak masuk URL. Reconnect selalu mengambil ticket baru dan layar DM memakai event realtime dengan polling 30 detik hanya sebagai fallback.

Event dari server:

```json
{"type":"order.update",  "payload":{ "...order" }}
{"type":"stock.update",  "payload":{"id":"pc-gaming","unitTersedia":3}}
{"type":"chat.message",  "payload":{"dari":"cs","teks":"Halo kak","waktu":"..."}}
{"type":"cs.typing",     "payload":{"typing":true}}
{"type":"wallet.update", "payload":{"saldo":275000}}
```

---

## Build via GitHub Actions

Tidak ada build otomatis. Workflow dijalankan **manual hanya setelah izin eksplisit pemilik** melalui repo publik source-free [`XyCloudStore-build`](https://github.com/xykalnotkel/XyCloudStore-build). Repo itu checkout source privat memakai deploy key read-only; secret penandatangan tidak pernah dipersist ke Git.

Yang dilakukan CI:

1. Setup Java 17 + Flutter 3.24.5 (dengan cache)
2. `flutter create . --platforms=android --org id.xycloud`
3. `flutter pub get`
4. Generate adaptive launcher icon (`flutter_launcher_icons`)
5. Generate native splash (`flutter_native_splash:create`)
6. Set label aplikasi jadi **XyCloudStore** dan pastikan izin `INTERNET`
7. `flutter analyze` + `flutter test`
8. Build APK **universal** dan **split-per-ABI**
9. Upload APK universal/per-ABI sebagai artifact terpisah serta corresponding-source bundle GPL

Input opsional saat run manual:

| Input | Default | Fungsi |
|---|---|---|
| `mock` | `false` | `true` = jalan dengan data demo tanpa server |
| `base_url` | `https://api.xycloud.my.id` | Base URL API XyCloud |
| `source_ref` | `main` | Branch/tag/commit source privat yang harus dibangun |

Jalankan workflow pada tag versi di repo build untuk sekaligus membuat GitHub Release publik. Input `source_ref` mengunci branch/tag/commit source yang dibangun. Urutan operasi lengkap ada di [arsitektur dua repositori](docs/repository-build-architecture-2026-09-17.md).

### Build lokal

```bash
cd app
flutter create . --platforms=android --org id.xycloud --project-name xycloud_order
flutter pub get
dart run flutter_launcher_icons
dart run flutter_native_splash:create
flutter run                       # mode demo
flutter build apk --release       # APK rilis
```

Sambungkan ke server sungguhan:

```bash
flutter build apk --release \
  --dart-define=XY_MOCK=false \
  --dart-define=XY_BASE_URL=https://api.xycloud.my.id
```

---

## Deploy Backend Cloudflare

Produksi tidak boleh diinisialisasi ulang dari `schema.sql`. Gunakan workflow manual **Deploy API Worker + D1**, ketik frasa `DEPLOY API`, lalu workflow akan menjalankan install terkunci, seluruh test, migrasi D1 yang belum tercatat, pemasangan secret Groq, deploy Worker, dan smoke test.

Untuk pengembangan lokal saja:

```bash
cd api
npm ci
npm test
npm run db:migrate:local
npm run dev
```

### Endpoint

| Method | Path | Fungsi |
|---|---|---|
| POST | `/api/auth/login`, `/api/auth/register` | autentikasi (token HMAC) |
| GET | `/api/pc/plans` | daftar paket PC |
| GET | `/api/akun/produk` | katalog akun |
| GET | `/api/banners` | banner slider beranda |
| GET, POST | `/api/orders` | list dan buat order sewa |
| GET | `/api/orders/:id` | detail order |
| POST | `/api/akun/beli` | beli akun, kredensial otomatis |
| GET | `/api/wallet/transaksi` | riwayat dompet |
| POST | `/api/wallet/topup` | top up saldo |
| GET, POST | `/api/cs/messages` | riwayat dan kirim chat |
| POST | `/api/cs/reply` | balasan dari dashboard admin |
| POST / WS | `/api/ws/ticket` → `/ws/user:<id>?ticket=…` | capability room-bound dan channel realtime user |
| WS | `/ws/katalog` | channel stok unit dan banner |
| WS | `/ws/cs:inbox` | channel dashboard CS |
| GET | `/admin` | dashboard admin dan CS (butuh admin key) |
| GET, POST, PATCH, DELETE | `/api/admin/*` | API dashboard, header `x-admin-key` |

---

## Fitur v1.4.0

### Login sosial sungguhan
Alur OAuth dijalankan di server: aplikasi membuat verifier acak, mengirim challenge SHA-256 serta
identitas instalasi saat membuka `/api/auth/{provider}/start`, lalu pengguna menyetujui di halaman
resmi Google atau Facebook. Callback hanya kembali melalui `xycloudstore://auth?code=...` dengan
handoff sekali pakai berumur dua menit. Aplikasi menukar code + verifier melalui
`POST /api/auth/social/exchange`; token sesi 30 hari hanya pernah dikirim di body respons HTTPS dan
disimpan di secure storage, bukan di custom-scheme URL. Flow browser tidak membutuhkan Firebase.
Tombol yang tampil di aplikasi mengikuti `GET /api/config`, jadi penyedia yang belum dikonfigurasi
otomatis disembunyikan.

Syarat Google: tambahkan `https://api.xycloud.my.id/api/auth/google/callback` pada Authorized redirect
URIs di Google Cloud Console. Facebook membutuhkan `FACEBOOK_APP_ID`, `FACEBOOK_APP_SECRET`, exact
redirect URI, mode Live, serta callback penghapusan data. Lihat [panduan setup Meta dan checklist keamanan](docs/facebook-login-meta-setup-2026-09-16.md).

**Login Google native pada versi terbaru:** membutuhkan OAuth client Android dengan package name dan SHA-1 sertifikat APK rilis. Web client tetap digunakan sebagai `serverClientId`; jangan diganti dengan Android client. Lihat [panduan konfigurasi beserta fingerprint APK](docs/login-google.md).

### Dompet dengan pembayaran nyata
Provider utama adalah **Pakasir** (QRIS + Virtual Account), dengan adaptor Tripay dan Midtrans tetap
tersedia. Pengguna menerima checkout/nomor bayar, aplikasi memantau status, dan saldo masuk setelah
server mengambil Transaction Detail dari provider serta mencocokkan project, order ID, dan nominal.
Webhook tidak pernah cukup untuk mengkredit saldo—khusus Pakasir, ini wajib karena provider tidak
mendokumentasikan signature webhook.

Kredit saldo, buku besar, dan perubahan status dijalankan dalam satu batch D1 dengan klaim unik
`topup_credit`, sehingga webhook, polling, cron, atau klik admin yang bersamaan tidak dapat menambah
saldo dua kali. Dashboard **Top Up** menampilkan kesehatan integrasi, webhook ditolak, rekonsiliasi,
provider/status transaksi, dan biaya. Tagihan gateway tidak boleh disetujui manual kecuali override
pemilik dengan frasa konfirmasi serta alasan audit.

Aktifkan Pakasir memakai Worker Secret `PAKASIR_PROJECT` dan `PAKASIR_API_KEY`, lalu pasang webhook
`https://api.xycloud.my.id/bayar/webhook/pakasir` pada proyek Pakasir. Jangan simpan API key di tabel
`setelan`. Klien Payment UI v2 menerima seluruh metode Pakasir; APK lama otomatis dibatasi ke
hosted QRIS agar tetap kompatibel. Jika tidak ada provider valid, sistem memakai jalur manual: kode
unik 3 digit, rekening, unggah bukti, dan persetujuan admin. Variabel non-rahasia: `PAYMENT_PROVIDER`, `BANK_NAMA`,
`BANK_NOMOR`, `BANK_ATASNAMA`, `QRIS_URL`, `MIN_TOPUP`, dan `MAX_TOPUP`.

### Moderasi AI yang dapat diaudit
Filter deterministik tetap menjadi lapisan pertama untuk forum, komentar, ulasan, profil publik, dan
preset HUD. Provider utama adalah Groq `openai/gpt-oss-20b` dengan Structured Outputs JSON Schema
ketat. Secret khusus XyCloudStore sudah disimpan terenkripsi untuk workflow, tetapi Worker hanya
boleh mengirim konten setelah Zero Data Retention organisasi dikonfirmasi dan rollout dimulai dalam
mode `shadow` sebelum `enforce` pada menu **Moderasi → AI Safety**.

Pesan privat/Chat Admin tidak pernah dikirim ke AI. D1 hanya menyimpan HMAC konten, verdict,
kategori, latency, dan jumlah token—bukan teks, prompt, atau respons mentah. Gangguan provider
bersifat fail-open setelah filter lokal dan AI tidak pernah menjatuhkan sanksi akun otomatis. Lihat [runbook moderasi AI](docs/ai-moderation-openrouter-2026-09-16.md).

### Produk akun lengkap
Kolom baru: `gambar`, `deskripsi`, `detail` (peta spesifikasi), `jumlah_ulasan`. Dashboard bisa
mengunggah gambar langsung dari komputer (otomatis ke Cloudinary) dan mengisi detail baris per baris.

### Ulasan dan rating
Tabel `ulasan` menyimpan rating 1-5, komentar, foto opsional, dan balasan admin. Rata-rata rating
produk dihitung ulang otomatis setiap ada ulasan baru atau yang dihapus. Menu **Ulasan** di dashboard
dipakai untuk membalas atau menghapus.

### Chat seperti WhatsApp
Dua arah realtime lewat WebSocket, kini mendukung kirim gambar (aplikasi dan dashboard), indikator
mengetik, tanda dibaca, dan tombol pindah ke WhatsApp memakai nomor pada `WA_ADMIN`.
Nomor WhatsApp yang diisi saat mendaftar tampil di dashboard sebagai tautan `wa.me` pada inbox CS,
daftar pengguna, dan daftar top up.

---

## SEO dan Mesin Pencari

| Berkas | Isi |
|---|---|
| `/robots.txt` | mengizinkan semua perayap kecuali `/admin` dan `/api/`, menunjuk ke peta situs |
| `/sitemap.xml` | delapan alamat: beranda, sewa, akun, komunitas, unduh, bantuan, dan dua halaman legal |
| `/brand/og.png` | gambar berbagi 1200x630 bergaya ungu dengan wordmark dan tagline |

Setiap halaman memperbarui judul, deskripsi, `canonical`, dan `og:url` secara langsung saat
berpindah. Data terstruktur JSON-LD memuat Organization, WebSite, MobileApplication, dan FAQPage.

## Deteksi Arsitektur Perangkat

Sebelumnya halaman unduh menebak semua Android modern sebagai ARM 64-bit, sehingga pemilik HP
32-bit ikut disarankan berkas 64-bit. Penyebabnya: peramban hanya mengirim `Sec-CH-UA-Arch`
dan `Sec-CH-UA-Bitness` kalau server memintanya lebih dulu.

Sekarang Worker mengirim `Accept-CH` dan `Critical-CH` pada setiap halaman, lalu keputusan
diambil berjenjang:

1. Petunjuk resmi peramban (`architecture` dan `bitness`)
2. String peramban (`aarch64`, `armv7`, `x86_64`)
3. Versi Android (5 ke bawah pasti 32-bit)
4. Kalau tetap tidak pasti, **tidak menebak**: berkas universal yang disarankan

Pengguna juga bisa menentukan sendiri lewat tombol 32-bit atau 64-bit yang tersimpan di peramban.
Aturan kecocokan: perangkat 32-bit hanya boleh ARM 32-bit dan universal, perangkat 64-bit boleh
ketiganya, dan berkas yang tidak cocok dinonaktifkan.

## Memesan Lewat Situs

Situs kini bukan sekadar etalase. Setelah masuk dengan akun yang sama dengan aplikasi,
pengguna bisa menyewa PC (pilih durasi, bayar dengan saldo), membeli akun digital,
mengisi saldo, serta melihat halaman **Akun Saya** berisi saldo, pesanan, dan riwayat transaksi.
Pendaftaran baru di situs juga melewati verifikasi kode email yang sama.

---

## Pengembang

XyCloudStore dikembangkan oleh **XyVerse**, studio kecil Indonesia.
Logo XyVerse dipakai sebagai kredit pengembang (baris "Built by XyVerse" di splash,
menu Tentang aplikasi, dan kaki halaman situs). Logo & ikon APLIKASI XyCloudStore
(`app/assets/brand/logo_icon*.png` + `wordmark*.png`) terpisah dan tetap dipakai
untuk launcher, splash, serta ikon notifikasi push.

## Pemeliharaan Sistem

| Bagian | Keterangan |
|---|---|
| Pemeliharaan otomatis | Penjadwal Cloudflare berjalan tiap jam: menghapus kode OTP kedaluwarsa, membersihkan penghitung pembatas laju, menutup sesi menggantung lebih dari 12 jam, menandai unit yang tidak melapor, membatalkan top up manual yang tidak dibayar 24 jam, dan memangkas catatan sistem lebih dari 30 hari |
| Mode pemeliharaan | Sakelar di dashboard. Saat menyala, seluruh API pengguna menjawab 503 dengan pesan yang bisa diatur. Dashboard dan agen PC tetap jalan |
| Singgahan | Tombol kosongkan singgahan tepi untuk halaman unduh, info rilis, dan logo email |
| Kesehatan layanan | Cek langsung D1, Resend, OneSignal, Cloudinary, Google OAuth, dan penyedia pembayaran beserta waktu tanggap basis data |
| Statistik | Pengguna, omzet, saldo beredar, top up, produk, unit, sesi, komunitas, grafik 30 hari, produk dan paket terlaris |

---

## Situs Web Publik

Worker yang sama juga melayani situs `xycloud.my.id` dan `www.xycloud.my.id`.
Rutenya dipilih berdasarkan host:

| Host | Isi |
|---|---|
| `xycloud.my.id`, `www.xycloud.my.id` | situs publik (`api/src/web.html`) |
| `admin.xycloud.my.id` | dashboard admin dan CS |
| `api.xycloud.my.id` | API, gambar, unduhan, halaman legal |

Seluruh isi situs ditarik langsung dari D1 lewat API yang sama dengan aplikasi:
paket PC, produk akun beserta ulasan, diskusi komunitas beserta balasan dan lencana member,
nomor WhatsApp, serta daftar rilis aplikasi. Tidak ada data yang ditulis dua kali.

### Unduhan aplikasi

Berkas APK tidak pernah ditautkan langsung ke GitHub. Semua lewat domain sendiri:

```
https://xycloud.my.id/unduh/XyCloudStore-arm64-v8a.apk
```

Worker mengambil berkas dari rilis, menyimpannya di singgahan tepi Cloudflare, lalu
mengirimkannya dengan `Content-Disposition` yang benar. Daftar berkas dan ukurannya
tersedia di `GET /api/rilis`, disegarkan tiap sepuluh menit.

### Deteksi perangkat

Pemilihan berkas dilakukan dua lapis:

1. **Sisi server** membaca `User-Agent` dan `Sec-CH-UA-Arch`, hasilnya ikut di `GET /api/rilis`.
2. **Sisi peramban** memakai `navigator.userAgentData.getHighEntropyValues` untuk memastikan
   arsitektur dan lebar bit, lalu memilih berkas yang paling pas.

Aturannya: petunjuk Intel memilih `x86_64`, petunjuk `armv7` memilih `armeabi-v7a`, dan
petunjuk ARM 64-bit memilih `arm64-v8a`. Jika arsitektur tidak pasti, sistem tidak menebak dan
menawarkan berkas universal. Pengguna tetap bisa memilih sendiri dari daftar semua versi.

### Referral teratribusi instalasi

Tautan `/unduh?ref=KODE` sekarang membuat ticket acak 256-bit yang hanya disimpan sebagai
HMAC di D1. Unduhan APK rilis ditandai server, lalu tombol **Buka aplikasi & aktifkan
undangan** menyerahkan ticket ke Android melalui `xycloudstore://referral`. Reward baru cair
setelah `PackageManager.firstInstallTime` membuktikan paket dipasang sesudah klik/unduh,
aplikasi mengikat ticket ke identitas perangkat, akun dibuat sesudah klik, perangkat pendaftaran
cocok, email terverifikasi, bukan self-referral, dan ticket belum pernah dipakai. Mengetik kode
saja tidak memberi saldo. Karena distribusi berupa sideload, timestamp/identitas klien tetap bukan
pengganti Play Integrity atau hardware attestation pada perangkat yang telah dikompromikan.
Rollout dikunci oleh `referral_install_aktif` dan baru dinyalakan setelah APK berisi
`ReferralActivity` dirilis. Rincian: `docs/batch-r-referral-install-attribution-2026-09-16.md`.

---

## Sesi Main (remote PC untuk game)

Sewa PC tidak lagi berhenti di kredensial RDP. Sekarang ada siklus sesi penuh:

| Tahap | Yang terjadi |
|---|---|
| `menyiapkan` | Server memilih unit menganggur, mengirim perintah ke agen di PC, mesin dibersihkan |
| `siap` | Sunshine siap menerima sambungan, aplikasi menampilkan alamat host |
| `pairing` | Penyewa mengetik PIN dari aplikasi streaming, server meneruskannya ke agen, agen memasukkannya ke Sunshine |
| `berjalan` | Perangkat terpasang, penyewa main. Timer berjalan di agen dan di aplikasi |
| `selesai` / `gagal` | Sesi ditutup, perangkat dilepas, mesin dibersihkan, unit kembali menganggur |

Endpoint pengguna: `POST /api/sesi/mulai`, `GET /api/sesi/:id`, `POST /api/sesi/:id/pin`,
`POST /api/sesi/:id/stream`, `GET /api/sesi/:id/diagnostik`, `POST /api/sesi/:id/telemetri`,
dan `POST /api/sesi/:id/akhiri`. Diagnostik menguji sampel port TCP dari jaringan Cloudflare;
UDP tetap harus diperiksa pada router/firewall host. Telemetri hanya menyimpan state/jalur/
latensi/kualitas—tidak pernah input kontrol, audio, gambar, atau isi gameplay.
Endpoint agen (pakai header `x-agen-kode`): `POST /api/agen/heartbeat`, `POST /api/agen/perintah/:id`.
Admin: `GET/POST /api/admin/agen`, `DELETE /api/admin/agen/:id`, `GET /api/admin/sesi`.

Klien Android memiliki watchdog penyambungan 35 detik, fallback publik↔LAN, progres tahap +
waktu, adaptive anti-lag berdasarkan respons awal, dan reconnect bertingkat 2/4/8 detik
(maksimal 3 kali; kualitas diturunkan bertahap). Status tersebut terlihat di layar sesi dan
Dashboard → Sesi PC. Audio host dan gamepad/touch diproses native. Uplink mikrofon HP bukan
bagian protokol GameStream; gunakan Discord di HP atau mikrofon yang terhubung ke PC host.

Program agen untuk PC/VM host ada di folder `agent-gui/` (GUI native
**Rust + egui/eframe**, tanpa Tauri/WebView dan tanpa runtime Python), dengan README berisi panduan pemasangan Sunshine,
daftar port, layanan otomatis, dan alur pembersihan antar penyewa.

Teknologi streaming yang dipakai: **Sunshine** (host) dan **Moonlight/Artemis** (klien),
protokol GameStream dengan encoder NVENC/AMF/QuickSync. RDP tidak dipakai karena tidak
mampu melayani game.

---

## Notifikasi Push

| Kejadian | Siapa yang menerima |
|---|---|
| Status order berubah | pemilik order |
| Balasan customer service | pemilik percakapan |
| Top up disetujui atau ditolak | pemilik permintaan |
| Balasan diskusi forum | pemilik diskusi dan semua yang pernah membalas |
| Balasan admin di forum | pemilik diskusi dan peserta diskusi |
| Diskusi disukai | pemilik diskusi, maksimal sekali per 30 menit per diskusi |
| Pengumuman admin | semua pengguna yang memasang aplikasi |
| Banner promo baru | semua pengguna, kalau opsi kirim push dicentang |

Pengguna dapat mematikan notifikasi komunitas, DM, dan livestream serta membisukan thread tertentu. Pemberitahuan pesanan, Chat Admin, dan saldo tetap aktif karena bersifat transaksional.

---

## Keamanan

| Lapisan | Penerapan |
|---|---|
| Password | PBKDF2-HMAC-SHA256 210.000 iterasi, salt acak 128-bit, hash 256-bit; akun plaintext/SHA-256 lama dimigrasikan saat login |
| Token | HMAC-SHA256, berlaku 30 hari, terikat `session_version`; WebSocket privat memakai ticket 60 detik |
| Penyimpanan di perangkat | `flutter_secure_storage` (EncryptedSharedPreferences Android) |
| Pembatas laju | Tabel `batas` di D1, per IP untuk login, daftar, kirim kode, reset, dan admin |
| Dashboard | Admin key hanya per-tab, key tambahan disimpan sebagai HMAC, RBAC per peran, CSP/anti-framing/anti-sniff, dan output pengguna di-escape |
| Login Google native | ID token diverifikasi ke Google: penerbit, audiens, masa berlaku, status email |
| Rahasia | Semua kunci hanya sebagai secret Worker atau GitHub Secrets, tidak pernah masuk repo |

## Legal

Syarat dan Ketentuan serta Kebijakan Privasi ditulis di `api/src/legal.js` dan disajikan dua cara:
halaman web (`/legal/syarat`, `/legal/privasi`) dan JSON untuk aplikasi (`/api/legal/...`).
Daftar lisensi pihak ketiga ikut di dalamnya, dan aplikasi juga menyediakan teks lisensi resmi
bawaan Flutter lewat `showLicensePage`.

---

## Identitas Merek

- Nama: **XyCloudStore**
- Warna utama: ungu `#6C2BE2`, ungu pekat `#4A12B8`, ungu terang `#8B5CF6`, lavender `#C4B5FD`
- Tanpa warna neon. Aksen emas `#D9A441` hanya untuk rating dan tier.
- Logo resmi ada di `app/assets/brand/` (ikon, wordmark, versi putih) dan dipakai di splash, onboarding,
  welcome, login, dashboard admin, serta ikon launcher.
- Ilustrasi di `app/assets/ilustrasi/` dibuat dengan AI bergaya 3D glosi ungu, disimpan sebagai
  WebP terkompresi. Aset yang membutuhkan latar transparan memakai alpha asli; checkerboard yang
  sempat tertanam pada ilustrasi blokir dibersihkan dengan mask terkontrol tanpa menghapus gembok putih.

## Domain

| Alamat | Fungsi |
|---|---|
| `https://api.xycloud.my.id` | API dan WebSocket aplikasi |
| `https://admin.xycloud.my.id` | dashboard admin dan CS |
| `https://xycloud-api.akuntiktok76y.workers.dev` | alamat cadangan otomatis |

Aplikasi memakai domain utama; kalau tidak bisa dihubungi, `ApiClient` otomatis pindah ke alamat cadangan.

---

## Dashboard Admin dan CS

Dashboard web ikut dibundel di dalam Worker, jadi tidak perlu hosting terpisah.

- URL: `https://admin.xycloud.my.id` atau `https://api.xycloud.my.id/admin`
- Masuk dengan **admin key** (`wrangler secret put ADMIN_KEY`), tersimpan di browser.

Yang bisa dikerjakan dari dashboard:

| Menu | Fungsi |
|---|---|
| Dashboard | jumlah pengguna, order, order berjalan, pendapatan, grafik 7 hari |
| Order | ubah status order; status `aktif` otomatis mengisi host, user, dan password lalu mendorong push realtime ke aplikasi |
| Paket PC | tambah, ubah, hapus paket sewa beserta harga dan stok unit |
| Produk Akun | kelola katalog akun digital (harga, stok, garansi, fitur) |
| Banner Slider | kelola banner beranda; perubahan langsung tampil di aplikasi tanpa update APK |
| Inbox CS | balas chat pengguna secara realtime, lengkap dengan indikator mengetik |
| Pengguna | lihat daftar akun dan sesuaikan saldo dompet |

Semua perubahan katalog dan banner disiarkan lewat WebSocket, aplikasi menerimanya tanpa perlu refresh manual.

---

## Menandatangani APK

APK rilis ditandatangani otomatis oleh GitHub Actions memakai keystore yang disimpan sebagai secret repository:

| Secret | Isi |
|---|---|
| `KEYSTORE_BASE64` | isi berkas `.jks` dalam base64 |
| `KEY_ALIAS` | alias kunci |
| `STORE_PASSWORD` | password keystore |
| `KEY_PASSWORD` | password kunci |

Membuat keystore baru:

```bash
keytool -genkeypair -v -keystore xycloud-release.jks -alias xycloud \
  -keyalg RSA -keysize 2048 -validity 10950
base64 -w0 xycloud-release.jks > keystore.b64
```

Saat build, workflow menulis `android/key.properties` lalu menjalankan `tools/patch_signing.py`
untuk menyisipkan `signingConfigs.release` ke berkas Gradle, dan memverifikasi hasilnya dengan `apksigner`.
Berkas keystore tidak pernah masuk ke repository.

---

## Email (Resend) dan Push (OneSignal)

### Email transaksional

Worker mengirim email lewat Resend memakai template ungu XyCloudStore (`api/src/mail.js`):

| Kejadian | Email |
|---|---|
| Daftar akun | kode verifikasi 6 digit, berlaku 15 menit |
| Verifikasi berhasil | email selamat datang |
| Lupa password | kode reset 6 digit |
| Beli akun digital | kredensial akun + struk pembayaran |
| Order sewa berubah jadi aktif | alamat RDP, username, password, durasi |

Pengaturan: `MAIL_FROM` dan `PUBLIC_URL` ada di `wrangler.toml`, kunci `RESEND_API_KEY` disimpan sebagai secret.
Logo untuk email dilayani Worker di `/brand/logo.png`.

Verifikasi email **wajib**: akun baru berstatus `email_verified = 0` dan harus memasukkan kode
sebelum bisa dipakai. Login dengan akun yang belum terverifikasi otomatis mengirim kode baru
dan aplikasi langsung membuka layar OTP.

Endpoint auth:

| Method | Path | Fungsi |
|---|---|---|
| POST | `/api/auth/register` | daftar, kirim kode verifikasi |
| POST | `/api/auth/verify` | tukar kode jadi token |
| POST | `/api/auth/resend` | kirim ulang kode (`tipe`: verifikasi / reset) |
| POST | `/api/auth/forgot` | minta kode reset password |
| POST | `/api/auth/reset` | pasang password baru |

### Push notification

`api/src/push.js` mengirim push lewat OneSignal saat status order berubah, saat CS membalas chat,
dan saat banner promo baru dibuat dengan opsi "Kirim notifikasi push". Aplikasi memakai
`onesignal_flutter` dan mengaitkan perangkat ke `external_id` = id pengguna, jadi kiriman selalu
tepat sasaran.

App OneSignal yang dipakai: **XyCloudStore** (`f4843c35-cc1d-4772-9f70-1c4349397ffb`).
Kredensial **Firebase FCM v1 (Service Account JSON)** sudah terpasang di app ini
(project `xycloud-c19f1`), jadi push Android siap terkirim begitu ada perangkat yang
memasang aplikasi dan berlangganan.

Perhatian (perbaikan 2026-09-13): akun OneSignal ini punya app kedua bernama **XyDesk**
(`e3d5adea-…`) yang tidak dipakai proyek ini, dan REST API key OneSignal bersifat per-app
(tidak saling tukar). Secret Worker `ONESIGNAL_API_KEY` sempat berisi key milik XyDesk
sehingga seluruh kiriman push gagal autentikasi diam-diam; sekarang sudah diisi key milik
XyCloudStore. Bila menyalin key lagi dari dashboard, pastikan ambil dari app XyCloudStore.

App ID dipakai di dua tempat: variabel `ONESIGNAL_APP_ID` pada `api/wrangler.toml` (sisi server) dan
`--dart-define=XY_ONESIGNAL_APP_ID` pada workflow build (sisi aplikasi). REST API key disimpan sebagai
secret Worker `ONESIGNAL_API_KEY`.

Menu **Email & Push** di dashboard admin bisa dipakai untuk menguji keduanya.

---

## Integrasi ke web XyCloud yang sudah ada

1. **Worker sebagai gateway** — ubah handler di `api/src/index.js` agar `fetch()` ke API web kamu, Durable Object tetap dipakai untuk push realtime. Paling cepat.
2. **Langsung ke API web kamu** — ganti `XyConfig.baseUrl` di app. Semua `fromJson` di `models.dart` sudah menerima gaya `snake_case` maupun `camelCase`.

Push pesan realtime dari sisi admin:

```bash
curl -X POST https://api.xycloud.my.id/api/cs/reply \
  -H "Authorization: Bearer <token-admin>" \
  -H "Content-Type: application/json" \
  -d '{"room":"user:u_001","teks":"Order kakak sudah kami proses ya"}'
```

---

## Sebelum produksi

- Pastikan webhook Pakasir telah diisi di dashboard provider dan jalankan rekonsiliasi dari dashboard admin.
- Untuk moderasi AI, pasang key OpenRouter yang valid, verifikasi tanpa konten, lalu jalankan mode `shadow` sebelum `enforce`.
- Simpan semua kredensial hanya sebagai Cloudflare Worker Secret; tabel `setelan` hanya untuk nilai non-rahasia.
- Hubungkan fungsi provisioning ke agen/hypervisor PC rental yang telah diotorisasi dan dipantau.
- Verifikasi push, email, login sosial, pembayaran sandbox, dan jalur pemulihan sebelum menerima transaksi nyata.
- Simpan berkas keystore rilis di tempat aman; kalau hilang, aplikasi tidak bisa diperbarui di Play Store.
