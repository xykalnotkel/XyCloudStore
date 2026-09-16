"use client";
import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { clearAdminKey, getAdminKey, loginAdmin } from "@/lib/api";
import { Users, Receipt, Wallet, Cpu, ShieldCheck, Rocket, Activity } from "lucide-react";

type Stats = {
  total_users: number;
  total_orders: number;
  pendapatan: number;
  unit_online: number;
};

export default function DashboardPage() {
  const router = useRouter();
  const [stats, setStats] = useState<Stats | null>(null);
  const [loading, setLoading] = useState(true);
  const [dateStr, setDateStr] = useState("");

  useEffect(() => {
    setDateStr(new Date().toLocaleDateString("id-ID"));
    const k = getAdminKey();
    if (!k) {
      router.replace("/login");
      return;
    }
    loginAdmin(k)
      .then((d) => {
        setStats({
          total_users: d?.total_users ?? d?.users ?? 0,
          total_orders: d?.total_orders ?? d?.orders ?? 0,
          pendapatan: d?.pendapatan ?? 0,
          unit_online: d?.unit_online ?? 0,
        });
      })
      .catch(() => {
        clearAdminKey();
        router.replace("/login");
      })
      .finally(() => setLoading(false));
  }, [router]);

  if (loading) {
    return (
      <div className="min-h-[60vh] grid place-items-center">
        <div className="flex flex-col items-center gap-3">
          <div className="w-8 h-8 rounded-full border-2 border-[#E9E3F5] border-t-[#7C3AED] animate-spin" />
          <div className="text-[13px] text-[#7C738F] font-medium">Memuat dashboard...</div>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-6 font-[var(--font-inter)]">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-semibold text-[#1E1B2E] tracking-tight">Dashboard</h1>
          <p className="text-sm text-[#7C738F] font-medium">Ringkasan tema terang ala xycloud.my.id</p>
        </div>
        <div className="flex gap-2">
          <span className="px-3 py-1 rounded-full bg-[#F3F0FF] border border-[#E9E3F5] text-xs text-[#1E1B2E] font-semibold flex items-center gap-1"><Activity size={12} /> Live</span>
          <span className="px-3 py-1 rounded-full bg-[#F3F0FF] border border-[#E9E3F5] text-xs text-[#7C738F] font-medium">{dateStr}</span>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        {[
          { label: "Total Pengguna", value: stats?.total_users ?? "—", Icon: Users, grad: "from-[#7C3AED] to-[#A855F7]" },
          { label: "Total Pesanan", value: stats?.total_orders ?? "—", Icon: Receipt, grad: "from-[#200050] to-[#7C3AED]" },
          { label: "Pendapatan", value: stats?.pendapatan ? `Rp ${stats.pendapatan.toLocaleString()}` : "—", Icon: Wallet, grad: "from-[#7C3AED] to-[#8B5CF6]" },
          { label: "Unit Online", value: stats?.unit_online ?? "—", Icon: Cpu, grad: "from-[#100030] to-[#7C3AED]" },
        ].map((c) => (
          <div key={c.label} className="xy-card rounded-[18px] p-5">
            <div className="flex items-center justify-between">
              <div className={`w-10 h-10 rounded-xl bg-gradient-to-br ${c.grad} grid place-items-center`}><c.Icon size={18} className="text-white" /></div>
              <div className="text-[11px] px-2 py-0.5 rounded-full bg-[#F3F0FF] border border-[#E9E3F5] font-medium">v3.3</div>
            </div>
            <div className="mt-4 text-[12px] text-[#7C738F] font-medium tracking-wide uppercase">{c.label}</div>
            <div className="text-xl font-semibold text-[#1E1B2E] mt-1 tracking-tight">{c.value}</div>
          </div>
        ))}
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
        <div className="lg:col-span-2 xy-card rounded-[18px] p-5">
          <h3 className="font-semibold text-[#1E1B2E] tracking-tight flex items-center gap-2"><Rocket size={16} className="text-[#7C3AED]" /> Apa yang baru di v3.3?</h3>
          <ul className="mt-3 space-y-2 text-sm text-[#1E1B2E]/80 list-disc pl-5 font-medium">
            <li>Next.js 14 App Router — admin.html lama 1800 baris dipecah jadi komponen, no emoji, Lucide icons konsisten</li>
            <li>Native updater fix: <code className="px-1.5 py-0.5 rounded bg-[#F3F0FF] border border-[#E9E3F5] font-mono text-xs">siapkan_pembaruan.py</code> auto-inject DownloadManager + notif progress tetap jalan walau app ditutup</li>
            <li>Security full audit: global IP rate-limit 180/60s, device 2 akun, saldo anti-double, upload validasi</li>
            <li>Menu baru: Live Monitor, Keuangan, Rilis App (tema popup Ramadan dll), Push Notif Builder — semua pakai Lucide</li>
            <li>Font konsisten: Plus Jakarta Sans di semua platform, icons Lucide (bukan emoji)</li>
          </ul>
        </div>
        <div className="xy-card rounded-[18px] p-5">
          <h3 className="font-semibold text-[#1E1B2E] tracking-tight flex items-center gap-2"><ShieldCheck size={16} className="text-[#7C3AED]" /> Next Steps</h3>
          <div className="mt-3 space-y-2">
            {[
              "Users / Orders / TopUp / Sampah — aksi penuh + massal",
              "Unit agen, GIPHY, Perangkat, Moderasi, Security",
              "Favorit agregasi, Galat, Audit, Sesi, Media, Referral",
              "Legacy admin.html hanya fallback darurat",
              "Deploy dashboard ke Cloudflare Pages / Vercel",
            ].map((t, i) => (
              <div key={i} className="flex gap-2 text-[13px] text-[#1E1B2E]/70 font-medium">
                <span className="w-5 h-5 rounded-full bg-[#F3F0FF] border border-[#E9E3F5] grid place-items-center text-[10px] font-semibold">{i + 1}</span>
                <span>{t}</span>
              </div>
            ))}
          </div>
        </div>
      </div>

      <div className="xy-card rounded-[18px] p-4 flex items-center justify-between">
        <div className="text-[12px] text-[#1E1B2E]/50 font-medium">Migrasi Next.js tuntas — legacy hanya darurat di <a href="https://api.xycloud.my.id/admin?legacy=1" className="text-[#8B5CF6] underline">/admin?legacy=1</a> • Lucide, Inter</div>
        <button
          onClick={() => {
            clearAdminKey();
            location.reload();
          }}
          className="text-xs px-3 py-1.5 rounded-full bg-white hover:bg-[#E9E3F5] border border-[#E9E3F5] font-medium text-[#6B5A8A]"
        >
          Logout
        </button>
      </div>
    </div>
  );
}
