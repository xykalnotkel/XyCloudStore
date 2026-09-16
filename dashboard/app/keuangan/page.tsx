"use client";
import { useEffect, useState } from "react";
import { adminFetch } from "@/lib/api";
import { AlertCircle, Banknote, Download, Hourglass, Landmark, TrendingUp, Users, Wallet } from "lucide-react";

const rupiah = (n: number | string | undefined | null) =>
  "Rp " + Number(n || 0).toLocaleString("id-ID");

function Badge({ status }: { status: string }) {
  const map: Record<string, string> = {
    menunggu: "bg-amber-500/15 border border-amber-500/30 text-amber-600",
    diperiksa: "bg-sky-500/15 border border-sky-500/30 text-sky-600",
    disetujui: "bg-emerald-500/15 border border-emerald-500/30 text-emerald-600",
    ditolak: "bg-rose-500/15 border border-rose-500/30 text-rose-600",
  };
  return <span className={`text-[10px] px-2 py-0.5 rounded-full font-semibold tracking-wide ${map[status] || map.menunggu}`}>{status}</span>;
}

export default function KeuanganPage() {
  const [keu, setKeu] = useState<any>(null);
  const [stats, setStats] = useState<any>(null);
  const [topup, setTopup] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState("");

  useEffect(() => {
    Promise.all([
      adminFetch("/api/admin/keuangan"),
      adminFetch("/api/admin/stats"),
      adminFetch("/api/admin/topup"),
    ])
      .then(([a, b, c]) => {
        setKeu(a);
        setStats(b);
        setTopup(Array.isArray(c) ? c : []);
      })
      .catch((e) => setErr(e.message))
      .finally(() => setLoading(false));
  }, []);

  const pending = topup.filter((t) => t.status === "menunggu" || t.status === "diperiksa");
  const jumlahPending = pending.reduce((s: number, t: any) => s + Number(t.nominal || 0) + Number(t.kode_unik || 0), 0);
  const harian = Array.isArray(stats?.harian) ? stats.harian.slice().sort((x: any, y: any) => String(x.d).localeCompare(String(y.d))) : [];
  const totalHarian = harian.reduce((s: number, r: any) => s + Number(r.v || 0), 0);

  const unduhCSV = () => {
    const baris: (string | number)[][] = [
      ["Ringkasan Keuangan XyCloudStore", new Date().toLocaleString("id-ID")],
      [],
      ["Metrik", "Nilai"],
      ["Pendapatan (kredit transaksi)", keu?.pendapatan ?? 0],
      ["Top up disetujui", keu?.topup ?? 0],
      ["Biaya provider pembayaran", keu?.biaya_provider ?? 0],
      ["Top up tertunda (jumlah)", jumlahPending],
      ["Pengguna terdaftar", stats?.users ?? 0],
      ["Pesanan total", stats?.orders ?? 0],
      ["Pesanan berjalan", stats?.ordersAktif ?? 0],
      ["Pendapatan 7 hari terakhir", totalHarian],
      [],
      ["Tanggal", "Pesanan", "Omzet"],
      ...harian.slice(-7).map((r: any) => [r.d, r.n, r.v || 0]),
    ];
    const csv = baris.map((r) => r.map((c) => (typeof c === "string" && /[",\n]/.test(c) ? `"${c.replace(/"/g, '""')}"` : c)).join(",")).join("\n");
    const url = URL.createObjectURL(new Blob(["\uFEFF" + csv], { type: "text/csv;charset=utf-8" }));
    const a = document.createElement("a");
    a.href = url;
    a.download = "keuangan-xycloud.csv";
    a.click();
    URL.revokeObjectURL(url);
  };

  const cards = [
    { l: "Pendapatan Total", v: rupiah(keu?.pendapatan), Icon: TrendingUp, t: "text-emerald-600" },
    { l: "Top up Masuk", v: rupiah(keu?.topup), Icon: Landmark, t: "text-[#7C3AED]" },
    { l: "Biaya Provider", v: rupiah(keu?.biaya_provider), Icon: Banknote, t: "text-rose-600" },
    { l: "Top up Tertunda", v: `${pending.length} (${rupiah(jumlahPending)})`, Icon: Hourglass, t: "text-amber-600" },
    { l: "Pengguna Terdaftar", v: String(stats?.users ?? 0), Icon: Users, t: "text-sky-600" },
  ];

  return (
    <div className="space-y-4 font-[var(--font-inter)]">
      <div className="flex items-center justify-between flex-wrap gap-2">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl xy-btn grid place-items-center"><Wallet size={18} className="text-white" /></div>
          <div>
            <h1 className="text-xl font-semibold text-[#1E1B2E] tracking-tight">Keuangan <span className="ml-2 text-[10px] px-2 py-0.5 rounded-full bg-[#F3F0FF] font-semibold">BARU</span></h1>
            <p className="text-sm text-[#7C738F] font-medium">Pendapatan, top up, dan tren pesanan — langsung dari D1</p>
          </div>
        </div>
        <button onClick={unduhCSV} className="text-xs px-3 py-2 rounded-xl xy-btn font-semibold text-white flex items-center gap-1.5">
          <Download size={13} /> Export CSV
        </button>
      </div>

      {loading ? (
        <div className="xy-card rounded-xl p-10 text-center text-[#7C738F] font-medium">Memuat data keuangan…</div>
      ) : err ? (
        <div className="xy-card rounded-xl p-4 text-red-600 font-medium">{err}</div>
      ) : (
        <>
          <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-5 gap-3">
            {cards.map((c) => (
              <div key={c.l} className="xy-card rounded-[14px] p-4 flex items-center gap-3">
                <div className="w-9 h-9 rounded-xl bg-[#F3F0FF] border border-[#E9E3F5] grid place-items-center"><c.Icon size={16} className={c.t} /></div>
                <div className="min-w-0">
                  <div className="text-[11px] text-[#7C738F] font-medium tracking-wide uppercase">{c.l}</div>
                  <div className="text-base font-semibold text-[#1E1B2E] mt-0.5 tracking-tight truncate">{c.v}</div>
                </div>
              </div>
            ))}
          </div>

          {Array.isArray(keu?.provider) && keu.provider.length > 0 && (
            <div className="flex flex-wrap gap-2">
              {keu.provider.map((p: any) => (
                <div key={p.provider || "legacy"} className="px-3 py-2 rounded-xl bg-white border border-[#E9E3F5] text-[11px] text-[#6B5A8A]">
                  <b className="uppercase text-[#1E1B2E]">{p.provider || "legacy"}</b> • {p.transaksi} transaksi • {rupiah(p.nominal)} • fee {rupiah(p.biaya)}
                </div>
              ))}
            </div>
          )}

          <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
            <div className="xy-card rounded-[16px] p-5">
              <div className="flex items-center justify-between">
                <h3 className="font-semibold text-[#1E1B2E] tracking-tight flex items-center gap-2"><TrendingUp size={15} className="text-[#7C3AED]" /> Tren Pesanan 30 Hari</h3>
                <span className="text-[11px] text-[#7C738F] font-mono">{harian.length} hari</span>
              </div>
              {harian.length === 0 ? (
                <div className="py-10 text-center text-[#7C738F] text-sm font-medium">Belum ada pesanan tercatat.</div>
              ) : (
                <div className="mt-4 space-y-1.5 max-h-[360px] overflow-auto pr-1">
                  {harian.slice(-14).map((r: any) => {
                    const p = totalHarian ? Math.max(3, Math.round((Number(r.v || 0) / totalHarian) * 100)) : 0;
                    return (
                      <div key={r.d} className="grid grid-cols-[92px_1fr_110px] items-center gap-2 text-[12px]">
                        <span className="text-[#7C738F] font-medium">{String(r.d).slice(5)}</span>
                        <div className="h-2 rounded-full bg-[#F3F0FF] overflow-hidden">
                          <div className="h-full rounded-full bg-gradient-to-r from-[#7C3AED] to-[#A855F7]" style={{ width: `${p}%` }} />
                        </div>
                        <span className="text-right font-mono text-[#1E1B2E]">{rupiah(r.v || 0)}<span className="text-[#7C738F]"> • {r.n}</span></span>
                      </div>
                    );
                  })}
                </div>
              )}
            </div>

            <div className="xy-card rounded-[16px] p-5">
              <div className="flex items-center justify-between">
                <h3 className="font-semibold text-[#1E1B2E] tracking-tight flex items-center gap-2"><AlertCircle size={15} className="text-amber-600" /> Top up Tertunda ({pending.length})</h3>
                <Banknote size={15} className="text-[#7C738F]" />
              </div>
              {pending.length === 0 ? (
                <div className="py-10 text-center text-[#7C738F] text-sm font-medium">Tidak ada top up menunggu — semua sudah diproses.</div>
              ) : (
                <div className="mt-3 space-y-2 max-h-[360px] overflow-auto pr-1">
                  {pending.map((t: any) => (
                    <div key={t.id} className="flex items-center justify-between gap-2 p-2.5 rounded-xl bg-[#F3F0FF] border border-[#E9E3F5]">
                      <div className="min-w-0">
                        <div className="text-[12px] text-[#1E1B2E] font-semibold truncate">{t.nama || t.email}</div>
                        <div className="text-[10px] text-[#7C738F] font-mono truncate">{t.id} • {t.metode || "-"}</div>
                      </div>
                      <div className="text-right shrink-0">
                        <div className="text-[12px] font-mono font-semibold text-[#1E1B2E]">{rupiah(Number(t.total || t.nominal || 0))}</div>
                        <Badge status={t.status} />
                      </div>
                    </div>
                  ))}
                </div>
              )}
              <div className="mt-3 text-[11px] text-[#7C738F] font-medium">Kelola persetujuan di menu <span className="text-[#7C3AED] font-semibold">Top Up</span>.</div>
            </div>
          </div>
        </>
      )}

      <div className="xy-card rounded-xl p-3 text-[11px] text-[#7C738F] font-medium">
        Sumber: /api/admin/keuangan (pendapatan & top up dari transaksi), /api/admin/stats (pengguna, pesanan, tren), /api/admin/topup (daftar pending). Export CSV dibuat di sisi klien. Icons Lucide, no emoji.
      </div>
    </div>
  );
}
