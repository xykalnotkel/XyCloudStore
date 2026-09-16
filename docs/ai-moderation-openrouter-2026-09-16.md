# Operasi Moderasi AI — OpenRouter/Grok

Tanggal: 16 September 2026

## Status saat coding

- Integrasi memakai API OpenAI-compatible OpenRouter dan model default `x-ai/grok-4.3`.
- Credential di berkas kerja dikenali sebagai format OpenRouter, tetapi pemeriksaan read-only `GET /api/v1/auth/key` mengembalikan HTTP 401.
- Credential tersebut **tidak** dipasang ke Cloudflare dan tidak disimpan ke repo/D1.
- Setelan awal `ai_moderation_mode=off`; filter lokal tetap aktif.

Minta atau buat API key OpenRouter baru sebelum mengaktifkan AI. Jangan mengirim key melalui chat publik, query string, dashboard Setelan, atau D1.

## Memasang credential

```bash
cd api
npx wrangler secret put OPENROUTER_API_KEY
```

Setelah deploy, masuk sebagai pemilik dan buka **Moderasi → AI Safety → Verifikasi koneksi**. Endpoint internal hanya memanggil metadata credential tanpa mengirim teks pengguna dan hanya mengembalikan `OK`, `AUTH`, `QUOTA`, `RATE_LIMIT`, `TIMEOUT`, atau `NETWORK`.

## Rollout yang diwajibkan

1. Biarkan mode **off** sampai secret valid.
2. Pilih **shadow** selama minimal beberapa hari. AI akan mengklasifikasi dan mencatat metadata, tetapi tidak memblokir.
3. Tinjau kategori, confidence, latency, galat, cache hit, dan false positive bersama moderator.
4. Baru pilih **enforce** bila sampel lokal memadai.
5. Jika error/auth/quota meningkat, kembali ke **off**; filter deterministik tidak ikut mati.

Hanya pemilik yang dapat mengubah mode atau memverifikasi credential. Moderator dapat melihat audit tanpa konten mentah.

## Konten yang diproses

AI hanya dipanggil untuk teks yang sengaja dibuat publik:

- diskusi, balasan, dan penyuntingan forum;
- ulasan produk dan paket PC;
- nama/bio/slogan profil yang diubah;
- preset HUD saat berstatus publik.

AI tidak menerima:

- Chat Admin, direct message, audio, gambar, gameplay, screenshot, bukti bayar;
- email, nomor telepon, token, kredensial akun, atau payload pembayaran yang disimpan terpisah;
- ID pengguna sebagai parameter model.

Teks publik tetap dapat berisi data yang ditulis sendiri oleh pengguna. Karena itu permintaan menetapkan `provider.data_collection=deny` dan `provider.zdr=true` agar hanya endpoint upstream yang tidak mengumpulkan/menyimpan prompt yang boleh dipilih.

## Kebijakan penegakan

1. Filter lokal berjalan lebih dahulu dan tetap memblokir kata terlarang, spam URL, domain mencurigakan, serta pola spam.
2. AI menghasilkan JSON schema ketat: `allow`, `review`, atau `block`, kategori, severity 0–4, confidence 0–1, dan reason code.
3. Verdict kontradiktif atau confidence rendah diturunkan menjadi `review`.
4. Hanya `block` berkeyakinan cukup pada mode `enforce` yang menolak publikasi.
5. `review` tidak otomatis menyembunyikan konten dan harus dinilai moderator.
6. AI tidak memblokir akun, menghapus saldo, atau menjatuhkan sanksi otomatis.
7. Jika OpenRouter timeout/rate-limit/error, konten yang lolos filter lokal tetap berjalan (fail-open) dan error code dicatat.

## Data dan retensi

- `ai_moderation_cache` menyimpan HMAC-SHA256 terikat secret, verdict, dan metadata maksimal 30 hari.
- `ai_moderation_event` menyimpan metadata audit maksimal 90 hari.
- Teks, prompt, respons model, URL, dan PII yang diekstrak tidak disimpan di kedua tabel.
- Ekspor data akun menyertakan metadata moderasi milik akun tanpa content hash.
- Penghapusan akun melepaskan `user_id` dari event melalui foreign key, sedangkan metadata anonim mengikuti retensi audit.

## Biaya dan performa

- Model dipin lewat `AI_MODERATION_MODEL` di `wrangler.toml`; penggantian harus diuji di shadow.
- Input dibatasi 12.000 karakter, keluaran 180 token, suhu nol, dan timeout 6,5 detik.
- Cache 30 hari mencegah pembayaran ulang untuk konten identik dalam konteks yang sama.
- Dashboard menampilkan jumlah prompt/completion token, bukan perkiraan rupiah yang bisa keliru ketika harga model berubah.
- Atur spending limit/guardrail di akun OpenRouter sebelum enforce.

## Rollback

Rollback tercepat tidak membutuhkan deploy:

1. masuk sebagai pemilik;
2. buka **Moderasi → AI Safety**;
3. pilih **Matikan AI**;
4. periksa event `AUTH`, `QUOTA`, `RATE_LIMIT`, `UPSTREAM`, atau `TIMEOUT`;
5. jangan menghapus filter lokal atau event audit untuk menutupi insiden.
