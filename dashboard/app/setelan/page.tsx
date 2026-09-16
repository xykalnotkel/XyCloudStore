"use client";
import { useEffect, useState } from "react";
import { adminFetch } from "@/lib/api";
import { KeySquare, Plus, Search, ShieldAlert, SlidersHorizontal, Trash2 } from "lucide-react";
import { Chip, EmptyBox, ErrBox, Header, jam, Load } from "@/components/ui/kit";
import { konfirm } from "@/components/ui/dialog";

export default function SetelanPage() {
  const [rows, setRows] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState("");
  const [q, setQ] = useState("");
  const [kunci, setKunci] = useState("");
  const [nilai, setNilai] = useState("");
  const [busy, setBusy] = useState(false);
  const [hasil, setHasil] = useState("");

  async function muat() {
    setLoading(true); setErr("");
    try { const d = await adminFetch("/api/admin/setelan"); setRows(Array.isArray(d) ? d : []); }
    catch (e: any) { setErr(e.message); }
    finally { setLoading(false); }
  }
  useEffect(() => { muat(); }, []);

  async function simpan() {
    const k = kunci.trim();
    if (!/^[a-z0-9_.-]{1,64}$/.test(k)) { setErr("Nama kunci hanya huruf/angka/titik/garis bawah (a–z, 0–9, ., _, -)."); return; }
    if (/(secret|token|password|passwd|credential|terenkripsi|encrypted|api[._-]?key|private[._-]?key|client[._-]?secret|admin[._-]?key|jwt[._-]?secret)/i.test(k)) {
      setErr("Secret/API key tidak boleh disimpan di D1. Gunakan Cloudflare Worker Secret."); return;
    }
    setBusy(true); setErr(""); setHasil("");
    try {
      await adminFetch("/api/admin/setelan", { method: "POST", body: { kunci: k, nilai } });
      setHasil("Setelan " + k + " tersimpan.");
      setKunci(""); setNilai("");
      await muat();
    } catch (e: any) { setErr(e.message); }
    finally { setBusy(false); }
  }

  async function hapus(k: string) {
    if (!await konfirm({ pesan: "Hapus setelan " + k + "?", bahaya: true })) return;
    setBusy(true); setErr(""); setHasil("");
    try { await adminFetch("/api/admin/setelan/" + encodeURIComponent(k), { method: "DELETE" }); setHasil("Setelan " + k + " dihapus."); await muat(); }
    catch (e: any) { setErr(e.message); }
    finally { setBusy(false); }
  }

  const tampil = rows.filter((r) => !q || r.kunci.includes(q.toLowerCase()) || String(r.nilai || "").toLowerCase().includes(q.toLowerCase()));

  return (
    <div className="space-y-4 font-[var(--font-inter)]">
      <Header icon={SlidersHorizontal} title="Setelan Umum" sub="Penyimpanan kunci–nilai (key–value) di tabel setelan — diatur Worker & dashboard"
        right={<span className="text-xs px-3 py-1.5 rounded-full bg-[#F3F0FF] border border-[#E9E3F5] font-medium">{rows.length} kunci</span>} />
      {hasil && <div className="px-4 py-2.5 rounded-xl bg-emerald-500/10 border border-emerald-500/25 text-emerald-700 text-[12.5px] font-semibold">{hasil}</div>}
      <div className="px-4 py-3 rounded-2xl bg-amber-500/10 border border-amber-500/25 text-amber-800 text-[12px] font-medium flex items-start gap-2">
        <ShieldAlert size={16} className="shrink-0 mt-0.5" />
        <span>Hanya konfigurasi non-rahasia. API key, token, password, dan client secret wajib disimpan dengan <code>wrangler secret put</code>; server menolak nama kunci sensitif.</span>
      </div>

      <div className="xy-card rounded-[20px] p-4">
        <div className="flex items-center gap-2 mb-3"><KeySquare size={15} className="text-[#7C3AED]" /><span className="text-[12px] font-semibold text-[#1E1B2E]">Tambah / ubah setelan</span></div>
        <div className="grid sm:grid-cols-[minmax(0,240px)_1fr_auto] gap-2">
          <input value={kunci} onChange={(e) => setKunci(e.target.value)} placeholder="nama.kunci (a-z,0-9,._-)" className="px-3.5 py-2 rounded-xl bg-white border border-[#E9E3F5] text-[12.5px] font-mono focus:border-[#7C3AED] outline-none" />
          <input value={nilai} onChange={(e) => setNilai(e.target.value)} placeholder="nilai" className="px-3.5 py-2 rounded-xl bg-white border border-[#E9E3F5] text-[12.5px] focus:border-[#7C3AED] outline-none" />
          <button onClick={simpan} disabled={busy} className="inline-flex items-center justify-center gap-1.5 px-4 h-9 rounded-xl xy-btn text-white text-[12px] font-semibold disabled:opacity-50"><Plus size={13} /> Simpan</button>
        </div>
      </div>

      <div className="relative max-w-[320px]">
        <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-[#9A8CBF]" />
        <input value={q} onChange={(e) => setQ(e.target.value)} placeholder="Cari kunci / nilai…" className="w-full pl-9 pr-3 py-2 rounded-xl bg-white border border-[#E9E3F5] text-[12.5px] focus:border-[#7C3AED] outline-none" />
      </div>

      {loading ? <Load /> : err ? <ErrBox msg={err} /> : tampil.length === 0 ? (
        <EmptyBox msg="Tidak ada setelan yang cocok." sub="Ketuk + Simpan untuk menambah kunci baru." />
      ) : (
        <div className="space-y-2">
          {tampil.map((r) => (
            <div key={r.kunci} className="xy-card rounded-[14px] px-4 py-3 flex items-start gap-3">
              <div className="min-w-0 flex-1">
                <div className="flex items-center gap-2 flex-wrap">
                  <code className="text-[12px] font-mono font-semibold text-[#1E1B2E]">{r.kunci}</code>
                  {r.rahasia ? <Chip tone="bad">{r.kunci === "integrasi_giphy_terenkripsi" ? "terenkripsi — kelola di menu Stiker" : "rahasia lama — hapus/pindahkan"}</Chip> : String(r.nilai || "").length > 0 && <Chip tone="netral">{String(r.nilai).length} karakter</Chip>}
                </div>
                <div className={`text-[12px] mt-0.5 font-mono break-all ${r.rahasia ? "text-rose-600 font-semibold" : "text-[#6B5A8A]"}`}>{r.nilai}</div>
                <div className="text-[10.5px] text-[#7C738F] mt-1">diperbarui {jam(r.diperbarui)}</div>
              </div>
              <button onClick={() => hapus(r.kunci)} disabled={busy} className="shrink-0 p-2 rounded-lg bg-white border border-[#E9E3F5] hover:border-rose-300 disabled:opacity-50"><Trash2 size={13} className="text-rose-500" /></button>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
