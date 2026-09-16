#!/usr/bin/env python3
"""
Siapkan ikon notifikasi push (small icon Android) dari LOGO APLIKASI
XyCloudStore (bukan logo studio XyVerse).

Ikon small-icon Android harus monokrom (siluet putih dengan alpha channel),
persegi ~96x96dp (dirender hingga 384px aman untuk density tinggi).

Alur:
  1. Baca `app/assets/ikon_push.png` (sudah digenerate dari LOGO APLIKASI),
     fallback ke `app/assets/brand/logo_icon_putih.png` bila belum ada.
  2. Tulis ke `api/src/ic-stat-onesignal.png` (salinan module, dipakai
     cepat bila dibutuhkan).
  3. Bila `[android_dir]` diberikan, buat
     `android/app/src/main/res/drawable/ic_stat_onesignal_default.png`
     sehingga meng-OVERRIDE ikon bawaan OneSignal (nama drawable sama,
     resource app menang atas AAR). Hasilnya: ikon push = logo aplikasi
     XyCloudStore.
  4. Cadangan nama alias `ic_stat_xycloudstore.png` (bukan XyVerse).

Idempoten: dijalankan ulang aman.
"""
from __future__ import annotations

import argparse
import os
import sys

try:
    from PIL import Image
except ImportError:
    sys.exit("PIL tidak tersedia; pasang lewat `pip install pillow`.")


def muat_ikon(repo_root: str):
    kandidat = [
        os.path.join(repo_root, "app", "assets", "ikon_push.png"),
        os.path.join(repo_root, "app", "assets", "brand", "logo_icon_putih.png"),
        os.path.join(repo_root, "app", "assets", "brand", "logo_icon.png"),
    ]
    for p in kandidat:
        if os.path.exists(p):
            return p
    sys.exit("Tidak menemukan aset logo (ikon_push.png / logo_icon_putih.png).")


def monokrom(src: str, ukuran: int = 384) -> Image.Image:
    im = Image.open(src).convert("RGBA")
    # crop alpha bounding box supaya siluet terisi penuh
    bbox = im.getchannel("A").getbbox()
    if bbox:
        im = im.crop(bbox)
    im.thumbnail((ukuran, ukuran), Image.LANCZOS)
    canvas = Image.new("RGBA", (ukuran, ukuran), (0, 0, 0, 0))
    w, h = im.size
    canvas.paste(im, ((ukuran - w) // 2, (ukuran - h) // 2), im)
    # paksa warna putih (Android small icon = siluet putih)
    px = canvas.load()
    for y in range(ukuran):
        for x in range(ukuran):
            r, g, b, a = px[x, y]
            if a > 0:
                px[x, y] = (255, 255, 255, a)
    return canvas


def utama() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--android-dir", default=None,
                    help="path android/ hasil flutter create (opsional)")
    args = ap.parse_args()

    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    src = muat_ikon(root)
    ikon = monokrom(src, 384)

    # 1) aset module Worker (dipakai bila nanti diperlukan; juga di-commit)
    dst_worker = os.path.join(root, "api", "src", "ic-stat-onesignal.png")
    os.makedirs(os.path.dirname(dst_worker), exist_ok=True)
    ikon.save(dst_worker, format="PNG")
    print(f"Tulis {dst_worker}")

    # 2) override drawable OneSignal di resource Android (bila android/ ada)
    if args.android_dir:
        drawable = os.path.join(args.android_dir, "app", "src", "main", "res", "drawable")
        os.makedirs(drawable, exist_ok=True)
        dst_drawable = os.path.join(drawable, "ic_stat_onesignal_default.png")
        ikon.save(dst_drawable, format="PNG")
        print(f"Tulis {dst_drawable}")

  # 3) cadangan nama alias (untuk payload small_icon lain) — nama konsisten
  #    dengan logo aplikasi XyCloudStore, BUKAN logo studio XyVerse.
  if args.android_dir:
      drawable = os.path.join(args.android_dir, "app", "src", "main", "res", "drawable")
      dst_alias = os.path.join(drawable, "ic_stat_xycloudstore.png")
      ikon.save(dst_alias, format="PNG")
      print(f"Tulis {dst_alias}")
  return 0


if __name__ == "__main__":
    raise SystemExit(utama())
