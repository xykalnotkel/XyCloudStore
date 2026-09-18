# Audit Konsistensi UI & Gerak — 2026-09-18

Audit menindaklanjuti laporan pemilik: video→GIF bug, transisi fade, bingkai
tidak pas, grid kepala profil, view profile mati, dan kustomisasi.

## Temuan & tindakan

### 1. Video → GIF "diam" (bug utama) — DIPERBAIKI (api/src/upload.js)
- `layaniGambar` memakai regex escape ganda `/\\.(gif|webp)$/i` dan `/\\.gif$/i`
  yang TIDAK PERNAH cocok, sehingga GIF (termasuk hasil konversi MP4→GIF)
  dianggap statis dan ditransformasi `f_webp,q_78,c_limit` → hanya frame
  pertama yang tersaji. Regex diperbaiki ke escape tunggal.
- `unggahVideoBanner`: fetch derivasi `f_gif` kini dicoba ulang 3× dengan
  jeda, dan byte divalidasi magic-byte `GIF` sebelum disimpan sebagai aset
  gif mandiri (sebelumnya byte apa pun diterima).

### 2. Perpindahan halaman memakai fade — DIHAPUS (app/lib/core/motion.dart dll)
- `xyRoute` dulu: fade + slide tipis + Stack lapis "halaman lama" yang
  menganimasikan `SizedBox.shrink` (kode mati). Kini: slide horizontal murni
  + parallax lewat secondaryAnimation, nol opacity.
- `xyRouteBawah`: slide vertikal penuh, tanpa fade.
- `xyFadeRoute` (fade+scale) dihapus; penggantinya `xyRouteBesar`
  (slide naik + settle skala). Tidak ada pemanggil lama yang terpakai.
- `FadeInUp` (common.dart): opacity dihapus, tinggal translate settle.
  Nama kelas dipertahankan agar 25+ pemanggil tidak berubah.
- Switcher login↔shell (main.dart) dan popup rilis (rilis_popup.dart):
  fade diganti slide.
- `TukarHalus` (ganti tab): fade dihapus, geser mikro; durasi mengikuti
  pengaturan `animasi`.

### 3. Bingkai avatar "tidak pas" — DIPERBAIKI (widgets/bingkai_profil.dart)
- Footprint widget dulu `size + 2×tebal` sehingga meluber dari slot yang
  dipesan pemanggil (baris komentar, leaderboard, header). Kini footprint
  persis `size`; cincin digambar masuk ke dalam dan foto mengecil sebesar
  tebal cincin. Partikel & permata mengikuti pita cincin baru.

### 4. Grid kepala profil — DITATA ULANG (profil_screen.dart)
- Email & bio dulu dipaksa masuk kolom sempit samping avatar (ellipsis
  1–2 baris). Kini sepenuh lebar di bawah baris avatar: email dengan ikon,
  bio maks 3 baris, lalu baris lencana. Urutan identitas: nama → @username
  → slogan.
- profil_publik_screen: urutan dulu nama → slogan → @username (tidak
  konsisten dengan profil sendiri) → disamakan nama → @username → slogan.

### 5. View profile "belum bisa" — DIWIRE (forum, notifikasi)
- Endpoint `/users/:id/profil` sehat (termasuk profil sintetis `admin`).
  Yang mati: navigasinya.
- Header post & avatar penulis komentar di detail forum kini bisa diketuk
  → ProfilPublikScreen.
- Notifikasi `refJenis: 'profil'` (mis. "mulai mengikuti kamu — ketuk untuk
  melihat profilnya") sebelumnya tidak berbuat apa-apa; kini membuka profil
  aktornya.
- Sudah terwire sebelumnya: kartu post forum, leaderboard, follows, dm_chat.

### 6. Kustomisasi & pengaturan — DIAUDIT, KATALOG KONSISTEN
- `daftarBingkai` (14 id) == dukungan renderer (polos + 5 gradasi + 8 aset
  AI); gate tier di picker sama dengan teks keterangan.
- `daftarGayaNama` satu berkas dengan renderer `GayaNama`.
- Tema banner: 5 kunci `XyBannerTema` semua ada di picker (pengaturan_screen
  ±1094) dan tersimpan lewat `perbaruiProfil(banner:)`.
- Kunci `PengaturanLokal` ber-UI semua: textScale/animasi/navTengah
  (OpsiTampilan), vibration (opsi kontrol), stickerAutoSave (Stiker),
  kunci streaming (Sesi/HUD). Tidak ada kunci yatim.

## Tidak diubah (sengaja)
- Fade saat memuat gambar jaringan (`CachedNetworkImage.fadeInDuration`) —
  itu lintas-muat berkas, bukan transisi halaman.
- Kebijakan gate tier banner/bingkai di server.
