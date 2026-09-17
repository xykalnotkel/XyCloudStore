#!/usr/bin/env python3
"""Mendaftarkan rilis APK baru ke server XyCloudStore.

Dipanggil alur build setelah rilis GitHub terbit, sehingga halaman unduh
di situs langsung menampilkan versi terbaru tanpa menanyakan GitHub.

Pemakaian:
    python3 tools/daftar_rilis.py v1.9.0

Variabel lingkungan:
    ADMIN_KEY   kunci admin XyCloudStore (wajib)
    API_URL     alamat API, bawaan https://api.xycloud.my.id
"""
import json
import os
import sys
import urllib.error
import urllib.request


def cari_apk(akar: str = '.') -> list[dict]:
    """Kumpulkan semua berkas APK hasil build beserta ukurannya."""
    ketemu: dict[str, dict] = {}
    for direktori, _, berkas in os.walk(akar):
        for nama in berkas:
            if nama.startswith('XyCloudStore-') and nama.endswith('.apk'):
                jalur = os.path.join(direktori, nama)
                ketemu[nama] = {'nama': nama, 'ukuran': os.path.getsize(jalur)}
    return list(ketemu.values())


def main() -> int:
    versi = sys.argv[1] if len(sys.argv) > 1 else os.getenv('GITHUB_REF_NAME', '')
    kunci = os.getenv('ADMIN_KEY', '')
    alamat = os.getenv('API_URL', 'https://api.xycloud.my.id')

    if not kunci:
        print('ADMIN_KEY belum diatur; pendaftaran rilis ditolak.', file=sys.stderr)
        return 1
    if not versi or not versi.startswith('v') or len(versi) > 40:
        print('Tag versi tidak valid; pendaftaran rilis ditolak.', file=sys.stderr)
        return 1
    if alamat != 'https://api.xycloud.my.id':
        print('API_URL rilis harus memakai origin produksi kanonik.', file=sys.stderr)
        return 1

    berkas = cari_apk()
    if not berkas:
        print('Tidak ada berkas APK yang ditemukan.', file=sys.stderr)
        return 1

    muatan = json.dumps({'versi': versi, 'berkas': berkas}).encode()
    permintaan = urllib.request.Request(
        f'{alamat}/api/admin/rilis',
        data=muatan,
        headers={
            'Content-Type': 'application/json',
            'x-admin-key': kunci,
            # penting: user agent bawaan urllib ditolak penyaring bot Cloudflare
            'User-Agent': 'XyCloudStore-CI/1.0',
        },
    )

    try:
        with urllib.request.urlopen(permintaan, timeout=25) as jawab:
            print(f'Rilis {versi} terdaftar ({jawab.status}) dengan {len(berkas)} berkas:')
            for b in berkas:
                print(f"  - {b['nama']} {round(b['ukuran'] / 1048576, 1)} MB")
    except urllib.error.HTTPError as e:
        print(f'GAGAL mendaftarkan rilis: HTTP {e.code} {e.read().decode(errors="ignore")[:300]}',
              file=sys.stderr)
        return 1
    except Exception as e:  # noqa: BLE001
        print(f'GAGAL mendaftarkan rilis: {e}', file=sys.stderr)
        return 1

    # Pendaftaran rilis adalah gerbang halaman unduh dan popup pembaruan.
    # Kalau gagal, CI HARUS merah: sebelumnya kegagalan ditelan (return 0)
    # sehingga selama lima hari server tetap menyajikan rilis lama sementara
    # semua workflow tampak hijau (audit 2026-09-13).
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
