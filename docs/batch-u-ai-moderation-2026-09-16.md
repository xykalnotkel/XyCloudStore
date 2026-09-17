# Batch U — Moderasi AI/Grok yang aman dan dapat diaudit

Tanggal: 16 September 2026

Status produksi backend:

- Worker `19a370aa-5109-41cd-9557-210195d8e8ba`;
- migration `0019_ai_moderation.sql` diterapkan;
- `ai_moderation_mode=off`;
- `OPENROUTER_API_KEY` tidak dipasang karena credential yang tersedia gagal autentikasi;
- Pakasir tetap aktif dan lolos smoke test kompatibilitas.

## Cakupan

- Integrasi OpenRouter/Grok untuk klasifikasi teks publik dengan JSON Schema ketat.
- Filter lokal tetap selalu berjalan dan diperluas memakai kamus anti-obfuscation yang sudah ada.
- Mode operasi `off`, `shadow`, dan `enforce`; default migration adalah `off`.
- Hanya pemilik yang dapat mengubah mode/verifikasi credential; moderator dapat melihat audit.
- Dashboard Moderasi mendapat tab **AI Safety**, diagnostics, statistik, token, latency, cache, dan event tanpa konten mentah.
- Forum baru/balasan/edit, ulasan produk/PC, profil publik, dan preset HUD publik masuk jalur yang sama.
- Chat Admin, direct message, gambar, audio, screenshot, gameplay, bukti bayar, dan data transaksi tidak dikirim ke AI.
- Edit forum yang sebelumnya dapat melewati moderasi kini memakai pemeriksaan yang sama dengan post baru.
- Batas eksplisit judul/isi forum dan komentar ulasan mencegah payload teks berlebihan.
- Bug dashboard yang mengirim ID laporan alih-alih objek laporan saat **Hapus konten** diperbaiki; tombol hapus hanya tampil untuk jenis konten yang didukung.

## Privasi dan ketahanan

- Permintaan memaksa OpenRouter `data_collection=deny` dan `zdr=true`.
- Prompt injection diperlakukan sebagai data; keluaran harus mengikuti schema enum.
- D1 hanya menyimpan HMAC konten serta metadata verdict. Teks/prompt/response mentah tidak disimpan.
- Cache berumur 30 hari; metadata audit berumur 90 hari dan dibersihkan cron.
- Gangguan provider fail-open hanya setelah filter lokal; AI tidak dapat mematikan komunitas.
- AI tidak pernah menjatuhkan sanksi akun otomatis.
- Ekspor data akun menyertakan metadata moderasi milik pengguna tanpa content hash.

## Credential

Credential yang disediakan berformat OpenRouter, tetapi pemeriksaan read-only mengembalikan HTTP 401. Credential tidak dipasang ke Worker. Integrasi tetap gelap (`off`) sampai pemilik menyediakan key valid dan menjalankan rollout shadow-first pada runbook `docs/ai-moderation-openrouter-2026-09-16.md`.

## Migrasi

`0019_ai_moderation.sql` menambah:

- `ai_moderation_cache`;
- `ai_moderation_event`;
- indeks waktu/verdict/user/expiry;
- setelan awal `ai_moderation_mode=off`.

## Validasi yang diizinkan

Kontrak test ditulis di `api/test/ai_moderation_contract.test.mjs`, tetapi tidak dijalankan. Sesuai instruksi, tidak ada test suite, compile, analyze, build, atau GitHub Actions pada batch ini. Review ringan menggunakan pemeriksaan sintaks, parse schema SQLite, audit route, scan secret, dan `git diff --check` sebelum commit.

## Pembaruan credential — 17 September 2026

Credential Groq baru berlabel XyCloudStore telah lolos verifikasi katalog dan completion sintetis. Provider default dipindah ke Groq `openai/gpt-oss-20b` dengan Structured Outputs `json_schema` ketat. Pemilik mengonfirmasi Zero Data Retention organisasi aktif pada 17 September 2026; secret belum dipasang ke Worker dan mode tetap `off` sampai deploy serta rollout `shadow`; lihat runbook operasi terbaru.
