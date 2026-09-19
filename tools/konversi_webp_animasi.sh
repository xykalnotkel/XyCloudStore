#!/bin/bash
# ============================================================
# XyCloudStore — Video → Animated WebP ala Discord
# Usage: ./konversi_webp_animasi.sh input.mp4 [output.webp]
# ============================================================
set -e

INPUT="$1"
OUTPUT="${2:-${INPUT%.*}_discord.webp}"

if [ -z "$INPUT" ]; then
  echo "Pakai: $0 input.mp4 [output.webp]"
  echo "Contoh: $0 video.mp4 banner.webp"
  exit 1
fi

if ! command -v ffmpeg &> /dev/null; then
  echo "ffmpeg belum terinstal. Install dulu: sudo apt install ffmpeg"
  exit 1
fi

echo "=== Konversi Discord-style Animated WebP ==="
echo "Input : $INPUT"
echo "Output: $OUTPUT"
echo "Spec  : 480px, 20 FPS, 5 detik, q75, loop infinite, alpha 8-bit"
echo ""

# Cek durasi, ambil 5 detik dari tengah jika video >5 detik
DUR=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$INPUT" 2>/dev/null || echo "0")
START="0"
if awk "BEGIN{exit !($DUR > 5)}"; then
  START=$(awk "BEGIN{print $DUR/2 - 2.5}")
  if awk "BEGIN{exit !($START < 0)}"; then START="0"; fi
fi

echo "Durasi sumber: ${DUR}s, mulai dari: ${START}s (5 detik)"

ffmpeg -y -ss "$START" -t 5 -i "$INPUT" \
  -vf "fps=20,scale=480:-1:flags=lanczos" \
  -vcodec libwebp -lossless 0 -quality 75 -compression_level 4 -loop 1 -an \
  "$OUTPUT"

echo ""
echo "--- Hasil ---"
ls -lh "$OUTPUT"
echo ""

# Bandingkan dengan GIF jika diminta
if [ "$3" == "--compare-gif" ]; then
  GIF_OUT="${INPUT%.*}_compare.gif"
  echo "Membuat perbandingan GIF..."
  ffmpeg -y -ss "$START" -t 5 -i "$INPUT" \
    -vf "fps=15,scale=480:-1:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=128[p];[s1][p]paletteuse=dither=bayer" \
    -loop 0 "$GIF_OUT"
  ls -lh "$GIF_OUT"
  echo ""
  echo "Perbandingan:"
  echo "  GIF : $(du -h "$GIF_OUT" | cut -f1)"
  echo "  WebP: $(du -h "$OUTPUT" | cut -f1)"
  WEBP_SIZE=$(stat -c%s "$OUTPUT")
  GIF_SIZE=$(stat -c%s "$GIF_OUT")
  SAVING=$(awk "BEGIN{print 100 - ($WEBP_SIZE/$GIF_SIZE*100)}")
  echo "  Hemat: ${SAVING}% lebih kecil dari GIF"
fi

echo ""
echo "Selesai! Upload ke XyCloudStore banner akan otomatis jadi WebP + GIF fallback."
