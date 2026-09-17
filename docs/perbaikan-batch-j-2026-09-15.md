# Perbaikan Batch J — 15 September 2026

Versi app: **3.6.0+24** · Worker: tanpa migrasi baru (tetap s.d. 0011) · Agen: v1.5.0-rust

## 1. Galeri picker: saringan Foto / Video / Semua
- `app/lib/ui/widgets/galeri_picker.dart`: bar saringan 3 chip di atas grid; ganti
  saringan memuat ulang album + aset sesuai `RequestType` (image/video/common).
- Banner picker (`bolehVideo: true`) kini bisa memilih MP4/video juga.
- Menu khusus foto tetap menolak video dengan snackbar penjelasan (video/GIF untuk
  banner Pro/VIP).

## 2. Pengaturan selengkap-lengkapnya
- Pengaturan sudah memuat: profil, banner, keamanan (biometrik, PIN transfer,
  password), notifikasi, data & penyimpanan (hemat data, bersihkan cache), privasi
  (saringan dewasa, mode privasi/anti-screenshot), tema, unduh dataku, hapus akun.
- **Baru** di Tentang Aplikasi: baris "Periksa pembaruan aplikasi" → rilis resmi
  GitHub (unduh build terbaru mandiri).

## 3. Bingkai profil animasi (AI-generated)
- Dua bingkai premium baru: **api** dan **galaksi** (`app/assets/bingkai/`, dibuat
  via AI + chroma-key, 512px, transparan).
- `bingkai_profil.dart`: partikel melayang — `_BintangOrbit` (galaksi: bintang
  mengorbit) dan `_BaraNaik` (api: bara naik) di atas ring statis.
- Whitelist server (`BINGKAI_PROFIL`, `BINGKAI_LANGGANAN`) ikut ditambah; bingkai
  langganan: aurora, permata, api, galaksi.

## 4. Leaderboard konsisten
- Sub-teks hero kini menyebut periode eksplisit: bulan berjalan
  ("1–30 September 2026", UTC) atau akumulasi total.
- Baris keterangan sumber data: "riwayat transaksi lunas (top 50) · urutan
  menurun · akun diblokir tidak tampil" — sama di kedua tab, jadi podium dan
  daftar tidak lagi terasa ambigu.

## 5. Splash native
- `assets/brand/splash_logo.png` dipangkas ke 89,5% kanvas → logo tampil lebih
  besar. CI membangun ulang splash saat rilis.

## 6. Onboarding
- Kata "dewa" dihapus (→ "kelas berat").
- Worker `/api/config` kini mengembalikan `statistik: { pengguna, unitOnline }`
  (dihitung `statistikPublik()`); welcome screen menampilkannya lewat
  `_ChipStatistik` ("N pengguna • M unit online", sembunyi bila 0).

## 7. Unit PC: spesifikasi otomatis + ikon AI
- Agen (`agent.rs spesifikasi()`): tambah **GPU** (Win32_VideoController) dan
  **versi OS** ke JSON spek heartbeat.
- Worker: endpoint user baru `GET /api/pc/unit-live` → baris agen
  {planId, status, versi, host, terakhir, spec}.
- App: `UnitLive` model + `repository.unitLive()`; `live_unit_screen.dart`
  digabung per planId (online+spec menang): hostname/CPU/RAM/GPU nyata saat agen
  hidup, chip "Spek terdeteksi" & "agen vX", catatan bila agen diam,
  RefreshIndicator; ikon pakai `assets/ikon/3d_unitpc.webp` (AI-generated).

## 8. Home: kartu kategori grid
- `_MenuCepat.kartu()` dibungkus Container halus (bg violet 5% / white 4,5% dark,
  border tipis) — label lebih terbaca tanpa norak.

## 9. Ilustrasi AI untuk blokir & maintenance
- `assets/ilustrasi/blokir.webp` (AI-generated) jadi hero di `blokir_screen.dart`.
- `perawatan_screen.dart` sudah memakai `maintenance.png` ✓.

## 10. Komunitas disempurnakan
- Forum: menu urutan diskusi (Terbaru / Terpopuler(suka) / Teramai(balasan));
  postingan tersemat selalu di atas.

## Perbaikan CI agen (lanjutan 0de6148)
- Runner CI Windows tanpa GPU: WARP tereliminasi uji kompatibilitas surface →
  `request_adapter` None walau `force_fallback_adapter=true`.
- Patch vendor `egui-wgpu/src/lib.rs`: bila request_adapter kosong, pilih manual
  dari `enumerate_adapters()` (utamakan software/WARP saat force_fallback;
  utamakan non-software selain itu) + log semua adapter ke gui.log.
- `cargo check` bersih; smoke test CI membuktikan tingkat 3 sungguhan.

## Verifikasi
- `flutter analyze`: 0 error (301 info pre-existing).
- `flutter test`: 17/17 lulus.
- Worker `npm test`: 26/26 lulus (termasuk asersi bingkai api/galaksi + statistik).
- `cargo check` agen native: bersih.
