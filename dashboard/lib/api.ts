export type AdminFetchOpts = {
  adminKey?: string;
  method?: string;
  body?: any;
  headers?: Record<string,string>;
};

export const API_BASE = process.env.NEXT_PUBLIC_API_BASE || "https://api.xycloud.my.id";
const BASE = API_BASE;

export async function adminFetch(path: string, opts: AdminFetchOpts = {}) {
  const key = opts.adminKey || (typeof window !== "undefined" ? sessionStorage.getItem("xy_admin_key") || "" : "");
  const headers: Record<string,string> = {
    "Content-Type": "application/json",
    ...(opts.headers || {}),
  };
  if (key) headers["x-admin-key"] = key;
  if (typeof window !== "undefined") {
    const did = localStorage.getItem("xy_device_id");
    if (did) headers["x-xy-device"] = did;
  }
  let res: Response;
  try {
    res = await fetch(`${BASE}${path}`, {
      method: opts.method || "GET",
      headers,
      body: opts.body ? JSON.stringify(opts.body) : undefined,
      cache: "no-store",
      credentials: "omit",
      referrerPolicy: "no-referrer",
    });
  } catch (e:any) {
    // NetworkError handling — give clear message
    throw new Error("NetworkError: tidak bisa terhubung ke " + BASE + " — cek koneksi, CORS, atau adblock. Detail: " + (e?.message || "fetch gagal"));
  }
  const text = await res.text();
  let data: any;
  try { data = JSON.parse(text); } catch { data = { raw: text }; }
  if (!res.ok) {
    const msg = data?.error || data?.message || `HTTP ${res.status}`;
    // if 403, key salah
    throw new Error(msg);
  }
  return data?.data !== undefined ? data.data : data;
}

// client side helpers
export function getAdminKey(): string {
  if (typeof window === "undefined") return "";
  return sessionStorage.getItem("xy_admin_key") || "";
}
export function setAdminKey(k: string) {
  if (typeof window !== "undefined") {
    // Secret hidup hanya selama tab/sesi browser ini, bukan tersimpan permanen.
    sessionStorage.setItem("xy_admin_key", k);
    localStorage.removeItem("xy_admin_key");
    localStorage.removeItem("xy_admin_ok");
  }
}
export function clearAdminKey() {
  if (typeof window !== "undefined") {
    sessionStorage.removeItem("xy_admin_key");
    localStorage.removeItem("xy_admin_key");
    localStorage.removeItem("xy_admin_ok");
  }
}

export async function loginAdmin(key: string) {
  // use /api/admin/stats which always exists and checks admin key
  return adminFetch("/api/admin/stats", { adminKey: key });
}
