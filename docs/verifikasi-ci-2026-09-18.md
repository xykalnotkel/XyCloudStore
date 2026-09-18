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

## 6. Hasil run

### Run #1 — `35351919422` (commit `b255e13`) → failure, 5,6 menit

Run pertama langsung membuktikan celah itu nyata. Tiga job hijau
(`kualitas`, `dashboard`, `agen-windows`) dan dua galat kompilasi **nyata**
ketemu:

| Job | Hasil | Keterangan |
|---|---|---|
| `kualitas` | ✅ | kedua tool audit baru lulus di runner |
| `dashboard` | ✅ | `tsc` + static export |
| `agen-windows` | ✅ | `cargo build --release --locked` + smoke-test `--veri` → **`obs_live.rs` (1.405 baris baru) terkompilasi** |
| `flutter` | ❌ | **error Dart nyata** — lihat di bawah |
| `agen-tauri-legacy` | ❌ | **error Rust nyata** — lihat di bawah |
| `api` | ❌ | langkah esbuild workflow ini sendiri yang salah (bukan galat source) |
| `native-aar` | ❌ | Gradle **BUILD SUCCESSFUL 3m33s**; yang gagal langkah laporan AAR (path salah) |

**Galat 1 — Dart** (`app/lib/ui/screens/livestream_screen.dart:36`):

```
error • The method 'substring' can't be unconditionally invoked because the
        receiver can be 'null' • unchecked_use_of_nullable_value
```

`_snackMutasiLive()` memanggil `hasil.substring(5)` pada parameter
`String? hasil`. Flow analysis Dart tidak bisa mempromosikan nullability
lewat variabel bool terpisah (`informasi`), jadi cabang itu tetap dianggap
mungkin null. Ini satu-satunya **error** dari 309 isu analyze; sisanya info
dan warning. Diperbaiki dengan `final teks = hasil ?? '';` lalu
`teks.startsWith('INFO:')` / `teks.substring(5)` — perilaku identik, tanpa
operator `!`. Berkas ini bagian dari batch livestream (`3f93be7`) yang masuk
dengan `[skip ci]`.

**Galat 2 — Rust** (`agent-gui/src-tauri/src/main.rs`):

```
error[E0583]: file not found for module `obs_live`
  --> src\agent.rs:15:1
   = help: to create the module `obs_live`, create file "src\agent\obs_live.rs"
```

Penyebabnya aturan resolusi modul Rust: modul non-inline `agent`
(berkas `src/agent.rs`) membuat direktori anak `src/agent/`, sehingga
`mod obs_live;` di dalam `agent.rs` dicari di `src/agent/obs_live.rs`.
Crate **native** tidak kena masalah ini karena menyertakan `agent.rs` lewat
`#[path = "../../src-tauri/src/agent.rs"]`, yang membuat direktori modulnya
tetap `src-tauri/src/`. Diperbaiki dengan satu baris di crate Tauri:
`#[path = "agent.rs"] mod agent;` — kedua crate kini memakai berkas yang sama
tanpa memindahkan apa pun.

Dua kegagalan sisanya adalah galat pada workflow verifikasi ini sendiri dan
sudah diperbaiki:

- **esbuild** butuh `--loader:.html=text --loader:.png=binary` karena Worker
  mengimpor `admin.html`, `admin-legacy.html`, `web.html`, dan tiga PNG brand
  sebagai modul sesuai `[[rules]]` di `wrangler.toml`. Loader sengaja
  dicerminkan persis dari `wrangler.toml`, bukan ditambah bebas, supaya impor
  tipe baru tanpa rule ikut merah.
- **Laporan AAR** mencari berkas dengan `find`, bukan mengasumsikan
  `native/xy_stream/build/outputs/aar/`. Path warisan `native-check.yml` itu
  memang keliru: Gradle menaruh keluaran di
  `app/build/xy_stream/outputs/aar/xy_stream-release.aar`.

### Run #2 — `35352787231` (commit `1ffa8e4`) → **success**, ~7 menit

Seluruh 8 job hijau. Angka terverifikasi dari log runner:

| Komponen | Hasil terukur |
|---|---|
| Aplikasi Flutter | `flutter analyze` **0 error** (308 isu tersisa = info/warning), `flutter test` lulus, `app-release.apk` **80,5 MB** — `id.xycloud.xycloud_order`, versionCode 26, versionName **3.8.0**, label `XyCloudStore` |
| Native `xy_stream` | `:xy_stream:assembleRelease` **BUILD SUCCESSFUL 3m58s**, `xy_stream-release.aar` **4,2 MB** (3 ABI via ndkBuild) |
| Agen Windows | `cargo build --release --locked` → `xycloud-agent.exe` **12.013.568 byte**, `--veri` → `XyCloudStore-Agent 1.5.5-rust` |
| Agen Tauri legacy | `cargo check --locked` lulus setelah perbaikan `#[path]` |
| API Worker | **65/65** test lulus, bundle esbuild **1,4 MB** |
| Dashboard | `tsc --noEmit` lulus, static export **58 route HTML** (sama dengan klaim audit 2026-09-17) |
| Kualitas | `py_compile` 14 tool, YAML valid, migrasi 0001–0021, skema D1 konsisten, aset lengkap, secret bersih |

Kesimpulan: **v3.8.0+26 terbukti bisa dikompilasi end-to-end** — Dart, Kotlin,
Java native + NDK, dan Rust — tanpa satu pun secret. Yang belum terverifikasi
hanyalah penandatanganan rilis dan perilaku di perangkat nyata.

## 7. Langkah berikutnya

1. **Build rilis sesungguhnya** di `XyCloudStore-build` (butuh
   `SOURCE_DEPLOY_KEY` + keystore). Repo build itu masih **0 run**; sekarang
   ada dasar yang jauh lebih aman untuk menekannya karena kompilasi sudah
   terbukti hijau.
2. **Job `agen-tauri-legacy` masih `continue-on-error`.** Setelah terbukti
   hijau di run #2, layak dinaikkan jadi job wajib (hapus
   `continue-on-error`) atau crate Tauri-nya sekalian dihapus — README sudah
   menyatakan v1.5 native menggantikannya.
3. **Utang lint Flutter: 308 isu** (mayoritas `prefer_const_constructors`,
   `curly_braces_in_flow_control_structures`, beberapa `unused_field` dan
   `use_build_context_synchronously`). Tidak menggagalkan build, tetapi
   `unused_field` di `transfer_sheet.dart:549` (`_kodeTerkirim`) layak
   diperiksa — bisa jadi logika yang belum tersambung.
4. Putuskan nasib varian tema `rilis_popup` (§3): tambah asetnya atau pangkas
   daftar `supported`.
5. Pertimbangkan cache Cargo (`Swatinem/rust-cache`, dipaku SHA) dan cache
   Gradle/NDK bila durasi mulai terasa; saat ini ~7 menit dengan cache Flutter
   bawaan action.
6. Ketatkan gerbang bertahap: jalankan dispatch dengan input `ketat=true`
   untuk membuat warning Flutter ikut menggagalkan, lalu
   `cek_referensi_aset.py --strict-varian`.

## 8. Catatan operasional: workflow baru harus ada di `main`

GitHub **hanya mendaftarkan** workflow yang berkasnya ada di branch default.
Run pertama workflow ini harus dipicu lewat `workflow_dispatch` setelah PR #1
di-merge ke `main`: selama berkasnya hanya ada di branch `ci/verifikasi-build`,
push ke branch itu **tidak** memicu run, `pull_request` juga tidak, dan
`POST /actions/workflows/verifikasi-build.yml/dispatches` dibalas **404**.
Tidak ada check suite Actions yang dibuat sama sekali, jadi gejalanya mudah
dikira "Actions mati" — padahal `actions/permissions` melaporkan
`enabled: true`.

Implikasinya untuk repo ini: pemicu `push: branches: [ci/**]` baru berguna
**setelah** `verifikasi-build.yml` ada di `main`. Sekarang sudah ada, jadi
branch `ci/**` berikutnya akan memicu run otomatis.

