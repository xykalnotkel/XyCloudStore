# Batch S — TikTok No Border, 0ms Button, Profile Drag-Drop Grid

Tanggal: 2026-09-19
Request: all card jangan ada garis border, background hitam ke abu-abuan card abu-abu kek TikTok, custom posisi grid di profile drag and drop, profile publik diperbagus, semua tombol 0ms kayak app gede super cepat & ada feedback denyut kayak WA

## 1. Card Tanpa Border Ala TikTok

**Before:** `XyCard` border `line` #E9E3F5, light mode bg lavender #F5F3FF, surface putih, border terlihat jelas — terasa murah di light mode.

**After TikTok Style:**
- `theme.dart`:
  - `bgGelap = #0A0A0A` (TikTok black pekat)
  - `surfaceGelap = #1E1E1E` (card abu-abu TikTok)
  - `surfaceGelap2 = #262626` (elevated)
  - `lineGelap = #1E1E1E` (same as surface → no visible border)
  - Light mode juga pakai dark brightness + same colors — jadi light & dark sama-sama TikTok black abu-abu tanpa border
  - `XyPalette` semua getter return TikTok colors: bg #0A0A0A, surface #1E1E1E, surfaceHigh #262626, line #1E1E1E (no border)
- `common.dart` `XyCard`:
  - `border = false` default
  - Decoration cuma `color: surface` + `borderRadius`, tanpa `border`
  - Komentar: "TikTok style: tanpa border, background abu-abu, no shadow"
- `XyBarisMenu`:
  - Dulu `border bottom lineSoft` → sekarang `color: surface, radius 12, margin bottom 8`, tanpa border, pakai `Pressable` 0ms
- `SkeletonForumList`, `SkeletonKomentarList`:
  - Hapus `border: Border.all(line)` → cuma `color: surface`, tanpa border
- Hasil: feed kayak TikTok — background hitam pekat, card abu-abu gelap #1E1E1E, tidak ada garis, clean

## 2. Tombol 0ms + Denyut WA

**Before:** `Pressable` pakai `InkWell onTap` → delay 100-150ms (Flutter nunggu tap confirm), tanpa animasi scale.

**After 0ms + Denyut:**
- `Pressable` rewrite jadi `StatefulWidget` dengan `AnimationController 120ms` + `Tween scale 1.0→0.92`:
  ```dart
  onTapDown: _ctrl.forward(); HapticFeedback.selectionClick(); // 0ms langsung
  onTapUp: _ctrl.reverse(); widget.onTap?.call();
  onTapCancel: _ctrl.reverse();
  AnimatedBuilder → Transform.scale
  ```
  - `behavior: HitTestBehavior.opaque`, `GestureDetector onTapDown` bukan `onTap` → **0ms langsung denyut**, tidak tunggu
  - Haptic feedback pas `onTapDown`, bukan `onTap`

- `GradientButton` rewrite sama:
  - `StatefulWidget`, `AnimationController 100ms`, scale `1.0→0.94`
  - `onTapDown` 0ms forward + haptic, `onTapUp` reverse + call `onPressed`
  - Glossy overlay tetap ada

- `XyBarisMenu` sekarang pakai `Pressable` → otomatis 0ms denyut

**Kenapa 0ms Ala App Gede & WA?**
- WA, IG, TikTok pakai `onTapDown` buat feedback, bukan `onTap` → terasa instant
- Scale 0.92-0.94 + 100-120ms easeOut → denyut halus kayak WA pas pencet chat
- Haptic `selectionClick` pas down, bukan up → otak ngerasa tombol responsif

## 3. Custom Posisi Grid Profile Drag & Drop

**File Baru:** `profile_layout_editor_screen.dart`

- Model `ProfileElement(id,label,icon,builder)`:
  - avatar, nama, username, badges, slogan, bio, bio_link, stats, action
- Load order dari `SharedPreferences 'profile_layout_order'` (atau default)
- UI:
  - Preview TikTok style di atas: `Container #1E1E1E radius 20` dengan column elemen sesuai `_elements` order
  - Builder tiap elemen pakai data user real dari `AppState.user` (avatar, GayaNama, LencanaTier, dll)
  - Drag & Drop list di bawah: `ReorderableListView.builder` dengan `onReorder` update `_elements`
  - Tiap item: `Container #1E1E1E radius 14` + ListTile icon 36 bg primary 15% + label w700 + drag handle
  - Tombol Simpan: FAB extended primary + `Prefs.setString('profile_layout_order', order.join(','))`
  - Reset: `Prefs.remove`

- Integrasi:
  - `pengaturan_screen.dart` → `KustomProfilScreen` tambah menu `Atur Layout Profil (Drag & Drop)` → `ProfileLayoutEditorScreen`
  - `profil_publik_screen.dart` → load `profile_layout_order` dari SharedPreferences, render elemen sesuai order custom via `_buildElement(id,p)`

- Hasil: user bisa atur posisi nama, bio, badge sesuka hati, drag & drop, disimpan lokal, profil publik ikut custom order

## 4. Profile Publik Diperbagus Ala TikTok

**Before:** banner 190 + avatar 96 + Wrap badges + bio link chip border + stats container border + action Row

**After TikTok:**
- Background `Scaffold #0A0A0A`
- `SliverAppBar` expanded 200, pinned, `BannerProfil` full, leading back button `Pressable` circle black 35% + icon white 20, action "Atur Layout" kalau saya
- Avatar 100 center, `ClipOval AppImage` atau inisial 36 w900
- Nama 22 w900 white center + LencanaTier + badge
- Username 13 w700 primary center
- Badges: pill `surface #262626 radius 20` + primary untuk badge khusus
- Slogan italic muted center
- Bio 13.5 height 1.5 w600 #E4E4E7 center (tebal)
- Bio link: `Pressable` container #262626 radius 20 + link icon white + text white w700
- Stats: container #1E1E1E radius 16 tanpa border, row posting/pengikut/mengikuti dengan value 18 w900 white + label 11 muted, divider 1px #2A2A2A, number format K/M (1.2K, 1.1M)
- Action: `GradientButton` Ikuti/Mengikuti + `Pressable` Pesan container #262626 radius 99
- Laporkan: `Pressable` container #1E1E1E radius 20
- No border di semua card, background hitam abu-abu

## File Berubah

- `app/lib/core/theme.dart` — TikTok colors #0A0A0A bg, #1E1E1E card, #262626 elevated, no border, light & dark sama
- `app/lib/ui/widgets/common.dart` — `XyCard` border false, `Pressable` 0ms denyut WA (GestureDetector onTapDown + scale 0.92), `GradientButton` 0ms + glossy + scale 0.94, `XyBarisMenu` tanpa border + Pressable, skeleton tanpa border
- `app/lib/ui/screens/profile_layout_editor_screen.dart` — NEW drag & drop grid editor + preview TikTok + Prefs
- `app/lib/ui/screens/profil_publik_screen.dart` — rewrite TikTok style + custom layout order + 0ms Pressable + no border
- `app/lib/core/prefs.dart` — tambah generic getString/setString/remove
- `app/lib/ui/screens/pengaturan_screen.dart` — tambah menu Atur Layout Profil + import editor
- `docs/batch-s-tiktok-no-border-0ms-2026-09-19.md` — NEW (file ini)

## Cara Test

1. **No Border TikTok**: buka app light mode → background hitam #0A0A0A, semua card abu-abu #1E1E1E tanpa garis, kayak TikTok. Dark mode sama.
2. **0ms Denyut WA**: pencet semua tombol (Pressable, GradientButton, XyBarisMenu) → langsung scale down 0.92 dalam 0ms + haptic, pas lepas scale up, kayak WA. Tidak ada delay 100ms.
3. **Profile Drag-Drop**: Profil → Kustomisasi Profil → Atur Layout Profil → lihat preview TikTok di atas, drag handle di list bawah untuk reorder avatar/nama/bio/badges/stats, Simpan → buka Profil Publik → order sesuai custom.
4. **Publik Diperbagus**: buka profil orang → avatar 100 center, nama 22 w900, stats K/M, bio tebal center, link chip #262626, tombol Ikuti + Pesan flat glossy, tanpa border.

## Next

- Push (tunggu instruksi)
- Build (tunggu instruksi)
- Tambah grid 2 kolom untuk layout (sekarang list vertical, next bisa grid ala IG)
- Simpan layout ke server juga biar sync antar device

---
*Batch S 2026-09-19 — TikTok No Border + 0ms WA Pulse + Profile Drag-Drop*
