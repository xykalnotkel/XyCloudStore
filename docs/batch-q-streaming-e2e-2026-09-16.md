# Batch Q — Streaming end-to-end, anti-lag, reconnect, dan diagnostik

Tanggal: 2026-09-16

## Cakupan yang ditutup

### 1. Progres yang tidak terasa diam

- Persiapan sesi dan koneksi native menampilkan persentase, tahap aktif, dan durasi berjalan.
- Native mengirim tahap terstruktur: validasi alamat, identitas terenkripsi, probe Sunshine,
  pairing, pembacaan aplikasi, dan siap.
- Watchdog 35 detik membatalkan task native yang tidak menjawab agar UI tidak menggantung.
- Pesan timeout menjelaskan titik terakhir dan menawarkan diagnostik, bukan sekadar spinner.

### 2. Jalur publik dan LAN

- Preferensi baru **Dahulukan jaringan lokal**.
- Default mencoba host publik lalu IP LAN agen sebagai cadangan jika masalah memang berasal
  dari DNS/koneksi. Jika preferensi LAN aktif, urutannya dibalik.
- Sertifikat pairing tetap memakai key unit/agen yang stabil sehingga pergantian jalur tidak
  membuat identitas host tertukar.

### 3. Adaptive anti-lag

- Probe awal Sunshine mengukur waktu respons host.
- Pada respons berat, native menurunkan batas resolusi/FPS/bitrate sebelum stream dibuka.
- Reconnect bertingkat juga menurunkan beban: percobaan 1 membatasi puncak kualitas,
  percobaan 2 memakai profil 720p yang lebih ringan, percobaan 3 memakai profil 480p/30.
- Pengaturan pengguna tetap dipakai bila jaringan sehat. Adaptive bisa dimatikan.
- Kualitas aktual ditampilkan di diagnostik layar sesi, bukan hanya nilai yang diminta.

### 4. Reconnect otomatis

- Saat koneksi video benar-benar terminated, aplikasi menjadwalkan ulang 2, 4, lalu 8 detik.
- Maksimal tiga percobaan beruntun; pengguna dapat membatalkan countdown.
- Menutup renderer secara manual tidak memicu reconnect.
- Counter baru direset setelah koneksi stabil 30 detik agar loop connect-putus cepat tidak
  berjalan tanpa batas.

### 5. Diagnostik pengguna dan operasi admin

- `GET /api/sesi/:id/diagnostik` hanya boleh dipakai pemilik sesi dan dibatasi rate.
- Probe Cloudflare menguji sampel TCP 47984, 47989, 48010 serta custom port jika ada secara
  paralel (maksimal sekitar enam detik), lalu memberi saran spesifik. UI jujur menyebut UDP
  tidak dapat diuji oleh probe TCP.
- `POST /api/sesi/:id/telemetri` menyimpan state klien, waktu, jalur, latensi, kualitas,
  jumlah putus, percobaan reconnect, dan alasan terakhir.
- Payload disanitasi, dibatasi panjang/rentang, terikat user pemilik sesi, dan rate-limited.
- Dashboard **Sesi PC** menampilkan state klien, latensi, jalur, kualitas, dan jumlah putus.
- Telemetri tidak menerima/menyimpan tombol, teks, audio, gambar, tangkapan layar, atau isi
  gameplay.

### 6. Input, audio, mic, dan gamepad

- Audio host, kontrol sentuh, trackpad, HUD, getar, serta gamepad Bluetooth/USB tetap memakai
  renderer native dalam APK.
- UI menjelaskan batas teknis dengan jujur: GameStream tidak menyediakan uplink mikrofon HP
  ke PC. On-mic memakai Discord di HP atau mikrofon/headset yang terhubung ke PC rental,
  sehingga tidak menjanjikan fitur palsu dan menghindari echo.

## Perubahan data

Migrasi `0015_streaming_telemetri.sql` menambah kolom metadata klien pada `sesi` dan indeks
`client_last`. Migrasi bersifat additive; sesi lama tetap valid dengan nilai kosong/default.

## Kontrak tes yang ditambahkan

`api/test/streaming_telemetri.test.mjs` mencakup:

- hanya pemilik sesi yang boleh mengirim telemetri;
- status di luar allowlist ditolak;
- CR/LF pada metadata dibersihkan;
- jumlah disconnect tidak dapat mundur karena event terlambat.

Sesuai instruksi pemilik, tes/Flutter analyze/compile/build belum dijalankan. Review batch ini
hanya menggunakan pemeriksaan sintaks JavaScript, delimiter ringan, dan `git diff --check`.
Build Android dilakukan satu kali setelah seluruh backlog coding selesai dan pemilik berkata
“jalankan build”.
