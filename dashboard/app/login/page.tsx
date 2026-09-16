"use client";
import { useState } from "react";
import { useRouter } from "next/navigation";
import { ShieldCheck, Eye, EyeOff, LogIn, ExternalLink } from "lucide-react";
import { loginAdmin, setAdminKey } from "@/lib/api";

export default function LoginPage() {
  const [key, setKey] = useState("");
  const [show, setShow] = useState(false);
  const [loading, setLoading] = useState(false);
  const [err, setErr] = useState("");
  const router = useRouter();

  async function handleLogin() {
    const k = key.trim();
    if (!k) { setErr("Admin key wajib diisi"); return; }
    setLoading(true); setErr("");
    try {
      await loginAdmin(k);
      setAdminKey(k);
      router.push("/");
    } catch (e: any) {
      setErr(e.message || "Gagal masuk");
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="min-h-screen flex items-center justify-center p-6 bg-[#F5F3FF]"
      style={{ backgroundImage: "radial-gradient(900px 500px at 50% -10%, #E9DFFB 0%, #F5F3FF 60%)" }}>
      <div className="w-full max-w-[430px]">
        <div className="bg-white border border-[#E9E3F5] rounded-[24px] p-7 shadow-[0_24px_60px_rgba(16,0,48,0.12)]">
          <div className="flex items-center gap-3 mb-6">
            <div className="w-16 h-16 rounded-2xl bg-gradient-to-br from-[#7C3AED] to-[#5B21B6] grid place-items-center shrink-0 shadow-[0_10px_20px_rgba(124,58,237,0.3)]">
              <img src="/brand/logo-icon.png" alt="XyCloud" className="w-11 h-11 object-contain" />
            </div>
            <div>
              <div className="font-semibold text-[#1E1B2E] text-[18px] tracking-tight leading-tight">XyCloud Admin</div>
              <div className="text-[11px] text-[#7C738F] font-semibold tracking-wide mt-0.5">ADMIN.XYCLOUD.MY.ID • CONSOLE</div>
            </div>
          </div>

          <h1 className="text-[20px] font-semibold text-[#1E1B2E] tracking-tight">Masuk Dashboard</h1>
          <p className="text-[13px] text-[#7C738F] font-medium leading-[1.5] mt-1.5">Masukkan Admin Key. Key hanya disimpan selama tab browser ini terbuka dan tidak dimasukkan ke URL.</p>

          <div className="mt-5 space-y-4">
            <div>
              <label className="block text-[11px] font-semibold tracking-wide uppercase text-[#7C738F] mb-2">Admin Key</label>
              <div className="relative">
                <input
                  type={show ? "text" : "password"}
                  value={key}
                  onChange={e => setKey(e.target.value)}
                  onKeyDown={e => { if (e.key === 'Enter') handleLogin(); }}
                  placeholder="xya_xxx atau key utama"
                  className="xy-input w-full pr-10"
                />
                <button type="button" onClick={() => setShow(!show)} className="absolute right-2 top-1/2 -translate-y-1/2 w-8 h-8 grid place-items-center rounded-lg bg-[#F3F0FF] hover:bg-[#E9E3F5]">
                  {show ? <EyeOff size={16} className="text-[#7C738F]" /> : <Eye size={16} className="text-[#7C738F]" />}
                </button>
              </div>
            </div>

            {err && (
              <div className="p-3 rounded-xl bg-[#FFF1F2] border border-[#FECDD3] text-[#BE123C] text-[12px] font-semibold leading-[1.4]">{err}</div>
            )}

            <button onClick={handleLogin} disabled={loading} className="xy-btn w-full h-[46px] flex items-center justify-center gap-2 text-[14px] disabled:opacity-60">
              {loading ? "Memeriksa..." : <><LogIn size={16} /> Masuk</>}
            </button>

            <div className="h-px bg-[#E9E3F5] my-1" />

            <div className="space-y-2">
              <div className="text-[11px] font-semibold uppercase tracking-wide text-[#7C738F]">Tautan Cepat</div>
              <a href="https://www.xycloud.my.id" className="flex items-center gap-3 p-3 rounded-[16px] border border-[#E9E3F5] bg-[#F5F3FF] hover:border-[#7C3AED] hover:bg-[#F3F0FF] transition-colors">
                <div className="w-9 h-9 rounded-xl bg-white border border-[#E9E3F5] grid place-items-center"><ExternalLink size={16} className="text-[#7C3AED]" /></div>
                <div className="flex-1"><div className="text-[13px] font-semibold text-[#1E1B2E]">www.xycloud.my.id</div><div className="text-[11px] text-[#7C738F]">Situs utama</div></div>
              </a>
              <a href="https://api.xycloud.my.id/admin?legacy=1" className="flex items-center gap-3 p-3 rounded-[16px] border border-[#E9E3F5] bg-[#F5F3FF] hover:border-[#7C3AED] hover:bg-[#F3F0FF] transition-colors">
                <div className="w-9 h-9 rounded-xl bg-white border border-[#E9E3F5] grid place-items-center"><ShieldCheck size={16} className="text-[#7C3AED]" /></div>
                <div className="flex-1"><div className="text-[13px] font-semibold text-[#1E1B2E]">Console Lama (Legacy)</div><div className="text-[11px] text-[#7C738F]">Fallback darurat</div></div>
              </a>
            </div>

            <div className="text-center text-[11px] text-[#7C738F] font-medium pt-2">
              Tema terang ala xycloud.my.id • Plus Jakarta Sans • Lucide • No Emoji
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
