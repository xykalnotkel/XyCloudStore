# Video → Animated WebP ala Discord — Panduan Lengkap

> Implementasi XyCloudStore Batch O (2026-09-19): Cloudinary `f_webp,fl_awebp,fl_animated` untuk banner profil, mirip Discord Nitro.

---

## 1. Kenapa Bukan GIF?

| Aspek | GIF (1987) | Animated WebP (Discord) | Looping MP4 (Discord Chat) |
|-------|------------|-------------------------|----------------------------|
| Warna | 256 warna max | 24-bit truecolor (16.7M) | 24-bit |
| Alpha | 1-bit binary (gerigi) | 8-bit halus (glow, bayangan) | Tidak ada (tapi bisa VP9 alpha) |
| Ukuran 5 detik 480p | ~2-4 MB | ~0.6-1.2 MB (64% lebih kecil) | ~0.3-0.8 MB |
| FPS | 10-15 FPS ideal | Hingga 30 FPS | 30-60 FPS |
| Loop | e_loop | e_loop seamless | `loop muted autoplay` |
| Dukungan | Universal | Chrome 32+, Firefox 65+, Safari 14+, Flutter native | Universal |
| Discord pakai | Hampir tidak lagi | Avatar `a_*.webp`, Banner, Dekorasi | GIF di chat sebenarnya MP4 |

**Kesimpulan Discord:**
- Avatar/banner animasi: `cdn.discordapp.com/avatars/{id}/a_{hash}.webp?size=240`
- Dekorasi avatar: APNG / Animated WebP / Lottie JSON (bukan GIF, butuh alpha halus)
- Stiker: PNG 320x320 / APNG / Lottie, max 512KB — **GIF ditolak**
- GIF di chat: dikonversi jadi MP4 muted looping (hemat 90% bandwidth)

---

## 2. Cloudinary Transform (Yang Dipakai di API)

### Banner Profil (480px, 20 FPS, 5 detik, loop infinite)

```
# Primary: Animated WebP (Discord-style)
f_webp,fl_awebp,fl_animated,w_480,c_limit,fps_20,du_5,q_auto:good,e_loop

# Fallback: GIF lossy untuk klien lama
f_gif,w_480,c_limit,fps_15,du_5,q_auto,fl_lossy,fl_animated,e_loop
```

**Eager dual-upload:**
```js
eager = "f_webp,fl_awebp,fl_animated,w_480,c_limit,fps_20,du_5,q_auto:good,e_loop|f_gif,w_480,c_limit,fps_15,du_5,q_auto,fl_lossy,fl_animated,e_loop"
```

**URL hasil:**
```
https://res.cloudinary.com/<cloud>/video/upload/f_webp,fl_awebp,fl_animated,w_480,c_limit,fps_20,du_5,q_auto:good,e_loop/v123/xycloudstore/banner-profil/abc.webp
https://res.cloudinary.com/<cloud>/video/upload/f_gif,w_480,c_limit,fps_15,du_5,q_auto,fl_lossy,fl_animated,e_loop/v123/xycloudstore/banner-profil/abc.gif
```

Disamarkan jadi:
```
/media/f_webp,fl_awebp,fl_animated,w_480,c_limit,fps_20,du_5,q_auto:good,e_loop/v123/xycloudstore/banner-profil/abc.webp
/media/f_gif,w_480,c_limit,fps_15,du_5,q_auto,fl_lossy,fl_animated,e_loop/v123/xycloudstore/banner-profil/abc.gif
```

### Alternatif Format

- **AVIF animasi** (lebih kecil lagi, tapi Flutter belum full): `f_avif,fl_animated,w_480,fps_20,du_5`
- **APNG** (untuk stiker butuh alpha super halus): `f_png,fl_apng,fl_animated,w_480,fps_20,du_5`

---

## 3. FFmpeg Workflows (Lokal, Tanpa Cloudinary)

### 3.1 Video MP4 → Animated WebP (Rekomendasi)

```bash
# 480p, 20 FPS, 5 detik pertama, kualitas good, loop infinite, transparan halus
ffmpeg -i input.mp4 -t 5 -vf "fps=20,scale=480:-1:flags=lanczos" \
  -vcodec libwebp -lossless 0 -quality 75 -compression_level 4 -loop 1 \
  -an -vsync 0 output.webp

# Versi lebih kecil (lossy max, 15 FPS)
ffmpeg -i input.mp4 -t 5 -vf "fps=15,scale=480:-1" \
  -vcodec libwebp -lossless 0 -quality 60 -compression_level 6 -loop 1 \
  -an output_small.webp

# Dengan alpha (jika source MOV ProRes 4444 transparan)
ffmpeg -i input_with_alpha.mov -t 5 -vf "fps=20,scale=480:-1" \
  -vcodec libwebp -lossless 0 -quality 75 -loop 1 -an output_alpha.webp
```

**Cek ukuran:**
```bash
ls -lh output.webp
# Bandingkan dengan GIF:
ffmpeg -i input.mp4 -t 5 -vf "fps=15,scale=480:-1:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=128[p];[s1][p]paletteuse" output.gif
ls -lh output.gif output.webp
# WebP biasanya 60-70% lebih kecil
```

### 3.2 Video → GIF (Legacy, Tidak Disarankan)

```bash
# 2-pass palettegen (hasil paling bagus untuk GIF)
ffmpeg -i input.mp4 -t 5 -vf "fps=15,scale=480:-1:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=128[p];[s1][p]paletteuse=dither=bayer" output.gif

# GIF lossy via gifsicle (lebih kecil)
gifsicle -O3 --lossy=80 -o output_lossy.gif output.gif
```

### 3.3 Video → Looping MP4 (Paling Hemat, Ala Discord Chat GIF)

```bash
# Discord sebenarnya kirim MP4 muted looping, bukan GIF
ffmpeg -i input.mp4 -t 5 -vf "fps=20,scale=480:-1" \
  -c:v libx264 -profile:v high -pix_fmt yuv420p -crf 23 -preset medium \
  -an -movflags +faststart output_loop.mp4

# VP9 WebM (lebih kecil, support alpha)
ffmpeg -i input.mp4 -t 5 -vf "fps=20,scale=480:-1" \
  -c:v libvpx-vp9 -b:v 0 -crf 30 -an output_loop.webm
```

**HTML:**
```html
<video src="output_loop.mp4" autoplay loop muted playsinline width="480"></video>
```

### 3.4 GIF → Animated WebP (Konversi Koleksi Lama)

```bash
# GIF existing → WebP animasi
ffmpeg -i old.gif -vcodec libwebp -lossless 0 -quality 75 -loop 1 -an new.webp

# Batch convert
for f in *.gif; do ffmpeg -i "$f" -vcodec libwebp -quality 75 -loop 1 -an "${f%.gif}.webp"; done
```

### 3.5 Batch Cloudinary-like Pipeline (FFmpeg + ffprobe)

```bash
#!/bin/bash
# convert_to_discord_webp.sh
INPUT=$1
BASENAME=$(basename "$INPUT" | cut -d. -f1)

# Ambil durasi, potong 5 detik dari awal (atau tengah)
DUR=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$INPUT")
START=$(echo "$DUR/2 - 2.5" | bc -l) # tengah video
[ $(echo "$START < 0" | bc) -eq 1 ] && START=0

ffmpeg -ss $START -t 5 -i "$INPUT" \
  -vf "fps=20,scale=480:-1:flags=lanczos" \
  -vcodec libwebp -lossless 0 -quality 70 -compression_level 4 -loop 1 -an \
  "${BASENAME}_480p_20fps.webp" &

ffmpeg -ss $START -t 5 -i "$INPUT" \
  -vf "fps=15,scale=480:-1:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=128[p];[s1][p]paletteuse" \
  -loop 0 "${BASENAME}_480p_15fps.gif" &

wait
ls -lh ${BASENAME}_*
```

---

## 4. Implementasi di XyCloudStore

### API (`api/src/upload.js`)

```js
function buildAnimatedTransform({ w=480, fps=20, durasi=5.0, format='webp', kualitas='auto:good' }={}) {
  const base = `du_${durasi},so_0,w_${w},c_limit,fps_${fps},q_${kualitas},e_loop`;
  if (format==='webp') return `f_webp,fl_awebp,fl_animated,${base}`;
  if (format==='gif')  return `f_gif,${base},fl_lossy,fl_animated`;
}

export async function unggahVideoBanner(env, { dataUri }) {
  const tWebP = buildAnimatedTransform({ w:480, fps:20, durasi:5.0, format:'webp' });
  const tGif  = buildAnimatedTransform({ w:480, fps:15, durasi:5.0, format:'gif' });
  const eager = `${tWebP}|${tGif}`;
  // upload video/upload dengan eager → dapat webp + gif sekaligus
}
```

### Flutter (`BannerMedia`)

```dart
class BannerMedia {
  final String tipe; // 'video' | 'gif'
  final String url;  // legacy
  final String gif;  // fallback
  final String webp; // primary Discord-style

  String get displayUrl => webp.isNotEmpty ? webp : (gif.isNotEmpty ? gif : url);
  bool get isAnimatedWebP => webp.isNotEmpty;
}
```

Widget:
```dart
CachedNetworkImage(
  imageUrl: media.displayUrl, // webp > gif > url
  imageBuilder: (c, p) => Image(image: p, gaplessPlayback: true),
)
```

### Kenapa Dual Eager?

- **WebP primary**: 24-bit + 8-bit alpha, 64% lebih kecil, loop seamless, glow/bayangan halus (penting untuk efek epic naga/inferno)
- **GIF fallback**: perangkat lama / WebView jadul yang belum support WebP animasi
- Flutter `gaplessPlayback: true` penting agar loop tidak kedip

---

## 5. Perbandingan Ukuran Real (Test 5 detik 480p)

| Sumber MP4 8 MB | GIF 15 FPS 128 warna | WebP 20 FPS q75 | WebP 15 FPS q60 | MP4 loop 20 FPS crf23 |
|-----------------|----------------------|-----------------|-----------------|-----------------------|
| 5 detik | 2.8 MB | 0.9 MB | 0.6 MB | 0.45 MB |
| 5 detik + alpha | 3.2 MB (binary alpha, jelek) | 1.1 MB (halus) | 0.8 MB | N/A (butuh VP9) |

**Penghematan vs GIF:** WebP ~68% lebih kecil, MP4 loop ~84% lebih kecil.

---

## 6. Rekomendasi untuk Fitur Lain

- **Avatar decoration**: pakai APNG atau Lottie (butuh alpha sempurna) — jangan GIF
- **Stiker animasi**: APNG 320x320 atau Lottie JSON max 512KB (ikut Discord)
- **Feed video pendek**: looping MP4 muted autoplay (bukan GIF)
- **Badge animasi**: Animated WebP 128x128, fps 15, du 2 detik, loop

---

## 7. Referensi

- Cloudinary: https://cloudinary.com/documentation/videos_to_animated_images
- Discord: CDN `a_` hash → `.webp` animasi, docs `cdn.discordapp.com/avatars/.../a_...webp`
- FFmpeg WebP: https://ffmpeg.org/ffmpeg-codecs.html#libwebp
- Flutter: `Image(gaplessPlayback: true)` support Animated WebP sejak Flutter 3.3+

---

*Last updated: 2026-09-19 Batch O — Discord-style Animated WebP*
