"use client";
import { useMemo, useState } from "react";
import { CheckCircle2, Download, Gift, Link2, ShieldAlert, Smartphone } from "lucide-react";
import {
  Chip, EmptyBox, ErrBox, Header, Load, rupiah, SearchBox, Stat, useAdminList,
} from "@/components/ui/kit";

function tone(status: string): "ok" | "warn" | "bad" | "info" | "netral" {
  if (["diklaim", "selesai"].includes(status)) return "ok";
  if (["diunduh", "terpasang"].includes(status)) return "info";
  if (["ditolak", "kedaluwarsa"].includes(status)) return "bad";
  return "warn";
}

function Funnel({ row }: { row: any }) {
  const steps = [
    { ok: !!row.dibuat, icon: Link2, title: "Klik" },
    { ok: !!row.downloaded_at || row.sumber === "legacy", icon: Download, title: "Unduh" },
    { ok: !!row.installed_at || row.sumber === "legacy", icon: Smartphone, title: "Buka app" },
    { ok: ["diklaim", "selesai"].includes(row.status), icon: CheckCircle2, title: "Klaim" },
  ];
  return <div className="flex items-center gap-1">
    {steps.map(({ ok, icon: Icon, title }, i) => <div key={title} className="flex items-center gap-1">
      {i > 0 && <span className={`w-3 h-px ${ok ? "bg-emerald-400" : "bg-[#DDD8E7]"}`} />}
      <span title={title} className={`w-7 h-7 rounded-full grid place-items-center ${ok ? "bg-emerald-50 text-emerald-600" : "bg-[#F3F0F7] text-[#A9A1B8]"}`}>
        <Icon size={13} />
      </span>
    </div>)}
  </div>;
}

export default function ReferralPage() {
  const { rows, loading, err } = useAdminList("/api/admin/referral");
  const [q, setQ] = useState("");
  const filtered = useMemo(() => rows.filter((r: any) =>
    `${r.nama_pengundang} ${r.nama_diundang} ${r.kode} ${r.status} ${r.risiko || ""}`.toLowerCase().includes(q.toLowerCase())), [rows, q]);
  const downloads = rows.filter((r: any) => r.downloaded_at || r.sumber === "legacy").length;
  const installs = rows.filter((r: any) => r.installed_at || r.sumber === "legacy").length;
  const claims = rows.filter((r: any) => ["diklaim", "selesai"].includes(r.status)).length;
  const rejected = rows.filter((r: any) => ["ditolak", "kedaluwarsa"].includes(r.status)).length;
  const bonuses = rows.reduce((a: number, r: any) => a + (["diklaim", "selesai"].includes(r.status)
    ? Number(r.bonus_pengundang || 0) + Number(r.bonus_diundang || 0) : 0), 0);

  return <div className="space-y-5 font-[var(--font-inter)]">
    <Header icon={Gift} title="Referral" sub="Funnel tiket install: klik, unduh APK, buka aplikasi, lalu klaim terverifikasi"
      right={<span className="text-xs px-3 py-1.5 rounded-full bg-[#F3F0FF] border border-[#E9E3F5] font-medium">{rows.length} tiket</span>} />
    {err && <ErrBox msg={err} />}
    <div className="grid grid-cols-2 xl:grid-cols-5 gap-3">
      <Stat label="Klik bertiket" value={rows.length} sub="termasuk legacy" tone="info" />
      <Stat label="APK diunduh" value={downloads} sub="unduhan tervalidasi" />
      <Stat label="App dibuka" value={installs} sub="device terikat" tone="ok" />
      <Stat label="Berhasil diklaim" value={claims} sub={rupiah(bonuses)} tone="ok" />
      <Stat label="Ditolak / expired" value={rejected} sub="tanpa reward" tone={rejected ? "bad" : ""} />
    </div>
    <div className="xy-card rounded-[14px] p-4 flex items-start gap-3">
      <ShieldAlert size={18} className="text-[#7C3AED] mt-0.5 shrink-0" />
      <div className="text-xs text-[#6F667C] leading-relaxed">Tiket mentah tidak disimpan di database. Reward baru diberikan setelah akun baru terverifikasi, perangkat pendaftaran cocok, bukan perangkat pengundang, dan tiket belum pernah dipakai.</div>
    </div>
    <SearchBox value={q} onChange={setQ} placeholder="Cari nama, kode, status, atau risiko…" />
    {loading ? <Load /> : filtered.length === 0 ? <EmptyBox msg="Belum ada atribusi referral." sub="Klik dari tautan undangan akan muncul di sini." /> :
      <div className="xy-card rounded-[14px] overflow-x-auto">
        <table className="w-full text-left text-[12.5px] min-w-[1080px]">
          <thead><tr className="border-b border-[#E9E3F5] bg-[#F5F3FF]">
            {["Pengundang / undangan", "Kode & sumber", "Funnel", "Status", "Perangkat / waktu", "Reward"].map((h) =>
              <th key={h} className="px-4 py-2.5 text-[10.5px] uppercase tracking-wider text-[#7C738F] font-semibold">{h}</th>)}
          </tr></thead>
          <tbody>{filtered.map((r: any) => <tr key={r.id} className="border-b border-[#F0EDFB] last:border-0 hover:bg-[#FBF9FD]">
            <td className="px-4 py-3"><div className="font-semibold text-[#292337]">{r.nama_pengundang || "—"}</div>
              <div className="text-xs text-[#8A8298]">→ {r.nama_diundang || "Belum ada akun"}</div></td>
            <td className="px-4 py-3"><div className="font-mono font-bold text-xs">{r.kode || "—"}</div>
              <div className="text-[11px] text-[#8A8298]">{r.sumber === "install_ticket" ? "Tiket instalasi" : "Legacy"}{r.download_variant ? ` · ${r.download_variant}` : ""}</div></td>
            <td className="px-4 py-3"><Funnel row={r} /></td>
            <td className="px-4 py-3"><Chip tone={tone(String(r.status || ""))}>{r.status || "diklik"}</Chip>
              {r.risiko && <div className="mt-1 text-[11px] font-semibold text-amber-700">{String(r.risiko).replaceAll("_", " ")}</div>}</td>
            <td className="px-4 py-3 text-xs"><div className="font-mono text-[#60586D]">{r.perangkat || "belum terikat"}</div>
              <div className="text-[#9A92A7] mt-1">Klik {String(r.dibuat || "—").replace("T", " ").slice(0, 16)}{r.package_installed_at ? ` · pasang ${String(r.package_installed_at).replace("T", " ").slice(0, 16)}` : ""}{r.installed_at ? ` · buka ${String(r.installed_at).replace("T", " ").slice(0, 16)}` : ""}</div></td>
            <td className="px-4 py-3"><div className="font-bold text-emerald-600">{rupiah(r.bonus_pengundang)}</div>
              <div className="text-[11px] text-[#8A8298]">teman {rupiah(r.bonus_diundang)}</div></td>
          </tr>)}</tbody>
        </table>
      </div>}
  </div>;
}
