"use client";
import { MonitorSmartphone } from "lucide-react";
import {
  Chip, EmptyBox, ErrBox, Header, jam, Load, toneStatus, useAdminList,
} from "@/components/ui/kit";

export default function SesiPage() {
  const { rows, loading, err } = useAdminList("/api/admin/sesi");

  return (
    <div className="space-y-4 font-[var(--font-inter)]">
      <Header
        icon={MonitorSmartphone}
        title="Sesi PC"
        sub="Sesi sewa aktif & riwayat (100 terakhir)"
        right={<span className="text-xs px-3 py-1.5 rounded-full bg-[#F3F0FF] border border-[#E9E3F5] font-medium">{rows.length} sesi</span>}
      />
      {err && <ErrBox msg={err} />}
      {loading ? <Load /> : rows.length === 0 ? (
        <EmptyBox msg="Belum ada sesi." sub="Muncul saat user mulai main di unit PC." />
      ) : (
        <div className="xy-card rounded-[20px] overflow-x-auto">
          <table className="w-full text-left text-[12.5px] min-w-[720px]">
            <thead>
              <tr className="border-b border-[#E9E3F5] bg-[#F5F3FF]">
                {["Sesi", "User", "Unit", "Order", "Status", "Klien", "Mulai", "Catatan"].map((h) => (
                  <th key={h} className="px-4 py-2.5 text-[10.5px] uppercase tracking-wider text-[#7C738F] font-semibold">{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {rows.map((s) => (
                <tr key={s.id} className="border-b border-[#F0EDFB] last:border-0 hover:bg-[#FBFAFF]">
                  <td className="px-4 py-3 font-mono text-[11px] text-[#7C738F]">{String(s.id).slice(0, 12)}</td>
                  <td className="px-4 py-3">
                    <div className="font-semibold">{s.nama || "—"}</div>
                    <div className="text-[11px] text-[#7C738F]">{s.email || s.user_id}</div>
                  </td>
                  <td className="px-4 py-3 font-medium">{s.unit || s.agen_id || "—"}</td>
                  <td className="px-4 py-3 font-mono text-[11px]">{s.order_id ? String(s.order_id).slice(0, 10) : "—"}</td>
                  <td className="px-4 py-3"><Chip tone={toneStatus(s.status)}>{s.status}</Chip></td>
                  <td className="px-4 py-3 min-w-[180px]">
                    <div className="flex items-center gap-1.5">
                      <span className={`w-1.5 h-1.5 rounded-full ${s.client_state === "connected" ? "bg-emerald-500" : s.client_state ? "bg-amber-500" : "bg-slate-300"}`} />
                      <span className="font-semibold text-[11px]">{s.client_state || "belum ada laporan"}</span>
                      {s.client_latency_ms != null && <span className="text-[10px] font-mono text-[#7C738F]">{s.client_latency_ms}ms</span>}
                    </div>
                    <div className="mt-1 text-[10px] text-[#7C738F] truncate max-w-[220px]">
                      {s.client_route || "jalur —"}{s.client_disconnects ? ` • putus ${s.client_disconnects}x` : ""}
                    </div>
                    {s.client_quality && <div className="text-[10px] text-[#7C738F] truncate max-w-[220px]">{s.client_quality}</div>}
                  </td>
                  <td className="px-4 py-3 text-[11px] font-mono text-[#7C738F]">{jam(s.mulai || s.dibuat)}</td>
                  <td className="px-4 py-3 text-[11.5px] text-[#6B5A8A] max-w-[180px] truncate">{s.catatan || "—"}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
