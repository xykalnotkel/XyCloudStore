# Konfigurasi login Google Android

Aplikasi mencoba pemilih akun Google bawaan Android terlebih dahulu. Browser hanya menjadi jalur cadangan jika login native tidak tersedia atau gagal sebelum memperoleh ID token.

## Identitas APK rilis

Nilai berikut dibaca dari sertifikat dan manifest artifact `XyCloudStore-arm64-v8a.apk` rilis v2.3.0. Rilis publik baru diterbitkan di [`XyCloudStore-build`](https://github.com/xykalnotkel/XyCloudStore-build/releases).

- Package name: `id.xycloud.xycloud_order`
- SHA-1 sertifikat penandatanganan: `BF:E5:D3:9B:7F:2F:BD:ED:68:8B:45:8F:4B:9C:9A:98:73:0B:1F:22`
- SHA-256 sertifikat penandatanganan: `56:A4:73:48:C9:BC:75:55:EA:76:42:03:BC:0D:43:4D:82:C8:1E:95:71:99:05:38:42:F5:D2:24:4B:79:44:A5`

Fingerprint ini milik **sertifikat**, bukan checksum berkas APK. Jika kunci signing berubah, perbarui pendaftaran OAuth Android. Jika kelak memakai Play App Signing, daftarkan fingerprint sertifikat app signing dari Play Console, bukan hanya upload key.

## Dua jenis OAuth client, jangan tertukar

Keduanya harus berada di project Google Cloud yang sama, nomor project `495336144977`.

| Penggunaan | OAuth client ID |
| --- | --- |
| Android — pasangan package name dan SHA-1 di Google Cloud Console | `495336144977-1b3k66ngo4nhjf6kuetcl5j1vosfgbg4.apps.googleusercontent.com` |
| Web — `serverClientId` aplikasi / audiens ID token dan OAuth browser | `495336144977-1fu3nv7r35pi2i0t8qu6ng0u695t0veg.apps.googleusercontent.com` |

- Android client ID disimpan sebagai `GOOGLE_CLIENT_ID_ANDROID` di `api/wrangler.toml`. Google mengenali aplikasi Android melalui package name dan sertifikat yang didaftarkan pada client ini.
- Web client ID tetap dipakai sebagai `XY_GOOGLE_SERVER_CLIENT_ID` pada `.github/workflows/build-apk.yml` dan default `LoginSosial.serverClientId` di `app/lib/data/login_sosial.dart`.
- Backend memakai secret `GOOGLE_CLIENT_ID` dengan Web client ID yang sama, serta `GOOGLE_CLIENT_SECRET` pasangan **Web client tersebut** untuk pertukaran kode pada jalur browser. Jangan menggantinya dengan secret milik Web client lain.
- `verifikasiIdTokenGoogle()` memeriksa token ke Google, lalu membatasi audiens ke client Web/Android yang dikonfigurasi. Token dari aplikasi lain tidak diterima.
- Authorized redirect URI pada Web client: `https://api.xycloud.my.id/api/auth/google/callback`.
- Client ID adalah identitas publik; client secret, private key service account, dan keystore tidak boleh dimasukkan ke APK atau repository. Alur ini tidak membutuhkan JSON service account Firebase.

## Setelah menambahkan Android client

1. Pastikan package name dan SHA-1 pada Google Cloud Console sama persis dengan identitas APK di atas.
2. Deploy konfigurasi backend: `cd api && npx wrangler deploy --keep-vars` menggunakan kredensial Cloudflare dari lingkungan kerja.
3. Tutup lalu buka kembali APK rilis v2.3.0 dan coba tombol Google. Pendaftaran OAuth yang baru dapat memerlukan waktu untuk diterapkan oleh Google.
4. Tidak perlu APK baru hanya untuk pendaftaran Android ini selama Web client ID, package name, dan sertifikat signing tetap sama.
5. Jika aplikasi masih membuka browser, periksa pendaftaran package/SHA-1, status consent screen/test users, serta ketersediaan Google Play Services pada perangkat. Jika server menolak setelah pemilih akun, cocokkan kembali audiens Web client ID.

Pemeriksaan konfigurasi server bukan pengganti uji login end-to-end pada perangkat Android dengan akun pengguna.
