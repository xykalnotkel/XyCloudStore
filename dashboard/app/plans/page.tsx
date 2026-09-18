"use client";
import { useEffect, useState } from "react";
import { adminFetch } from "@/lib/api";
import { Monitor, Plus, Star, Trash2 } from "lucide-react";
import { Chip, ErrBox, Header, Load, rupiah, Tabel } from "@/components/ui/kit";
import { konfirm } from "@/components/ui/dialog";

const kosong = {
  nama: "", gpu: "", cpu: "", ram_gb: 16, storage_gb: 256,
  harga_per_jam: 5000, harga_per_hari: 50000, region: "Jakarta", tag: "",
  total_unit: 1, unit_tersedia: 1, gambar: "",
};

export default function PlansPage() {
  const [rows, setRows] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState("");
  const [form, setForm] = useState({ ...kosong });
  const [saving, setSaving] = useState(false);

  const handlePilihGambar = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    if (file.size > 5 * 1024 * 1024) {
      setErr("Ukuran gambar maksimal 5 MB.");
      return;
    }
    const reader = new FileReader();
    reader.onload = () => {
      setForm((prev) => ({ ...prev, gambar: String(reader.result || "") }));
    };
    reader.readAsDataURL(file);
  };

  async function muat() {
    setLoading(true); setErr("");
    try { setRows(await adminFetch("/api/admin/plans")); }
    catch (e: any) { setErr(e.message); }
    finally { setLoading(false); }
  }
  useEffect(() => { muat(); }, []);

  async function simpan() {
    if (!form.nama.trim() || !form.gpu.trim()) { setErr("Nama & GPU wajib diisi."); return; }
    setSaving(true); setErr("");
    try {
      await adminFetch("/api/admin/plans", { method: "POST", body: form });
      setForm({ ...kosong });
      await muat();
    } catch (e: any) { setErr(e.message); }
    finally { setSaving(false); }
  }

  async function hapus(id: string) {
    if (!await konfirm({ pesan: "Hapus paket " + id + "?", bahaya: true })) return;
    try {
      await adminFetch("/api/admin/plans/" + id, { method: "DELETE" });
      await muat();
    } catch (e: any) { setErr(e.message); }
  }

  return (
    <div className="space-y-4 font-[var(--font-inter)]">
      <Header icon={Monitor} title="Paket PC" sub="Katalog paket sewa PC (pc_plans) — CRUD via /api/admin/plans"
        right={<span className="text-xs px-3 py-1.5 rounded-full bg-[#F3F0FF] border border-[#E9E3F5] font-medium">{rows.length} paket</span>} />

      <div className="grid grid-cols-1 lg:grid-cols-4 gap-4">
        <div className="xy-card rounded-[20px] p-5 h-fit">
          <h3 className="font-semibold text-[#1E1B2E] tracking-tight flex items-center gap-2"><Plus size={15} className="text-[#7C3AED]" /> Tambah / Ubah Paket</h3>
          <div className="mt-3 space-y-2.5">
            <input value={form.nama} onChange={(e) => setForm({ ...form, nama: e.target.value })} placeholder="Nama, ex: RTX 4090 Ultra" className="w-full px-3.5 py-2 rounded-xl bg-white border border-[#E9E3F5] text-[13px] focus:border-[#7C3AED] outline-none" />
            <div className="grid grid-cols-2 gap-2">
              <input value={form.gpu} onChange={(e) => setForm({ ...form, gpu: e.target.value })} placeholder="GPU" className="px-3.5 py-2 rounded-xl bg-white border border-[#E9E3F5] text-[13px] focus:border-[#7C3AED] outline-none" />
              <input value={form.cpu} onChange={(e) => setForm({ ...form, cpu: e.target.value })} placeholder="CPU" className="px-3.5 py-2 rounded-xl bg-white border border-[#E9E3F5] text-[13px] focus:border-[#7C3AED] outline-none" />
            </div>
            <div className="grid grid-cols-4 gap-2">
              {(["ram_gb", "storage_gb", "total_unit", "unit_tersedia"] as const).map((k) => (
                <input key={k} type="number" value={String((form as any)[k])} onChange={(e) => setForm({ ...form, [k]: Number(e.target.value) || 0 })} placeholder={k} className="px-2 py-2 rounded-xl bg-white border border-[#E9E3F5] text-[12px] focus:border-[#7C3AED] outline-none" />
              ))}
            </div>
            <div className="grid grid-cols-2 gap-2">
              <input type="number" value={String(form.harga_per_jam)} onChange={(e) => setForm({ ...form, harga_per_jam: Number(e.target.value) || 0 })} placeholder="Harga/jam" className="px-3.5 py-2 rounded-xl bg-white border border-[#E9E3F5] text-[13px] focus:border-[#7C3AED] outline-none" />
              <input type="number" value={String(form.harga_per_hari)} onChange={(e) => setForm({ ...form, harga_per_hari: Number(e.target.value) || 0 })} placeholder="Harga/hari" className="px-3.5 py-2 rounded-xl bg-white border border-[#E9E3F5] text-[13px] focus:border-[#7C3AED] outline-none" />
            </div>
            <input value={form.region} onChange={(e) => setForm({ ...form, region: e.target.value })} placeholder="Region" className="w-full px-3.5 py-2 rounded-xl bg-white border border-[#E9E3F5] text-[13px] focus:border-[#7C3AED] outline-none" />
            
            {/* Upload Gambar Paket */}
            <div>
              <label className="block text-[11px] font-semibold text-[#7C738F] uppercase tracking-wide mb-1">Foto Paket PC</label>
              {form.gambar ? (
                <div className="relative rounded-xl overflow-hidden border border-[#E9E3F5] h-24 bg-[#F8F7FC] mb-1">
                  <img src={form.gambar} alt="Preview" className="w-full h-full object-cover" />
                  <button type="button" onClick={() => setForm((prev) => ({ ...prev, gambar: "" }))} className="absolute top-1 right-1 p-1 rounded-full bg-black/60 text-white text-xs">✕</button>
                </div>
              ) : (
                <label className="flex items-center justify-center gap-1.5 py-2 rounded-xl border border-dashed border-[#E9E3F5] hover:border-[#7C3AED] text-xs font-semibold text-[#7C3AED] cursor-pointer bg-white">
                  <span>Unggah Gambar</span>
                  <input type="file" accept="image/*" className="hidden" onChange={handlePilihGambar} />
                </label>
              )}
            </div>

            <button onClick={simpan} disabled={saving} className="w-full py-2.5 rounded-full xy-btn text-white font-semibold text-[13px] disabled:opacity-50">
              {saving ? "Menyimpan…" : "Simpan Paket"}
            </button>
            {err && <div className="text-[12px] text-red-600 font-semibold">{err}</div>}
          </div>
        </div>

        <div className="lg:col-span-3">
          {loading ? <Load /> : err && rows.length === 0 ? <ErrBox msg={err} /> : (
            <Tabel kosong="Belum ada paket PC."
              kolom={[
                { k: "nama", label: "Paket", render: (r) => <div className="flex items-center gap-2.5 min-w-0">
                  {r.gambar ? (
                    <img src={r.gambar} alt={r.nama} className="w-10 h-10 rounded-lg object-cover border border-[#E9E3F5] shrink-0" />
                  ) : (
                    <div className="w-10 h-10 rounded-lg bg-[#F3F0FF] text-[#7C3AED] grid place-items-center font-bold text-xs shrink-0">
                      {(r.nama || "?")[0]}
                    </div>
                  )}
                  <div className="min-w-0"><div className="font-semibold text-[#1E1B2E] truncate">{r.nama}</div><div className="text-[11px] text-[#7C738F]">{r.tag || "—"} • {r.region}</div></div>
                </div> },
                { k: "spec", label: "Spesifikasi", render: (r) => <div className="text-[11.5px] text-[#1E1B2E]/85"><b>{r.gpu}</b> • {r.cpu} • {r.ram_gb}GB • {r.storage_gb}GB</div> },
                { k: "harga", label: "Harga", render: (r) => <div><div className="font-semibold text-[#1E1B2E]">{rupiah(r.harga_per_jam)}<span className="text-[10px] text-[#7C738F] font-medium">/jam</span></div><div className="text-[11px] text-[#7C738F]">{rupiah(r.harga_per_hari)}/hari</div></div> },
                { k: "stok", label: "Unit", render: (r) => <div className="flex items-center gap-1.5">{r.unit_tersedia}/{r.total_unit} {Number(r.unit_tersedia) > 0 ? <Chip tone="ok">ready</Chip> : <Chip tone="bad">habis</Chip>}</div> },
                { k: "rating", label: "Rating", render: (r) => <span className="inline-flex items-center gap-1 text-[12px] font-semibold text-[#1E1B2E]"><Star size={12} className="text-amber-500" /> {Number(r.rating || 0).toFixed(1)} <span className="text-[#7C738F] font-medium">({r.jumlah_ulasan || 0})</span></span> },
                { k: "id", label: "", render: (r) => <button onClick={() => hapus(r.id)} className="p-2 rounded-lg bg-white border border-[#E9E3F5] hover:border-rose-300"><Trash2 size={13} className="text-rose-500" /></button> },
              ]}
              rows={rows} />
          )}
        </div>
      </div>
    </div>
  );
}
