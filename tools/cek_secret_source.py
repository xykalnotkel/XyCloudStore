#!/usr/bin/env python3
"""Pindai source untuk pola credential yang tidak boleh pernah masuk Git.

Latar belakang
--------------
Audit 2026-09-17 melakukan "audit pola secret" secara manual dan menyimpulkan
temuan hanya fixture test bertanda dummy. Alat ini mengotomatiskan audit itu
supaya bisa jalan di setiap CI run:

- Kunci privat PEM (RSA/EC/OpenSSH/PGP), keystore base64
- Token GitHub (ghp_/gho_/ghs_/ghu_/github_pat_), Slack, Stripe, Google API key
- Access key AWS, JWT, dan assignment generik ``api_key|secret|password|token``
  dengan nilai panjang yang bukan placeholder

Nilai temuan TIDAK dicetak utuh — hanya 4 karakter pertama + panjangnya, supaya
log CI sendiri tidak menjadi tempat bocor.

Cara pakai
----------
    python3 tools/cek_secret_source.py            # exit 1 bila ada temuan nyata
    python3 tools/cek_secret_source.py --json     # keluaran mesin
    python3 tools/cek_secret_source.py --path api # batasi ke subdirektori
"""
from __future__ import annotations

import argparse
import base64
import json
import re
import sys
from pathlib import Path

AKAR = Path(__file__).resolve().parent.parent

# Direktori yang tidak dipindai: bukan source proyek atau biner/hasil build.
LEWATI_DIR = {
    ".git", ".cache", "node_modules", "build", "dist", "out", ".next", ".dart_tool",
    "__pycache__", "coverage", "target", ".gradle", ".idea",
}
# Berkas kunci/lock: berisi hash integritas, bukan secret.
LEWATI_BERKAS = {"package-lock.json", "Cargo.lock", "moonlight.lock.json"}
EKSTENSI_DIPINDAI = {
    ".dart", ".js", ".mjs", ".cjs", ".ts", ".tsx", ".java", ".kt", ".rs", ".py",
    ".sql", ".json", ".yaml", ".yml", ".toml", ".html", ".css", ".md", ".gradle",
    ".kts", ".properties", ".xml", ".sh", ".env", ".txt", ".pro", ".cfg", ".ini",
}

POLA: list[tuple[str, re.Pattern[str]]] = [
    ("kunci-privat-pem", re.compile(r"-----BEGIN (?:RSA |EC |DSA |OPENSSH |PGP )?PRIVATE KEY")),
    ("token-github", re.compile(r"\bgh[pousr]_[A-Za-z0-9]{20,}\b|\bgithub_pat_[A-Za-z0-9_]{20,}\b")),
    ("token-slack", re.compile(r"\bxox[baprs]-[A-Za-z0-9-]{10,}\b")),
    ("kunci-stripe", re.compile(r"\b(?:sk|rk)_live_[A-Za-z0-9]{16,}\b")),
    ("kunci-google-api", re.compile(r"\bAIza[0-9A-Za-z_\-]{30,}\b")),
    ("access-key-aws", re.compile(r"\b(?:AKIA|ASIA)[0-9A-Z]{16}\b")),
    ("jwt", re.compile(r"\beyJ[A-Za-z0-9_\-]{10,}\.eyJ[A-Za-z0-9_\-]{10,}\.[A-Za-z0-9_\-]{10,}\b")),
    (
        "assignment-secret",
        re.compile(
            r"""(?i)\b(api[_-]?key|apikey|secret[_-]?key|app[_-]?secret|access[_-]?token|"""
            r"""auth[_-]?token|password|passwd|private[_-]?key|keystore[_-]?base64|"""
            r"""cloudflare[_-]?api[_-]?token|admin[_-]?key|signing[_-]?key)\b"""
            r"""\s*[:=]\s*['"]([^'"]{12,})['"]"""
        ),
    ),
    (
        "bearer-literal",
        re.compile(r"""(?i)\b(?:authorization|x-admin-key|bearer)\s*[:=]\s*['"]?(?!.*\$\{)[A-Za-z0-9_\-\.]{28,}"""),
    ),
]

# Nilai yang jelas placeholder/fixture → dilaporkan sebagai info, bukan gagal.
POLA_PLACEHOLDER = re.compile(
    r"(?i)(dummy|contoh|example|sample|test|fixture|placeholder|changeme|change_me|"
    r"your[_-]?|xxx+|<[^>]+>|\{\{|\$\{|redacted|fake|mock|invalid|none|null|todo|"
    r"rahasia|kunci[_-]?admin|secret[_-]?here|12345|abcdef)"
)


def samarkan(nilai: str) -> str:
    """Tampilkan 4 karakter pertama + panjang, tanpa membocorkan sisanya."""
    bersih = nilai.strip()
    if len(bersih) <= 4:
        return f"<{len(bersih)} char>"
    return f"{bersih[:4]}…<{len(bersih)} char>"


def iterasi_berkas(akar: Path):
    for path in sorted(akar.rglob("*")):
        if not path.is_file():
            continue
        if any(bagian in LEWATI_DIR for bagian in path.relative_to(AKAR).parts):
            continue
        if path.name in LEWATI_BERKAS:
            continue
        if path.suffix.lower() not in EKSTENSI_DIPINDAI and path.suffix:
            continue
        if not path.suffix:
            continue
        yield path


def nilai_mencurigakan(nilai: str) -> bool:
    """True bila nilai punya entropi/karakter khas credential, bukan placeholder."""
    if POLA_PLACEHOLDER.search(nilai):
        return False
    if len(nilai) < 12:
        return False
    # Hanya huruf kecil semua + ada spasi/kata umum → kemungkinan string biasa.
    unik = set(re.sub(r"[^A-Za-z0-9]", "", nilai))
    if len(unik) < 6:
        return False
    if re.fullmatch(r"[a-z0-9_\-\./:@ ]+", nilai) and "_" not in nilai and not re.search(r"\d", nilai):
        return False
    # Blob base64 panjang (mis. keystore) → curiga.
    tanpa_spasi = re.sub(r"\s+", "", nilai)
    if len(tanpa_spasi) >= 64:
        try:
            base64.b64decode(tanpa_spasi + "=" * (-len(tanpa_spasi) % 4), validate=True)
            return True
        except Exception:
            pass
    return bool(re.search(r"[A-Z]", nilai) and re.search(r"[a-z]", nilai) and re.search(r"\d", nilai)) or len(
        re.sub(r"[^A-Za-z0-9]", "", nilai)
    ) >= 24


def pindai(akar: Path) -> list[dict[str, object]]:
    temuan: list[dict[str, object]] = []
    for path in iterasi_berkas(akar):
        try:
            teks = path.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            continue
        for nomor, baris in enumerate(teks.splitlines(), start=1):
            if len(baris) > 4000:
                continue
            for nama, pola in POLA:
                for cocok in pola.finditer(baris):
                    if nama == "assignment-secret":
                        nilai = cocok.group(2)
                        if not nilai_mencurigakan(nilai):
                            continue
                        ringkas = samarkan(nilai)
                    else:
                        nilai = cocok.group(0)
                        if POLA_PLACEHOLDER.search(baris) and nama in {"assignment-secret", "bearer-literal"}:
                            continue
                        ringkas = samarkan(nilai)
                    temuan.append(
                        {
                            "berkas": str(path.relative_to(AKAR)),
                            "baris": nomor,
                            "pola": nama,
                            "nilai": ringkas,
                            "placeholder": bool(POLA_PLACEHOLDER.search(baris)),
                        }
                    )
    return temuan


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--json", action="store_true", help="cetak hasil sebagai JSON")
    parser.add_argument("--path", default=".", help="batasi pemindaian ke subdirektori (bawaan: seluruh repo)")
    parser.add_argument("--lapor-placeholder", action="store_true", help="tampilkan juga temuan bertanda dummy/test")
    args = parser.parse_args()

    target = (AKAR / args.path).resolve()
    if not target.exists():
        print(f"Path tidak ditemukan: {target}", file=sys.stderr)
        return 2

    semua = pindai(target)
    serius = [t for t in semua if not t["placeholder"]]
    info = [t for t in semua if t["placeholder"]]

    if args.json:
        print(json.dumps({"serius": serius, "info": info}, ensure_ascii=False, indent=2))
    else:
        berkas_dipindai = sum(1 for _ in iterasi_berkas(target))
        print(f"Berkas dipindai         : {berkas_dipindai}")
        print(f"Temuan perlu ditindak   : {len(serius)}")
        print(f"Temuan placeholder/dummy: {len(info)}")
        for t in serius:
            print(f"  [!] {t['berkas']}:{t['baris']} pola={t['pola']} nilai={t['nilai']}")
        if args.lapor_placeholder:
            for t in info:
                print(f"  [i] {t['berkas']}:{t['baris']} pola={t['pola']} nilai={t['nilai']}")

    if serius:
        print("\nHASIL: GAGAL — pindahkan credential ke secret manager.", file=sys.stderr)
        return 1
    print("\nHASIL: LULUS — tidak ada credential nyata di source.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
