# Rencana Pembaruan 3.0 — UI/UX, Validasi Transaksi, Multi-select, Maintenance Bertingkat

Dokumen ini merangkum kondisi sekarang (hasil pemetaan) dan rencana perubahan sesuai
permintaan: **UI/UX tetap ungu glossy**, scroll antilag, validasi transaksi tidak langsung
konfirmasi, pindah akun dengan select/select-all, maintenance yang bisa dipilih cakupannya,
serta ilustrasi 3D.

> Status: **Bagian D ✅ · C ✅ · B ✅ · A (fondasi aplikasi glossy + anti-lag) ✅ sebagian**.
> Backend & console belum dideploy — perlu kamu tes dulu (wrangler) sebelum dipakai di produksi.
> Perlu build Flutter & profil perangkat untuk validasi visual/lag akhir (lihat Bagian A).

---

## 1. Temuan saat ini (pemetaan repo)

Struktur:
- `app/` — aplikasi Flutter (Android). Tema ungu ada di `core/theme.dart`.
- `api/` — backend Cloudflare Workers + D1.
  - `index.js` — router utama (Web Worker).
  - `admin.html` — **Console admin** (~1685 baris, semua tampilan dalam satu berkas).
  - `web.html` — **situs publik** (~1695 baris).
  - `sistem.js`, `sewa.js`, `bayar.js`, `akun.js`, dst — modul logika.
- `preview/xycloudorder-preview.html` — demo HTML interaktif.

### Maintenance sekarang = 1 saklar global
- Setting `mode_pemeliharaan` (`'0'`/`'1'`) + `pesan_pemeliharaan`.
- `index.js` (baris ~585): kalau `mode_pemeliharaan==='1'`, **semua** permintaan
  non-admin & non-agen dibalas 503. **Tidak bisa** pilih "web saja / app saja / halaman ini saja".
- App Flutter mendeteksi HTTP 503 → tampilkan `PerawatanScreen`.
- `sistem.js` punya pengaman auto-mati bila lewat batas `pemeliharaan_maks_menit`.

### Transaksi
- **Top up otomatis**: setelah bayar via penyedia → saldo masuk "otomatis dalam hitungan detik"
  (webhook `bayar.js`). Jalur manual: butuh konfirmasi admin.
- **Sewa PC**: dibuat lewat `sewa.js`, ada status `pending/dibayar/provisioning/aktif`.
  Perlu ditelusuri agar tidak "langsung konfirmasi" tanpa validasi.
- **Beli akun digital**: perlu ditelusuri alurnya (auto-provision atau menunggu).

### Pindah akun
- Di Console sudah ada per-akun "Pindahkan ke Sampah" (arsip), kelola saldo, blokir.
- Belum ada multi-select / select-all / aksi massal di daftar mana pun.

### Warna
- Sudah ungu. Yang diminta: pertahankan ungu glossy, rapikan UI/UX + performa scroll.

### GitHub Actions
- Ada `.github/workflows/build-apk.yml` & `native-check.yml`.
- **Fakta**: kalau repo ini publik, berkas workflow terlihat oleh siapa pun yang membuka repo
  di GitHub (`.github/workflows/`). Tidak bisa disembunyikan dari pengunjung selama repo publik.
  Yang muncul di aplikasi/website memang tidak ada. Opsi: (a) buat repo privat (CI tetap jalan
  untuk repo privat, build APK tetap di Actions), atau (b) pindahkan trigger build ke repo privat
  terpisah lalu unduh artefak dari sana.

---

## 2. Rencana perubahan (urut)

### A. UI/UX ungu glossy + scroll antilag
- Console & situs: pastikan `transform`/`box-shadow` dipakai hemat; pakai `content-visibility`,
  `contain`, debounce pencarian, dan hanya render baris tabel yang terlihat (virtualisasi) supaya
  daftar panjang tidak lag.
- Terapkan kartu/hover/skeleton yang konsisten ungu glossy; cek kontras untuk mode terang/gelap.
- (Berlaku di `admin.html`, `web.html`, dan komponen Flutter `core/theme.dart` + `common.dart`.)

### B. Validasi transaksi — tidak "langsung konfirmasi"
- **Isi saldo**: tambahkan opsi verifikasi admin untuk jalur otomatis bila diinginkan, atau
  jadikan "menunggu verifikasi admin" lebih dulu bila penyedia manual; pastikan ada rekam bukti.
- **Sewa PC**: pastikan order dibuat di status `pending`/`dibayar` dan **provisioning baru jalan
  setelah validasi** (cek isi saldo cukup, unit tersedia, bukan langsung nyala).
- **Beli akun**: pastikan ada langkah verifikasi/cek stok sebelum kredensial dikirim.
- Tambah log audit + notifikasi "sedang diverifikasi" supaya transparan.
- (File: `index.js`, `bayar.js`, `sewa.js`, `api/src/admin.html` (halaman topup/order), `wallet_screen.dart`.)

### C. Multi-select & pilih semua (pindah/kelola akun & daftar lain)
- Tambah kolom checkbox di tabel (Console `admin.html`) + checkbox **Pilih Semua** di header,
  dengan bar aksi massal muncul bila ada yang tercentang.
- Aksi massal sesuai konteks tabel: Order (ubah status/hapus), Top Up (setujui/tolak),
  Pengguna (pindah ke Sampah/blokir/ubah tier), Forum (moderasi), dll.
- (Dimulai dari Console agar paling berdampak; lalu ke daftar lain.)

### D. Maintenance bertingkat (bisa pilih cakupan) — ✅ SELESAI (belum deploy)
- Saklar global diubah jadi bertingkat, cakupan: **`semua` | `web` | `aplikasi`**.
  - `semua`   → web + aplikasi Android ditutup (perilaku lama).
  - `web`     → hanya situs publik; aplikasi tetap jalan.
  - `aplikasi`→ hanya aplikasi Android; situs tetap jalan.
  - Console admin & agen PC selalu diizinkan supaya bisa dimatikan lagi.
- Setting baru `pemeliharaan_cakupan`. `index.js` memutuskan per permintaan via helper
  `tertutupPemeliharaan()` + `deteksiPlatform()` (browser kirim header `Origin` → web;
  aplikasi Android tidak → aplikasi). `/api/config` tetap boleh dibaca.
- Halaman perawatan **situs** baru (di `index.js`) memakai ilustrasi web 3D
  (`/brand/maintenance-web.png`).
- Endpoint `/sistem/pemeliharaan` kini menerima & menyimpan `cakupan`.
- Console → Sistem: kartu **Mode pemeliharaan bertingkat** dengan 3 kartu pilih cakupan +
  keterangan + pesan. `statistikLengkap` kini mengekspos `cakupanPemeliharaan`.
- Ilustrasi dipasang: web → `api/src/assets/maintenance-web.png` (+ route `/brand/`),
  app → `app/assets/ilustrasi/maintenance.webp`; `PerawatanScreen` Flutter kini menampilkan
  ilustrasi 3D (dengan fallback ikon bila aset gagal dimuat).
- Preview visual: `preview/maint-web-preview.html`.
- **Cara uji sebelum produksi:** `cd api && npm i && npx wrangler dev`, lalu:
  Console → Sistem → pilih cakupan & nyalakan. Verifikasi: (a) web jadi halaman perawatan,
  (b) aplikasi Android normal saat cakupan `web`, (c) sebaliknya.
- (File: `index.js`, `sistem.js`, `admin.html`, `perawatan_screen.dart`, `assets/*`.)

Catatan desain: "halaman ini saja / backend-sistem" pada prompt asli kami sempitkan dulu ke
3 cakupan aman di atas (web/app/semua). Console admin sengaja selalu diizinkan agar tidak
mengunci pemilik di luar. Kalau butuh opsi "console admin juga ikut mati" / "backend-sistem",
bilang — perlu mekanisme kunci pemulihan terpisah supaya tidak terkunci.

### C. Multi-select & pilih semua + aksi massal (Console) — ✅ SELESAI (belum deploy)
- Sistem pilihan generik `PILIH` (per cakupan `orders`/`topup`/`users`/`sampah`) + helper:
  `cbSel` (kotak per baris), `cbSelHead` (kotak "pilih semua"), `syncSel` (sorot baris + bilah
  aksi muncul), `kosongPilihan`.
- **Order**: kotak per baris + pilih semua → aksi massal **Selesaikan** / **Batalkan** (loop
  PATCH per id, konfirmasi, laporan sukses/gagal).
- **Top Up**: pilih semua → **Setujui semua** / **Tolak semua** (melewati yang sudah berstatus
  akhir).
- **Pengguna**: pilih semua → **Pindah ke Sampah** / **Blokir** / **Buka blokir** (akun pemilik
  otomatis dilewati).
- **Sampah**: pilih semua → **Pulihkan** / **Hapus permanen** (butuh ketik `HAPUS` + konfirmasi,
  pemilik dilewati).
- Bilah aksi `position:sticky` + sorot baris ungu muda; kotak centang diwarnai ungu.
- Preview interaktif: `preview/multi-select-preview.html` (mock Order — bisa diklik untuk coba).
- (File: `admin.html`. Perlu uji interaktif: pilih beberapa → aksi; pilih semua → aksi.)

### B. Validasi transaksi (tidak "langsung konfirmasi") — ✅ SELESAI (belum deploy)
Arah dari pemilik: perkuat validasi di semua jalur (sewa sudah kuat), fokus ke **beli akun**
(dulu paling "langsung konfirmasi") & **top-up**; untuk kredensial tak tersedia → **TOLAK,
jangan potong saldo**.

- **Beli akun (`/akun/beli`, index.js)**:
  - Klaim kredensial ATOMIK & eksklusif (UPDATE guarded; coba sampai 3×) → dua pembeli tak
    bisa ambil baris kredensial yang sama.
  - Kalau tak ada kredensial siap → ditolak bersih, saldo **tidak** dipotong (bukan lagi
    "akan dikirim admin" sambil memotong saldo).
  - Potong saldo pakai pengaman `... WHERE id=? AND saldo>=?`; kalau gagal, klaim dilepas.
  - Kredensial kosong → klaim dilepas & tolak.
  - Stok produk & catatan transaksi baru menyusul setelah klaim+potong berhasil.
- **Top-up webhook (jalur penyedia otomatis, index.js)**: klaim atomik `status='disetujui'`
  hanya untuk status menunggu/diperiksa → webhook terulang/bersamaan **tidak menggandakan saldo**.
- **Top-up setujui admin (`/admin/topup/:id`, index.js)**: klaim atomik yang sama; cegah
  setujui dua kali / setelah ditolak; nominal di-guard.
- **App (`akun_screen.dart`)**: kalau beli gagal karena validasi server, muncul SnackBar pesan
  jelas (saldo tak cukup / kredensial belum siap), bukan diam-diam tutup.
- **Sewa PC**: sudah divalidasi (cek saldo/voucher/unit, `dibayar`→`provisioning`→`aktif` hanya
  setelah agen sukses; refund bila tak siap). Tidak ada "langsung konfirmasi" yang perlu diubah.
- ⚠️ Menyentuh saldo/transaksi — **uji dulu**: `cd api && npm i && npx wrangler dev`.
  Catatan: tabel `akun_stok` tak berubah (tetap `id/produk_id/email/password/terpakai/user_id`).

### E. Ilustrasi 3D ungu glossy (sudah jadi)
- `api/src/assets/maintenance-web.png` (1584×672, banner situs).
- `api/src/assets/maintenance-app.png` (1024×1024, layar app).
- Belum dipasang ke kode; menunggu implementasi bagian D.

---

## 3. Perlu konfirmasi darimu

1. **Urutan pengerjaan** — mulai dari bagian mana (saran: D → B → C → A).
2. **Akses push ke GitHub** (token) kalau ingin langsung di-commit/ke-push; atau kamu review diff dulu.
3. **Maintenance**: istilah "halaman ini saja" itu maksudnya = **Console admin saja** atau menu lain?
4. **Validasi saldo otomatis**: untuk pembayaran lewat penyedia yang sudah lunas, tetap auto-masuk,
   atau mau diubah menjadi diverifikasi admin dulu?
5. **GitHub Actions**: repo mau dibuat **privat**, atau tetap publik (workflow tetap terlihat di repo)?

### A. UI/UX ungu glossy + scroll anti-lag — fondasi SELESAI (perlu build & profil)
Prioritas dari pemilik: menyeluruh, terutama di aplikasi.

**Glossy ungu (aplikasi Flutter)** — `core/theme.dart`:
- Gradien kini **glossy vertikal** (kilau terang di atas → pekat di bawah) untuk gradPrimary,
  gradDeep, gradMidnight, gradAurora — memberi kesan kaca/gloss tanpa kembali ke neon.
- `XyTheme.glow()` diaktifkan kembali sebagai **kilau lembut ungu** (bukan neon): bayangan
  berwarna transparan 2 lapis. Semua GradientButton & elemen hero kini mendapat kilau halus.
- `gradPrimary` tetap `static const` → semua `const BoxDecoration` yang memakainya tetap valid.

**Anti-lag scroll (aplikasi)** — `ui/widgets/common.dart`:
- `XyCard` kini membungkus isinya dengan `RepaintBoundary` → saat bergulir, repaint per kartu
  tidak menyebar ke seluruh layar (mengurangi jank di daftar panjang).
- Catatan: `GambarProduk` sudah `cacheWidth` + loading shimmer; home sudah pakai
  `ListView.separated` & `GridView` (lazy). FadeInUp animasi hanya sekali (bukan per-frame).

**Preview arahan desain:** `preview/app-glossy-preview.html` (mock, bukan screenshot).

**Perlu langkah validasi oleh pemilik (Flutter build):**
- `flutter analyze` untuk memastikan tak ada galat tipe.
- `flutter build apk` lalu uji di perangkat: pastikan gradien glossy tampak pas di tema
  terang & gelap, kontras teks putih di kartu saldo tetap terbaca, dan scroll home/forum/CS
  terasa ringan.
- Langkah anti-lag lanjutan yang disarankan (per layar, butuh profil real-device):
  kurangi bayangan besar pada item feed, aktifkan `cacheExtent` sedang, dan pastikan layar
  komunitas (thread panjang) & chat CS tidak membangun semua pesan sekaligus (pakai lazy +
  binarisasi tanggal), plus hentikan animasi list saat tab tidak aktif.

### Pembaruan aplikasi (popup rilis + unduh native) — kerangka Flutter SELESAI, native butuh build
- `rilis` kini punya kolom `gambar` (banner kustom per rilis; migrasi 0004). `/api/rilis`
  mengembalikannya.
- Warna glossy diubah ke **Orchid lembut** (swatch #3) & gradien tipis: gradPrimary
  `#E0C9EF→#B492DF` (bukan ungu tua), glow dikurangi.
- Kerangka Flutter: `pembaruan_channel.dart` (xycloud/updater), `morph_bg.dart`,
  `rilis_popup.dart`, `pembaruan_screen.dart`. Auto-popup di shell (sekali/sesi), X →
  PembaruanScreen. Pengaturan → buka PembaruanScreen.
- Media: tambah `cached_network_image` (disk cache perangkat); `GambarProduk` memakai
  `AppImage`. Produk/banner CDN tetap dioptimasi `/img`.
- Native Android (DownloadManager + notif progress, jalan saat app ditutup) **belum** bisa
  kubuild — lihat `docs/rilis-3.0-pembaruan-app.md` (kode Kotlin + permission + cara uji).
  WAJIB di-build & diuji di perangkat sebelum rilis.
- Preview: `preview/app-glossy-preview.html`, `preview/warna-glossy.html`.
