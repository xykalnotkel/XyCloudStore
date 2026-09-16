"use client";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { MENU, MenuIcon } from "@/lib/theme";
import { useEffect, useState } from "react";
import {
  LayoutDashboard, Receipt, Users, Monitor, Gamepad2, Image as ImageIcon, Gift, Ticket,
  CreditCard, Cpu, Activity, ShieldCheck, Wallet, MessageCircle, MessagesSquare, Star,
  BarChart3, LineChart, Rocket, Bell, Package, FileText, Settings, ShieldUser,
  ChevronsLeft, ChevronsRight, Share2, Heart, Bug, MonitorSmartphone, Sticker, Trash2,
  Smartphone, ShieldAlert, Wrench, Database, BellRing, ScrollText, Terminal, ReceiptText,
  MessageSquareText, ArrowLeftRight, SlidersHorizontal, UploadCloud, HeartPulse, ListChecks,
  Gavel, Flag, Bot, Power, Globe, Layers, HardDrive, Send, AtSign, Filter,
  LogOut, Menu, X,
} from "lucide-react";
import { clearAdminKey } from "@/lib/api";

const iconMap: Record<MenuIcon, any> = {
  "layout-dashboard": LayoutDashboard,
  receipt: Receipt,
  users: Users,
  monitor: Monitor,
  gamepad: Gamepad2,
  image: ImageIcon,
  gift: Gift,
  ticket: Ticket,
  "credit-card": CreditCard,
  cpu: Cpu,
  activity: Activity,
  "shield-check": ShieldCheck,
  wallet: Wallet,
  "message-circle": MessageCircle,
  "messages-square": MessagesSquare,
  star: Star,
  "bar-chart-3": BarChart3,
  "line-chart": LineChart,
  rocket: Rocket,
  bell: Bell,
  package: Package,
  "file-text": FileText,
  settings: Settings,
  "shield-user": ShieldUser,
  "share-2": Share2,
  heart: Heart,
  bug: Bug,
  sesi: MonitorSmartphone,
  sticker: Sticker,
  trash: Trash2,
  smartphone: Smartphone,
  "shield-alert": ShieldAlert,
  tool: Wrench,
  database: Database,
  "bell-ring": BellRing,
  "scroll-text": ScrollText,
  terminal: Terminal,
  "receipt-text": ReceiptText,
  "message-square-text": MessageSquareText,
  "arrow-left-right": ArrowLeftRight,
  "sliders-horizontal": SlidersHorizontal,
  "upload-cloud": UploadCloud,
  "heart-pulse": HeartPulse,
  "list-checks": ListChecks,
  gavel: Gavel,
  flag: Flag,
  bot: Bot,
  power: Power,
  globe: Globe,
  layers: Layers,
  "hard-drive": HardDrive,
  send: Send,
  "at-sign": AtSign,
  filter: Filter,
};

function NavBody({
  collapsed, pathname, onNavigate,
}: {
  collapsed: boolean;
  pathname: string | null;
  onNavigate?: () => void;
}) {
  return (
    <div className="flex-1 overflow-y-auto p-2 space-y-0.5">
      {MENU.map((m) => {
        const active = pathname === m.path || (m.path !== "/" && pathname?.startsWith(m.path));
        const Icon = iconMap[m.icon] || LayoutDashboard;
        return (
          <Link
            key={m.id}
            href={m.path}
            title={m.label}
            onClick={onNavigate}
            className={`group flex items-center gap-3 px-3 py-2.5 rounded-[10px] text-[13px] transition-colors border border-transparent
              ${active
                ? "bg-[#7C3AED] text-white font-semibold border-[#6D28D9]"
                : "hover:bg-[#F3F0FF] text-[#6B5A8A] hover:text-[#1E1B2E] font-medium"}`}
          >
            <Icon size={17} className={active ? "text-white" : "text-[#9A8CBF] group-hover:text-[#7C3AED]"} />
            {!collapsed && <span className="truncate tracking-tight">{m.label}</span>}
            {!collapsed && (m as any).badge && (
              <span className={`ml-auto text-[10px] px-1.5 py-0.5 rounded-full font-semibold tracking-wide border ${
                active ? "bg-white/15 border-white/25 text-white" : "bg-[#F3F0FF] border-[#E9E3F5] text-[#7C3AED]"
              }`}>{(m as any).badge}</span>
            )}
          </Link>
        );
      })}
    </div>
  );
}

export default function Sidebar() {
  const pathname = usePathname();
  const router = useRouter();
  const [collapsed, setCollapsed] = useState(false);
  const [mobileOpen, setMobileOpen] = useState(false);
  const [sesiAktif, setSesiAktif] = useState(false);

  useEffect(() => {
    const k = typeof window !== "undefined" ? sessionStorage.getItem("xy_admin_key") || "" : "";
    setSesiAktif(Boolean(k));
  }, [pathname]);

  useEffect(() => {
    setMobileOpen(false);
  }, [pathname]);

  if (pathname === "/login") return null;

  const keluar = () => { clearAdminKey(); router.push("/login"); };

  const brand = (compact: boolean) => (
    <div className={`h-[56px] flex items-center px-3 gap-2 border-b border-[#E9E3F5] bg-[#7C3AED] ${compact ? "justify-center" : ""}`}>
      {compact ? (
        <img src="/brand/logo-icon.png" alt="XyCloud" className="w-9 h-9 object-contain" />
      ) : (
        <img src="/brand/logo-full.png" alt="XyCloudStore" className="h-8 w-auto object-contain" />
      )}
      {!compact && (
        <button
          type="button"
          onClick={() => setCollapsed((v) => !v)}
          className="ml-auto w-8 h-8 rounded-[8px] bg-white/10 hover:bg-white/20 grid place-items-center border border-white/20 shrink-0 hidden md:grid"
          aria-label="Ciutkan menu"
        >
          <ChevronsLeft size={15} className="text-white" />
        </button>
      )}
    </div>
  );

  const foot = (compact: boolean) => (
    <div className="p-3 border-t border-[#E9E3F5] space-y-2 bg-[#F5F3FF]/70">
      {!compact && (
        <div className="bg-white border border-[#E9E3F5] rounded-[12px] p-3">
          <div className="text-[11px] text-[#7C738F] font-semibold tracking-wide uppercase">Admin</div>
          <div className="text-[12px] text-[#1E1B2E] font-medium mt-1">{sesiAktif ? "Sesi aktif di tab ini" : "—"}</div>
          <button
            type="button"
            onClick={keluar}
            className="mt-2 w-full h-9 rounded-[10px] bg-white hover:bg-[#F3F0FF] text-[#6B5A8A] hover:text-[#7C3AED] text-[12px] font-semibold flex items-center justify-center gap-1.5 border border-[#E9E3F5]"
          >
            <LogOut size={13} /> Keluar
          </button>
        </div>
      )}
      {compact && (
        <button
          type="button"
          onClick={keluar}
          title="Keluar"
          className="mx-auto w-9 h-9 rounded-[10px] bg-white hover:bg-[#F3F0FF] text-[#6B5A8A] hover:text-[#DC2626] grid place-items-center border border-[#E9E3F5]"
        >
          <LogOut size={15} />
        </button>
      )}
    </div>
  );

  return (
    <>
      {/* Mobile top bar */}
      <div className="md:hidden fixed top-0 inset-x-0 z-30 h-14 flex items-center gap-3 px-3 bg-white border-b border-[#E9E3F5]">
        <button
          type="button"
          aria-label="Buka menu"
          onClick={() => setMobileOpen(true)}
          className="w-10 h-10 rounded-[10px] border border-[#E9E3F5] grid place-items-center text-[#7C3AED] bg-white"
        >
          <Menu size={18} />
        </button>
        <img src="/brand/logo-full.png" alt="XyCloud" className="h-7 w-auto object-contain" />
        <div className="ml-auto text-[11px] font-semibold text-[#7C738F]">Admin</div>
      </div>

      {/* Mobile drawer */}
      {mobileOpen && (
        <div className="md:hidden fixed inset-0 z-40 flex">
          <button type="button" aria-label="Tutup" className="absolute inset-0 bg-[#100030]/40" onClick={() => setMobileOpen(false)} />
          <aside className="relative z-10 w-[min(86vw,300px)] h-full bg-white border-r border-[#E9E3F5] flex flex-col shadow-xl">
            <div className="h-14 flex items-center px-3 gap-2 border-b border-[#E9E3F5] bg-[#7C3AED]">
              <img src="/brand/logo-full.png" alt="XyCloudStore" className="h-8 w-auto object-contain" />
              <button
                type="button"
                aria-label="Tutup menu"
                onClick={() => setMobileOpen(false)}
                className="ml-auto w-8 h-8 rounded-[8px] bg-white/10 border border-white/20 grid place-items-center"
              >
                <X size={16} className="text-white" />
              </button>
            </div>
            <div className="px-4 py-2 border-b border-[#E9E3F5] bg-[#F5F3FF] text-[11px] text-[#7C738F] font-medium">
              v3.3 · {MENU.length} menu
            </div>
            <NavBody collapsed={false} pathname={pathname} onNavigate={() => setMobileOpen(false)} />
            {foot(false)}
          </aside>
        </div>
      )}

      {/* Desktop sidebar */}
      <aside
        className={`${collapsed ? "w-[72px]" : "w-[260px]"} shrink-0 transition-all duration-200 hidden md:flex flex-col h-screen sticky top-0 bg-white border-r border-[#E9E3F5] font-[var(--font-inter)] relative`}
      >
        {brand(collapsed)}
        {collapsed && (
          <button
            type="button"
            onClick={() => setCollapsed(false)}
            className="absolute left-[62px] top-[12px] w-6 h-6 rounded-full bg-white border border-[#E9E3F5] grid place-items-center z-10"
            aria-label="Bentangkan menu"
          >
            <ChevronsRight size={13} className="text-[#7C3AED]" />
          </button>
        )}
        {!collapsed && (
          <div className="px-4 py-2 border-b border-[#E9E3F5]/60 bg-[#F5F3FF]">
            <div className="text-[11px] text-[#7C738F] font-medium">v3.3 · {MENU.length} menu</div>
          </div>
        )}
        <NavBody collapsed={collapsed} pathname={pathname} />
        {foot(collapsed)}
      </aside>
    </>
  );
}
