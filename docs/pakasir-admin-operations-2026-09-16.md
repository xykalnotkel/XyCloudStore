# Pakasir, Dashboard Admin, dan Operasi Pembayaran

Tanggal: 16 September 2026  
Provider utama: Pakasir  
Webhook produksi: `https://api.xycloud.my.id/bayar/webhook/pakasir`  
Worker rollout: `92238883-09bb-40ab-bae6-8228e32cc90b`  
D1 migration: `0018_pakasir_payment_operations.sql` diterapkan

## 1. Konfigurasi rahasia

Simpan kredensial sebagai Cloudflare Worker Secret, bukan di `wrangler.toml`, D1, dashboard Setelan, log, atau aplikasi:

```bash
cd api
npx wrangler secret put PAKASIR_PROJECT
npx wrangler secret put PAKASIR_API_KEY
```

`PAYMENT_PROVIDER="pakasir"` adalah pilihan provider non-rahasia. Worker hanya mengaktifkan Pakasir jika kedua secret ada dan slug project valid. Endpoint `GET /api/admin/bayar/info` hanya mengembalikan boolean kesiapan; nilainya tidak pernah dikirim.

## 2. Konfigurasi proyek Pakasir

Di halaman Edit Proyek Pakasir:

1. Isi Webhook URL dengan `https://api.xycloud.my.id/bayar/webhook/pakasir`.
2. Gunakan HTTPS dan pastikan tidak ada spasi/trailing path yang berbeda.
3. Untuk uji sandbox, buat transaksi dari aplikasi lalu gunakan Payment Simulation resmi hanya pada order sandbox tersebut.
4. Jangan mengirim API key melalui aplikasi atau parameter buatan sendiri.

QRIS memakai checkout resmi Pakasir dengan `qris_only=1`. Virtual Account memakai `POST /api/transactioncreate/{method}` dan menampilkan nomor bayar serta total termasuk biaya bila disediakan provider. APK dengan Payment UI v2 mengirim header `X-Xy-Payment-Version: 2` dan menerima semua sepuluh metode terdokumentasi. Klien lama tanpa capability header hanya diberi hosted QRIS; permintaan metode lamanya juga dipaksa ke QRIS agar nomor VA tidak keliru ditampilkan sebagai transfer manual.

## 3. Model kepercayaan webhook

Dokumentasi Pakasir tidak menyediakan signature webhook. Karena itu Worker memperlakukan webhook hanya sebagai sinyal:

1. Batasi metode ke `POST`, provider yang dikenal, ukuran body 64 KiB, dan laju per IP/provider.
2. Parse JSON dan cocokkan `project`, `order_id`, serta `amount` dengan top up D1.
3. Ambil ulang Transaction Detail dari Pakasir memakai API key di server.
4. Cocokkan kembali project, order ID, dan nominal lokal.
5. Kredit hanya jika detail server-to-server berstatus `completed` dan seluruh identitas cocok.

Payload mentah dan API key tidak disimpan. `payment_webhook_event` hanya menyimpan metadata audit teredaksi dan hash sumber. Event dipangkas setelah 90 hari.

## 4. Idempotensi saldo

Semua jalur—webhook, polling aplikasi, tombol Cek, cron, rekonsiliasi admin, dan persetujuan manual—menggunakan satu fungsi kredit. Satu `DB.batch` melakukan:

1. klaim unik pada `topup_credit.topup_id`;
2. penambahan saldo;
3. penulisan buku besar dengan ID deterministik;
4. penandaan klaim sudah dikreditkan;
5. perubahan status top up ke `disetujui`.

D1 melakukan commit atau rollback seluruh batch. Retry dan proses paralel tidak dapat mengkredit dua kali.

## 5. Perilaku aplikasi

- Status top up gateway dipoll setiap empat detik oleh UI.
- Server membatasi panggilan Transaction Detail menjadi paling sering sekali per sepuluh detik per top up.
- Tombol **Sudah bayar? Cek sekarang** menjalankan pemeriksaan paksa dengan rate limit.
- Instruksi checkout/VA disimpan agar top up pending bisa dibuka kembali dari Dompet.
- Top up gateway tidak menerima unggah bukti manual.
- Kegagalan membuat tagihan tidak pernah diam-diam diturunkan ke transfer manual.
- Batas default: Rp10.000–Rp10.000.000 dan maksimal lima top up pending dua hari terakhir.

## 6. Operasi dashboard

Halaman **Top Up** menyediakan:

- provider aktif dan checklist konfigurasi tanpa nilai secret;
- URL webhook yang dapat disalin;
- jumlah pending gateway, webhook 24 jam, webhook ditolak, serta kredit 24 jam;
- provider, status provider, biaya, dan jumlah webhook per top up;
- verifikasi satu transaksi;
- rekonsiliasi hingga 30 transaksi pending (pemilik);
- pembatalan Pakasir sebelum tagihan gateway ditolak.

Persetujuan gateway selalu memeriksa provider terlebih dahulu. Penolakan normal hanya dilanjutkan bila status final gagal/pembatalan dikonfirmasi lagi oleh Transaction Detail; HTTP 2xx dari endpoint cancel saja tidak cukup, terutama untuk hosted checkout yang belum dibuka. Override kredit hanya dapat dilakukan pemilik dengan `override_gateway=true`, frasa `KREDIT MANUAL`, dan alasan minimal 20 karakter. Override penolakan memakai frasa `TOLAK GATEWAY`; keduanya masuk audit keamanan.

Halaman **Keuangan** memisahkan omzet layanan dari transfer saldo/penyesuaian, menampilkan biaya provider, dan memberi ringkasan per provider.

## 7. Hardening dashboard

- Admin key hanya disimpan di `sessionStorage` selama tab aktif.
- Admin key tidak diterima melalui query string.
- WebSocket admin memakai tiket HMAC berumur 60 detik dan terbatas pada room.
- Kunci admin tambahan baru disimpan sebagai HMAC satu arah; nilai mentah hanya muncul saat dibuat/dirotasi.
- Kunci tambahan plaintext lama dimigrasikan otomatis saat login berikutnya.
- Percobaan key salah dibatasi 12 kali per 15 menit per IP.
- Dashboard static memiliki CSP, HSTS, anti-framing, no-referrer, dan Permissions Policy.
- Nama setelan yang terlihat seperti token/password/API key ditolak dan nilai lama hanya ditampilkan teredaksi.

## 8. Urutan deployment dan rollback

Urutan aman agar Worker lama dan baru tetap kompatibel:

1. Pastikan tidak ada top up gateway lama yang pending.
2. Terapkan migration `0018_pakasir_payment_operations.sql` terlebih dahulu. Kolom baru punya default kompatibel dengan Worker lama.
3. Deploy Worker baru ketika secret Pakasir belum ada; provider efektif tetap manual.
4. Smoke-test health, config, admin diagnostics, CORS, dan webhook malformed.
5. Pasang `PAKASIR_PROJECT`, kemudian `PAKASIR_API_KEY`. Provider baru aktif setelah keduanya valid.
6. Verifikasi `/api/config` tanpa capability hanya menawarkan QRIS dan dengan `X-Xy-Payment-Version: 2` menawarkan metode v2.
7. Isi webhook di Pakasir dan lakukan satu pengujian sandbox terkontrol dari akun uji sebelum transaksi nyata.

Rollback tercepat bila provider bermasalah adalah mengubah `PAYMENT_PROVIDER` ke `manual` lalu deploy ulang, atau menonaktifkan salah satu secret Pakasir. Jangan menghapus migration: transaksi yang sudah dibuat harus tetap dapat direkonsiliasi berdasarkan kolom `provider` immutable. Setelah rollback, periksa semua baris pending Pakasir melalui dashboard provider; jangan mengubahnya menjadi transfer manual.

## 9. Checklist verifikasi tanpa transaksi nyata

- [x] Migration `0018_pakasir_payment_operations.sql` tercatat di D1.
- [x] Kolom payment, `topup_credit`, `payment_webhook_event`, dan indeks tersedia.
- [x] Secret list menunjukkan `PAKASIR_PROJECT` dan `PAKASIR_API_KEY` ada tanpa mencetak nilainya.
- [x] `/api/config` menunjukkan pembayaran otomatis dan daftar metode Pakasir.
- [ ] Login sebagai pemilik dan pastikan `/api/admin/bayar/info` menunjukkan provider `pakasir`, verifikasi detail wajib, dan URL webhook benar.
- [ ] Setelah webhook dipasang, kirim pengujian sandbox resmi dan pastikan event diterima tanpa kredit ganda.
- [x] CORS hanya memantulkan origin XyCloud yang diizinkan.
- [x] Admin tanpa key ditolak; query `?key=` tidak memberi akses.
- [x] Tidak ada Payment Simulation atau transaksi nyata selama smoke test infrastruktur.

## 10. Penanganan insiden

Jika ada mismatch, webhook setelah penolakan, atau status provider tidak konsisten:

1. jangan melakukan kredit manual sebelum membuka detail order provider;
2. periksa Log Keamanan dan metadata `payment_webhook_event`;
3. jalankan Rekonsiliasi dari dashboard;
4. cocokkan nominal, order ID, project, dan waktu pembayaran;
5. jika override benar-benar diperlukan, tulis alasan lengkap agar jejak audit dapat dipertanggungjawabkan.
