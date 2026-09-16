# Batch R — Referral install-attribution (2026-09-16)

## Tujuan

Referral tidak lagi memberi saldo hanya karena seseorang mengetik kode. Reward harus berasal dari rantai yang dapat diaudit:

1. penerima membuka `/unduh?ref=KODE`;
2. Worker membuat capability ticket acak sekali pakai dan hanya menyimpan HMAC/hash-nya;
3. penerima mengunduh nama APK yang benar-benar ada pada rilis aktif lewat endpoint pelacak;
4. setelah APK terpasang, penerima menekan **Buka aplikasi & aktifkan undangan**;
5. `ReferralActivity` menyimpan ticket di `SharedPreferences` privat;
6. aplikasi mengirim waktu pemasangan paket dari Android `PackageManager.firstInstallTime` dan mengikat ticket ke pseudonymous `X-XY-Device` lewat `/api/referral/buka`;
7. server memastikan pemasangan paket terjadi setelah klik/unduh (dengan toleransi jam OEM 10 menit);
8. setelah akun baru terverifikasi, `/api/referral/atribusi` memvalidasi seluruh syarat lalu memberi reward secara atomik.

## Batas platform yang dinyatakan jujur

APK dibagikan langsung (sideload), bukan hanya lewat Google Play. Karena itu Play Install Referrer tidak tersedia sebagai bukti universal. Implementasi ini membuktikan rangkaian **klik bertiket → unduhan APK rilis → `firstInstallTime` paket sesudah unduh → deep link dibuka oleh aplikasi → akun baru pada identitas perangkat yang sama**. Ini adalah atribusi instalasi praktis untuk sideload. Timestamp dan identitas dikirim klien serta divalidasi server, tetapi tanpa Play Integrity/hardware attestation mekanisme ini tidak diklaim kebal terhadap aplikasi yang telah dimodifikasi pada perangkat kompromi.

## Rollout aman

Migrasi membuat setelan `referral_install_aktif=0`. Endpoint mint ticket tetap gelap sehingga web produksi tidak menjanjikan flow yang belum dapat ditangkap APK lama. Setelah build final berisi `ReferralActivity` diterbitkan dan smoke test diizinkan, pemilik mengubah setelan tersebut ke `1` lewat menu Setelan admin (`POST /api/admin/setelan`); tiket yang sudah terbit tetap dapat diselesaikan bila fitur kelak dipause kembali.

## Endpoint

| Method | Path | Akses | Fungsi |
|---|---|---|---|
| POST | `/api/referral/klik` | publik, rate-limited | validasi kode dan buat ticket 256-bit berumur 7 hari |
| GET | `/api/referral/unduh` | publik, rate-limited | validasi ticket + nama APK rilis, tandai unduhan, redirect ke domain unduhan sendiri |
| POST | `/api/referral/buka` | publik + `X-XY-Device` | ikat ticket ke perangkat yang membuka aplikasi |
| POST | `/api/referral/atribusi` | authenticated | validasi dan klaim reward |
| POST | `/api/referral/pakai` | authenticated | alias kompatibilitas; memakai validator atribusi yang sama, bukan jalur kode langsung |
| GET | `/api/admin/referral` | admin | funnel klik, unduh, app dibuka, klaim, expired/ditolak |

## Kontrol anti-fraud

- ticket mentah 32-byte/64-hex tidak masuk D1; primary key tabel adalah HMAC;
- ticket kedaluwarsa 7 hari, terikat ke satu perangkat, dan single-use;
- file unduhan harus cocok dengan daftar APK rilis aktif;
- `PackageManager.firstInstallTime` wajib sesudah klik dan unduh; app yang sudah terpasang sebelum tautan dibuka ditolak;
- akun penerima wajib dibuat setelah klik dan memakai `registration_device` yang sama;
- email penerima wajib terverifikasi;
- self-referral berdasarkan user ID ditolak;
- perangkat yang pernah terkait ke akun pengundang tidak boleh dipakai membuat akun penerima;
- satu akun hanya boleh menjadi penerima satu referral;
- unique index dan trigger D1 menjaga idempotensi/race;
- INSERT referral, dua perubahan saldo, dua entri buku besar, relasi `diundang_oleh`, dan konsumsi ticket berlangsung dalam transaksi trigger yang sama;
- perubahan jaringan dicatat sebagai risiko (`jaringan_berubah`) tanpa menghukum pengguna seluler yang wajar;
- percobaan ditolak dan rate limit masuk audit keamanan tanpa menyimpan ticket mentah.

## Android dan aplikasi

- callback `flutter_web_auth_2` kini hanya menangkap `xycloudstore://auth`;
- `ReferralActivity` khusus menangkap host `xycloudstore://referral`;
- Android tree dibuat ulang di CI, jadi perubahan permanen ditempatkan pada `native/xy_stream` dan `tools/patch_manifest.py`;
- Dart membaca dan menghapus capability melalui channel `xycloud/settings`;
- konfirmasi instalasi berjalan sebelum login, sedangkan klaim dicoba otomatis setelah pemulihan sesi, login email, verifikasi email, reset, Google native/web, atau callback login sosial;
- observer lifecycle membaca ulang ticket saat `ReferralActivity` membangunkan Flutter engine yang masih hidup, jadi pengguna tidak perlu restart atau membuka menu Referral;
- kegagalan jaringan mempertahankan ticket untuk retry; status terminal (invalid/expired/device fraud) membersihkan ticket.

## UI

- tombol berbagi mengutamakan tautan, bukan kode lepas;
- halaman unduh menjelaskan tiga langkah dan menampilkan tombol deep link;
- layar Referral menjelaskan bahwa kode saja tidak cukup;
- dashboard admin menampilkan funnel, varian APK, device hash yang dipotong, status, risiko, dan total reward.

## Verifikasi batch

Kontrak statis ada di `api/test/referral_attribution.test.mjs`. Sesuai instruksi proyek, Flutter/npm test, analyze, compile, build, dan GitHub Actions belum dijalankan. Review ringan hanya memakai pemeriksaan sintaks non-build, delimiter, diff whitespace, dan scan credential pada baris baru.
