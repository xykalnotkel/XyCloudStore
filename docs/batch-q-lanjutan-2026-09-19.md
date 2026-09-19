# Batch Q Lanjutan — Bug Report 2026-09-19 + Flat UI + Kamera HP Real + Story Editor Lengkap

Tanggal: 2026-09-19
Status: Implementasi lokal selesai, menunggu instruksi push/build (sesuai standing rule)

## Ringkasan Bug Report Masuk

1. Kustomisasi Profil menu hilang
2. Tes mp4 to webp belum jelas
3. Live HP kamera tidak kebuka
4. Story UI: in/out animation tumpang tindih, like gabisa, repost kurang bagus
5. Story posting teks harus ada editor: gaya teks, background, label/no label, etc
6. Video sebelum post bisa diedit native (cut/trim)
7. Stream PC host tidak menjawab dalam 35 detik
8. Loading jangan spinner/progress saja, pakai skeleton; spinner hanya di beberapa tempat
9. UI tombol-tombol dibikin flat (optimasi performa low-end)

## Yang Dikerjakan

### 1. Live HP Kamera Real (camera ^0.10.5+9)
- File: `app/lib/ui/screens/livestream_screen.dart` → `MobileBroadcastLiveScreen` sekarang pakai `CameraController` real
- Flow: `availableCameras()` → pilih front/back → `CameraController(high, enableAudio: mic)` → `initialize()` → `CameraPreview`
- Permission handling: `CameraAccessDenied` → pesan user-friendly "Buka Pengaturan > Aplikasi > XyCloudStore > Izin > Kamera"
- Fitur: flip kamera depan/belakang, flash torch, mic toggle (re-init controller), lifecycle `WidgetsBindingObserver` dispose/resume
- Flat UI: top bar SafeArea split (LIVE badge, durasi, viewer) tidak overlap, bottom controls flat tanpa glow/gradient
- Ingest info bottom sheet: endpoint RTMP `rtmps://live.cloudflare.com:443/live/`, sumber, status kamera, ID siaran
- Chat overlay simulasi + toggle
- Menghapus mock gradient placeholder lama (1304-1901)

### 2. Story Editor Lengkap (Instagram-like)
- File baru: `app/lib/ui/screens/story_editor_screen.dart`
- Fitur:
  - Gaya teks: normal/bold/italic/bold_italic/neon/pelangi/ketik/ombak/retro/minimal (10 opsi)
  - Warna picker 15 warna hex, ukuran Slider 14-40, align left/center/right
  - BG type: gradient (5 preset: ungu/emas/neon/senja/cyber) / solid color picker / image picker via GaleriPicker+Kompres.dataUri
  - Teks BG toggle + warna bg teks
  - Filter chips: normal/bw/sepia/vintage/vivid/warm/cool
  - Label builder: location/mention/hashtag/countdown/mood → JSON, no label jika kosong
  - Video trim RangeSlider dengan VideoPlayerController preview, max 15s
  - Privasi selector, bagikan
- API: `api/migrations/0027_story_editor_lengkap.sql` menambah 12 kolom (gaya_teks, warna_teks, ukuran_teks, align_teks, bg_type, bg_warna, bg_image_url, teks_bg, teks_bg_warna, label, trim_start, trim_end, filter, durasi_video)
- `api/schema.sql` sync, `api/src/index.js` stories POST terima 14 field baru + bg_image_url upload
- Models: `StoryItem` extended batch Q fields, `app_state.dart` buatStory signature extended, repository interface updated
- Wiring: `forum_screen.dart` onBuatStory sekarang `Navigator.push(xyRoute(StoryEditorScreen))` bukan `_SheetBuatStory` modal

### 3. Story Viewer Fixed (No Overlap, Like Reactive, Repost Bagus)
- File: `forum_screen.dart` → `StoryFullScreenViewer` diganti versi improved
- Fix overlap: top SafeArea split → progress bar di atas (8px top), header di bawah dengan spacing 14px, tidak tumpang tindih
- Like reactive: `context.watch<AppState>()` → ambil story terbaru dari `app.stories.where(id==raw.id)`, animasi like dengan `TweenAnimationBuilder` elasticOut
- Double-tap to like
- Repost bagus: bottom sheet preview dengan avatar, teks, tombol Batal/Repost (bukan dialog sederhana)
- Video support: `VideoPlayerController.networkUrl` untuk tipe video, sync durasi timer dengan video durasi <15s
- Skeleton placeholder untuk image loading (bukan spinner)
- Label chips: parse JSON label → icon + text chips (location, mention, hashtag, countdown, mood)
- Gaya teks rendering: hex color, bold/italic, neon shadow, retro shadow, ketik letterSpacing
- Background: gradient / solid / image URL

### 4. Video Editor Native (Trim)
- File baru: `app/lib/ui/screens/video_editor_screen.dart`
- Fitur: VideoPlayer preview dengan ColorFiltered matrix (bw/sepia/vivid), play/pause overlay, trim RangeSlider 1-15s constraint, filter selector 7 opsi, volume slider + mute toggle
- Return map `{trim_start, trim_end, filter, durasi, muted}`
- Wiring: `story_editor_screen.dart` `_pickVideo()` sekarang push `VideoEditorScreen` dulu, baru set dataUri + trim values
- Constructor support both `file` and `videoFile` param untuk backward compat

### 5. Stream PC Host Timeout 35s → 60s + Retry
- File: `app/lib/ui/screens/sesi_screen.dart` sudah fixed di batch Q awal:
  - Timeout 35→60 detik untuk VM lambat
  - Retry hint, pesan error lebih jelas: "Host tidak menjawab dalam 60 detik. Proses native sudah dihentikan agar layar tidak diam; tunggu sebentar lalu coba lagi atau jalankan Diagnostik jaringan. Jika VM Cyberindo baru nyala, tunggu 1-2 menit lalu hubungkan ulang."
  - Jalur cadangan LAN/Publik otomatis
  - Sanitized error messages

### 6. Loading Skeleton, Bukan Spinner
- `livestream_screen.dart`: `_Discovery` empty → `Kosong` dengan ilustrasi livestream, `_Studio` loading → `SkeletonList(count:3)`
- `forum_screen.dart`: `SkeletonForumList`, `SkeletonBox` untuk image placeholder
- `video_editor_screen.dart`: loading → `SkeletonBox`
- `mobile_broadcast_live_screen.dart` (now in livestream): loading kamera → `SkeletonBox` + text "Membuka kamera..."
- Spinner hanya di: button loading, kirim balasan story, tip dialog, dll (tempat yang memang butuh indikator proses)

### 7. Flat UI Optimization (Performa Low-End)
- `GradientButton`: sudah flat (solid color, Material+InkWell, tanpa gradient/shadow/glow/scale) — Batch P
- `XyCard`: flat, border line only, tanpa gradient/shadow, elevated diabaikan
- `Pressable`: flat InkWell, scale diabaikan, tanpa AnimatedScale
- `_PilihanSumber` di livestream: `AnimatedContainer` → `Container`, border `XyTheme.line` bukan white opacity, tanpa animasi berat
- Broadcast controls: `_FlatIconBtn` dan `_ControlBtn` flat, `Colors.black54` + `borderRadius 10`, tanpa BoxShadow/glow
- Hero Live masih gradient tapi bukan tombol; tombol-tombol sudah flat

### 8. Kustomisasi Profil Menu
- Check: `profil_screen.dart` line 357 sudah ada `_bangunBagianAkun` → `XyBarisMenu` Kustomisasi Profil → `pengaturan.KustomProfilScreen`
- Import `pengaturan_screen.dart as pengaturan` ada
- Menu tidak hilang di kode terbaru, mungkin bug di build lama. Sudah verified ada.

### 9. MP4 to WebP Testing Guide
- Docs: `docs/VIDEO_TO_ANIMATED_WEBP.md` ditambah section 7 lengkap:
  - Cara test lokal `tools/konversi_webp_animasi.sh` dengan contoh output, batch convert, ffprobe check
  - Cara test Cloudinary transform via curl manual + via API XyCloudStore `/api/me/banner-media`
  - Verifikasi di Flutter `BannerMedia.displayUrl` + `gaplessPlayback: true`
  - Troubleshooting table
- Tool: `tools/konversi_webp_animasi.sh` sudah ada, executable, support `--compare-gif`

## File Berubah

- `app/lib/ui/screens/livestream_screen.dart` — rewrite MobileBroadcastLiveScreen real camera + flat UI
- `app/lib/ui/screens/forum_screen.dart` — viewer improved + wiring StoryEditorScreen + skeleton
- `app/lib/ui/screens/story_editor_screen.dart` — NEW full editor + video trim wiring + VideoEditorScreen integration
- `app/lib/ui/screens/video_editor_screen.dart` — NEW native trim editor
- `app/lib/ui/screens/profil_screen.dart` — verified Kustomisasi Profil menu ada
- `app/pubspec.yaml` — camera, video_player, video_trimmer, path
- `api/migrations/0027_story_editor_lengkap.sql` — 12 kolom baru stories
- `api/schema.sql` — sync
- `api/src/index.js` — stories POST terima field baru
- `app/lib/models/models.dart`, `providers/app_state.dart`, `data/repository.dart` — extended
- `docs/VIDEO_TO_ANIMATED_WEBP.md` — tambah testing guide
- `docs/batch-q-lanjutan-2026-09-19.md` — NEW (file ini)

## Yang Belum / Menunggu Instruksi

- Push ke GitHub (standing rule: tunggu instruksi user)
- Build via GitHub Actions (jangan langsung, tunggu instruksi)
- Hapus file intermediate `forum_screen_improved.dart` dan `mobile_broadcast_live_screen.dart` (sudah dihapus)
- Audit inconsistency menyeluruh (page transitions tanpa fade-in, dll) — next step setelah push

## Cara Test Manual (Tanpa Build)

1. Story Editor: buka Forum → + Story → Editor muncul dengan preview, gaya teks, background, label, trim video
2. Story Viewer: tap story → progress bar di atas, header tidak overlap, like reactive + animasi, double-tap like, repost bottom sheet preview
3. Live HP Kamera: Studio Kreator → Pilih Sumber Kamera HP → Mulai Live HP → kamera depan kebuka, bisa flip, flash, mic toggle, chat overlay, akhiri
4. Video Trim: pilih video story → VideoEditorScreen muncul → trim slider 1-15s, filter, volume, selesai → kembali ke editor dengan trim values
5. Flat UI: semua tombol tanpa glow/gradient/shadow, responsif di low-end
6. Skeleton: loading forum/live tidak spinner besar, pakai shimmer
7. MP4 to WebP: jalankan `./tools/konversi_webp_animasi.sh sample.mp4` → cek output.webp ukuran vs GIF

## Catatan Keamanan

- Credential file `/home/user/uploads/kuncikerjasama.txt` tidak di-commit, tidak diekspos
- Camera permission error handling sudah user-friendly
- Story editor trim values disimpan sebagai metadata, bukan re-encode di client (hemat baterai), server bisa pakai Cloudinary transform `so_{trim_start},du_{durasi}` jika perlu

---
*Batch Q Lanjutan 2026-09-19 — Kamera HP Real + Story Editor Lengkap + Flat UI + Skeleton*
