"use client";
import { useEffect, useMemo, useState } from "react";
import { adminFetch } from "@/lib/api";
import { Check, Copy, CreditCard, ExternalLink, RefreshCw, ShieldCheck, X, Zap } from "lucide-react";
import {
  Btn, Chip, ErrBox, Header, jam, Load, MsgOk, rupiah, runBatch, SelectBar,
  toneStatus, useAdminList, useSelection,
} from "@/components/ui/kit";
import { konfirm } from "@/components/ui/dialog";

export default function TopupPage() {
  const { rows, loading, err, setErr, reload } = useAdminList("/api/admin/topup");
  const [ok, setOk] = useState("");
  const [busy, setBusy] = useState(false);
  const [catatan, setCatatan] = useState("");
  const [darurat, setDarurat] = useState(false);
  const [frasaDarurat, setFrasaDarurat] = useState("");
  const [filter, setFilter] = useState("pending");
  const [info, setInfo] = useState<any>(null);

  async function muatInfo() {
    try { setInfo(await adminFetch("/api/admin/bayar/info")); }
    catch { setInfo(null); }
  }
  useEffect(() => { muatInfo(); }, []);

  const list = useMemo(() => {
    if (filter === "semua") return rows;
    if (filter === "pending") return rows.filter((r) => ["menunggu", "diperiksa"].includes(String(r.status)));
    return rows.filter((r) => String(r.status) === filter);
  }, [rows, filter]);

  const ids = list.map((r) => r.id).filter(Boolean);
  const sel = useSelection(ids);

  const n = (s: string) => rows.filter((r) => r.status === s).length;

  async function aksi(id: string, status: string, pakaiDarurat = false) {
    return adminFetch("/api/admin/topup/" + id, {
      method: "PATCH",
      body: {
        status,
        catatan: catatan || undefined,
        ...(pakaiDarurat ? {
          override_gateway: true,
          konfirmasi: frasaDarurat,
        } : {}),
      },
    });
  }

  async function satu(id: string, status: string) {
    const frasaWajib = status === "disetujui" ? "KREDIT MANUAL" : "TOLAK GATEWAY";
    if (darurat && (catatan.trim().length < 20 || frasaDarurat !== frasaWajib)) {
      setErr(`Override ${status} memerlukan alasan minimal 20 karakter dan frasa persis “${frasaWajib}”.`);
      return;
    }
    const pesan = darurat
      ? `OVERRIDE DARURAT: ${status === "disetujui" ? "kredit tanpa konfirmasi lunas provider" : "tolak walau pembatalan provider belum terverifikasi"}? Tindakan masuk audit keamanan.`
      : status === "ditolak" ? "Tolak top up ini?" : "Setujui & tambahkan saldo?";
    if (!await konfirm({ pesan, bahaya: darurat || status === "ditolak" })) return;
    setBusy(true); setErr(""); setOk("");
    try {
      const r: any = await aksi(id, status, darurat);
      setCatatan(""); setDarurat(false); setFrasaDarurat("");
      setOk(r?.pesan || (r?.status === "disetujui" || status === "disetujui" ? "Saldo ditambahkan" : "Ditolak"));
      await reload();
    } catch (e: any) { setErr(e.message); }
    finally { setBusy(false); }
  }

  async function verifikasi(id: string) {
    setBusy(true); setErr(""); setOk("");
    try {
      const r: any = await adminFetch("/api/admin/topup/" + id + "/verifikasi", { method: "POST" });
      setOk(r?.pesan || "Selesai diperiksa ke penyedia.");
      await reload();
    } catch (e: any) { setErr(e.message); }
    finally { setBusy(false); }
  }

  async function rekonsiliasi() {
    if (!await konfirm({ pesan: "Cocokkan hingga 30 top up pending ke detail provider sekarang?" })) return;
    setBusy(true); setErr(""); setOk("");
    try {
      const r: any = await adminFetch("/api/admin/bayar/rekonsiliasi", { method: "POST", body: {} });
      setOk(`Rekonsiliasi selesai: ${r.disetujui || 0} lunas, ${r.ditolak || 0} gagal, ${r.menunggu || 0} masih menunggu.`);
      await Promise.all([reload(), muatInfo()]);
    } catch (e: any) { setErr(e.message); }
    finally { setBusy(false); }
  }

  async function salinWebhook() {
    if (!info?.webhook_url) return;
    try { await navigator.clipboard.writeText(info.webhook_url); setOk("URL webhook disalin."); }
    catch { setErr("Browser tidak mengizinkan akses clipboard."); }
  }

  async function massal(status: string) {
    if (!sel.count) return;
    if (!await konfirm({ pesan: `${status === "disetujui" ? "Setujui" : "Tolak"} ${sel.count} permintaan?`, bahaya: status === "ditolak" })) return;
    setBusy(true); setErr(""); setOk("");
    try {
      const msg = await runBatch(sel.list, (id) => aksi(id, status), status === "disetujui" ? "disetujui" : "ditolak");
      setOk(msg); sel.clear(); await reload();
    } catch (e: any) { setErr(e.message); }
    finally { setBusy(false); }
  }

  return (
    <div className="space-y-4 font-[var(--font-inter)]">
      <Header icon={CreditCard} title="Top Up" sub="Pembayaran otomatis, verifikasi provider, dan transfer manual"
        right={
          <div className="flex gap-2 flex-wrap">
            <span className="text-xs px-3 py-1.5 rounded-full bg-amber-500/15 border border-amber-500/30 text-amber-700 font-semibold">{n("menunggu") + n("diperiksa")} pending</span>
            <span className="text-xs px-3 py-1.5 rounded-full bg-[#F3F0FF] border border-[#E9E3F5] font-medium">{rows.length} total</span>
          </div>
        } />

      {info && (
        <div className="xy-card rounded-[18px] p-4 space-y-3">
          <div className="flex flex-wrap items-center gap-2">
            <div className={`w-9 h-9 rounded-xl grid place-items-center ${info.otomatis ? "bg-emerald-500/10 text-emerald-600" : "bg-amber-500/10 text-amber-600"}`}><ShieldCheck size={17} /></div>
            <div className="min-w-0 flex-1">
              <div className="text-[13px] font-semibold text-[#1E1B2E]">{info.otomatis ? `Otomatis via ${String(info.penyedia).toUpperCase()}` : "Pembayaran manual"}</div>
              <div className="text-[11px] text-[#7C738F]">Webhook selalu dicocokkan ke order lokal dan diverifikasi ulang lewat API detail sebelum saldo dikreditkan.</div>
            </div>
            <button onClick={muatInfo} disabled={busy} className="h-8 px-3 rounded-xl border border-[#E9E3F5] text-[11px] font-semibold text-[#7C3AED] flex items-center gap-1"><RefreshCw size={12} /> Segarkan</button>
            {info.boleh_rekonsiliasi && <button onClick={rekonsiliasi} disabled={busy || !info.otomatis} className="h-8 px-3 rounded-xl xy-btn text-white text-[11px] font-semibold flex items-center gap-1 disabled:opacity-50"><Zap size={12} /> Rekonsiliasi</button>}
          </div>
          <div className="grid grid-cols-2 md:grid-cols-5 gap-2">
            {[
              ["Pending gateway", info.statistik?.pending_gateway ?? 0],
              ["Webhook 24 jam", info.statistik?.webhook_24_jam ?? 0],
              ["Ditolak 24 jam", info.statistik?.webhook_ditolak_24_jam ?? 0],
              ["Kredit 24 jam", info.statistik?.kredit_24_jam ?? 0],
              ["Nominal kredit", rupiah(info.statistik?.nominal_kredit_24_jam ?? 0)],
            ].map(([label, value]) => <div key={String(label)} className="rounded-xl bg-[#F5F3FF] border border-[#E9E3F5] px-3 py-2"><div className="text-[10px] text-[#7C738F] uppercase font-semibold">{label}</div><div className="text-[13px] font-semibold text-[#1E1B2E] mt-0.5">{value}</div></div>)}
          </div>
          {info.webhook_url && (
            <div className="flex items-center gap-2 rounded-xl bg-[#F5F3FF] border border-[#E9E3F5] px-3 py-2">
              <code className="text-[10.5px] text-[#6B5A8A] break-all flex-1">{info.webhook_url}</code>
              <button onClick={salinWebhook} className="p-1.5 rounded-lg bg-white border border-[#E9E3F5]" title="Salin URL webhook"><Copy size={12} className="text-[#7C3AED]" /></button>
            </div>
          )}
          {info.webhook_terakhir && (
            <div className="rounded-xl bg-white border border-[#E9E3F5] px-3 py-2 text-[10.5px] text-[#6B5A8A] flex flex-wrap gap-x-2 gap-y-1">
              <b className="text-[#1E1B2E]">Webhook terakhir</b>
              <span>{String(info.webhook_terakhir.provider || "—").toUpperCase()}</span>
              <span>• {info.webhook_terakhir.event_status || "tanpa status"}</span>
              <span>• {info.webhook_terakhir.verified ? "detail terverifikasi" : "belum/ditolak"}</span>
              <span>• {info.webhook_terakhir.outcome || "—"}</span>
              <span>• {jam(info.webhook_terakhir.received_at)}</span>
            </div>
          )}
          {info.konfigurasi?.pakasir && (
            <div className="flex flex-wrap gap-2 text-[10.5px]">
              <Chip tone={info.konfigurasi.pakasir.project ? "ok" : "bad"}>Project secret {info.konfigurasi.pakasir.project ? "tersedia" : "belum ada"}</Chip>
              <Chip tone={info.konfigurasi.pakasir.api_key ? "ok" : "bad"}>API key secret {info.konfigurasi.pakasir.api_key ? "tersedia" : "belum ada"}</Chip>
              <Chip tone={info.konfigurasi.pakasir.siap ? "ok" : "warn"}>Adaptor {info.konfigurasi.pakasir.siap ? "siap" : "belum siap"}</Chip>
              <span className="self-center text-[#7C738F]">Nilai rahasia tidak pernah dikirim ke dashboard.</span>
            </div>
          )}
          {info.penyedia === "pakasir" && <div className="text-[11px] text-amber-700 bg-amber-500/10 border border-amber-500/20 rounded-xl px-3 py-2">Pakasir tidak mendokumentasikan signature webhook. Karena itu payload webhook tidak pernah menjadi dasar kredit; server mengambil Transaction Detail dengan API key dan mencocokkan project, order ID, serta nominal.</div>}
        </div>
      )}

      <div className="flex flex-wrap gap-1.5">
        {["pending", "menunggu", "diperiksa", "disetujui", "ditolak", "semua"].map((f) => (
          <button key={f} type="button" onClick={() => setFilter(f)}
            className={`text-[11px] px-3 py-1.5 rounded-full border font-semibold ${filter === f ? "bg-[#7C3AED] text-white border-[#7C3AED]" : "bg-white border-[#E9E3F5] text-[#6B5A8A]"}`}>
            {f}
          </button>
        ))}
      </div>

      <div className="space-y-2 max-w-2xl">
        <input value={catatan} onChange={(e) => setCatatan(e.target.value)} placeholder="Catatan opsional (wajib minimal 20 karakter untuk override)"
          className="xy-input w-full text-[12.5px]" />
        {info?.boleh_rekonsiliasi && (
          <div className={`rounded-xl border px-3 py-2.5 ${darurat ? "bg-red-500/10 border-red-500/30" : "bg-white border-[#E9E3F5]"}`}>
            <label className="flex items-start gap-2 text-[11.5px] font-semibold text-[#4B425E] cursor-pointer">
              <input type="checkbox" checked={darurat} onChange={(e) => { setDarurat(e.target.checked); setFrasaDarurat(""); }} className="mt-0.5" />
              <span>Override darurat untuk satu aksi berikutnya. Hanya gunakan setelah memeriksa dashboard Pakasir; kredit/penolakan tanpa konfirmasi provider dapat menimbulkan kerugian.</span>
            </label>
            {darurat && (
              <div className="mt-2 space-y-1">
                <input value={frasaDarurat} onChange={(e) => setFrasaDarurat(e.target.value)}
                  placeholder="Ketik KREDIT MANUAL atau TOLAK GATEWAY sesuai aksi"
                  className="xy-input w-full text-[12px] !border-red-300" />
                <div className="text-[10.5px] text-red-700">Tidak berlaku untuk aksi massal. Alasan dan tindakan direkam di audit keamanan.</div>
              </div>
            )}
          </div>
        )}
      </div>

      <SelectBar count={sel.count} onClear={sel.clear}>
        <Btn tone="ok" disabled={busy} onClick={() => massal("disetujui")}><Check size={13} /> Setujui massal</Btn>
        <Btn tone="bahaya" disabled={busy} onClick={() => massal("ditolak")}><X size={13} /> Tolak massal</Btn>
      </SelectBar>

      {ok && <MsgOk msg={ok} />}
      {err && <ErrBox msg={err} />}
      {loading ? <Load /> : (
        <div className="xy-card rounded-[20px] overflow-x-auto">
          <table className="w-full text-left text-[12.5px] min-w-[1050px]">
            <thead>
              <tr className="border-b border-[#E9E3F5] bg-[#F5F3FF]">
                <th className="px-3 py-2.5 w-10"><input type="checkbox" checked={sel.allSelected} onChange={sel.toggleAll} /></th>
                {["ID / User", "Nominal", "Total", "Provider", "Bukti", "Status", "Waktu", "Aksi"].map((h) => (
                  <th key={h} className="px-4 py-2.5 text-[10.5px] uppercase tracking-wider text-[#7C738F] font-semibold">{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {list.length === 0 && (
                <tr><td colSpan={9} className="px-4 py-10 text-center text-[#7C738F]">Tidak ada data pada filter ini.</td></tr>
              )}
              {list.map((r) => (
                <tr key={r.id} className="border-b border-[#F0EDFB] last:border-0 hover:bg-[#FBFAFF]">
                  <td className="px-3 py-3"><input type="checkbox" checked={sel.selected.has(r.id)} onChange={() => sel.toggle(r.id)} /></td>
                  <td className="px-4 py-3">
                    <div className="font-mono text-[11px] text-[#7C738F]">{r.id}</div>
                    <div className="font-semibold">{r.nama || "—"}</div>
                    <div className="text-[10.5px] text-[#7C738F]">{r.email || r.phone || ""}</div>
                  </td>
                  <td className="px-4 py-3 font-semibold">{rupiah(r.nominal)}</td>
                  <td className="px-4 py-3">
                    <div className="font-semibold">{rupiah(r.total || Number(r.nominal || 0) + Number(r.kode_unik || 0))}</div>
                    <div className="text-[10.5px] text-[#7C738F]">{r.metode || "—"}{Number(r.provider_fee || 0) > 0 ? ` • fee ${rupiah(r.provider_fee)}` : ""}</div>
                  </td>
                  <td className="px-4 py-3">
                    <Chip tone={r.provider && !["manual", "legacy"].includes(String(r.provider)) ? "ok" : "netral"}>{r.provider || (Number(r.kode_unik) === 0 ? "legacy" : "manual")}</Chip>
                    <div className="text-[10px] text-[#7C738F] mt-1">{r.provider_status || "belum dicek"}</div>
                    {Number(r.webhook_count || 0) > 0 && <div className="text-[10px] text-[#7C738F]">{r.webhook_count} webhook</div>}
                  </td>
                  <td className="px-4 py-3">
                    {r.bukti ? (
                      <a href={r.bukti} target="_blank" rel="noreferrer" className="inline-flex items-center gap-1 text-[#7C3AED] font-semibold text-[12px]">
                        <ExternalLink size={12} /> Bukti
                      </a>
                    ) : "—"}
                  </td>
                  <td className="px-4 py-3"><Chip tone={toneStatus(r.status)}>{r.status}</Chip></td>
                  <td className="px-4 py-3 text-[11px] font-mono text-[#7C738F]">{jam(r.dibuat || r.created_at)}</td>
                  <td className="px-4 py-3">
                    {["menunggu", "diperiksa"].includes(String(r.status)) ? (
                      <div className="flex gap-1">
                        <Btn tone="ghost" className="!h-8 !px-2.5" disabled={busy} title="Cek otomatis ke penyedia pembayaran (QRIS/DANA sudah benar-benar dibayar?)" onClick={() => verifikasi(r.id)}><Zap size={12} /></Btn>
                        <Btn tone="ok" className="!h-8 !px-2.5" disabled={busy} onClick={() => satu(r.id, "disetujui")}><Check size={12} /></Btn>
                        <Btn tone="bahaya" className="!h-8 !px-2.5" disabled={busy} onClick={() => satu(r.id, "ditolak")}><X size={12} /></Btn>
                      </div>
                    ) : <span className="text-[11px] text-[#9A8CBF]">—</span>}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
