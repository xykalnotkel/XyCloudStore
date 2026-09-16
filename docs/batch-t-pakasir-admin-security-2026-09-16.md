# Batch T — Pakasir, Operasi Top Up, dan Hardening Admin

Tanggal penyelesaian: 16 September 2026

## Status produksi

- Cloudflare Worker: `92238883-09bb-40ab-bae6-8228e32cc90b`
- D1 migration: `0018_pakasir_payment_operations.sql` diterapkan
- Provider efektif: `pakasir`
- Worker Secrets: `PAKASIR_PROJECT` dan `PAKASIR_API_KEY` tersedia; nilainya tidak dicetak, tidak dikirim oleh API, dan tidak disimpan di repo/D1
- Webhook yang harus dipasang di proyek Pakasir: `https://api.xycloud.my.id/bayar/webhook/pakasir`
- Tidak ada transaksi, Payment Simulation, kredit saldo, atau pembatalan nyata yang dibuat selama rollout

## Hasil utama

### Pembayaran

- Provider disimpan immutable per top up: Pakasir, Tripay, Midtrans, manual, atau legacy.
- QRIS Pakasir memakai hosted checkout resmi; sepuluh metode v2 mencakup QRIS dan seluruh VA yang didokumentasikan provider.
- APK lama tanpa capability header dibatasi dan dipaksa ke hosted QRIS. Payment UI v2 mengirim `X-Xy-Payment-Version: 2` untuk menerima nomor VA, biaya, serta kedaluwarsa.
- Tidak ada fallback diam-diam dari kegagalan gateway ke transfer manual.
- Webhook hanya sinyal. Kredit membutuhkan Transaction Detail server-to-server dan kecocokan provider/project, order ID, serta nominal.
- Kredit saldo menggunakan klaim unik `topup_credit`, ID buku besar deterministik, dan satu `DB.batch` transaksional.
- Polling aplikasi, tombol cek, cron, webhook, rekonsiliasi, dan admin memakai satu jalur kredit idempoten.
- Pembatalan baru dianggap berhasil bila status final gagal dikonfirmasi; HTTP 2xx cancel saja tidak cukup.
- Instruksi checkout/VA disembunyikan setelah transaksi final dan tidak ikut backup atau respons daftar admin.

### Dashboard dan operasi

- Halaman Top Up menampilkan status provider, checklist secret boolean, URL webhook, statistik webhook/kredit, provider/status/fee per transaksi, event terakhir, verifikasi, dan rekonsiliasi.
- Override darurat hanya pemilik, hanya satu aksi, membutuhkan alasan 20 karakter dan frasa `KREDIT MANUAL` atau `TOLAK GATEWAY`, serta masuk audit keamanan.
- Halaman Keuangan memisahkan transfer/penyesuaian dari omzet dan menampilkan fee serta breakdown provider.
- Penyesuaian saldo hanya pemilik, dibatasi Rp10 juta per aksi, tidak boleh membuat saldo negatif, wajib alasan, atomik, dan diaudit.
- Seluruh 53 path menu dashboard memiliki halaman; audit sumber menemukan endpoint statis yang direferensikan dashboard tersedia di Worker.

### Keamanan admin

- Admin key hanya hidup di `sessionStorage`, bukan URL atau penyimpanan permanen.
- Key admin tambahan disimpan sebagai HMAC satu arah; nilai lengkap hanya dikirim saat dibuat/dirotasi.
- Baris key plaintext lama dimigrasikan saat login berikutnya dan daftar hanya menampilkan preview teredaksi.
- WebSocket admin memakai tiket HMAC 60 detik untuk room `cs:inbox`.
- Percobaan key salah dibatasi per IP; traffic admin valid dibatasi per admin dan IP.
- CORS memakai allowlist origin produksi/fallback; origin asing tidak menerima ACAO.
- Halaman admin, proxy dashboard, dan static dashboard memiliki CSP, HSTS, anti-framing, no-referrer, Permissions Policy, COOP/CORP yang sesuai.
- Setelan bernama token/password/secret/API key—termasuk bentuk tanpa separator—ditolak dan nilai sensitif lama diteredaksi. Paket GIPHY terenkripsi hanya dikelola lewat menu khusus.

## Verifikasi yang dijalankan

- `node --check` pada seluruh JavaScript backend yang berubah: lulus.
- Ekstraksi dan `node --check` untuk script inline admin/legacy: lulus.
- `git diff --check`: lulus.
- `schema.sql` pada SQLite in-memory dan keberadaan 12 kolom payment + dua tabel operasi: lulus.
- D1 remote: dua tabel tersedia, 12/12 kolom tersedia, dan tidak ada migration tertunda.
- D1 remote sebelum rollout: tidak ada top up gateway lama pending; 15 top up historis/manual tetap berlabel manual setelah migration.
- Audit nama setelan remote: tidak ditemukan kredensial gateway; `integrasi_giphy_terenkripsi` kini teredaksi di daftar umum.
- Secret-name audit Cloudflare: dua secret Pakasir tersedia tanpa nilai.
- Production smoke read-only: health JSON, Pakasir aktif, legacy QRIS-only, v2 sepuluh metode, CORS allowlist, penolakan admin key via query, method guard webhook, CSP/HSTS/anti-frame admin: lulus.
- Pemindaian literal kredensial: Cloudflare token, API key Pakasir, dan API key Grok tidak terdapat di workspace repo.

## Yang sengaja tidak dijalankan

Sesuai instruksi, tidak ada Flutter compile/analyze/test/build, build dashboard, workflow GitHub Actions, Payment Simulation, ataupun transaksi finansial nyata. Perubahan source dashboard dan APK akan masuk build final setelah seluruh batch coding selesai dan pemilik memberi perintah **jalankan build**.

## Tindakan eksternal pemilik

1. Isi webhook proyek Pakasir dengan URL di atas.
2. Pastikan proyek berada pada mode yang dimaksud (Sandbox untuk uji terkontrol; Production hanya setelah uji selesai).
3. Lakukan satu transaksi sandbox dari akun uji setelah semua batch coding selesai atau ketika pemilik mengizinkan uji pembayaran.
4. Jika anomali muncul, ubah `PAYMENT_PROVIDER` ke `manual`, deploy Worker, lalu rekonsiliasi semua order Pakasir pending—jangan mengubahnya menjadi transfer manual.
