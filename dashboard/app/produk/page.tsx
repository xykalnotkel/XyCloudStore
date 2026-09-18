"use client";
import { useEffect, useState, useRef } from "react";
import { adminFetch } from "@/lib/api";
import { Gamepad2, Plus, Package, Star, UploadCloud, X, Trash2, Pencil } from "lucide-react";
import { Select, Check, ErrBox, Field } from "@/components/ui/kit";
import { toast, konfirm } from "@/components/ui/dialog";

export default function ProdukPage() {
  const [produk, setProduk] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState("");
  const [busy, setBusy] = useState(false);
  const [editId, setEditId] = useState<string | null>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);

  const [form, setForm] = useState({
    nama: "",
    kategori: "game",
    harga: 0,
    stok: 0,
    deskripsi: "",
    gambar: "",
  });

  const muat = () => {
    setLoading(true);
    adminFetch("/api/admin/produk")
      .then((d) => setProduk(d.produk || d.data || []))
      .catch((e) => setErr(e.message))
      .finally(() => setLoading(false));
  };

  useEffect(() => {
    muat();
  }, []);

  const handlePilihGambar = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    if (file.size > 5 * 1024 * 1024) {
      toast("Ukuran gambar maksimal 5 MB", "err");
      return;
    }
    const reader = new FileReader();
    reader.onload = () => {
      setForm((prev) => ({ ...prev, gambar: String(reader.result || "") }));
    };
    reader.readAsDataURL(file);
  };

  const mulaiEdit = (p: any) => {
    setEditId(p.id);
    setForm({
      nama: p.nama || "",
      kategori: p.kategori || "game",
      harga: p.harga || 0,
      stok: p.stok ?? p.total_stok ?? 0,
      deskripsi: p.deskripsi || "",
      gambar: p.gambar || "",
    });
  };

  const batalEdit = () => {
    setEditId(null);
    setForm({ nama: "", kategori: "game", harga: 0, stok: 0, deskripsi: "", gambar: "" });
  };

  const simpan = async () => {
    if (!form.nama.trim()) {
      toast("Nama produk wajib diisi", "err");
      return;
    }
    setBusy(true);
    try {
      await adminFetch("/api/admin/produk", {
        method: "POST",
        body: {
          ...(editId ? { id: editId } : {}),
          ...form,
        },
      });
      toast(editId ? "Produk diperbarui" : "Produk dibuat", "ok");
      batalEdit();
      muat();
    } catch (e: any) {
      toast(e.message || "Gagal menyimpan", "err");
    } finally {
      setBusy(false);
    }
  };

  const hapus = async (id: string, nama: string) => {
    const ok = await konfirm({
      judul: "Hapus Produk?",
      pesan: `Hapus produk "${nama}" secara permanen?`,
      okLabel: "Hapus",
      bahaya: true,
    });
    if (!ok) return;
    try {
      await adminFetch(`/api/admin/produk/${id}`, { method: "DELETE" });
      toast("Produk berhasil dihapus", "ok");
      muat();
    } catch (e: any) {
      toast(e.message || "Gagal menghapus", "err");
    }
  };

  return (
    <div className="space-y-5 font-[var(--font-inter)]">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl xy-btn grid place-items-center">
            <Gamepad2 size={18} className="text-white" />
          </div>
          <div>
            <h1 className="text-xl font-semibold text-[#1E1B2E] tracking-tight">Produk Akun</h1>
            <p className="text-sm text-[#7C738F] font-medium">Kelola akun game/streaming dengan gambar & upload otomatis</p>
          </div>
        </div>
        <span className="text-xs px-3 py-1 rounded-full bg-[#F3F0FF] border border-[#E9E3F5] font-medium">
          {produk.length} produk
        </span>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
        {/* Form Tambah / Edit */}
        <div className="xy-card rounded-[16px] p-5 h-fit">
          <div className="flex items-center justify-between mb-3">
            <h3 className="font-semibold text-[#1E1B2E] tracking-tight flex items-center gap-2">
              {editId ? <Pencil size={16} /> : <Plus size={16} />}
              {editId ? "Ubah Produk" : "Tambah Produk"}
            </h3>
            {editId && (
              <button onClick={batalEdit} className="text-xs text-[#7C738F] hover:text-[#1E1B2E]">
                Batal
              </button>
            )}
          </div>

          <div className="space-y-3">
            {/* Upload Area Gambar Banner/Cover Produk */}
            <div>
              <label className="block text-[11px] font-semibold text-[#7C738F] uppercase tracking-wide mb-1.5">
                Foto / Banner Produk
              </label>
              {form.gambar ? (
                <div className="relative rounded-xl overflow-hidden border border-[#E9E3F5] h-36 bg-[#F8F7FC] group">
                  <img src={form.gambar} alt="Preview" className="w-full h-full object-cover" />
                  <button
                    onClick={() => setForm((prev) => ({ ...prev, gambar: "" }))}
                    className="absolute top-2 right-2 p-1.5 rounded-full bg-black/60 text-white hover:bg-black/80 transition"
                    title="Hapus gambar"
                  >
                    <X size={14} />
                  </button>
                </div>
              ) : (
                <div
                  onClick={() => fileInputRef.current?.click()}
                  className="rounded-xl border-2 border-dashed border-[#E9E3F5] hover:border-[#7C3AED] p-5 text-center cursor-pointer bg-[#FDFCFE] hover:bg-[#F3F0FF]/30 transition group"
                >
                  <UploadCloud size={24} className="mx-auto text-[#7C3AED] mb-1.5 group-hover:scale-110 transition" />
                  <div className="text-xs font-semibold text-[#1E1B2E]">Klik untuk Upload Gambar</div>
                  <div className="text-[10.5px] text-[#7C738F] mt-0.5">PNG, JPG, WebP maks 5 MB</div>
                </div>
              )}
              <input
                ref={fileInputRef}
                type="file"
                accept="image/*"
                className="hidden"
                onChange={handlePilihGambar}
              />
            </div>

            <input
              value={form.nama}
              onChange={(e) => setForm({ ...form, nama: e.target.value })}
              placeholder="Nama produk (misal: Steam Akun GTA V)"
              className="w-full px-4 py-2.5 rounded-xl bg-[#FFFFFF] border border-[#E9E3F5] text-sm text-[#1E1B2E] font-medium"
            />
            <div className="grid grid-cols-2 gap-2">
              <Select
                value={form.kategori}
                onChange={(v) => setForm({ ...form, kategori: v })}
                options={[
                  { value: "game", label: "Game" },
                  { value: "streaming", label: "Streaming" },
                  { value: "software", label: "Software" },
                  { value: "vpn", label: "VPN" },
                ]}
              />
              <input
                type="number"
                value={form.harga || ""}
                onChange={(e) => setForm({ ...form, harga: parseInt(e.target.value) || 0 })}
                placeholder="Harga (Rp)"
                className="px-4 py-2.5 rounded-xl bg-[#FFFFFF] border border-[#E9E3F5] text-sm text-[#1E1B2E] font-medium"
              />
            </div>
            <input
              type="number"
              value={form.stok || ""}
              onChange={(e) => setForm({ ...form, stok: parseInt(e.target.value) || 0 })}
              placeholder="Jumlah stok"
              className="w-full px-4 py-2.5 rounded-xl bg-[#FFFFFF] border border-[#E9E3F5] text-sm text-[#1E1B2E] font-medium"
            />
            <textarea
              value={form.deskripsi}
              onChange={(e) => setForm({ ...form, deskripsi: e.target.value })}
              placeholder="Deskripsi produk, garansi, dan kelengkapan"
              rows={3}
              className="w-full px-4 py-2.5 rounded-xl bg-[#FFFFFF] border border-[#E9E3F5] text-sm text-[#1E1B2E] font-medium"
            />
            <button
              onClick={simpan}
              disabled={busy}
              className="w-full h-10 rounded-[10px] xy-btn font-semibold text-white tracking-wide disabled:opacity-50"
            >
              {busy ? "Menyimpan…" : editId ? "Perbarui Produk" : "Simpan Produk"}
            </button>
            <div className="text-[11px] text-[#7C738F] font-medium">
              Gambar yang diunggah otomatis dioptimalkan ke format WebP cepat oleh Worker.
            </div>
          </div>
        </div>

        {/* Daftar Produk */}
        <div className="lg:col-span-2">
          {loading ? (
            <div className="xy-card rounded-xl p-6 text-center text-[#7C738F] font-medium">Memuat...</div>
          ) : err ? (
            <div className="xy-card rounded-xl p-4 text-red-600 font-medium">{err}</div>
          ) : (
            <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
              {produk.map((p: any) => (
                <div key={p.id} className="xy-card rounded-[14px] p-4 flex flex-col justify-between">
                  <div className="flex gap-3">
                    {p.gambar ? (
                      <div className="w-14 h-14 rounded-xl overflow-hidden shrink-0 border border-[#E9E3F5] bg-[#F8F7FC]">
                        <img src={p.gambar} alt={p.nama} className="w-full h-full object-cover" />
                      </div>
                    ) : (
                      <div className="w-14 h-14 rounded-xl bg-gradient-to-br from-[#7C3AED] to-[#A855F7] grid place-items-center text-white font-semibold tracking-tight shrink-0">
                        {(p.nama || "?")[0]}
                      </div>
                    )}
                    <div className="min-w-0 flex-1">
                      <div className="font-semibold text-[#1E1B2E] text-[13.5px] truncate tracking-tight">{p.nama}</div>
                      <div className="text-[11px] text-[#7C738F] font-medium mt-0.5">
                        {p.kategori} • Rp {(p.harga || 0).toLocaleString("id-ID")} • stok {p.stok ?? p.total_stok ?? 0}
                      </div>
                      <div className="mt-2 flex gap-1.5 flex-wrap">
                        <span className="text-[10px] px-2 py-0.5 rounded-full bg-[#F3F0FF] border border-[#E9E3F5] font-semibold">
                          {p.status || "aktif"}
                        </span>
                        {p.terlaris && (
                          <span className="text-[10px] px-2 py-0.5 rounded-full bg-amber-500/20 border border-amber-500/30 font-semibold text-amber-700">
                            terlaris
                          </span>
                        )}
                      </div>
                    </div>
                  </div>

                  <div className="mt-3 pt-3 border-t border-[#E9E3F5] flex items-center justify-end gap-2">
                    <button
                      onClick={() => mulaiEdit(p)}
                      className="px-2.5 py-1 rounded-lg border border-[#E9E3F5] bg-[#F8F7FC] text-[#7C3AED] text-xs font-semibold flex items-center gap-1 hover:border-[#7C3AED]"
                    >
                      <Pencil size={12} /> Edit
                    </button>
                    <button
                      onClick={() => hapus(p.id, p.nama)}
                      className="px-2.5 py-1 rounded-lg border border-rose-200 bg-rose-50 text-rose-700 text-xs font-semibold flex items-center gap-1 hover:bg-rose-100"
                    >
                      <Trash2 size={12} /> Hapus
                    </button>
                  </div>
                </div>
              ))}
              {produk.length === 0 && (
                <div className="col-span-2 xy-card rounded-xl p-8 text-center text-[#7C738F] text-sm font-medium">
                  Belum ada produk. Tambahkan produk pertama di panel kiri.
                </div>
              )}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
