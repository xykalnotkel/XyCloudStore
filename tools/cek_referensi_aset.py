#!/usr/bin/env python3
"""Periksa referensi aset literal aplikasi Flutter terhadap berkas yang benar-benar ada.

Latar belakang
--------------
Audit 2026-09-17 memeriksa "literal asset reference app: tidak ada berkas yang
hilang" secara manual. Alat ini membuat pemeriksaan itu bisa diulang di CI:

1. Setiap string literal ``assets/...`` di ``app/lib/**/*.dart`` harus menunjuk
   berkas yang ada di ``app/`` (atau berada di direktori yang dideklarasikan
   pubspec, misalnya aset yang dihasilkan ``flutter_launcher_icons``).
2. Setiap direktori aset yang dideklarasikan ``app/pubspec.yaml`` harus ada dan
   tidak kosong — Flutter gagal build bila direktori aset hilang.
3. Berkas aset yang tidak pernah direferensikan dilaporkan sebagai info
   (kandidat pembersihan ukuran APK), bukan kegagalan.

Cara pakai
----------
    python3 tools/cek_referensi_aset.py            # lapor + exit 1 bila ada yang hilang
    python3 tools/cek_referensi_aset.py --json     # keluaran mesin
    python3 tools/cek_referensi_aset.py --quiet    # hanya ringkasan
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

AKAR = Path(__file__).resolve().parent.parent
APP = AKAR / "app"
LIB = APP / "lib"
PUBSPEC = APP / "pubspec.yaml"

# String literal Dart yang memuat jalur aset, mis. 'assets/brand/icon.png'.
# Jalur terinterpolasi ('assets/bingkai/$id.webp') ikut tertangkap lalu
# diperlakukan sebagai pola varian, bukan berkas literal.
POLA_ASET = re.compile(r"""['"](assets/[^'"\s]+?\.(?:png|jpg|jpeg|webp|gif|svg|json|txt|ttf|otf|webm|mp4))['"]""")
# Interpolasi Dart: $nama atau ${obj.prop}
POLA_INTERPOLASI = re.compile(r"\$\{[^}]*\}|\$[A-Za-z_][A-Za-z0-9_]*")
# Direktori/berkas aset yang dideklarasikan pubspec (baris "    - assets/brand/").
POLA_PUBSPEC_ASET = re.compile(r"^\s*-\s+(assets/[^\s#]+)\s*$")
# Aset yang boleh tidak ada di repo karena dihasilkan saat build.
DIPERBOLEHKAN_HILANG = {
    # flutter_native_splash / launcher icon menulis ke android/, bukan assets/.
}
EKSTENSI_ASET = {".png", ".jpg", ".jpeg", ".webp", ".gif", ".svg", ".json", ".txt", ".ttf", ".otf", ".webm", ".mp4"}


def kumpulkan_referensi() -> dict[str, list[str]]:
    """Petakan jalur aset -> daftar berkas Dart yang mereferensikannya."""
    referensi: dict[str, list[str]] = {}
    if not LIB.exists():
        raise SystemExit(f"Direktori tidak ditemukan: {LIB}")
    for dart in sorted(LIB.rglob("*.dart")):
        try:
            isi = dart.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        for jalur in POLA_ASET.findall(isi):
            referensi.setdefault(jalur, []).append(str(dart.relative_to(AKAR)))
    return referensi


def kumpulkan_deklarasi_pubspec() -> list[str]:
    if not PUBSPEC.exists():
        raise SystemExit(f"pubspec tidak ditemukan: {PUBSPEC}")
    deklarasi: list[str] = []
    for baris in PUBSPEC.read_text(encoding="utf-8").splitlines():
        cocok = POLA_PUBSPEC_ASET.match(baris)
        if cocok:
            deklarasi.append(cocok.group(1))
    return deklarasi


def periksa() -> dict[str, object]:
    referensi = kumpulkan_referensi()
    deklarasi = kumpulkan_deklarasi_pubspec()

    hilang: list[dict[str, object]] = []
    varian_kosong: list[dict[str, object]] = []
    varian_ada: list[dict[str, object]] = []
    for jalur, pemakai in sorted(referensi.items()):
        if "$" in jalur:
            # Jalur terinterpolasi → cocokkan sebagai glob. Kode pemanggil
            # umumnya punya errorBuilder, jadi varian kosong = peringatan.
            pola = POLA_INTERPOLASI.sub("*", jalur)
            kandidat = sorted((APP / Path(pola).parent).glob(Path(pola).name)) if (APP / Path(pola).parent).is_dir() else []
            if kandidat:
                varian_ada.append({"pola": pola, "jumlah": len(kandidat), "direferensikan_oleh": pemakai})
            else:
                varian_kosong.append({"pola": pola, "direferensikan_oleh": pemakai})
            continue
        kandidat = APP / jalur
        if kandidat.exists():
            continue
        if jalur in DIPERBOLEHKAN_HILANG:
            continue
        hilang.append({"aset": jalur, "direferensikan_oleh": pemakai})

    deklarasi_masalah: list[dict[str, object]] = []
    for entri in deklarasi:
        target = APP / entri
        if entri.endswith("/"):
            if not target.is_dir():
                deklarasi_masalah.append({"entri": entri, "masalah": "direktori tidak ada"})
            elif not any(p.suffix.lower() in EKSTENSI_ASET for p in target.iterdir()):
                deklarasi_masalah.append({"entri": entri, "masalah": "direktori kosong (tidak ada aset)"})
        elif not target.exists():
            deklarasi_masalah.append({"entri": entri, "masalah": "berkas tidak ada"})

    # Aset di disk yang tidak pernah direferensikan dari Dart (literal maupun
    # lewat pola varian yang cocok).
    terpakai = {j for j in referensi if "$" not in j}
    for item in varian_ada:
        pola = str(item["pola"])
        for p in sorted((APP / Path(pola).parent).glob(Path(pola).name)):
            terpakai.add(str(p.relative_to(APP)))
    tidak_terpakai: list[str] = []
    for entri in deklarasi:
        target = APP / entri
        berkas = sorted(target.rglob("*")) if target.is_dir() else [target]
        for p in berkas:
            if not p.is_file() or p.suffix.lower() not in EKSTENSI_ASET:
                continue
            relatif = str(p.relative_to(APP))
            if relatif not in terpakai:
                tidak_terpakai.append(relatif)

    return {
        "total_referensi": len(referensi),
        "total_deklarasi_pubspec": len(deklarasi),
        "hilang": hilang,
        "varian_kosong": varian_kosong,
        "varian_ada": varian_ada,
        "deklarasi_masalah": deklarasi_masalah,
        "tidak_terpakai": tidak_terpakai,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--json", action="store_true", help="cetak hasil sebagai JSON")
    parser.add_argument("--quiet", action="store_true", help="hanya ringkasan dan galat")
    parser.add_argument(
        "--strict-tidak-terpakai",
        action="store_true",
        help="anggap aset tak terpakai sebagai kegagalan (bawaan: info saja)",
    )
    parser.add_argument(
        "--strict-varian",
        action="store_true",
        help="anggap pola varian tanpa satu pun berkas sebagai kegagalan (bawaan: peringatan)",
    )
    args = parser.parse_args()

    hasil = periksa()
    if args.json:
        print(json.dumps(hasil, ensure_ascii=False, indent=2))
    else:
        print(f"Referensi aset literal : {hasil['total_referensi']}")
        print(f"Deklarasi aset pubspec : {hasil['total_deklarasi_pubspec']}")
        if hasil["hilang"]:
            print("\nBERKAS ASET HILANG:")
            for item in hasil["hilang"]:
                print(f"  - {item['aset']}")
                for pemakai in item["direferensikan_oleh"]:  # type: ignore[union-attr]
                    print(f"      dipakai di: {pemakai}")
        if hasil["deklarasi_masalah"]:
            print("\nDEKLARASI PUBSPEC BERMASALAH:")
            for item in hasil["deklarasi_masalah"]:
                print(f"  - {item['entri']} → {item['masalah']}")
        if hasil["varian_ada"]:
            print("\nPola varian terinterpolasi yang punya berkas:")
            for item in hasil["varian_ada"]:
                print(f"  - {item['pola']} → {item['jumlah']} berkas")
        if hasil["varian_kosong"]:
            print("\nPERINGATAN — pola varian tidak punya satu pun berkas (kode harus punya fallback):")
            for item in hasil["varian_kosong"]:
                print(f"  - {item['pola']}")
                for pemakai in item["direferensikan_oleh"]:  # type: ignore[union-attr]
                    print(f"      dipakai di: {pemakai}")
        if not args.quiet and hasil["tidak_terpakai"]:
            print(f"\nAset tak direferensikan literal ({len(hasil['tidak_terpakai'])}) — info saja:")
            for jalur in hasil["tidak_terpakai"]:
                print(f"  - {jalur}")

    gagal = bool(hasil["hilang"] or hasil["deklarasi_masalah"])
    if args.strict_tidak_terpakai and hasil["tidak_terpakai"]:
        gagal = True
    if args.strict_varian and hasil["varian_kosong"]:
        gagal = True
    if gagal:
        print("\nHASIL: GAGAL", file=sys.stderr)
        return 1
    print("\nHASIL: LULUS — tidak ada aset yang direferensikan tetapi hilang.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
