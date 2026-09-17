
/** Token terang — kanonik sama app (XyTheme) + web + globals.css */
export const xyLight = {
  bg: "#F5F3FF",
  card: "#FFFFFF",
  soft: "#F3F0FF",
  line: "#E9E3F5",
  ink: "#1E1B2E",
  ink2: "#4B445F",
  muted: "#7C738F",
  violet: "#7C3AED",
  violet2: "#5B21B6",
  violet3: "#A855F7",
  indigo: "#2E1065",
  midnight: "#100030",
  gold: "#D9A441",
  font: "Inter, 'Plus Jakarta Sans', system-ui, sans-serif",
  weightMax: 600 as const,
};

export const xyTheme = {
  bg: "#100030",
  bg2: "#200050",
  violet: "#7C3AED",
  violet2: "#8B5CF6",
  violet3: "#A855F7",
  indigo: "#7830C0",
  card: "#1A0A3A",
  border: "rgba(124,58,237,0.22)",
  gradient: "linear-gradient(135deg,#100030 0%,#200050 35%,#2D0A5E 55%,#7C3AED 100%)",
  btn: "linear-gradient(135deg,#7C3AED 0%,#8B5CF6 45%,#A855F7 100%)",
  font: "'Plus Jakarta Sans', Inter, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif",
};

// Icon names map to lucide-react icons — NO EMOJI for cross-platform consistency
// Solid UI — no glassmorphism
export type MenuIcon =
  | "layout-dashboard"
  | "receipt"
  | "users"
  | "monitor"
  | "gamepad"
  | "image"
  | "gift"
  | "ticket"
  | "credit-card"
  | "cpu"
  | "activity"
  | "shield-check"
  | "wallet"
  | "message-circle"
  | "messages-square"
  | "star"
  | "bar-chart-3"
  | "line-chart"
  | "rocket"
  | "bell"
  | "package"
  | "file-text"
  | "settings"
  | "shield-user"
  | "share-2"
  | "heart"
  | "bug"
  | "sesi"
  | "sticker"
  | "trash"
  | "smartphone"
  | "shield-alert"
  | "tool"
  | "database"
  | "bell-ring"
  | "scroll-text"
  | "terminal"
  | "receipt-text"
  | "message-square-text"
  | "arrow-left-right"
  | "sliders-horizontal"
  | "upload-cloud"
  | "heart-pulse"
  | "list-checks"
  | "gavel"
  | "flag"
  | "bot"
  | "power"
  | "globe"
  | "layers"
  | "hard-drive"
  | "send"
  | "at-sign"
  | "filter";

export const MENU: { id: string; label: string; icon: MenuIcon; path: string; badge?: string }[] = [
  { id: "dash", label: "Dashboard", icon: "layout-dashboard", path: "/" },
  { id: "orders", label: "Pesanan", icon: "receipt", path: "/orders" },
  { id: "users", label: "Pengguna", icon: "users", path: "/users" },
  { id: "plans", label: "Paket PC", icon: "monitor", path: "/plans" },
  { id: "produk", label: "Produk Akun", icon: "gamepad", path: "/produk" },
  { id: "banners", label: "Banner", icon: "image", path: "/banners" },
  { id: "promosi", label: "Promosi", icon: "gift", path: "/promosi" },
  { id: "stiker", label: "Stiker & GIPHY", icon: "sticker", path: "/stiker" },
  { id: "voucher", label: "Voucher", icon: "ticket", path: "/voucher" },
  { id: "topup", label: "TopUp", icon: "credit-card", path: "/topup" },
  { id: "unit", label: "Unit PC", icon: "cpu", path: "/unit" },
  { id: "sesi", label: "Sesi PC", icon: "sesi", path: "/sesi", badge: "BARU" },
  { id: "live", label: "Live Monitor", icon: "activity", path: "/live" },
  { id: "livestream", label: "XyCloud Live", icon: "activity", path: "/livestream", badge: "BARU" },
  { id: "security", label: "Security", icon: "shield-check", path: "/security" },
  { id: "perangkat", label: "Perangkat", icon: "smartphone", path: "/perangkat" },
  { id: "keuangan", label: "Keuangan", icon: "wallet", path: "/keuangan" },
  { id: "cs", label: "CS Realtime", icon: "message-circle", path: "/cs" },
  { id: "forum", label: "Forum", icon: "messages-square", path: "/forum" },
  { id: "moderasi", label: "Moderasi", icon: "shield-alert", path: "/moderasi" },
  { id: "ulasan", label: "Ulasan", icon: "star", path: "/ulasan" },
  { id: "statistik", label: "Statistik", icon: "bar-chart-3", path: "/statistik" },
  { id: "analitik", label: "Analitik", icon: "line-chart", path: "/analitik" },
  { id: "referral", label: "Referral", icon: "share-2", path: "/referral" },
  { id: "favorit", label: "Favorit", icon: "heart", path: "/favorit" },
  { id: "galat", label: "Galat App", icon: "bug", path: "/galat" },
  { id: "rilis", label: "Rilis App", icon: "rocket", path: "/rilis" },
  { id: "push", label: "Push Notif", icon: "bell", path: "/push" },
  { id: "alat", label: "Email & Push", icon: "tool", path: "/alat" },
  { id: "media", label: "Media", icon: "package", path: "/media" },
  { id: "audit", label: "Audit Log", icon: "file-text", path: "/audit" },
  { id: "sampah", label: "Sampah User", icon: "trash", path: "/sampah" },
  { id: "cadangan", label: "Cadangan DB", icon: "database", path: "/cadangan" },
  { id: "sistem", label: "Sistem", icon: "settings", path: "/sistem" },
  { id: "peran", label: "Peran Admin", icon: "shield-user", path: "/peran" },
  { id: "notifikasi", label: "Notifikasi", icon: "bell-ring", path: "/notifikasi" },
  { id: "log-sistem", label: "Log Sistem", icon: "scroll-text", path: "/log-sistem" },
  { id: "perintah", label: "Perintah Agen", icon: "terminal", path: "/perintah" },
  { id: "voucher-pakai", label: "Voucher Terpakai", icon: "receipt-text", path: "/voucher-pakai" },
  { id: "ulasan-pc", label: "Ulasan Paket PC", icon: "message-square-text", path: "/ulasan-pc" },
  { id: "transaksi", label: "Riwayat Transaksi", icon: "arrow-left-right", path: "/transaksi" },
  { id: "setelan", label: "Setelan Umum", icon: "sliders-horizontal", path: "/setelan" },
  { id: "impor-cadangan", label: "Impor Cadangan", icon: "upload-cloud", path: "/impor-cadangan" },
  { id: "kesehatan", label: "Kesehatan & Cache", icon: "heart-pulse", path: "/kesehatan" },
  { id: "keamanan", label: "Log Keamanan", icon: "list-checks", path: "/keamanan" },
  // ---- Batch E: 10 menu baru yang berfungsi penuh ----
  { id: "banding", label: "Banding Akun", icon: "gavel", path: "/banding" },
  { id: "laporan", label: "Laporan Pengguna", icon: "flag", path: "/laporan" },
  { id: "agen", label: "Agen Windows", icon: "bot", path: "/agen" },
  { id: "pemeliharaan", label: "Mode Pemeliharaan", icon: "power", path: "/pemeliharaan" },
  { id: "seo", label: "SEO & Situs", icon: "globe", path: "/seo" },
  { id: "stok", label: "Stok Akun", icon: "layers", path: "/stok" },
  { id: "db", label: "Database", icon: "hard-drive", path: "/db" },
  { id: "push-stat", label: "Statistik Push", icon: "send", path: "/push-stat" },
  { id: "username", label: "Username", icon: "at-sign", path: "/username" },
  { id: "kata", label: "Kata Terlarang", icon: "filter", path: "/kata" },
] as const;
