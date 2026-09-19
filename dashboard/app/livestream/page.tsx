"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { adminFetch } from "@/lib/api";
import {
  Activity, AlertTriangle, BadgeCheck, Ban, BellRing, CheckCircle2, CircleDollarSign, Eye,
  HeartHandshake, Radio, RefreshCw, Settings2, ShieldCheck, Square, Users, Wallet, Wrench,
} from "lucide-react";

type Data = {
  config?: any;
  creators?: any[];
  lives?: any[];
  payouts?: any[];
  tips?: any[];
  finance?: any;
  push_outbox?: { stats?: any; rows?: any[] };
  provider_cleanup?: { stats?: any; rows?: any[] };
};

const rp = (n: any) => `Rp${Math.max(0, Number(n) || 0).toLocaleString("id-ID")}`;
const dt = (v: any) => v ? new Date(v).toLocaleString("id-ID") : "—";

function Badge({ value }: { value: string }) {
  const good = ["approved", "live", "paid", "available", "charged", "sent", "deleted", "effective", "provider ready"].includes(value);
  const warn = ["pending", "sending", "starting", "ending", "held", "requested", "processing", "off"].includes(value);
  return <span className={`inline-flex px-2 py-0.5 rounded-full border text-[10px] font-semibold uppercase tracking-wide ${
    good ? "bg-emerald-50 border-emerald-200 text-emerald-700" :
    warn ? "bg-amber-50 border-amber-200 text-amber-700" :
    "bg-rose-50 border-rose-200 text-rose-700"
  }`}>{value || "—"}</span>;
}

function Stat({ label, value, icon: Icon, tone = "text-[#7C3AED]" }: any) {
  return <div className="xy-card rounded-[14px] p-4 flex items-center gap-3">
    <div className="w-10 h-10 rounded-xl bg-[#F3F0FF] grid place-items-center"><Icon size={17} className={tone}/></div>
    <div><div className="text-[10px] uppercase tracking-wide font-semibold text-[#7C738F]">{label}</div>
      <div className="text-lg font-semibold text-[#1E1B2E] mt-0.5">{value}</div></div>
  </div>;
}

export default function LivestreamOperationsPage() {
  const [data, setData] = useState<Data>({});
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState("");
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");
  const [tab, setTab] = useState("creator");
  const [form, setForm] = useState<any>({});
  const [providerReport, setProviderReport] = useState<Record<string, any>>({});
  // Polling tidak boleh menimpa input atau meluncurkan permintaan tumpang tindih.
  const configDirty = useRef(false);
  const loadInFlight = useRef<Promise<void> | null>(null);
  const actionInFlight = useRef(false);

  const load = useCallback(async () => {
    if (loadInFlight.current) return loadInFlight.current;
    const request = (async () => {
      try {
        const d = await adminFetch("/api/admin/livestream");
        setData(d || {});
        const c = d?.config || {};
        if (!configDirty.current) {
          setForm({
            enabled: c.enabled === true,
            platform_fee_bps: c.feeBps ?? 2000,
            min_tip: c.minTip ?? 5000,
            max_tip: c.maxTip ?? 500000,
            min_payout: c.minPayout ?? 100000,
            max_minutes: c.maxMinutes ?? 240,
            max_concurrent: c.maxConcurrent ?? 2,
          });
        }
        setError("");
      } catch (e: any) {
        setError(e?.message || "Gagal memuat operasi livestream");
      } finally {
        setLoading(false);
      }
    })();
    loadInFlight.current = request;
    try {
      await request;
    } finally {
      if (loadInFlight.current === request) loadInFlight.current = null;
    }
  }, []);

  useEffect(() => { load(); const id = setInterval(load, 15000); return () => clearInterval(id); }, [load]);

  const act = async (id: string, fn: () => Promise<any>, message = "Perubahan berhasil disimpan.") => {
    if (actionInFlight.current) return;
    actionInFlight.current = true;
    setBusy(id); setError(""); setSuccess("");
    try {
      await fn();
      setSuccess(message);
      // Bila polling lama dimulai sebelum mutasi, tunggu lalu paksa snapshot
      // kedua. Respons stale tidak boleh membuat owner mengulang tindakan uang.
      const staleLoad = loadInFlight.current;
      if (staleLoad) {
        await staleLoad;
        if (loadInFlight.current === staleLoad) loadInFlight.current = null;
      }
      await load();
    } catch (e: any) {
      setError(e?.message || "Tindakan gagal");
    } finally {
      actionInFlight.current = false;
      setBusy("");
    }
  };

  const saveConfig = () => {
    const integer = (v: any) => Number.isSafeInteger(Number(v));
    if (!integer(form.platform_fee_bps) || form.platform_fee_bps < 0 || form.platform_fee_bps > 5000
      || !integer(form.min_tip) || !integer(form.max_tip) || form.min_tip < 1000
      || form.max_tip > 5000000 || form.min_tip > form.max_tip
      || !integer(form.min_payout) || form.min_payout < 50000 || form.min_payout > 10000000
      || !integer(form.max_minutes) || form.max_minutes < 15 || form.max_minutes > 360
      || !integer(form.max_concurrent) || form.max_concurrent < 1 || form.max_concurrent > 10) {
      setSuccess("");
      setError("Konfigurasi tidak valid. Fee 0–5000 bps, tip Rp1.000–Rp5.000.000, payout Rp50.000–Rp10.000.000, durasi 15–360 menit, dan kapasitas 1–10.");
      return;
    }
    const enabling = form.enabled && !data.config?.enabled;
    if (enabling && Number(data.provider_cleanup?.stats?.pending || 0) > 0) {
      setSuccess("");
      setError("Rollout diblokir sampai antrean cleanup Cloudflare dan OBS bernilai nol.");
      return;
    }
    if (enabling && !window.confirm("Aktifkan Cloudflare Stream berbiaya setelah credential, OBS unit, player privat, dan payout benar-benar diverifikasi?")) return;
    return act("config", async () => {
      await adminFetch("/api/admin/livestream/config", {
        method: "POST",
        body: { ...form, ...(enabling ? { confirmation: "AKTIFKAN LIVE" } : {}) },
      });
      configDirty.current = false;
    }, form.enabled ? "Konfigurasi tersimpan. Status rollout mengikuti kesiapan provider." : "Fitur dimatikan; penghentian ingest aktif telah diantrikan.");
  };

  const review = (creator: any, status: string) => {
    const input = window.prompt(`Catatan review untuk ${creator.user_nama || creator.display_name}:`, creator.review_note || "");
    if (input === null) return;
    const note = input.trim();
    if (["rejected", "suspended"].includes(status) && note.length < 8) {
      setSuccess(""); setError("Alasan penolakan atau suspend minimal 8 karakter."); return;
    }
    return act(`creator-${creator.user_id}`, () => adminFetch(`/api/admin/livestream/creators/${encodeURIComponent(creator.user_id)}`, {
      method: "PATCH", body: { status, review_note: note, payout_verified: status === "approved" ? creator.payout_verified === 1 : false },
    }), `Status kreator diubah menjadi ${status}.`);
  };

  const verifyPayout = (creator: any) => {
    const input = window.prompt("Label metode tersamar (contoh: BCA •••• 1234). Jangan masukkan nomor rekening lengkap:", creator.payout_label || "");
    if (input === null) return;
    const label = input.trim();
    if (!label || label.length > 80 || label.replace(/\D/g, "").length > 4) {
      setSuccess("");
      setError("Label payout wajib diisi, maksimal 80 karakter, dan hanya boleh memuat maksimal 4 digit terakhir.");
      return;
    }
    return act(`creator-${creator.user_id}`, () => adminFetch(`/api/admin/livestream/creators/${encodeURIComponent(creator.user_id)}`, {
      method: "PATCH", body: { status: "approved", payout_verified: true, payout_label: label, review_note: creator.review_note || "" },
    }), "Metode payout tersamar telah diverifikasi.");
  };

  const payoutAction = (p: any, status: string) => {
    let provider_ref = "", note = "";
    if (status === "paid") {
      const input = window.prompt("Referensi transfer yang SUDAH berhasil (4–100 karakter):", "");
      if (input === null) return;
      provider_ref = input.trim();
      if (provider_ref.length < 4 || provider_ref.length > 100) {
        setSuccess(""); setError("Referensi transfer wajib 4–100 karakter."); return;
      }
    } else {
      const input = window.prompt(status === "rejected" ? "Alasan penolakan (earning akan dilepas kembali):" : "Catatan pemrosesan:", "");
      if (input === null) return;
      note = input.trim();
      if (note.length > 300 || (status === "rejected" && note.length < 8)) {
        setSuccess(""); setError("Catatan maksimal 300 karakter; alasan penolakan minimal 8 karakter."); return;
      }
    }
    return act(`payout-${p.id}`, () => adminFetch(`/api/admin/livestream/payouts/${p.id}`, {
      method: "PATCH", body: { status, provider_ref, note, ...(status === "paid" ? { confirmation: "BAYAR" } : {}) },
    }), status === "paid" ? "Payout ditandai terkirim dan ledger diselesaikan." : `Payout diubah menjadi ${status}.`);
  };

  const checkProvider = (live: any) => act(`provider-${live.id}`, async () => {
    setProviderReport(current => { const next = { ...current }; delete next[live.id]; return next; });
    const report = await adminFetch(`/api/admin/livestream/sessions/${live.id}/provider`);
    setProviderReport(current => ({ ...current, [live.id]: report }));
  }, "Diagnostik Live Input Cloudflare selesai; lihat hasil pada kartu siaran.");

  const reconcile = () => {
    if (!window.confirm("Jalankan ulang outbox dan cleanup dengan idempotency key yang sama? Proses berjalan di latar belakang.")) return;
    return act("reconcile", () => adminFetch("/api/admin/livestream/reconcile", {
      method: "POST", body: { confirmation: "RETRY CLEANUP" },
    }), "Rekonsiliasi diantrikan. Segarkan lagi untuk melihat hasil watchdog.");
  };

  const reverseTip = (tip: any) => {
    const input = window.prompt("Alasan refund/fraud (8–200 karakter):", "");
    if (input === null) return;
    const reason = input.trim();
    if (reason.length < 8 || reason.length > 200) {
      setSuccess(""); setError("Alasan refund harus 8–200 karakter."); return;
    }
    if (!window.confirm("Refund saldo viewer dan batalkan earning yang belum dibayar?")) return;
    return act(`tip-${tip.id}`, () => adminFetch(`/api/admin/livestream/tips/${tip.id}/reverse`, {
      method: "POST", body: { confirmation: "KEMBALIKAN", reason },
    }), "Dukungan dikembalikan dan ledger kreator dibatalkan secara atomik.");
  };

  const cfg = data.config || {};
  const creators = data.creators || [];
  const lives = data.lives || [];
  const payouts = data.payouts || [];
  const tips = data.tips || [];
  const finance = data.finance || {};
  const pushStats = data.push_outbox?.stats || {};
  const pushRows = data.push_outbox?.rows || [];
  const cleanupStats = data.provider_cleanup?.stats || {};
  const cleanupRows = data.provider_cleanup?.rows || [];
  const active = lives.filter(x => ["queued", "starting", "live", "ending"].includes(x.status)
    || (x.status === "failed" && Number(x.cleanup_pending) === 1));
  const pushNeedsAttention = Number(pushStats.retrying || 0) + pushRows.filter(x => x.status === "sent" && x.last_error).length;

  return <div className="space-y-4 font-[var(--font-inter)]">
    <div className="flex items-start justify-between gap-3 flex-wrap">
      <div className="flex items-center gap-3">
        <div className="w-11 h-11 rounded-xl bg-gradient-to-br from-[#7C3AED] to-[#A855F7] grid place-items-center"><Radio size={19} className="text-white"/></div>
        <div><h1 className="text-xl font-semibold text-[#1E1B2E] tracking-tight">XyCloud Live</h1>
          <p className="text-sm text-[#7C738F] font-medium">Approval kreator, operasi OBS/Stream, ledger dukungan, payout, dan budget guard</p></div>
      </div>
      <button onClick={load} disabled={loading || !!busy} className="h-10 px-3 rounded-xl border border-[#E9E3F5] bg-white text-[#6B5A8A] text-xs font-semibold flex items-center gap-2 disabled:opacity-50">
        <RefreshCw size={14} className={loading ? "animate-spin" : ""}/> Segarkan
      </button>
    </div>

    {error && <div role="alert" aria-live="assertive" className="rounded-xl border border-rose-200 bg-rose-50 text-rose-700 p-3 text-sm font-medium flex gap-2"><AlertTriangle size={16} className="shrink-0 mt-0.5"/>{error}</div>}
    {success && <div role="status" aria-live="polite" className="rounded-xl border border-emerald-200 bg-emerald-50 text-emerald-800 p-3 text-sm font-medium flex gap-2"><CheckCircle2 size={16} className="shrink-0 mt-0.5"/>{success}</div>}
    {pushNeedsAttention > 0 && <div className="rounded-xl border border-amber-200 bg-amber-50 text-amber-800 p-3 text-xs font-medium flex gap-2">
      <AlertTriangle size={15} className="shrink-0"/> Outbox push follower memiliki {pushNeedsAttention} operasi retry/peringatan provider. Buka tab Push follower; jangan mengirim ulang manual dengan idempotency key baru.
    </div>}
    {Number(cleanupStats.pending || 0) > 0 && <div className="rounded-xl border border-rose-200 bg-rose-50 text-rose-700 p-3 text-xs font-medium flex gap-2">
      <AlertTriangle size={15} className="shrink-0"/> Ada {Number(cleanupStats.pending)} Live Input orphan yang masih menunggu disable/delete Cloudflare. Rollout baru harus tetap OFF sampai antrean ini nol.
    </div>}

    <div className="grid grid-cols-2 lg:grid-cols-3 xl:grid-cols-6 gap-3">
      <Stat label="Live aktif/terkunci" value={active.length} icon={Activity} tone="text-rose-600"/>
      <Stat label="Pending creator" value={creators.filter(x => x.status === "pending").length} icon={Users}/>
      <Stat label="Gross dukungan" value={rp(finance.gross)} icon={HeartHandshake} tone="text-pink-600"/>
      <Stat label="Fee platform" value={rp(finance.platform_fee)} icon={CircleDollarSign} tone="text-emerald-600"/>
      <Stat label="Liabilitas creator" value={rp(Number(finance.held || 0) + Number(finance.available || 0) + Number(finance.reserved || 0))} icon={Wallet} tone="text-amber-600"/>
      <Stat label="Push perlu perhatian" value={pushNeedsAttention} icon={BellRing} tone={pushNeedsAttention ? "text-rose-600" : "text-emerald-600"}/>
    </div>

    <section className="xy-card rounded-[16px] p-4">
      <div className="flex items-center justify-between gap-3 flex-wrap">
        <div><div className="flex items-center gap-2 font-semibold text-[#1E1B2E]"><Settings2 size={16} className="text-[#7C3AED]"/> Rollout & anggaran</div>
          <div className="text-[11px] text-[#7C738F] mt-1">Provider: Cloudflare Stream · ingress gratis, delivery berbiaya · player wajib tiket app</div></div>
        <div className="flex gap-2"><Badge value={cfg.configured ? "provider ready" : "not configured"}/><Badge value={cfg.effective ? "effective" : "off"}/></div>
      </div>
      <div className="grid grid-cols-2 md:grid-cols-4 xl:grid-cols-7 gap-3 mt-4">
        <label className="text-xs font-semibold text-[#6B5A8A]">Fitur
          <select value={form.enabled ? "1" : "0"} onChange={e => { configDirty.current = true; setForm({...form, enabled:e.target.value === "1"}); }} className="mt-1 w-full h-10 px-2 rounded-lg border border-[#E9E3F5] bg-white">
            <option value="0">OFF</option><option value="1">ON</option>
          </select></label>
        {[
          ["Fee (bps)", "platform_fee_bps"], ["Tip min", "min_tip"], ["Tip max", "max_tip"],
          ["Payout min", "min_payout"], ["Durasi max", "max_minutes"], ["Live bersamaan", "max_concurrent"],
        ].map(([label,key]) => <label key={key} className="text-xs font-semibold text-[#6B5A8A]">{label}
          <input type="number" value={form[key] ?? ""} onChange={e => { configDirty.current = true; setForm({...form, [key]:Number(e.target.value)}); }}
            className="mt-1 w-full h-10 px-2 rounded-lg border border-[#E9E3F5] bg-white"/></label>)}
      </div>
      <div className="mt-3 flex items-center justify-between gap-3 flex-wrap">
        <p className="text-[11px] text-[#7C738F]">Mengaktifkan pertama kali memerlukan konfirmasi eksplisit. Mematikan fitur langsung memutus semua ingest aktif.</p>
        <button onClick={saveConfig} disabled={!!busy} className="xy-btn h-10 px-4 rounded-xl text-white text-xs font-semibold disabled:opacity-50">
          {busy === "config" ? "Menyimpan…" : "Simpan konfigurasi"}
        </button>
      </div>
    </section>

    <div className="flex gap-1 p-1 rounded-xl bg-[#F3F0FF] border border-[#E9E3F5] overflow-x-auto">
      {[["creator","Kreator"],["session","Siaran"],["payout","Payout"],["tip","Ledger dukungan"],["push","Push follower"]].map(([id,label]) =>
        <button key={id} onClick={() => setTab(id)} className={`px-4 h-9 rounded-lg text-xs font-semibold whitespace-nowrap ${tab===id?"bg-white text-[#7C3AED] shadow-sm":"text-[#7C738F]"}`}>{label}</button>)}
    </div>

    {loading ? <div className="xy-card rounded-xl p-10 text-center text-[#7C738F]">Memuat control plane…</div> : null}

    {!loading && tab === "creator" && <div className="xy-card rounded-[16px] overflow-x-auto">
      <table className="w-full text-left text-xs"><thead className="bg-[#F8F7FC] text-[#7C738F] uppercase tracking-wide text-[10px]"><tr>
        <th className="p-3">Kreator</th><th className="p-3">Status</th><th className="p-3">Usia/syarat</th><th className="p-3">Payout</th><th className="p-3">Diajukan</th><th className="p-3 text-right">Aksi</th>
      </tr></thead><tbody>{creators.map(c => <tr key={c.user_id} className="border-t border-[#E9E3F5]">
        <td className="p-3"><div className="font-semibold text-[#1E1B2E]">{c.display_name}</div><div className="text-[10px] text-[#7C738F]">{c.user_email}<br/>{c.bio}</div></td>
        <td className="p-3"><Badge value={c.status}/>{c.review_note && <div className="mt-1 text-[10px] text-[#7C738F] max-w-[180px]">{c.review_note}</div>}</td>
        <td className="p-3">{c.age_18 ? "18+" : "Tidak"}<br/><span className="text-[10px] text-[#7C738F]">{c.terms_version}</span></td>
        <td className="p-3">{c.payout_verified ? <><BadgeCheck size={14} className="inline text-emerald-600"/> {c.payout_label}</> : "Belum diverifikasi"}</td>
        <td className="p-3 whitespace-nowrap">{dt(c.applied_at)}</td>
        <td className="p-3"><div className="flex justify-end gap-1 flex-wrap">
          {c.status !== "approved" && <button onClick={() => review(c,"approved")} disabled={!!busy} className="px-2 py-1 rounded bg-emerald-50 text-emerald-700 font-semibold disabled:opacity-50">Setujui</button>}
          {c.status === "pending" && <button onClick={() => review(c,"rejected")} disabled={!!busy} className="px-2 py-1 rounded bg-rose-50 text-rose-700 font-semibold disabled:opacity-50">Tolak</button>}
          {c.status === "approved" && <button onClick={() => review(c,"suspended")} disabled={!!busy} className="px-2 py-1 rounded bg-rose-50 text-rose-700 font-semibold disabled:opacity-50"><Ban size={11} className="inline"/> Suspend</button>}
          {c.status === "approved" && !c.payout_verified && <button onClick={() => verifyPayout(c)} disabled={!!busy} className="px-2 py-1 rounded bg-[#F3F0FF] text-[#7C3AED] font-semibold disabled:opacity-50">Verifikasi payout</button>}
        </div></td>
      </tr>)}</tbody></table>
      {!creators.length && <div className="p-8 text-center text-[#7C738F]">Belum ada pengajuan kreator.</div>}
    </div>}

    {!loading && tab === "session" && <div className="grid grid-cols-1 xl:grid-cols-2 gap-3">
      {lives.map(l => <div key={l.id} className="xy-card rounded-[15px] p-4">
        <div className="flex items-start justify-between gap-2"><div><div className="font-semibold text-[#1E1B2E]">{l.title}</div>
          <div className="text-[11px] text-[#7C738F] mt-1 flex items-center gap-1.5 flex-wrap">
            <span>{l.creator_name} · {l.game}</span>
            {l.agen_id === "agen_mobile" ? (
              <span className="inline-flex px-1.5 py-0.5 rounded-full bg-purple-100 text-purple-700 font-semibold text-[10px]">
                Mobile Stream (HP)
              </span>
            ) : (
              <span>· {l.agen_nama || l.agen_id || "PC Rental"}</span>
            )}
          </div></div><Badge value={l.status}/></div>
        <div className="grid grid-cols-3 gap-2 mt-3 text-center"><div className="bg-[#F8F7FC] rounded-lg p-2"><Eye size={13} className="mx-auto text-[#7C3AED]"/><b>{l.viewers || 0}</b><small className="block text-[#7C738F]">aktif</small></div>
          <div className="bg-[#F8F7FC] rounded-lg p-2"><Users size={13} className="mx-auto text-[#7C3AED]"/><b>{l.viewer_peak || 0}</b><small className="block text-[#7C738F]">puncak</small></div>
          <div className="bg-[#F8F7FC] rounded-lg p-2"><HeartHandshake size={13} className="mx-auto text-pink-600"/><b>{rp(l.gross_tip)}</b><small className="block text-[#7C738F]">gross</small></div></div>
        <div className="mt-3 text-[10px] text-[#7C738F]">Mulai {dt(l.started_at)} · Batas {dt(l.scheduled_end)} · credential {l.credential_issued_at ? "pernah diambil" : "belum diambil"}<br/>Provider input …{String(l.provider_input_uid || "").slice(-8)} · {l.provider_deleted_at ? `dihapus ${dt(l.provider_deleted_at)}` : l.provider_disabled_at ? `ingress diblokir ${dt(l.provider_disabled_at)}` : "aktif/belum dicek"} · health {l.health_code || "menunggu"} · audit {dt(l.last_health_at)} {l.output_reconnecting ? "· reconnecting" : ""} {l.cleanup_pending ? "· CLEANUP PENDING" : ""}<br/>Congestion {Math.round(Number(l.output_congestion || 0) * 100)}% · frame lewat {Number(l.output_skipped_frames || 0).toLocaleString("id-ID")}/{Number(l.output_total_frames || 0).toLocaleString("id-ID")} {l.failure_code ? `· fault ${l.failure_code}` : ""}{l.end_reason ? <><br/>Alasan akhir: {l.end_reason}</> : null}</div>
        {providerReport[l.id] && <div className="mt-3 rounded-lg border border-[#E9E3F5] bg-[#F8F7FC] p-2 text-[10px] text-[#6B5A8A]">
          Cloudflare: <b>{providerReport[l.id].ok ? providerReport[l.id].status || "terhubung" : providerReport[l.id].code || "gagal"}</b>
          {typeof providerReport[l.id].enabled === "boolean" ? ` · ingress ${providerReport[l.id].enabled ? "aktif" : "nonaktif"}` : ""}
        </div>}
        {((l.provider_input_uid && !l.provider_deleted_at) || ["queued","starting","live","ending"].includes(l.status) || (l.status === "failed" && Number(l.cleanup_pending) === 1)) && <div className="flex gap-2 mt-3">
          {l.provider_input_uid && !l.provider_deleted_at && <button onClick={() => checkProvider(l)} disabled={!!busy} className="flex-1 h-9 rounded-lg border border-[#E9E3F5] text-[#7C3AED] font-semibold text-xs disabled:opacity-50"><ShieldCheck size={12} className="inline"/> {busy === `provider-${l.id}` ? "Memeriksa…" : "Cek provider"}</button>}
          {(["queued","starting","live","ending"].includes(l.status) || (l.status === "failed" && Number(l.cleanup_pending) === 1)) && <button onClick={() => { if(window.confirm("Putus ingest dan akhiri siaran ini?")) act(`end-${l.id}`, () => adminFetch(`/api/admin/livestream/sessions/${l.id}/end`,{method:"POST",body:{reason:"Diakhiri dari dashboard operasi"}}), "Penghentian ingest dan cleanup OBS telah diantrikan."); }} disabled={!!busy} className="flex-1 h-9 rounded-lg bg-rose-600 text-white font-semibold text-xs disabled:opacity-50"><Square size={12} className="inline"/> Akhiri</button>}
          {["live", "starting"].includes(l.status) && (
            <a
              href={`https://api.xycloud.my.id/live/watch/${l.id}`}
              target="_blank"
              rel="noopener noreferrer"
              className="h-9 px-3 rounded-lg bg-[#7C3AED] text-white font-semibold text-xs flex items-center justify-center gap-1 hover:bg-[#6D28D9]"
            >
              <Eye size={12} /> Buka Player
            </a>
          )}
        </div>}
      </div>)}
      {!lives.length && <div className="xy-card rounded-xl p-8 text-center text-[#7C738F]">Belum ada riwayat siaran.</div>}
    </div>}

    {!loading && tab === "payout" && <div className="xy-card rounded-[16px] overflow-x-auto"><table className="w-full text-left text-xs"><thead className="bg-[#F8F7FC] text-[10px] uppercase text-[#7C738F]"><tr>
      <th className="p-3">Kreator</th><th className="p-3">Jumlah</th><th className="p-3">Metode</th><th className="p-3">Status</th><th className="p-3">Waktu</th><th className="p-3 text-right">Aksi</th></tr></thead>
      <tbody>{payouts.map(p => <tr key={p.id} className="border-t border-[#E9E3F5]"><td className="p-3"><b>{p.user_nama || "Akun dihapus"}</b><div className="text-[10px] text-[#7C738F]">{p.user_email}</div></td>
        <td className="p-3 font-semibold">{rp(p.amount)}</td><td className="p-3">{p.payout_label}</td><td className="p-3"><Badge value={p.status}/>{(p.provider_ref || p.note) && <div className="mt-1 text-[10px] text-[#7C738F] max-w-[220px] break-words">{p.provider_ref ? `Ref ${p.provider_ref}` : ""}{p.provider_ref && p.note ? " · " : ""}{p.note || ""}</div>}</td><td className="p-3">{dt(p.requested_at)}{p.processed_at && <div className="text-[10px] text-[#7C738F]">diproses {dt(p.processed_at)}</div>}</td>
        <td className="p-3"><div className="flex justify-end gap-1">{p.status === "requested" && <button onClick={() => payoutAction(p,"processing")} disabled={!!busy} className="px-2 py-1 bg-amber-50 text-amber-700 rounded font-semibold disabled:opacity-50">Proses</button>}
          {["requested","processing"].includes(p.status) && <><button onClick={() => payoutAction(p,"paid")} disabled={!!busy} className="px-2 py-1 bg-emerald-50 text-emerald-700 rounded font-semibold disabled:opacity-50">Sudah transfer</button><button onClick={() => payoutAction(p,"rejected")} disabled={!!busy} className="px-2 py-1 bg-rose-50 text-rose-700 rounded font-semibold disabled:opacity-50">Tolak</button></>}</div></td></tr>)}</tbody></table>
      {!payouts.length && <div className="p-8 text-center text-[#7C738F]">Belum ada payout.</div>}
    </div>}

    {!loading && tab === "tip" && <div className="xy-card rounded-[16px] overflow-x-auto"><table className="w-full text-left text-xs"><thead className="bg-[#F8F7FC] text-[10px] uppercase text-[#7C738F]"><tr>
      <th className="p-3">Waktu</th><th className="p-3">Viewer → creator</th><th className="p-3">Gross</th><th className="p-3">Fee / net</th><th className="p-3">Earning</th><th className="p-3 text-right">Anti-fraud</th></tr></thead>
      <tbody>{tips.map(t => <tr key={t.id} className="border-t border-[#E9E3F5]"><td className="p-3 whitespace-nowrap">{dt(t.created_at)}</td><td className="p-3">{t.viewer_name || "Akun dihapus"} → {t.creator_name || "Akun dihapus"}<div className="text-[10px] text-[#7C738F]">{t.livestream_id}</div></td>
        <td className="p-3 font-semibold">{rp(t.gross)}</td><td className="p-3">{rp(t.platform_fee)} / {rp(t.creator_net)}</td><td className="p-3"><Badge value={t.earning_status || t.status}/>{t.reverse_reason && <div className="mt-1 text-[10px] text-[#7C738F] max-w-[220px]">{t.reverse_reason}</div>}</td>
        <td className="p-3 text-right">{t.status === "charged" && ["held","available"].includes(t.earning_status) ? <button onClick={() => reverseTip(t)} disabled={!!busy} className="px-2 py-1 bg-rose-50 text-rose-700 rounded font-semibold disabled:opacity-50">Refund</button> : <Badge value={t.status}/>}</td></tr>)}</tbody></table>
      {!tips.length && <div className="p-8 text-center text-[#7C738F]">Ledger dukungan masih kosong.</div>}
    </div>}

    {!loading && tab === "push" && <div className="space-y-3">
      <div className="flex items-center justify-between gap-3 flex-wrap xy-card rounded-xl p-3">
        <div><b className="text-xs text-[#1E1B2E]">Watchdog & rekonsiliasi</b><div className="text-[10px] text-[#7C738F]">Memakai ulang UUID OneSignal dan antrean provider yang sudah ada—tidak membuat transaksi atau resource baru.</div></div>
        <button onClick={reconcile} disabled={!!busy} className="h-9 px-3 rounded-lg border border-[#E9E3F5] text-[#7C3AED] text-xs font-semibold disabled:opacity-50"><Wrench size={13} className="inline mr-1"/>{busy === "reconcile" ? "Mengantrikan…" : "Jalankan rekonsiliasi"}</button>
      </div>
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-3">
        <Stat label="Menunggu" value={Number(pushStats.pending || 0)} icon={BellRing} tone="text-amber-600"/>
        <Stat label="Sedang dikirim" value={Number(pushStats.sending || 0)} icon={RefreshCw}/>
        <Stat label="Terkirim" value={Number(pushStats.sent || 0)} icon={BadgeCheck} tone="text-emerald-600"/>
        <Stat label="Dibatalkan" value={Number(pushStats.cancelled || 0)} icon={Ban} tone="text-rose-600"/>
      </div>
      <div className="xy-card rounded-[16px] overflow-x-auto">
        <table className="w-full text-left text-xs"><thead className="bg-[#F8F7FC] text-[10px] uppercase text-[#7C738F]"><tr>
          <th className="p-3">Live / dibuat</th><th className="p-3">Status</th><th className="p-3">Percobaan</th><th className="p-3">Jadwal/lease</th><th className="p-3">Provider</th><th className="p-3">Error/peringatan</th>
        </tr></thead><tbody>{pushRows.map(o => <tr key={o.id} className="border-t border-[#E9E3F5] align-top">
          <td className="p-3"><b>{o.livestream_id}</b><div className="text-[10px] text-[#7C738F]">{dt(o.created_at)}</div></td>
          <td className="p-3"><Badge value={o.status}/></td><td className="p-3 font-semibold">{Number(o.attempts || 0)}</td>
          <td className="p-3 text-[10px]">next {dt(o.next_attempt_at)}<br/>lease {dt(o.lease_until)}</td>
          <td className="p-3 text-[10px]">{o.provider_id || (o.status === "sent" ? "tanpa subscription aktif" : "—")}<br/>{o.sent_at ? dt(o.sent_at) : ""}</td>
          <td className={`p-3 text-[10px] max-w-[280px] ${o.last_error ? "text-amber-700" : "text-[#7C738F]"}`}>{o.last_error || "—"}</td>
        </tr>)}</tbody></table>
        {!pushRows.length && <div className="p-8 text-center text-[#7C738F]">Outbox belum memiliki event follower.</div>}
      </div>
      <div className="rounded-xl border border-[#E9E3F5] bg-[#F8F7FC] p-3 text-[11px] text-[#6B5A8A]">
        Oldest open: {dt(pushStats.oldest_open_at)} · maksimum percobaan {Number(pushStats.max_attempts || 0)}. Retry selalu memakai UUID OneSignal yang sama; status sent dengan peringatan tidak boleh dikirim ulang manual.
      </div>
      <div className="xy-card rounded-[16px] overflow-x-auto">
        <div className="p-3 border-b border-[#E9E3F5]"><b className="text-xs text-[#1E1B2E]">Kompensasi resource Cloudflare</b><div className="text-[10px] text-[#7C738F]">Live Input yang sempat tercipta ketika transaksi D1 gagal/race. Pending wajib nol sebelum rollout.</div></div>
        <table className="w-full text-left text-xs"><thead className="bg-[#F8F7FC] text-[10px] uppercase text-[#7C738F]"><tr>
          <th className="p-3">Live / input</th><th className="p-3">Status</th><th className="p-3">Percobaan</th><th className="p-3">Alasan</th><th className="p-3">Error terakhir</th><th className="p-3">Diperbarui</th>
        </tr></thead><tbody>{cleanupRows.map(o => <tr key={o.input_uid} className="border-t border-[#E9E3F5] align-top">
          <td className="p-3"><b>{o.live_id}</b><div className="text-[10px] text-[#7C738F]">…{String(o.input_uid || "").slice(-8)}</div></td>
          <td className="p-3"><Badge value={o.status}/></td><td className="p-3 font-semibold">{Number(o.attempts || 0)}</td>
          <td className="p-3 text-[10px]">{o.reason}</td><td className="p-3 text-[10px] text-rose-700">{o.last_error || "—"}</td><td className="p-3 text-[10px]">{dt(o.updated_at)}</td>
        </tr>)}</tbody></table>
        {!cleanupRows.length && <div className="p-6 text-center text-[#7C738F] text-xs">Tidak ada resource kompensasi.</div>}
      </div>
      <div className="text-[10px] text-[#7C738F]">Provider cleanup pending {Number(cleanupStats.pending || 0)} · oldest {dt(cleanupStats.oldest_pending_at)} · max attempts {Number(cleanupStats.max_attempts || 0)}</div>
    </div>}

    <div className="xy-card rounded-xl p-3 text-[11px] text-[#7C738F] flex gap-2"><ShieldCheck size={14} className="text-[#7C3AED] shrink-0"/>
      Stream key tidak pernah ditampilkan dashboard atau disimpan D1. Agen mengambilnya on-demand, scene asing memicu fail-closed, playback wajib signed URL, dan input provider dihapus setelah ACK cleanup. Payout adalah proses owner-reviewed; label hanya boleh menyimpan nama metode dan maksimal 4 digit terakhir.</div>
  </div>;
}
