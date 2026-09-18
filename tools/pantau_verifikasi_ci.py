#!/usr/bin/env python3
"""Pantau run workflow `Verifikasi Build Menyeluruh` dari terminal.

Latar belakang
--------------
Workflow verifikasi (`.github/workflows/verifikasi-build.yml`) punya job panjang:
Flutter + NDK bisa 35-60 menit, cargo build agen Windows 15-35 menit. Alat ini
menampilkan status tiap job secara berkala dan, bila ada yang gagal, langsung
mengambil langkah (step) yang merah beserta ekor lognya — jadi tidak perlu
membuka tab Actions lalu klik satu per satu.

Catatan penting tentang pemicu
------------------------------
GitHub **hanya mendaftarkan** workflow yang ada di branch default. File workflow
yang baru push ke branch non-default tidak akan memicu run sama sekali (push
maupun pull_request), dan `workflow_dispatch`-nya dibalas 404. Karena itu workflow
verifikasi harus sudah ada di `main` dulu; setelah itu push ke branch `ci/**`
baru memicu run.

Cara pakai
----------
    export GITHUB_TOKEN=ghp_...                 # atau --token
    python3 tools/pantau_verifikasi_ci.py                    # run terbaru di main
    python3 tools/pantau_verifikasi_ci.py --ref ci/patch-1   # run di branch lain
    python3 tools/pantau_verifikasi_ci.py --sekali             # cetak sekali, keluar
    python3 tools/pantau_verifikasi_ci.py --log-gagal          # unduh log job gagal
    python3 tools/pantau_verifikasi_ci.py --mulai              # dispatch run baru

Token hanya dipakai untuk membaca repo publik + memicu dispatch; nilainya tidak
pernah dicetak maupun ditulis ke berkas.
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.request
import zipfile
import io

API = "https://api.github.com"
REPO = os.environ.get("XY_REPO", "xykalnotkel/XyCloudStore")
NAMA_WORKFLOW = os.environ.get("XY_WORKFLOW", "verifikasi-build.yml")
IKON = {
    "success": "LULUS ",
    "failure": "GAGAL ",
    "cancelled": "BATAL ",
    "skipped": "LEWAT ",
    "in_progress": "jalan ",
    "queued": "antre ",
    "waiting": "tunggu",
    "completed": "selesai",
    "pending": "tunda ",
}


def panggil(jalur: str, token: str, data: dict | None = None, metode: str | None = None) -> tuple[int, object]:
    url = jalur if jalur.startswith("http") else f"{API}{jalur}"
    body = json.dumps(data).encode() if data is not None else None
    req = urllib.request.Request(
        url,
        data=body,
        method=metode or ("POST" if data is not None else "GET"),
        headers={
            "Authorization": f"Bearer {token}",
            "Accept": "application/vnd.github+json",
            "Content-Type": "application/json",
            "User-Agent": "XyCloudStore-pantau-ci/1.0",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=40) as resp:
            mentah = resp.read()
            if not mentah:
                return resp.status, None
            try:
                return resp.status, json.loads(mentah)
            except json.JSONDecodeError:
                return resp.status, mentah
    except urllib.error.HTTPError as exc:
        try:
            return exc.code, json.loads(exc.read())
        except Exception:  # noqa: BLE001
            return exc.code, {"message": str(exc)}


def cari_id_workflow(token: str) -> int:
    kode, data = panggil(f"/repos/{REPO}/actions/workflows", token)
    if kode != 200:
        raise SystemExit(f"Gagal membaca daftar workflow (HTTP {kode}): {data}")
    for w in data.get("workflows", []):  # type: ignore[union-attr]
        if w.get("path", "").endswith(NAMA_WORKFLOW):
            return int(w["id"])
    raise SystemExit(
        f"Workflow {NAMA_WORKFLOW} tidak terdaftar. Workflow hanya terdaftar bila "
        f"berkasnya sudah ada di branch default ({REPO})."
    )


def ambil_run(token: str, wid: int, ref: str | None) -> dict | None:
    query = f"/repos/{REPO}/actions/workflows/{wid}/runs?per_page=10"
    if ref:
        query += f"&branch={ref}"
    kode, data = panggil(query, token)
    if kode != 200:
        raise SystemExit(f"Gagal membaca run (HTTP {kode}): {data}")
    runs = data.get("workflow_runs", []) if isinstance(data, dict) else []
    return runs[0] if runs else None


def ambil_jobs(token: str, run: dict) -> list[dict]:
    kode, data = panggil(run["jobs_url"] + "?per_page=50", token)
    if kode != 200:
        return []
    return data.get("jobs", []) if isinstance(data, dict) else []


def cetak_status(run: dict, jobs: list[dict]) -> bool:
    """Cetak tabel status. Return True bila seluruh job sudah selesai."""
    print(f"\nRun #{run['run_number']} | {run['head_branch']} | {run['event']} | {run['status']}/{run['conclusion'] or '-'}")
    print(f"commit {run['head_sha'][:7]} | mulai {run['run_started_at']}")
    print(f"{run['html_url']}\n")
    selesai = True
    for j in jobs:
        kesimpulan = j.get("conclusion") or j["status"]
        tanda = IKON.get(kesimpulan, kesimpulan)
        mulai = (j.get("started_at") or "")[11:19]
        print(f"  [{tanda}] {j['name']:<36} mulai {mulai}")
        for langkah in j.get("steps", []):
            if langkah.get("conclusion") in {"failure", "cancelled"} or langkah["status"] == "in_progress":
                ikon_langkah = IKON.get(langkah.get("conclusion") or langkah["status"], "?")
                print(f"           └─ {ikon_langkah} {langkah['name']}")
        if j["status"] != "completed":
            selesai = False
    return selesai and run["status"] == "completed"


def ambil_log_gagal(token: str, jobs: list[dict], baris: int) -> None:
    """Unduh log job yang gagal dan cetak ekor bagian yang error."""
    for j in jobs:
        if j.get("conclusion") not in {"failure", "cancelled"}:
            continue
        gagal = [s for s in j.get("steps", []) if s.get("conclusion") in {"failure", "cancelled"}]
        nama_step = gagal[0]["name"] if gagal else "(step tidak diketahui)"
        print(f"\n===== {j['name']} → step gagal: {nama_step} =====")
        try:
            req = urllib.request.Request(
                j["id"] and f"{API}/repos/{REPO}/actions/jobs/{j['id']}/logs",
                headers={
                    "Authorization": f"Bearer {token}",
                    "Accept": "application/vnd.github+json",
                    "User-Agent": "XyCloudStore-pantau-ci/1.0",
                },
            )
            with urllib.request.urlopen(req, timeout=90) as resp:
                teks = resp.read().decode("utf-8", errors="replace")
        except Exception as exc:  # noqa: BLE001
            print(f"  (log tidak bisa diunduh: {exc}) — buka {j.get('html_url')}")
            continue
        potongan = teks.splitlines()
        # Cari baris error khas tiap toolchain, lalu cetak konteksnya.
        indeks = [
            i
            for i, b in enumerate(potongan)
            if any(
                k in b
                for k in ("error:", "Error:", "ERROR", "FAILURE:", "failed", "Exception", "Undefined name")
            )
        ]
        if not indeks:
            for b in potongan[-baris:]:
                print(" ", b)
            continue
        awal = max(0, indeks[0] - 5)
        akhir = min(len(potongan), indeks[-1] + baris)
        for b in potongan[awal:akhir]:
            print(" ", b)


def dispatch(token: str, wid: int, ref: str, ketat: str) -> None:
    kode, data = panggil(
        f"/repos/{REPO}/actions/workflows/{wid}/dispatches",
        token,
        data={"ref": ref, "inputs": {"ketat": ketat}},
    )
    if kode not in (200, 204):
        raise SystemExit(f"Dispatch ditolak (HTTP {kode}): {data}")
    print(f"Run baru dipicu pada ref '{ref}' (mode ketat={ketat}).")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--token", default=os.environ.get("GITHUB_TOKEN", ""), help="PAT GitHub (bawaan: $GITHUB_TOKEN)")
    parser.add_argument("--ref", default=None, help="branch yang run-nya dipantau (bawaan: run terbaru)")
    parser.add_argument("--sekali", action="store_true", help="cetak status sekali lalu keluar")
    parser.add_argument("--interval", type=int, default=60, help="jeda antar cek dalam detik (bawaan: 60)")
    parser.add_argument("--batas-menit", type=int, default=90, help="berhenti setelah N menit (bawaan: 90)")
    parser.add_argument("--log-gagal", action="store_true", help="cetak potongan log job yang gagal")
    parser.add_argument("--baris-log", type=int, default=40, help="jumlah baris log yang dicetak (bawaan: 40)")
    parser.add_argument("--mulai", action="store_true", help="picu run baru (workflow_dispatch) lalu pantau")
    parser.add_argument("--ketat", default="false", choices=["false", "true"], help="input 'ketat' saat --mulai")
    args = parser.parse_args()

    if not args.token:
        print("Token tidak ada. Set GITHUB_TOKEN atau pakai --token.", file=sys.stderr)
        return 2

    wid = cari_id_workflow(args.token)
    print(f"Workflow '{NAMA_WORKFLOW}' id={wid} di {REPO}")

    if args.mulai:
        dispatch(args.token, wid, args.ref or "main", args.ketat)
        time.sleep(12)

    mulai = time.time()
    while True:
        run = ambil_run(args.token, wid, args.ref)
        if not run:
            print("Belum ada run. Pakai --mulai untuk memicu, atau push ke branch ci/**.")
            if args.sekali:
                return 1
            time.sleep(args.interval)
            continue
        jobs = ambil_jobs(args.token, run)
        selesai = cetak_status(run, jobs)
        if selesai:
            if args.log_gagal:
                ambil_log_gagal(args.token, jobs, args.baris_log)
            gagal = [j["name"] for j in jobs if j.get("conclusion") not in {"success", "skipped", None}]
            if gagal:
                print(f"\nHASIL: GAGAL — {len(gagal)} job merah: {', '.join(gagal)}")
                return 1
            print("\nHASIL: LULUS — seluruh job hijau.")
            return 0
        if args.sekali:
            return 0
        if (time.time() - mulai) / 60.0 > args.batas_menit:
            print(f"\nBerhenti memantau setelah {args.batas_menit} menit; run masih jalan.")
            return 0
        time.sleep(args.interval)


if __name__ == "__main__":
    raise SystemExit(main())
