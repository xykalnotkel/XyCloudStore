# Batch S — Facebook Login, identitas sosial, dan penghapusan data

Tanggal: **16 September 2026**

## Tujuan

Mengaudit serta menyiapkan Facebook Login agar setara dengan Google tanpa menyimpan token/ID provider mentah, sekaligus memenuhi callback penghapusan data Meta dan menjaga provider tetap gelap bila credential belum tersedia.

## Perubahan yang ditutup

### OAuth Facebook

- Graph API dipin ke `v26.0` melalui `FACEBOOK_GRAPH_VERSION`.
- Authorization Code tetap ditukar hanya di Cloudflare Worker.
- Exact callback produksi: `https://api.xycloud.my.id/api/auth/facebook/callback`.
- Profil dipanggil memakai `Authorization: Bearer`, bukan access token di query URL.
- `appsecret_proof` HMAC-SHA256 diwajibkan pada pembacaan profil.
- Token type/expiry dan respons profile/id/email divalidasi.
- Timeout subrequest dan pesan error ramah ditambahkan; detail provider/secret tidak dilempar mentah.
- Email sintetis `@facebook.local` dihapus. Facebook tanpa email valid diarahkan untuk mengizinkan email atau memakai email/password.
- Penolakan email baru memakai `auth_type=rerequest` pada percobaan berikutnya, setelah aplikasi menampilkan alasan (education message).
- Halaman callback di-escape, memakai no-referrer, dan cookie state dibersihkan.
- Long-lived token tidak lagi ditempatkan pada custom-scheme URI. Callback hanya membawa code acak 64-hex selama 2 menit; D1 menyimpan keyed hash-nya, terikat ke install identity pemulai OAuth.
- App membuat verifier acak PKCE-style; browser hanya melihat challenge SHA-256 base64url. Aplikasi menukar code + verifier melalui `POST /api/auth/social/exchange` di HTTPS.
- Exchange dibatasi lima replay identik untuk toleransi respons jaringan hilang dan menghasilkan token deterministik yang sama; verifier/device mismatch, expiry, atau perubahan `session_version` ditolak.

### Identitas sosial stabil

Migration `0017_social_identity_facebook.sql` menambah identity/deletion, lalu `0021_oauth_handoff.sql` menambah handoff browser yang aman:

- `social_identity`: primary key `(provider, provider_user_hash)` dan unique `(provider, user_id)`;
- `social_deletion_request`: status asynchronous deletion dengan confirmation code yang hanya disimpan sebagai HMAC;
- `oauth_handoffs`: hanya keyed hash code, challenge SHA-256, provider, user, device hash, snapshot `session_version`, hitungan replay maksimal lima, dan expiry 2 menit—tanpa verifier, access token, atau provider ID mentah.

ID Google/Facebook mentah tidak masuk D1. Hash app-scoped dibuat dengan `securityHash`. Akun sosial lama berbasis email akan ditautkan saat login berikutnya; tidak mungkin di-backfill sebelum provider mengembalikan `sub/id`.

Perubahan email provider tidak membuat user baru. Konflik provider/user ditolak, dan callback paralel tidak dibiarkan menghasilkan akun duplikat.

### Foto profil sosial

- Foto provider diunduh hanya dari allowlist Google/Meta dengan HTTPS, redirect validation, timeout, content-type, dan batas 2 MiB.
- Foto disalin ke Cloudinary layanan; URL CDN provider bertoken tidak disimpan.
- Dedup lintas akun dimatikan khusus avatar OAuth agar setiap aset punya lifecycle penghapusan sendiri.
- URL avatar provider lama dibersihkan oleh migration; login berikutnya mengimpor ulang secara aman.
- Avatar OAuth milik akun yang dihapus dimasukkan ke queue pemusnahan Cloudinary.

### Kepatuhan Meta

Endpoint publik:

- Login callback: `/api/auth/facebook/callback`
- Data deletion callback/instructions: `/api/auth/facebook/data-deletion`
- Deauthorize callback: `/api/auth/facebook/deauthorize`
- Confirmation status: `/api/auth/facebook/deletion-status?code=...`

Callback POST:

1. menerima form-urlencoded atau JSON `signed_request`;
2. memverifikasi HMAC-SHA256 memakai App Secret;
3. memetakan `user_id` Meta melalui HMAC identity;
4. memberi response `{ url, confirmation_code }`;
5. menghapus akun bila tidak ada saldo/pesanan/top-up aktif, atau menandai menunggu;
6. retry maksimal 20 request tiap cron jam;
7. menghapus status selesai setelah 180 hari.

### Cleanup akun

Penghapusan akun kini turut membersihkan:

- `social_identity` dan attribution referral yang memiliki foreign key;
- follows, DM, saved posts, preset HUD, sesi, CS, forum, ulasan, dan device link;
- receipt top-up (`bukti=NULL`), catatan transfer, serta notification transfer;
- ID transfer/referral memakai marker unik `dihapus:<id>` agar tidak berbenturan dengan unique index;
- avatar OAuth melalui media deletion queue.

Ini sekaligus memperbaiki potensi kegagalan penghapusan kedua user akibat semua `referral.diundang` sebelumnya diubah ke marker `dihapus` yang sama.

### Diagnostik admin dan legal

- `GET /api/admin/sistem/oauth` menunjukkan kesiapan Google/Facebook, validitas pasangan credential Facebook, Graph version, callback, jumlah identity, dan deletion status tanpa secret/token.
- Kesehatan sistem kini memiliki `loginFacebook`.
- Dashboard Kesehatan menampilkan status OAuth dan callback Meta.
- Kebijakan privasi diperbarui untuk Facebook Login, HMAC identity, token, penghapusan data, dan retensi confirmation status.
- Panduan pemilik Meta tersedia di `docs/facebook-login-meta-setup-2026-09-16.md`.

## Gate dan keterbatasan produksi

Pada saat batch dibuat, Cloudflare tidak memiliki:

- `FACEBOOK_APP_ID`
- `FACEBOOK_APP_SECRET`

Karena itu `/api/config` tetap mengembalikan `providers.facebook=false` dan tombol Facebook tetap tersembunyi. Kode tidak dapat membuat Meta App, memperoleh secret, mendaftarkan callback, menambah tester, atau memindahkan app ke Live tanpa akses pemilik akun Meta.

## Verifikasi batch

Dijalankan tanpa compile/build/test suite:

- `node --check` untuk sumber API dan kontrak test baru;
- parse migration 0017 dengan SQLite in-memory;
- pemeriksaan kolom/index migration;
- pemeriksaan delimiter Dart/TSX;
- `git diff --check`;
- scan pola synthetic Facebook email/access token query lama.

Test kontrak `api/test/oauth_facebook_contract.test.mjs` ditambahkan tetapi **tidak dijalankan**, mengikuti instruksi bahwa seluruh coding diselesaikan sebelum satu build/test final.
