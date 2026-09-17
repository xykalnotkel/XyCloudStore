# Facebook Login — setup Meta dan operasi

Tanggal audit: **16 September 2026**

## Status saat ini

Implementasi server dan aplikasi sudah tersedia, tetapi tombol Facebook sengaja tetap tersembunyi di produksi sampai kedua binding berikut diisi:

- `FACEBOOK_APP_ID`
- `FACEBOOK_APP_SECRET`

Keduanya **tidak ditemukan** di Cloudflare Worker maupun berkas credential yang diberikan. App Secret tidak boleh dimasukkan ke APK, dashboard browser, repository, atau log. Secret hanya dikirim Worker ke endpoint HTTPS pertukaran code yang didokumentasikan Meta.

Implementasi memakai OAuth Authorization Code di browser, pertukaran kode hanya di Worker, Graph API yang dipin ke `v26.0`, Bearer token, `appsecret_proof`, validasi token lewat profil `/me`, identitas provider stabil yang di-HMAC, serta callback penghapusan data Meta.

## URL yang harus disalin persis ke Meta App Dashboard

| Pengaturan | Nilai produksi |
|---|---|
| App domain | `xycloud.my.id` |
| Valid OAuth Redirect URI | `https://api.xycloud.my.id/api/auth/facebook/callback` |
| Privacy Policy URL | `https://xycloud.my.id/legal/privasi` |
| Terms URL | `https://xycloud.my.id/legal/syarat` |
| User data deletion callback | `https://api.xycloud.my.id/api/auth/facebook/data-deletion` |
| Deauthorize callback | `https://api.xycloud.my.id/api/auth/facebook/deauthorize` |
| User data deletion instructions (GET) | `https://api.xycloud.my.id/api/auth/facebook/data-deletion` |
| Aplikasi Android kembali ke | `xycloudstore://auth` (bukan URL yang didaftarkan sebagai redirect Meta) |

Huruf, skema HTTPS, host, path, dan trailing slash harus sama persis. Jangan mendaftarkan `xycloudstore://auth` sebagai OAuth redirect Meta: Meta kembali ke Worker dahulu, lalu Worker membuka aplikasi.

## Langkah di Meta App Dashboard

1. Buat/pilih aplikasi Meta untuk login konsumen XyCloudStore dan tambahkan use case/product **Facebook Login**.
2. Pada Basic Settings, isi nama, domain, email kontak, kategori, ikon, Privacy Policy URL, Terms URL, dan mekanisme penghapusan data di tabel di atas.
3. Pada Facebook Login Settings:
   - aktifkan Client OAuth Login;
   - aktifkan Web OAuth Login;
   - aktifkan HTTPS dan strict redirect URI;
   - masukkan **hanya** Valid OAuth Redirect URI persis dari tabel.
4. Minta scope minimum `public_profile` dan `email`. Jangan menambah permission yang tidak dipakai.
5. Isi callback penghapusan data dan deauthorize. Keduanya menerima `signed_request` serta memverifikasi HMAC-SHA256 dengan App Secret; callback penghapusan mengembalikan `url` + `confirmation_code` sesuai kontrak Meta.
6. Saat app masih Development Mode, tambahkan akun penguji sebagai role/tester. Pengguna umum baru bisa masuk setelah app dipindahkan ke Live dan seluruh syarat dashboard Meta terpenuhi.
7. Tinjau tampilan consent, branding, URL legal, dan use case sebelum Live. Persyaratan review/business verification dapat berubah di dashboard Meta; ikuti indikator yang ditampilkan untuk app tersebut.

Dokumentasi Meta yang menjadi acuan:

- https://developers.facebook.com/docs/facebook-login/guides/advanced/manual-flow/
- https://developers.facebook.com/documentation/facebook-login/overview
- https://developers.facebook.com/docs/development/create-an-app/app-dashboard/data-deletion-callback/

## Memasang credential ke Cloudflare

Jalankan dari direktori `api/` pada terminal tepercaya. Wrangler akan meminta nilai secara interaktif; jangan menaruh nilai di command history.

```bash
npx wrangler secret put FACEBOOK_APP_ID
npx wrangler secret put FACEBOOK_APP_SECRET
```

Versi Graph bukan secret dan sudah dipin di `wrangler.toml`:

```toml
FACEBOOK_GRAPH_VERSION = "v26.0"
```

Setelah secret dipasang, deploy Worker kembali. `/api/config` baru mengembalikan `providers.facebook=true` bila **kedua** binding tersedia. Dashboard **Kesehatan & Cache → OAuth & kepatuhan Meta** menampilkan:

- apakah credential ada;
- apakah pasangan App ID/App Secret lolos validasi Graph;
- Graph version;
- callback login dan penghapusan data;
- jumlah identity dan request penghapusan tanpa membocorkan secret/token.

## Checklist verifikasi sebelum tombol dipakai publik

1. Dashboard admin menunjukkan Facebook **Terkonfigurasi** dan **Credential tervalidasi**.
2. `/api/config` menunjukkan `providers.facebook: true`.
3. Uji dengan akun role/tester:
   - consent berhasil;
   - callback kembali ke aplikasi hanya dengan `code`, bukan token sesi;
   - exchange HTTPS pada device pemulai berhasil, replay respons-hilang memberi token yang sama, dan device berbeda ditolak;
   - akun baru dibuat satu kali;
   - login kedua masuk ke user yang sama;
   - perubahan email Facebook tidak membuat akun baru;
   - penolakan permission email menampilkan instruksi memakai email/password;
   - pembatalan login kembali ke aplikasi tanpa token.
4. Dari Meta Apps and Websites, kirim permintaan penghapusan dan pastikan response berisi URL status + confirmation code.
5. Pastikan status selesai untuk akun tanpa saldo/pesanan aktif; akun dengan kewajiban aktif berstatus menunggu dan dicoba ulang tiap jam.
6. Uji akun biasa setelah app benar-benar Live, bukan hanya role developer/tester.
7. Pantau `security_events` untuk `oauth_*`, `facebook_deletion_*`, dan error provider.

## Perilaku keamanan dan privasi

- Access token Facebook hanya hidup selama satu request dan tidak masuk D1.
- App Secret dikirim hanya server-to-server ke endpoint HTTPS pertukaran code resmi Meta; URL subrequest tidak pernah dicatat oleh kode aplikasi.
- Profil diminta dengan Bearer token dan `appsecret_proof`.
- Code Meta hanya dapat ditukar oleh App ID + App Secret + exact redirect URI yang sama; token provider kemudian harus lolos permintaan profil `/me` dan validasi jenis/masa.
- Token sesi XyCloudStore 30 hari tidak pernah ditempatkan di custom-scheme URL. URL kembali hanya membawa handoff code acak 2 menit; exchange HTTPS memerlukan verifier PKCE-style yang hanya dipegang app, serta cocok dengan challenge, install identity, dan snapshot `session_version`. Maksimal lima replay identik menoleransi kehilangan respons tanpa membuka sesi lintas perangkat.
- Email sintetis seperti `123@facebook.local` tidak lagi dibuat. Bila Meta tidak memberi email valid, login ditolak dengan penjelasan; klik berikutnya baru memakai `auth_type=rerequest` agar Meta meminta izin email kembali setelah education message.
- ID Facebook/Google mentah tidak disimpan. D1 menyimpan HMAC app-scoped dalam `social_identity`.
- Foto profil penyedia diimpor ke Cloudinary milik layanan melalui allowlist host + batas ukuran; URL CDN bertoken tidak disimpan.
- Penghapusan akun membersihkan identity sosial dan attribution referral terkait sebelum user dihapus.
- Jika `SECURITY_HASH_SECRET`/`JWT_SECRET` atau App Secret dirotasi, rencanakan migrasi dan update Worker terlebih dahulu agar identity serta signed-request lama tidak terputus.

## Keterbatasan yang masih memerlukan pemilik akun Meta

Kode tidak dapat melakukan hal berikut tanpa akses pemilik:

- membuat/memilih Meta App;
- memperoleh App ID/App Secret;
- mendaftarkan exact redirect URI dan data deletion callback;
- menambah tester atau memindahkan app ke Live;
- menyelesaikan review/business verification jika diminta Meta.

Karena itu status aman bawaan tetap **Facebook nonaktif** sampai credential dan konfigurasi dashboard selesai.
