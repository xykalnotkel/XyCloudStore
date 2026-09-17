# Batch V — XyCloud Live: runbook operasi dan respons insiden

Tanggal: 16 September 2026

Status: **coding / belum diterapkan ke produksi**

## 1. Tujuan dan batas aman

XyCloud Live memungkinkan kreator yang disetujui menyiarkan **Game Capture** dari PC rental melalui OBS ke Cloudflare Stream. Implementasi sengaja tidak menyediakan Display Capture, Window Capture, Browser Capture, FFmpeg/GDI, atau fallback lain. Jika scene, audio, atau kontrol OBS tidak dapat diverifikasi, output harus gagal tertutup (*fail-closed*).

Batas awal:

- feature flag `livestream_enabled=0`;
- maksimal 2 siaran bersamaan;
- maksimal 240 menit dan tidak pernah melewati akhir lease rental;
- fee platform 20%;
- dukungan Rp5.000–Rp500.000;
- payout minimum Rp100.000;
- earning ditahan 7 hari;
- rekaman Cloudflare Stream dihapus maksimal 30 hari;
- player hanya diterbitkan lewat tiket pengguna terautentikasi; tautan publik adalah teaser.

## 2. Prasyarat sebelum rollout

Jangan aktifkan flag sebelum seluruh butir berikut lulus di staging/unit uji:

1. Migration `0020_livestream_creator.sql` sukses dan schema production sesuai.
2. Worker memiliki secret/config berikut tanpa mencetak nilainya:
   - `CF_STREAM_API_TOKEN` dengan izin minimum Stream edit;
   - `CF_STREAM_ACCOUNT_ID`;
   - `CF_STREAM_CUSTOMER_HOST` berbentuk `customer-….cloudflarestream.com`.
3. Domain customer Stream dan origin yang diizinkan sudah sesuai domain resmi.
4. Agen Windows versi `1.5.5-rust` atau lebih baru terpasang.
5. OBS Studio **30.1 atau lebih baru** tersedia; versi diverifikasi melalui `GetVersion` sebelum scene disentuh. obs-websocket hanya mendengar di `127.0.0.1:4455` dengan password lokal turunan agen. Nonce handshake dan mask frame wajib berasal dari CSPRNG Windows (`BCryptGenRandom`); tidak ada fallback waktu/counter.
6. Heartbeat dashboard menunjukkan `spec.obs.installed=true` pada unit uji. Keberadaan field `capture_audio` saja bukan bukti kompatibilitas; OBS <30.1 wajib gagal dengan `OBS_VERSION_REQUIRES_30_1`.
7. OneSignal memiliki channel `xy_live_v1`; notifikasi follower dapat dimatikan pengguna.
8. Pemilik telah membaca `/legal/live`, prosedur payout, dan prosedur moderasi.
9. Saldo uji, akun viewer, akun kreator, dan lease PC uji tersedia. Jangan memakai pelanggan nyata untuk smoke test.

## 3. Urutan penerapan yang aman

1. Ambil backup D1 sebelum migration.
2. Terapkan migration 0020.
3. Deploy Worker dengan `livestream_enabled` tetap `0`.
4. Deploy dashboard dan agen uji.
5. Verifikasi endpoint admin XyCloud Live menunjukkan provider `configured`, tetapi status efektif masih `off`.
6. Setujui hanya akun kreator uji dan verifikasi label payout tersamar.
7. Dari dashboard, ubah flag ke ON dengan konfirmasi `AKTIFKAN LIVE` dan concurrency tetap 1 pada smoke test pertama.
8. Jalankan satu siaran pendek, pantau ingest, player bertiket, viewer heartbeat, cleanup, ledger dukungan, reversal, hold, dan payout sandbox/manual terkontrol.
9. Hanya setelah bukti cleanup dan rekonsiliasi benar, naikkan concurrency maksimal ke 2.

Perubahan konfigurasi dilakukan dari menu **XyCloud Live**, tidak dengan SQL ad-hoc. Mematikan flag akan mengantrikan akhir semua siaran dan menonaktifkan ingest provider. Trigger D1 memeriksa ulang flag serta nol cleanup pada saat INSERT, sehingga request start yang balapan dengan tombol OFF dibatalkan dan Live Input yang telanjur dibuat masuk antrean kompensasi durabel sebelum respons dikirim.

## 4. Checklist satu siaran

### Sebelum mulai

- kreator berstatus `approved`, usia 18+, dan menyetujui `live-creator-v1`;
- lease rental aktif, status agen tepat `online`, dan heartbeat server kurang dari 90 detik; status payload agen tidak dipercaya (`offline` hanya ditetapkan watchdog server);
- game sudah fullscreen dan tidak menampilkan informasi pribadi;
- Game Capture OBS 30.1+ wajib memakai `capture_audio=true`; source game harus unmuted, volume multiplier >0, dan audio track 1 aktif;
- mic tetap OFF kecuali source `XyCloudMic` jenis `wasapi_input_capture` sudah disiapkan operator dan kreator memberi consent; bila ON, mic juga wajib unmuted, volume >0, dan track 1 aktif;
- seluruh **Global Audio Devices** tetap disabled agar suara aplikasi lain tidak bocor;
- tidak ada OBS lain yang berjalan di luar kendali agen; bila OBS sudah berjalan tanpa tombstone `LiveState`, agen menolak `OBS_UNMANAGED_RUNNING` walau password websocket cocok—tutup OBS manual, jangan biarkan agen mengambil alih profil/scene pribadi;
- kapasitas global belum penuh.

### Saat mulai

- Worker membuat satu Live Input Cloudflare;
- D1 hanya menyimpan UID input, tidak pernah stream key;
- command D1 hanya memuat `live_id`;
- agen mengambil credential langsung melalui endpoint agen terautentikasi;
- agen membuat/mengaudit scene `XyCloudLive`, source game `XyCloudGameCapture`, menonaktifkan global audio, memverifikasi Game Capture audio terisolasi + track 1 (dan mic + track 1 hanya bila consent), memasang service, lalu StartStream;
- ACK agen hanya memuat status dan kode yang sudah disanitasi;
- follower baru diberi notifikasi setelah ACK sukses, bukan saat input baru dibuat;
- transisi `starting → live` memakai conditional update sebagai concurrency gate; trigger D1 men-snapshot maksimal 10.000 follower opt-in dan membuat inbox deterministik dalam transaksi yang sama;
- fan-out eksternal memakai outbox ber-lease serta UUID idempotensi OneSignal yang sama pada setiap retry, sehingga ACK balapan, replay, atau respons HTTP yang hilang tidak mengirim push kedua.

### Selama live

Pantau dashboard setiap 15–30 detik:

- heartbeat/health code `OK` (agen mempercepat audit OBS dari interval idle 20 detik menjadi 5 detik selama tombstone live ada);
- `output_reconnecting=false` pada kondisi normal;
- congestion di bawah 20%;
- rasio skipped frame di bawah 3% setelah sekurangnya 300 frame;
- viewer aktif masuk akal dan tidak melonjak anomali;
- gross, fee, dan creator net selalu memenuhi `gross = fee + net`;
- tidak ada source asing atau global audio yang terbuka;
- setiap 5 detik agen membaca ulang program scene, jumlah/jenis source, mute/volume/track audio, profil bitrate+reconnect, output 1080p30, serta route service RTMPS. Route dibaca balik dan wajib sama tepat dengan Cloudflare sebelum maupun sesudah output aktif;
- audit yang tidak dapat diverifikasi tidak memperbarui `last_health_at`; setelah 30 detik Worker memicu `OBS_MONITOR_TIMEOUT`, memblokir ingress, dan mengantrikan cleanup fail-closed.

Jika congestion/reconnect meningkat, jangan membuka fallback capture. Minta kreator menghentikan aktivitas jaringan lain atau akhiri siaran; player Cloudflare menangani adaptasi playback sisi penonton.

### Saat berakhir

Urutan wajib:

1. Worker menonaktifkan Live Input segera.
2. Agen StopStream dan menunggu output tidak aktif.
3. Agen mencoba `SetStreamServiceSettings` kosong maksimal 6 kali dengan jeda 600 ms.
4. Agen memanggil `GetStreamServiceSettings` dan memastikan key kosong.
5. Baru setelah verifikasi, state lokal dihapus dan OBS yang diluncurkan agen ditutup.
6. Worker menghapus Live Input agar key lama tidak dapat dipakai ulang.
7. Status D1 menjadi `ended` hanya setelah ACK cleanup agen; watchdog per menit memblokir ingress setelah heartbeat keselamatan hilang 90 detik dan menandai `failed` bila ACK akhir tetap hilang, tanpa memalsukan status `ended`.
8. Timestamp `provider_disabled_at` dan `provider_deleted_at` menjadi bukti lifecycle provider; watchdog mencoba lagi bila API Cloudflare sempat gagal.
9. Bila Live Input berhasil dibuat tetapi transaksi D1 kalah race/gagal, UID masuk `livestream_provider_cleanup`; cron mencoba disable lalu delete dengan backoff. Status pending wajib nol sebelum rollout berikutnya, dan histori `deleted` disimpan 30 hari untuk audit.
10. `deleteRecordingAfterDays=30` dipasang saat input dibuat. Scheduled deletion rekaman tetap berlaku meski Live Input selesai/dihapus; verifikasi `scheduledDeletion` pada smoke test Cloudflare.

`cleanup_pending=true` berarti insiden OBS belum selesai walaupun provider sudah diblokir. Status `failed + cleanup_pending=1` tetap mengunci kreator, lease, unit, kapasitas, dan penghapusan akun; heartbeat tidak boleh membersihkan lock tersebut. Jangan menghapus state atau mematikan paksa OBS sebelum key terverifikasi kosong. Antrean `livestream_provider_cleanup` berbeda: itu adalah kompensasi resource provider tanpa parent live dan terlihat pada tab Push follower/Kompensasi resource.

Tombol **Jalankan rekonsiliasi** di dashboard memanggil `POST /api/admin/livestream/reconcile` dengan konfirmasi `RETRY CLEANUP`. Operasi hanya memajukan jadwal row `pending` dan memulihkan lease push yang sudah kedaluwarsa; attempts serta UUID/idempotency key lama tidak direset. Gunakan satu kali lalu tunggu watchdog—jangan membuat outbox, payout, atau Live Input pengganti secara manual.

## 5. Matriks respons insiden

| Sinyal | Tindakan otomatis | Tindakan operator |
|---|---|---|
| `OBS_UNSAFE_SCENE_SOURCE` / `OBS_SCENE_CHANGED` / `OBS_SCENE_DUPLICATE` | Stop output, blokir/hapus input, tandai failed | Periksa scene; hapus source asing/duplikat; jangan restart sebelum pengguna menutup data pribadi |
| `OBS_STREAM_SERVICE_*` / route ingest berubah | Stop output dan blokir provider; key tidak dicatat pada fault | Pulihkan service hanya lewat agen; jangan menyalin key ke log atau dashboard |
| `OBS_MONITOR_TIMEOUT` | Setelah 30 detik tanpa audit definitif, ingress diblokir dan cleanup diantrikan | Periksa obs-websocket localhost/password; jangan menganggap heartbeat jaringan saja sebagai bukti aman |
| `OBS_OS_RNG` | Koneksi kontrol gagal sebelum key dipasang | Perbaiki layanan CSPRNG Windows/OS; dilarang mengganti dengan nonce waktu atau counter |
| `OBS_GLOBAL_AUDIO_NOT_DISABLED` / `UNMUTED` | Start dibatalkan atau live fail-closed | Matikan seluruh Global Audio Devices; siapkan mic scene eksplisit bila dibutuhkan |
| `OBS_VERSION_REQUIRES_30_1` | Tidak ada scene/service yang diubah | Upgrade OBS ke 30.1+ lalu ulangi; jangan melewati pemeriksaan versi |
| `GAME_AUDIO_*` / `STREAM_AUDIO_TRACK_*` / `INPUT_VOLUME_*` | Start atau heartbeat gagal tertutup dan ingest diblokir | Pastikan Game Capture `capture_audio=true`, source tidak mute, volume >0, serta track 1 game/mic aktif; jangan mengaktifkan Desktop Audio sebagai fallback |
| `OBS_PROCESS_EXITED` | Provider diblokir, state lokal dipertahankan | Biarkan command akhir/start berikutnya meluncurkan OBS tanpa autostart untuk cleanup key |
| `*_CLEANUP_PENDING` | State/proses dipertahankan dan retry terbatas dilakukan lagi | Jangan kill OBS; periksa kontrol localhost dan jalankan akhir ulang dari dashboard |
| `OBS_UNMANAGED_RUNNING` | Start ditolak | Tutup OBS yang dibuka manual; jalankan ulang lewat agen |
| reconnect/congestion tinggi | Diagnostik disimpan | Akhiri bila berkepanjangan; periksa uplink unit; jangan menurunkan privasi/capture guard |
| Cloudflare AUTH/RATE_LIMIT/UPSTREAM | Input/start gagal | Flag OFF bila meluas; periksa token/kuota/status Cloudflare tanpa membuat input percobaan berulang |
| `livestream_provider_cleanup` pending | Cron mencoba disable/delete dengan timeout 8 detik per request | Flag tetap OFF; periksa credential/API dan rekonsiliasi daftar Live Inputs Cloudflare memakai `live_id`/8 karakter UID terakhir, bukan stream key |
| lonjakan viewer/biaya | concurrency dan tiket membatasi | Flag OFF atau turunkan concurrency; cek sesi viewer dan metrik delivery Cloudflare |
| dugaan konten ilegal/doxxing | Terminasi dashboard menonaktifkan ingest | Simpan kode/live ID dan bukti minimum sesuai kebijakan; suspend kreator; eskalasi sesuai hukum |
| tip fraud/duplikat | Tidak otomatis paid | Refund hanya earning `held/available`, isi alasan minimal 8 karakter, audit viewer dan device |
| push follower timeout/5xx | Outbox kembali `pending`, memakai UUID idempotensi yang sama, dan heartbeat/cron mencoba lagi | Periksa `last_error`, OneSignal/FCM, serta usia event; jangan membuat outbox baru atau mengganti UUID |

## 6. Moderasi dan privasi

- Judul, nama game, bio kreator, dan pesan dukungan melewati filter lokal serta AI publik bila flag AI aktif.
- Pesan privat, Chat Admin, stream key, dan credential provider tidak boleh dikirim ke AI.
- Rekaman bukan alasan untuk membiarkan pelanggaran berjalan; operator harus terminasi secepat mungkin.
- Admin tidak boleh mengunduh/menyalin rekaman untuk penggunaan pribadi.
- Semua komunikasi insiden memakai `live_id`, kode fault, dan timestamp—bukan stream key atau nomor rekening.
- Pembekuan akun segera mencabut sesi penonton, mengakhiri live kreator, dan memblokir penerbitan player/tip baru; jangan menunggu cron.
- Deletion akun ditahan selama live, cleanup, earning, atau payout aktif; histori finansial dianonimkan sesuai lifecycle akun.

### Player privat dan skala token

- Endpoint aplikasi menerbitkan handoff HMAC `v:2` selama 2 menit untuk akun terautentikasi. Handoff memakai `exp` epoch **milidetik**, nonce mentah tidak disimpan, dan URL tidak boleh dicatat ke log.
- Navigasi awal membawa handoff sekali pakai di query; Worker mencocokkan keyed hash D1 lalu menghapusnya atomik sebelum memberi `303` ke URL bersih. Capability player yang berbeda disimpan dalam cookie `HttpOnly; Secure; SameSite=Lax` yang **namanya dan Path-nya khusus per `live_id`**. Replay URL query setelah redirect ditolak, sementara dua tab live berbeda tidak saling menimpa cookie.
- Halaman anonim hanya teaser. UID Live Input tidak pernah dipakai langsung sebagai capability iframe; `requireSignedURLs` dan `allowedOrigins` tetap aktif saat semua jalur error.
- Token Cloudflare memiliki custom `exp` sampai akhir sesi +1 jam, tetapi tidak pernah lebih dari 6 jam. Issuance halaman dibatasi 12/jam/view dan tiket aplikasi 60/jam/akun.
- Jalur REST `/stream/{uid}/token` hanya untuk smoke test/volume rendah (rekomendasi Cloudflare: kurang dari 1.000 token/hari) dan terkena rate limit. Sebelum proyeksi menembus batas itu, flag tetap OFF sampai signing key dengan penyimpanan secret/rotasi atau Stream Workers binding sudah dipasang dan diuji. Jangan mengatasi 429 dengan membuka UID atau menurunkan `requireSignedURLs`.
- Binding menghasilkan token default satu jam dan tidak mendukung custom restriction yang dibutuhkan semua skenario; signing key dipilih bila expiry khusus tetap wajib. Rotasi key harus mempertahankan overlap token aktif, lalu key lama dicabut setelah TTL maksimum berlalu.

## 7. Ledger, reversal, dan payout

- Tip mengurangi saldo viewer, membuat transaksi keluar, earning `held`, dan agregat live dalam trigger atomik D1.
- App mempertahankan `client_id` ketika respons tip hilang. Replay exact mengembalikan row asli beserta status `charged` atau `reversed`; ID yang dipakai ulang dengan nominal/pesan/live berbeda ditolak.
- Self-tip ditolak.
- Reversal hanya dapat dilakukan saat earning `held` atau `available`; alasan wajib dicatat. Trigger mengembalikan saldo viewer, menandai earning `reversed`, dan mengurangi agregat.
- Payout mencadangkan **seluruh** earning available pengguna dalam satu request; trigger membandingkan ulang jumlah dan reservasi terjadi atomik.
- Request payout membawa `client_id` yang disimpan terenkripsi per akun sebelum request pertama dan dipakai ulang lintas restart selama hasil belum pasti. Sesudah server mengonfirmasi sukses, key dibersihkan; kegagalan refresh UI dilaporkan sebagai “payout masuk antrean, status belum termuat”, bukan sebagai kegagalan payout. Hasil exact tetap dapat diputar ulang walau payout sudah `paid/rejected`; payout aktif dengan `client_id` berbeda adalah konflik 409, bukan replay palsu. Hanya kode server yang memastikan belum ada INSERT yang boleh membersihkan key lokal. Aksi admin `processing/paid/rejected` dan reversal tip juga mengembalikan 200 hanya untuk payload exact; hasil berbeda adalah 409.
- Status yang sah: `requested → processing → paid/rejected` atau `requested → paid/rejected`.
- Klik **Sudah transfer** hanya setelah bukti transfer berhasil dan referensi provider tersedia. Jangan memakai tindakan ini sebagai instruksi untuk mengirim uang.
- Penolakan melepas earning kembali ke `available`.
- Label payout hanya bentuk tersamar, misalnya `BCA •••• 1234`; nomor rekening lengkap tidak disimpan di field tersebut.
- Rekonsiliasi harian: jumlah earning `paid` per payout harus sama dengan `creator_payout.amount`; gross harus sama dengan fee + net.

## 8. Kontrol biaya

Tinjau setiap hari selama rollout:

- menit delivery Cloudflare Stream;
- menit rekaman tersimpan;
- jumlah input aktif dan input yatim;
- viewer serentak/puncak;
- gross dukungan, fee platform, liabilitas held/available/reserved;
- rasio siaran gagal dan penyebabnya.

Guard awal adalah concurrency 2, durasi 240 menit, player bertiket, no anonymous iframe, dan retention 30 hari. Jika biaya melewati budget: set flag OFF, pastikan seluruh ingest dinonaktifkan, lalu hapus input yatim. Jangan sekadar menyembunyikan kartu aplikasi sementara input masih aktif.

### Batas watchdog per menit

- Trigger `* * * * *` hanya menjalankan `rawatLivestream`; pemeliharaan umum tetap pada `0 * * * *` dan dibedakan memakai nilai `event.cron`.
- Selector lease/start/health masing-masing maksimal 20 row, dideduplikasi menurut `live_id`, lalu dijalankan maksimal 5 pekerjaan bersamaan.
- Selector retry disable, delete terminal, dan provider orphan masing-masing maksimal 20 row. Pekerjaan provider dibatasi 4 koneksi bersamaan; satu slot tersisa untuk satu request OneSignal outbox.
- Satu panggilan Cloudflare memiliki timeout 8 detik, OneSignal 10 detik, dan outbox memproses maksimal 3 event. Backlog yang belum terambil tetap berada di D1 untuk menit berikutnya.
- Jangan menaikkan limit/concurrency cron hanya karena backlog terlihat. Cari penyebab `AUTH`, `RATE_LIMIT`, atau `UPSTREAM`; penambahan paralel justru dapat memperpanjang outage. Pantau `oldest_open_at`, `max_attempts`, dan provider cleanup pending dari dashboard.

## 9. Rollback

1. Dashboard → XyCloud Live → set fitur OFF.
2. Pastikan semua live masuk `ending`, semua input `enabled=false`, lalu tunggu ACK cleanup.
3. Hapus Live Input yang sudah selesai dari Cloudflare.
4. Pertahankan tabel/ledger; jangan rollback migration dengan DROP karena payout/audit harus tetap utuh.
5. Rollback Worker/Flutter/agen hanya setelah tidak ada sesi aktif dan tidak ada `cleanup_pending`.
6. Jika dashboard tidak dapat dipakai, hentikan rollout melalui setting D1 terkontrol dan catat log perubahan; prosedur ini adalah opsi darurat saja.

## 10. Bukti siap produksi

Simpan hasil uji (tanpa rahasia):

- timestamp migration/deploy dan commit;
- versi Worker dan agen;
- satu `live_id` uji;
- screenshot status provider/health yang sudah disamarkan;
- bukti key kosong berdasarkan kode cleanup sukses, bukan nilai key;
- hasil watch bertiket, query→303→cookie per-live/URL bersih, dua tab live bersamaan, expiry custom, rate limit, serta penolakan teaser anonim;
- hasil tip/reversal/replay pascareversal, hold release, payout reject/paid, dan exact replay respons admin/payout kreator uji;
- hasil notifikasi follower opt-in/opt-out serta replay ACK/timeout provider yang tetap menghasilkan satu push logis;
- hasil penolakan OBS <30.1 dan OBS manual unmanaged, terminasi scene asing/global audio, serta audit game/mic unmuted-volume-track 1;
- hasil crash OBS lalu stale cleanup;
- hasil provider orphan compensation dan bukti scheduled deletion rekaman 30 hari;
- biaya aktual smoke test serta keputusan REST token rendah-volume atau signing key/binding untuk skala target.

Jangan mengaktifkan produksi hanya karena halaman UI tampil. Semua bukti di atas harus lulus dan ditinjau pemilik.
