"use client";
import { useEffect, useState } from "react";
import { adminFetch } from "@/lib/api";
import { Copy, KeyRound, Plus, RefreshCw, ShieldUser, Trash2, UserPlus } from "lucide-react";
import { Chip, ErrBox, Header, jam, Load, Select } from "@/components/ui/kit";
import { konfirm, toast } from "@/components/ui/dialog";

export default function PeranPage() {
  const [rows, setRows] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState("");
  const [nama, setNama] = useState("");
  const [peran, setPeran] = useState("cs");
  const [saving, setSaving] = useState(false);
  const [baru, setBaru] = useState<{ kunci: string; peran: string } | null>(null);

  async function muat() {
    setLoading(true); setErr("");
    try { setRows(await adminFetch("/api/admin/peran")); }
    catch (e: any) { setErr(e.message); }
    finally { setLoading(false); }
  }
  useEffect(() => { muat(); }, []);

  async function buat() {
    if (!nama.trim()) return;
    setSaving(true); setErr(""); setBaru(null);
    try {
      const hasil = await adminFetch("/api/admin/peran", { method: "POST", body: { nama: nama.trim(), peran } });
      setBaru({ kunci: hasil?.kunci || "", peran: hasil?.peran || peran });
      setNama("");
      await muat();
    } catch (e: any) { setErr(e.message); }
    finally { setSaving(false); }
  }

  async function hapus(id: string, preview: string) {
    if (!await konfirm({ pesan: `Hapus admin key ${preview}?`, bahaya: true })) return;
    try {
      await adminFetch("/api/admin/peran/" + id, { method: "DELETE" });
      await muat();
    } catch (e: any) { setErr(e.message); }
  }

  async function putar(id: string, nama: string) {
    if (!await konfirm({ pesan: `Putar kunci untuk "${nama}"? Kunci lama langsung mati.`, bahaya: true })) return;
    setErr(""); setBaru(null);
    try {
      const hasil = await adminFetch(`/api/admin/peran/${id}/rotate`, { method: "POST", body: {} });
      if (hasil?.kunci) setBaru({ kunci: hasil.kunci, peran: hasil.peran || "" });
      await muat();
    } catch (e: any) { setErr(e.message); }
  }

  function salin(kunci: string) {
    navigator.clipboard?.writeText(kunci).then(() => toast("Key disalin ke clipboard.", "ok")).catch(() => {});
  }

  return (
    <div className="space-y-4 font-[var(--font-inter)]">
      <Header icon={ShieldUser} title="Peran Admin" sub="Kelola admin key & peran (khusus pemilik)"
        right={<span className="text-xs px-3 py-1.5 rounded-full bg-[#F3F0FF] border border-[#E9E3F5] font-medium">{rows.length} admin</span>} />

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
        <div className="xy-card rounded-[20px] p-5 lg:row-span-1">
          <h3 className="font-semibold text-[#1E1B2E] tracking-tight flex items-center gap-2"><UserPlus size={15} className="text-[#7C3AED]" /> Tambah Admin</h3>
          <div className="mt-3 space-y-3">
            <input value={nama} onChange={(e) => setNama(e.target.value)} placeholder="Nama admin"
              className="w-full px-4 py-2.5 rounded-xl bg-white border border-[#E9E3F5] text-sm text-[#1E1B2E] font-medium focus:border-[#7C3AED] outline-none" />
            <Select
              value={peran}
              onChange={setPeran}
              options={[
                { value: "pemilik", label: "pemilik" },
                { value: "cs", label: "cs" },
                { value: "moderator", label: "moderator" },
              ]}
            />
            <button onClick={buat} disabled={saving || !nama.trim()}
              className="w-full h-10 rounded-[10px] xy-btn text-white font-semibold text-[13px] flex items-center justify-center gap-1.5 disabled:opacity-50">
              <Plus size={15} /> {saving ? "Membuat…" : "Buat Key Baru"}
            </button>
          </div>
          {baru && (
            <div className="mt-3 p-3 rounded-xl bg-emerald-500/10 border border-emerald-500/25">
              <div className="text-[11px] font-semibold text-emerald-700 uppercase tracking-wide flex items-center gap-1"><KeyRound size={12} /> Key baru ({baru.peran})</div>
              <div className="mt-1 flex items-center gap-2">
                <code className="flex-1 text-[11px] font-mono font-semibold text-[#1E1B2E] break-all">{baru.kunci}</code>
                <button onClick={() => salin(baru.kunci)} className="shrink-0 p-1.5 rounded-lg bg-white border border-[#E9E3F5]"><Copy size={13} className="text-[#7C3AED]" /></button>
              </div>
              <div className="text-[10.5px] text-emerald-700 mt-1">Simpan sekarang — key tidak bisa dilihat lagi.</div>
            </div>
          )}
        </div>

        <div className="lg:col-span-2">
          {loading ? <Load /> : err ? <ErrBox msg={err} /> : (
            <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
              {rows.map((a) => (
                <div key={a.id} className="xy-card rounded-[18px] p-4">
                  <div className="flex items-start justify-between gap-2">
                    <div className="min-w-0">
                      <div className="text-[13px] font-semibold text-[#1E1B2E]">{a.nama}</div>
                      <div className="text-[10.5px] text-[#7C738F] mt-0.5">dibuat {jam(a.dibuat)}{a.terakhir ? ` • terakhir ${jam(a.terakhir)}` : ""}</div>
                    </div>
                    <div className="flex flex-col items-end gap-1">
                      <Chip tone={a.aktif ? "ok" : "bad"}>{a.aktif ? "aktif" : "nonaktif"}</Chip>
                      <Chip tone="info">{a.peran}</Chip>
                    </div>
                  </div>
                  <div className="mt-3 flex items-center gap-2 p-2 rounded-xl bg-[#F5F3FF] border border-[#E9E3F5]">
                    <KeyRound size={13} className="text-[#7C3AED] shrink-0" />
                    <code className="flex-1 text-[11px] font-mono text-[#1E1B2E] truncate">{a.kunci_preview || "••••••••"}</code>
                    {a.legacy_unhashed && <Chip tone="warn">migrasi saat login</Chip>}
                    <button onClick={() => putar(a.id, a.nama)} className="p-1.5 rounded-lg bg-white border border-[#E9E3F5] hover:border-[#C4B5FD]" title="Putar kunci"><RefreshCw size={12} className="text-[#7C3AED]" /></button>
                    <button onClick={() => hapus(a.id, a.kunci_preview || "••••") } className="p-1.5 rounded-lg bg-white border border-[#E9E3F5] hover:border-rose-300" title="Hapus"><Trash2 size={12} className="text-rose-500" /></button>
                  </div>
                </div>
              ))}
              {rows.length === 0 && <div className="col-span-2 text-center text-[#7C738F] py-10 font-medium">Belum ada admin key.</div>}
            </div>
          )}
        </div>
      </div>
      {err && <ErrBox msg={err} />}
    </div>
  );
}
