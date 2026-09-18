# Verifikasi Build Menyeluruh di CI — 18 September 2026

Dokumen ini mencatat **celah verifikasi** yang ditemukan pada source saat ini,
apa yang sudah bisa diverifikasi lokal, dan gerbang CI baru yang menutup celah
itu tanpa mempublikasikan apa pun.

---

## 1. Celah yang ditemukan

Build CI terakhir yang **sukses** di repo source adalah `Build Android APK`
pada **2026-09-16 17:27 UTC** (commit `a22e18f`). Setelah itu masuk **9 commit
berturut-turut dengan `[skip ci]`**:

| Commit | Waktu (UTC) | Isi |
|---|---|---|
| `d13257c` | 09-16 18:06 | editor HUD + preset komunitas |
| `d5ef5b1` | 09-16 18:36 | reconnect adaptif + diagnostik E2E |
| `fba1e83` | 09-16 19:16 | atribusi instalasi referral anti-fraud |
| `b2513e7` | 09-16 19:55 | hardening Facebook Login & identitas sosial |
| `c405727` | 09-16 20:53 | Pakasir payments + admin ops |
| `5a5d7ae` | 09-16 21:11 | pipeline moderasi Groq privacy-safe |
| `3f93be7` | 09-17 00:22 | control plane livestream kreator |
| `16d5b5e` | 09-17 16:20 | tutup backlog kesiapan produksi |
| `5ae7651` | 09-17 17:37 | konfirmasi Groq Zero Data Retention |

Total **207 berkas berubah, +20.678 / −13.261 baris**. Pada rentang itu
workflow `build-apk.yml`, `agent-windows.yml`, dan `native-check.yml` justru
**dihapus** dari repo source (dipindah ke `XyCloudStore-build`), dan repo build
itu mencatat **0 run** sejak dibuat.

Akibatnya, kode berikut **belum pernah dikompilasi satu kali pun**:

- **Dart/Flutter** — 35.397 baris di `app/lib`, termasuk layar baru
  `livestream_screen.dart` (1.106 baris), `hud_preset_screen.dart` (745),
  `hud_editor_screen.dart` (718), serta `models/livestream.dart` (202).
- **Java native** — `native/xy_stream` (1.728 baris), termasuk `XyHud.java`
  (206 baris baru), `ReferralActivity.java` (64), `LiveLinkActivity.java` (39),
  dan perubahan `NativeStreaming.java` (+109/−?).
- **Rust agen** — `agent-gui/src-tauri/src/obs_live.rs` (**1.405 baris baru**).
  Modul ini ikut terkompilasi crate native karena `src-native/src/main.rs`
  menyertakan `agent.rs` lewat `#[path]`, dan `agent.rs:15` mendeklarasikan
  `mod obs_live;`. `cargo build` untuk `xycloud-agent` **1.5.5** belum pernah
  dijalankan sejak modul itu ada.

Riwayat menunjukkan risiko ini nyata, bukan teoritis: commit `bec7308`
("KeyEvent 6 argumen — konstruktor 7 tak ada di API") dan `39012d7` adalah
perbaikan galat kompilasi Java yang baru ketahuan **setelah** dicoba build.

## 2. Yang sudah diverifikasi lokal (hijau)

Dijalankan di lingkungan tanpa Flutter/Rust/wrangler (Node 20, Java 11,
Python 3.13):

| Pemeriksaan | Hasil |
|---|---|
| `node --test api/test/*.test.mjs` | **65/65 lulus** |
| `npm run lint` dashboard (`next typegen` + `tsc --noEmit`) | lulus |
| `npm run build` dashboard (static export) | lulus, 56 halaman `out/` |
| `python3 -m py_compile tools/*.py` | lulus (12 tool) |
| `python3 tools/cek_skema_d1.py --lokal` | lulus (skema repo konsisten) |
| Penomoran `api/migrations/` | 0001–0021 unik, tanpa lompatan |
| YAML seluruh workflow | 4 berkas valid |
| Pola secret di source | 0 temuan nyata (1 fixture dummy) |

## 3. Temuan audit baru (tidak menggagalkan build)

**Varian tema `rilis_popup` dideklarasikan tetapi tidak ada berkasnya.**
`app/lib/ui/widgets/rilis_popup.dart` mendaftar tema `ramadan`, `idulfitri`,
`lebaran`, `natal`, `imlek`, `kemerdekaan`, `halloween`, lalu mengembalikan
`assets/ilustrasi/rilis_popup_$t.webp`. Direktori `app/assets/ilustrasi/` hanya
memuat `rilis_popup.webp` — **nol** varian bertema.

Dampak: tidak crash (ada `errorBuilder` bertingkat tiga yang jatuh ke gambar
default lalu ke gradasi warna), tetapi fitur tema musiman **tidak pernah
aktif**. Pilihannya: tambahkan aset variannya, atau pangkas daftar `supported`
supaya tidak menjanjikan fitur yang tidak ada.

Temuan ini kini terpantau otomatis oleh `tools/cek_referensi_aset.py` sebagai
peringatan (bukan kegagalan) — lihat §5.

## 4. Workflow baru: `Verifikasi Build Menyeluruh`

Berkas: `.github/workflows/verifikasi-build.yml` — 8 job.

| Job | Runner | Isi |
|---|---|---|
| `kualitas` | ubuntu | `py_compile` tools, validasi YAML workflow, penomoran migrasi, `cek_skema_d1 --lokal`, `cek_referensi_aset`, `cek_secret_source` |
| `api` | ubuntu | Node 22, `npm ci`, `node --check`, **`npm test` (65 test)**, `npm audit --omit=dev`, bundle esbuild Worker |
| `dashboard` | ubuntu | Node 22, `npm ci`, `next typegen` + `tsc --noEmit`, `next build` static export, hitung route (≥50) |
| `flutter` | ubuntu | Java 17 + Flutter 3.24.5 → seluruh tool preparasi → **`flutter analyze`** → **`flutter test`** → **`flutter build apk --release`** |
| `native-aar` | ubuntu | `siapkan_streaming.py` (Moonlight v12.1 terpaku) → `./gradlew :xy_stream:assembleRelease` untuk 3 ABI |
| `agen-windows` | windows | Rust stable-msvc → `cargo build --release --locked` → smoke-test `--veri` |
| `agen-tauri-legacy` | windows | `cargo check` crate Tauri lama — **informatif** (`continue-on-error`) |
| `ringkasan` | ubuntu | Tabel hasil seluruh job; gagal bila ada job wajib yang merah |

### Batas yang dijaga

Workflow ini **hanya memverifikasi**, sesuai kebijakan "build & deploy manual
setelah izin eksplisit pemilik":

- **Tanpa keystore.** Template Flutter memakai `signingConfigs.debug` untuk
  `buildTypes.release`, sehingga `flutter build apk --release` mengompilasi
  jalur rilis penuh (Dart kernel, Kotlin, Java native, `ndkBuild` 3 ABI) tanpa
  satu pun secret. `tools/patch_signing.py` **tidak** dipanggil.
- **Tidak ada artifact.** APK, AAR, dan exe agen **tidak diunggah**; hanya
  ukuran dan metadata yang dicetak ke ringkasan run. APK bertanda tangan debug
  memang tidak boleh beredar.
- **Tidak menyentuh produksi.** Tidak ada `wrangler deploy`, migrasi D1 remote,
  Pages/Vercel, registrasi rilis, maupun secret vendor.
- **Trigger terbatas.** `workflow_dispatch` (dengan opsi `ketat`), push ke
  branch `ci/**` atau `verifikasi/**`, dan `pull_request` ke `main`. Push ke
  `main` **tidak** memicu apa pun, jadi kebiasaan `[skip ci]` tetap aman.
- Seluruh action dipaku ke **SHA commit** yang sama dengan workflow lama;
  tidak ada tag bergerak baru.

### Cara menjalankan

```bash
# otomatis: push ke branch verifikasi
git push origin HEAD:ci/verifikasi-build

# atau manual lewat UI: Actions → Verifikasi Build Menyeluruh → Run workflow
# atau lewat API (butuh token dengan scope repo):
curl -X POST -H "Authorization: Bearer $GH_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  https://api.github.com/repos/xykalnotkel/XyCloudStore/actions/workflows/verifikasi-build.yml/dispatches \
  -d '{"ref":"main","inputs":{"ketat":"false"}}'
```

Repo ini publik, jadi menit runner GitHub-hosted tidak dihitung ke kuota
berbayar. Estimasi durasi: `flutter` 35–60 menit (paling lama karena NDK +
3 ABI), `native-aar` 25–45 menit, `agen-windows` 15–35 menit (kompilasi
`eframe`/`wgpu` dari nol), sisanya di bawah 10 menit. Seluruh job jalan
paralel.

## 5. Tool audit baru

Dua pemeriksaan manual pada `docs/final-readiness-2026-09-17.md` diubah jadi
tool yang bisa diulang:

- **`tools/cek_referensi_aset.py`** — memindai string literal `assets/...` di
  `app/lib/**/*.dart`, memastikan berkasnya ada, memvalidasi deklarasi aset
  `pubspec.yaml`, dan memperlakukan jalur terinterpolasi (`assets/bingkai/$id.webp`)
  sebagai pola varian: ≥1 berkas = info, 0 berkas = peringatan.
  `--strict-varian` menaikkan peringatan jadi kegagalan; `--json` untuk mesin.
- **`tools/cek_secret_source.py`** — memindai 354 berkas source untuk kunci
  privat PEM, token GitHub/Slack/Stripe/Google/AWS, JWT, dan assignment
  secret generik. Nilai temuan disamarkan (4 karakter pertama + panjang) supaya
  log CI tidak jadi tempat bocor. Placeholder/fixture dilaporkan terpisah dan
  tidak menggagalkan.

Keduanya exit 1 bila ada masalah nyata, sehingga bisa jadi gerbang.

## 6. Langkah berikutnya

1. Jalankan workflow ini dan **perbaiki galat kompilasi** yang muncul — inilah
   nilai utamanya: Dart/Java/Rust yang belum pernah dikompilasi hampir pasti
   menyimpan galat seperti `bec7308` dan `39012d7`.
2. Setelah hijau, jalankan build rilis sesungguhnya di `XyCloudStore-build`
   (butuh `SOURCE_DEPLOY_KEY` + keystore). Repo build itu masih **0 run**.
3. Putuskan nasib varian tema `rilis_popup` (§3): tambah aset atau pangkas daftar.
4. Pertimbangkan cache Cargo (`Swatinem/rust-cache`, dipaku SHA) dan cache
   Gradle/NDK untuk memangkas durasi setelah workflow terbukti stabil.
5. Ketatkan gerbang secara bertahap: `flutter analyze` tanpa
   `--no-fatal-warnings` (input `ketat=true` sudah tersedia), lalu
   `cek_referensi_aset.py --strict-varian`.
