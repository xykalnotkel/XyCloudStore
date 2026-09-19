"use client";
import { useState } from "react";
import { Layers, Plus, KeyRound } from "lucide-react";
import { Chip, ErrBox, Header, Load, SearchBox, Tabel, rupiah, useAdminList, Btn, Panel, Field, Select, TextArea } from "@/components/ui/kit";
import { adminFetch } from "@/lib/api";
import { toast } from "@/components/ui/dialog";

export default function StokPage() {
  const { rows, loading, err, reload } = useAdminList("/api/admin/stok");
  const [cari, setCari] = useState("");
  const [modalBuka, setModalBuka] = useState(false);
  const [produkDipilih, setProdukDipilih] = useState("");
  const [bulkTeks, setBulkTeks] = useState("");
  const [busy, setBusy] = useState(false);

  const q = cari.trim().toLowerCase();
  const daftar = rows.filter((r: any) => !q || `${r.nama} ${r.kategori}`.toLowerCase().includes(q));
  const totalTersedia = rows.reduce((n: number, r: any) => n + Number(r.tersedia || 0), 0);
  const kritis = rows.filter((r: any) => Number(r.tersedia || 0) === 0).length;

  const bukaModalTambah = (prodId?: string) => {
    setProdukDipilih(prodId || (rows[0]?.produk_id || ""));
    setBulkTeks("");
    setModalBuka(true);
  };

  const simpanStok = async () => {
    if (!produkDipilih) {
      toast("Pilih produk terlebih dahulu", "err");
      return;
    }
    if (!bulkTeks.trim()) {
      toast("Masukkan kredensial akun minimal 1 baris", "err");
      return;
    }
    setBusy(true);
    try {
      const res = await adminFetch("/api/admin/stok", {
        method: "POST",
        body: {
          produk_id: produkDipilih,
          teks_bulk: bulkTeks,
        },
      });
      toast(`Berhasil menambahkan ${res.ditambahkan || 0} akun ke stok!`, "ok");
      setModalBuka(false);
      reload();
    } catch (e: any) {
      toast(e.message || "Gagal menambahkan stok", "err");
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="space-y-4 font-[var(--font-inter)]">
      <Header
        icon={Layers}
        title="Stok & Kredensial Akun"
        sub="Ketersediaan stok akun digital & kredensial instan per produk"
        right={
          <div className="flex items-center gap-2">
            <Chip tone={kritis > 0 ? "bad" : "ok"}>{kritis} produk habis</Chip>
            <Chip tone="info">{totalTersedia} akun siap jual</Chip>
            <SearchBox value={cari} onChange={setCari} placeholder="Cari produk…" />
            <Btn tone="utama" onClick={() => bukaModalTambah()}>
              <Plus size={15} className="mr-1 inline" /> Isi Stok Akun
            </Btn>
          </div>
        }
      />

      {loading ? (
        <Load />
      ) : err ? (
        <ErrBox msg={err} onRetry={reload} />
      ) : (
        <Tabel
          kolom={[
            {
              k: "nama",
              label: "Produk",
              render: (r) => (
                <div>
                  <span className="font-semibold text-[#1E1B2E]">{r.nama}</span>
                  <div className="text-[11px] text-[#7C738F] font-mono">ID: {r.produk_id}</div>
                </div>
              ),
            },
            { k: "kategori", label: "Kategori", render: (r) => <Chip tone="netral">{r.kategori}</Chip> },
            { k: "harga", label: "Harga", render: (r) => <span className="font-semibold">{rupiah(r.harga)}</span> },
            {
              k: "tersedia",
              label: "Ketersediaan",
              render: (r) => (
                <Chip tone={Number(r.tersedia) === 0 ? "bad" : Number(r.tersedia) <= 3 ? "warn" : "ok"}>
                  {r.tersedia} dari {r.total} unit
                </Chip>
              ),
            },
            {
              k: "aksi",
              label: "Aksi",
              render: (r) => (
                <Btn tone="sekunder" onClick={() => bukaModalTambah(r.produk_id)}>
                  <KeyRound size={13} className="mr-1 inline" /> + Stok
                </Btn>
              ),
            },
          ]}
          rows={daftar}
          kosong="Belum ada produk akun."
        />
      )}

      {/* Modal Tambah Stok Kredensial */}
      <Panel open={modalBuka} title="Isi Stok Kredensial Akun" onClose={() => setModalBuka(false)}>
        <div className="space-y-4">
          <Field label="Pilih Produk">
            <Select
              value={produkDipilih}
              onChange={setProdukDipilih}
              options={rows.map((r: any) => ({
                value: r.produk_id,
                label: `${r.nama} (Tersedia: ${r.tersedia})`,
              }))}
            />
          </Field>

          <Field label="Kredensial Akun (Format: email:password)">
            <TextArea
              rows={6}
              value={bulkTeks}
              onChange={(e) => setBulkTeks(e.target.value)}
              placeholder={`user1@gmail.com:Pass1234!\nuser2@gmail.com:Pass5678!\nuser3@gmail.com:SecretPass`}
            />
            <div className="text-[11px] text-[#7C738F] mt-1">
              Masukkan 1 akun per baris. Pisahkan email dan kata sandi menggunakan tanda titik dua (:) atau koma (,).
            </div>
          </Field>

          <div className="flex justify-end gap-2 pt-2">
            <Btn tone="batal" onClick={() => setModalBuka(false)}>
              Batal
            </Btn>
            <Btn tone="utama" disabled={busy} onClick={simpanStok}>
              {busy ? "Menyimpan…" : "Simpan Kredensial"}
            </Btn>
          </div>
        </div>
      </Panel>
    </div>
  );
}
