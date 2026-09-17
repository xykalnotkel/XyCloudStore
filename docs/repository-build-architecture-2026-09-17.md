# Arsitektur Dua Repositori XyCloudStore

Tanggal: 17 September 2026

## Tujuan

- `xykalnotkel/XyCloudStore` menjadi repositori **source privat**.
- `xykalnotkel/XyCloudStore-build` adalah repositori **publik tanpa source produk**, khusus workflow manual, artifact, dan GitHub Release.
- Build Android/Windows memakai kuota runner repositori publik tanpa membuka backend, dashboard admin, atau riwayat source privat.

## Status yang sudah disiapkan

- Repositori publik `XyCloudStore-build` sudah dibuat.
- Isinya hanya README, `.gitignore`, serta workflow manual Android dan Windows.
- Source diambil memakai deploy key Ed25519 read-only; private key hanya tersimpan terenkripsi sebagai Actions secret `SOURCE_DEPLOY_KEY` pada repo build.
- Checkout bersifat sparse: APK hanya mengambil `app`, `native`, dan tool build; Agen hanya mengambil `agent-gui`. Backend/dashboard tidak masuk workspace runner publik.
- Berkas deploy key dihapus segera setelah checkout, sebelum toolchain/dependency pihak ketiga berjalan.
- Semua Actions pihak ketiga dipin ke SHA commit. Default permission workflow repo build read-only; hanya job publikasi terpisah meminta `contents: write`.
- Signing bersifat fail-closed dan corresponding-source bundle menolak direktori backend/dashboard/agent/runbook/workflow privat.
- Artifact Agen Windows terakhir sudah dimigrasikan ke release publik `agent-windows` agar tautan unduhan tidak putus.
- Source repo memiliki workflow manual `bootstrap-public-builder.yml` untuk menyalin lima secret build langsung antar-Actions API tanpa mencetak nilainya.
- API diarahkan ke `REPO_RILIS=xykalnotkel/XyCloudStore-build` pada perubahan yang belum dideploy.

## Urutan aman saat izin build diberikan

1. Push seluruh source final ke `main` dengan `[skip ci]`.
2. Jalankan **Bootstrap Public Build Secrets** satu kali dengan frasa `SIAPKAN BUILDER`.
3. Verifikasi nama secret target: `SOURCE_DEPLOY_KEY`, `KEYSTORE_BASE64`, `KEY_ALIAS`, `STORE_PASSWORD`, `KEY_PASSWORD`, dan `ADMIN_KEY`.
4. Buat tag versi pada repo build, lalu jalankan workflow Android secara manual dengan `source_ref` menunjuk commit source final.
5. Verifikasi test/analyze/build, tanda tangan APK, checksum, artifact per ABI, dan corresponding-source bundle GPL.
6. Publikasikan release pada repo build dan daftarkan rilis ke API.
7. Pastikan `/unduh` dan updater menunjuk release publik baru.
8. Baru ubah visibilitas repo source menjadi **private**. Jangan membalik urutan 4–8 karena unduhan lama dapat putus.

## Batas keamanan

- Workflow tidak berjalan pada `push`, `pull_request`, jadwal, atau tag otomatis; hanya `workflow_dispatch`.
- Deploy key tidak memiliki hak tulis ke source.
- Secret penandatangan APK tidak masuk repo, log, artifact, atau corresponding-source bundle.
- Public runner memang membaca source selama job; hanya pemilik dengan hak ubah workflow yang dapat memicu job ber-secret. Secret tidak diberikan pada PR/fork.
- Komponen aplikasi/engine yang wajib dibuka karena GPL tetap disertakan sebagai corresponding-source bundle per rilis. Backend dan dashboard bukan bagian bundle tersebut.
- Repo source sengaja belum diprivatkan sebelum APK publik pengganti tersedia dan perubahan endpoint rilis sudah live.
