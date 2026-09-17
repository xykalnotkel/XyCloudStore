#!/usr/bin/env python3
"""Siapkan tiga screenshot APK nyata untuk hero situs XyCloudStore.

Contoh setelah build manual dan pengambilan gambar dari emulator/perangkat:
  python3 tools/siapkan_screenshot_hero.py \
    --home captures/home.png \
    --stream captures/stream.png \
    --community captures/community.png

Output ditempatkan di dashboard/public/brand/screens/ dan otomatis dilayani
melalui /brand/screens/* oleh Worker. Script tidak membuat mockup: semua input
wajib berupa tangkapan layar raster dari APK yang sudah dijalankan.
"""

from __future__ import annotations

import argparse
import hashlib
from pathlib import Path
import sys

try:
    from PIL import Image, ImageFilter, ImageOps
except ImportError as exc:  # pragma: no cover - pesan operasional
    raise SystemExit("Pillow belum tersedia. Jalankan: python3 -m pip install pillow") from exc

TARGET = (1080, 2400)
MAX_INPUT_BYTES = 30 * 1024 * 1024
MIN_WIDTH = 720
MIN_HEIGHT = 1280
OUTPUT_DIR = Path(__file__).resolve().parents[1] / "dashboard/public/brand/screens"


def parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description="Optimalkan screenshot APK nyata menjadi WebP hero.")
    p.add_argument("--home", required=True, type=Path, help="Screenshot beranda/saldo")
    p.add_argument("--stream", required=True, type=Path, help="Screenshot streaming/HUD")
    p.add_argument("--community", required=True, type=Path, help="Screenshot komunitas/profil")
    return p


def proses(sumber: Path, nama: str) -> tuple[Path, str, int]:
    if not sumber.is_file():
        raise ValueError(f"Berkas tidak ditemukan: {sumber}")
    if sumber.stat().st_size > MAX_INPUT_BYTES:
        raise ValueError(f"Input terlalu besar (>30 MB): {sumber}")
    if sumber.suffix.lower() not in {".png", ".jpg", ".jpeg", ".webp"}:
        raise ValueError(f"Format input tidak didukung: {sumber.suffix}")

    with Image.open(sumber) as mentah:
        mentah.verify()
    with Image.open(sumber) as mentah:
        if mentah.width < MIN_WIDTH or mentah.height < MIN_HEIGHT:
            raise ValueError(
                f"Resolusi {sumber} terlalu kecil ({mentah.width}x{mentah.height}); "
                f"minimal {MIN_WIDTH}x{MIN_HEIGHT}."
            )
        # Salin piksel ke RGB baru agar EXIF, lokasi, profil vendor, dan metadata
        # perangkat tidak ikut dipublikasikan.
        rgb = Image.new("RGB", mentah.size, "#F5F3FF")
        rgba = mentah.convert("RGBA")
        rgb.paste(rgba, mask=rgba.getchannel("A"))
        hasil = ImageOps.fit(
            rgb,
            TARGET,
            method=Image.Resampling.LANCZOS,
            centering=(0.5, 0.0),
        ).filter(ImageFilter.UnsharpMask(radius=0.65, percent=45, threshold=3))

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    tujuan = OUTPUT_DIR / nama
    hasil.save(tujuan, "WEBP", quality=86, method=6, exact=True)
    ukuran = tujuan.stat().st_size
    if ukuran > 1_500_000:
        tujuan.unlink(missing_ok=True)
        raise ValueError(f"Output {nama} masih terlalu besar ({ukuran} byte).")
    digest = hashlib.sha256(tujuan.read_bytes()).hexdigest()
    return tujuan, digest, ukuran


def main() -> int:
    args = parser().parse_args()
    pasangan = [
        (args.home, "home.webp"),
        (args.stream, "stream.webp"),
        (args.community, "community.webp"),
    ]
    try:
        hasil = [proses(sumber.resolve(), nama) for sumber, nama in pasangan]
    except (OSError, ValueError) as exc:
        print(f"Gagal: {exc}", file=sys.stderr)
        return 2

    print("Screenshot APK siap untuk hero:")
    for tujuan, digest, ukuran in hasil:
        print(f"- {tujuan.relative_to(OUTPUT_DIR.parents[3])} | {ukuran:,} byte | sha256 {digest}")
    print("Periksa visual dan data pribadi sebelum deploy dashboard/Worker.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
