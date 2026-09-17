"use client";
import { useEffect, useMemo, useRef, useState } from "react";
import { adminFetch, API_BASE } from "@/lib/api";
import { CheckCheck, Loader2, MessageCircle, Search, Send } from "lucide-react";
import { ErrBox, jam, Load } from "@/components/ui/kit";
import VoiceNote from "@/components/ui/voice-note";

const BALASAN_CEPAT = [
  "Halo, terima kasih sudah menghubungi XyCloudStore. Ada yang bisa dibantu?",
  "Untuk top up saldo, pilih menu Isi Saldo di aplikasi, lalu kirim bukti transfer. Tim kami cek maksimal beberapa menit.",
  "Refund sewa yang gagal otomatis dikembalikan ke saldo. Kalau belum masuk, kirim ID pesanan ya.",
  "Tiket CS kamu sedang kami proses. Mohon tunggu sebentar ya.",
  "Bisa infokan ID pesanan atau email terdaftar supaya kami cek lebih cepat?",
];

export default function CsPage() {
  const [rooms, setRooms] = useState<any[]>([]);
  const [aktif, setAktif] = useState<string | null>(null);
  const [pesan, setPesan] = useState<any[]>([]);
  const [loadingRoom, setLoadingRoom] = useState(true);
  const [err, setErr] = useState("");
  const [q, setQ] = useState("");
  const [teks, setTeks] = useState("");
  const [kirimBusy, setKirimBusy] = useState(false);
  const bawahRef = useRef<HTMLDivElement>(null);
  const aktifRef = useRef<string | null>(null);
  const wsRef = useRef<WebSocket | null>(null);
  const typingRef = useRef({ room: "", at: 0 });
  const [sekarang, setSekarang] = useState(Date.now());
  const [realtime, setRealtime] = useState<"menghubungkan" | "online" | "offline">("menghubungkan");

  const ruangAktif = useMemo(() => rooms.find((r) => r.room === aktif) || null, [rooms, aktif]);

  async function muatRooms() {
    try {
      const d = await adminFetch("/api/admin/cs");
      setRooms(Array.isArray(d) ? d : []);
      // otomatis pilih room terbaru saat pertama kali
      setAktif((prev) => {
        if (prev && Array.isArray(d) && d.some((r: any) => r.room === prev)) return prev;
        return Array.isArray(d) && d.length ? d[0].room : null;
      });
    } catch (e: any) { setErr(e.message); }
  }

  async function buka(room: string) {
    setAktif(room);
  }

  useEffect(() => {
    aktifRef.current = aktif;
  }, [aktif]);

  // Dashboard menukar admin key dengan ticket WebSocket 60 detik. Secret admin
  // tidak pernah masuk URL; polling 30 detik di bawah hanya menjadi fallback.
  useEffect(() => {
    let selesai = false;
    let timer: ReturnType<typeof setTimeout> | null = null;
    let jeda = 1000;

    const jadwalkan = () => {
      if (selesai || timer) return;
      setRealtime("offline");
      timer = setTimeout(() => {
        timer = null;
        void sambung();
      }, jeda);
      jeda = Math.min(30_000, jeda * 2);
    };

    const sambung = async () => {
      if (selesai || wsRef.current) return;
      setRealtime("menghubungkan");
      try {
        const t = await adminFetch("/api/admin/ws-ticket", {
          method: "POST", body: { room: "cs:inbox" },
        });
        if (selesai) return;
        if (!t?.ticket) throw new Error("Ticket realtime tidak tersedia");
        const wsBase = API_BASE.replace(/^https:/, "wss:").replace(/^http:/, "ws:").replace(/\/+$/, "");
        const ws = new WebSocket(`${wsBase}/ws/${encodeURIComponent("cs:inbox")}?ticket=${encodeURIComponent(t.ticket)}`);
        wsRef.current = ws;
        ws.onopen = () => { jeda = 1000; setRealtime("online"); };
        ws.onmessage = (event) => {
          try {
            const data = JSON.parse(String(event.data || "{}"));
            if (data.type !== "chat.message" || !data.payload?.id) return;
            const m = data.payload;
            if (m.room === aktifRef.current) {
              setPesan((lama) => lama.some((x) => x.id === m.id) ? lama : [...lama, m]);
              setSekarang(Date.now());
            }
            void muatRooms();
          } catch { /* frame asing tidak mengganggu fallback polling */ }
        };
        ws.onerror = () => ws.close();
        ws.onclose = () => {
          if (wsRef.current === ws) wsRef.current = null;
          jadwalkan();
        };
      } catch {
        wsRef.current = null;
        jadwalkan();
      }
    };

    void sambung();
    return () => {
      selesai = true;
      if (timer) clearTimeout(timer);
      const ws = wsRef.current;
      wsRef.current = null;
      ws?.close();
    };
    // Ticket dan adminFetch membaca key sesi terbaru saat setiap reconnect.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    muatRooms();
    const t = setInterval(() => {
      muatRooms();
      if (aktif) {
        adminFetch("/api/admin/cs/room/" + encodeURIComponent(aktif))
          .then((d) => { if (Array.isArray(d)) { setPesan(d); setSekarang(Date.now()); } })
          .catch(() => {});
      }
    }, 30000);
    return () => clearInterval(t);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [aktif]);

  useEffect(() => {
    if (!aktif) return;
    setLoadingRoom(true); setErr("");
    adminFetch("/api/admin/cs/room/" + encodeURIComponent(aktif))
      .then((d) => setPesan(Array.isArray(d) ? d : []))
      .catch((e) => setErr(e.message))
      .finally(() => setLoadingRoom(false));
  }, [aktif]);

  useEffect(() => {
    bawahRef.current?.scrollIntoView({ behavior: "smooth", block: "end" });
  }, [pesan.length, loadingRoom, sekarang]);

  async function kirim(isi?: string) {
    const txt = (isi ?? teks).trim();
    if (!txt || !aktif || kirimBusy) return;
    setKirimBusy(true); setErr("");
    try {
      const m = await adminFetch("/api/admin/cs/reply", { method: "POST", body: { room: aktif, teks: txt } });
      setTeks("");
      void kirimTyping(false);
      setPesan((p) => p.some((x) => x.id === m.id) ? p : [...p, m]);
      setSekarang(Date.now());
    } catch (e: any) { setErr(e.message); }
    finally { setKirimBusy(false); }
  }

  async function kirimTyping(on: boolean) {
    if (!aktif) return;
    const now = Date.now();
    // Satu indikator per 1,5 detik cukup; status berhenti tetap dikirim segera.
    if (on && typingRef.current.room === aktif && now - typingRef.current.at < 1500) return;
    typingRef.current = { room: aktif, at: now };
    try {
      await adminFetch("/api/admin/cs/typing", {
        method: "POST", body: { room: aktif, typing: on },
      });
    } catch { /* indikator typing tidak boleh menggagalkan chat */ }
  }

  const daftarRoom = rooms.filter((r) => !q || ((r.nama || "") + " " + (r.email || "") + " " + (r.room || "")).toLowerCase().includes(q.toLowerCase()));
  const totalPesan = rooms.reduce((a, r) => a + Number(r.total || 0), 0);

  return (
    <div className="space-y-3 font-[var(--font-inter)]">
      <div className="flex items-start justify-between flex-wrap gap-2">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-[#7C3AED] to-[#5B21B6] grid place-items-center shadow-[0_8px_18px_rgba(124,58,237,.25)]">
            <MessageCircle size={18} className="text-white" />
          </div>
          <div>
            <h1 className="text-xl font-semibold text-[#1E1B2E] tracking-tight">CS Realtime</h1>
            <p className="text-sm text-[#7C738F] font-medium">Balas chat pengguna langsung • fallback sinkron 30 detik</p>
          </div>
        </div>
        <div className="flex gap-2">
          <span className={`text-xs px-3 py-1.5 rounded-full border font-semibold ${realtime === "online" ? "bg-emerald-500/15 border-emerald-500/25 text-emerald-700" : realtime === "menghubungkan" ? "bg-amber-500/15 border-amber-500/25 text-amber-700" : "bg-red-500/10 border-red-500/20 text-red-700"}`}>
            Realtime {realtime}
          </span>
          <span className="text-xs px-3 py-1.5 rounded-full bg-violet-500/15 border border-violet-500/25 text-violet-700 font-semibold">{rooms.length} room</span>
          <span className="text-xs px-3 py-1.5 rounded-full bg-[#F3F0FF] border border-[#E9E3F5] font-medium">{totalPesan} pesan</span>
        </div>
      </div>
      {err && <ErrBox msg={err} />}

      <div className="grid md:grid-cols-[300px_1fr] gap-3 h-[calc(100vh-170px)] min-h-[480px]">
        {/* ===== panel kiri: daftar room ===== */}
        <div className="xy-card rounded-[20px] flex flex-col overflow-hidden">
          <div className="p-3 border-b border-[#E9E3F5]">
            <div className="relative">
              <Search size={13} className="absolute left-3 top-1/2 -translate-y-1/2 text-[#9A8CBF]" />
              <input value={q} onChange={(e) => setQ(e.target.value)} placeholder="Cari percakapan…" className="w-full pl-8 pr-3 py-2 rounded-xl bg-[#F5F3FF] border border-transparent focus:border-[#C4B5FD] focus:bg-white text-[12px] outline-none" />
            </div>
          </div>
          <div className="flex-1 overflow-y-auto p-2 space-y-1.5">
            {daftarRoom.length === 0 ? (
              <div className="p-6 text-center text-[12px] text-[#7C738F] font-medium">Belum ada percakapan.<br />Room muncul saat pengguna membuka chat dukungan.</div>
            ) : daftarRoom.map((r) => {
              const isAktif = aktif === r.room;
              const tS = String(r.terakhir || "");
              const menit = (Date.now() - new Date(/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}/.test(tS) ? tS.replace(" ", "T") + "Z" : tS).getTime()) / 60000;
              return (
                <button key={r.room} onClick={() => buka(r.room)}
                  className={`w-full text-left rounded-[14px] px-3 py-2.5 transition-all border ${isAktif ? "bg-gradient-to-r from-[#7C3AED] to-[#6D28D9] text-white border-transparent shadow-[0_8px_16px_rgba(124,58,237,.22)]" : "hover:bg-[#F5F3FF] border-transparent"}`}>
                  <div className="flex items-center gap-2">
                    <div className={`w-8 h-8 shrink-0 rounded-full grid place-items-center text-[12px] font-semibold ${isAktif ? "bg-white/20 text-white" : "bg-[#F3F0FF] text-[#7C3AED]"}`}>
                      {(r.nama || r.email || "?")[0].toUpperCase()}
                    </div>
                    <div className="min-w-0 flex-1">
                      <div className={`flex items-center justify-between gap-1`}>
                        <span className={`truncate text-[12.5px] font-semibold ${isAktif ? "text-white" : "text-[#1E1B2E]"}`}>{r.nama || r.email || r.room}</span>
                        {menit < 60 && <span className={`text-[9px] px-1.5 rounded-full font-semibold ${isAktif ? "bg-white/25 text-white" : "bg-emerald-500/15 text-emerald-600"}`}>{Math.max(1, Math.round(menit))}m</span>}
                      </div>
                      <div className={`truncate text-[11px] mt-0.5 ${isAktif ? "text-white/75" : "text-[#7C738F]"}`}>{r.preview || "Belum ada pesan teks"}</div>
                    </div>
                  </div>
                </button>
              );
            })}
          </div>
          <div className="px-3 py-2 border-t border-[#E9E3F5] bg-[#F5F3FF]/60 text-[10.5px] text-[#7C738F] font-medium">Log 7 hari terakhir • {rooms.length} room</div>
        </div>

        {/* ===== panel kanan: thread ===== */}
        <div className="xy-card rounded-[20px] flex flex-col overflow-hidden">
          {!aktif ? (
            <div className="flex-1 grid place-items-center p-10 text-center">
              <div>
                <MessageCircle size={28} className="mx-auto text-[#C4B5FD]" />
                <p className="mt-3 text-[#7C738F] font-semibold text-sm">Pilih percakapan di kiri</p>
                <p className="text-[11.5px] text-[#9A8CBF]">Room akan muncul saat ada pengguna membuka chat dukungan.</p>
              </div>
            </div>
          ) : (
            <>
              {/* header room */}
              <div className="px-4 py-3 border-b border-[#E9E3F5] bg-[#F5F3FF]/70 flex items-center gap-3">
                <div className="w-9 h-9 rounded-full bg-gradient-to-br from-[#7C3AED] to-[#5B21B6] grid place-items-center text-white font-semibold text-[13px]">{(ruangAktif?.nama || ruangAktif?.email || "?")[0].toUpperCase()}</div>
                <div className="min-w-0 flex-1">
                  <div className="font-semibold text-[#1E1B2E] text-[13.5px] truncate">{ruangAktif?.nama || "Pengguna"}</div>
                  <div className="font-mono text-[10.5px] text-[#7C738F] truncate">{ruangAktif?.email || aktif} {ruangAktif?.phone ? "• " + ruangAktif.phone : ""}</div>
                </div>
                <div className="text-[11px] text-[#7C738F] font-medium text-right shrink-0">
                  <div>{ruangAktif?.total} pesan</div>
                  {ruangAktif?.terakhir && <div className="text-[10px]">terakhir {jam(ruangAktif.terakhir)}</div>}
                </div>
              </div>

              {/* pesan */}
              <div className="flex-1 overflow-y-auto px-4 py-4 space-y-3 bg-[#FBFAFF]">
                {loadingRoom ? <Load /> : pesan.length === 0 ? (
                  <div className="text-center text-[#9A8CBF] text-[12px] pt-10">Belum ada pesan di percakapan ini.</div>
                ) : pesan.map((m) => {
                  const dariCs = m.dari === "cs";
                  const tipe = m.tipe || (m.audio ? "audio" : m.gambar ? "gambar" : "teks");
                  const labelTipe = tipe === "gambar" ? "Foto" : tipe === "audio" ? "Pesan suara" : "Pesan";
                  return (
                    <div key={m.id} className={`flex ${dariCs ? "justify-end" : "justify-start"}`}>
                      <div className={`max-w-[82%] min-w-[120px] ${tipe !== "gambar" ? "rounded-[18px] px-3.5 py-2.5" : "rounded-[14px] overflow-hidden bg-transparent border-0"} text-[13px] leading-relaxed shadow-sm whitespace-pre-line ${dariCs ? "bg-gradient-to-br from-[#7C3AED] to-[#6D28D9] text-white rounded-br-md" : "bg-white border border-[#E9E3F5] text-[#1E1B2E] rounded-bl-md"}`}>
                        {(m.reply_teks || m.reply_to) && (
                          <div className={`mb-1.5 rounded-lg px-2 py-1 border-l-[3px] ${dariCs ? "bg-white/15 border-white/70" : "bg-[#F5F3FF] border-[#7C3AED]"}`}>
                            <div className={`text-[10px] font-semibold ${dariCs ? "text-white/85" : "text-[#7C3AED]"}`}>
                              {labelTipe} · {dariCs ? "balasan kamu" : "balasan CS"}
                            </div>
                            {m.reply_teks && <div className={`text-[11px] truncate ${dariCs ? "text-white/80" : "text-[#7C738F]"}`}>{m.reply_teks}</div>}
                          </div>
                        )}
                        {tipe === "audio" ? (
                          <VoiceNote
                            src={m.audio}
                            durasi={typeof m.durasi === "number" ? m.durasi : null}
                            gelap={dariCs}
                          />
                        ) : (
                          <>
                            {m.gambar && <img src={m.gambar} alt="lampiran" className={`max-h-56 object-cover ${m.teks ? "mb-1.5" : ""} ${dariCs ? "" : "rounded-lg"}`} />}
                            {m.teks && <div>{m.teks}</div>}
                          </>
                        )}
                        <div className={`flex items-center gap-1 mt-1 text-[9.5px] ${dariCs ? "text-white/70" : "text-[#9A8CBF]"}`}>
                          {jam(m.waktu)}
                          {dariCs && <CheckCheck size={11} />}
                        </div>
                      </div>
                    </div>
                  );
                })}
                <div ref={bawahRef} />
              </div>

              {/* balasan cepat */}
              <div className="px-3 pt-2 border-t border-[#E9E3F5] bg-white">
                <div className="flex gap-1.5 overflow-x-auto pb-1.5 scrollbar-thin">
                  {BALASAN_CEPAT.map((b, i) => (
                    <button key={i} onClick={() => kirim(b)} disabled={kirimBusy}
                      className="shrink-0 text-[10.5px] px-2.5 py-1 rounded-full bg-[#F3F0FF] border border-[#E9E3F5] text-[#6B5A8A] hover:border-[#C4B5FD] hover:text-[#7C3AED] font-semibold whitespace-nowrap">
                      {b.length > 34 ? b.slice(0, 34) + "…" : b}
                    </button>
                  ))}
                </div>
                <div className="flex items-center gap-2 pb-3">
                  <textarea value={teks}
                    onChange={(e) => { setTeks(e.target.value); void kirimTyping(e.target.value.trim().length > 0); }}
                    onBlur={() => { if (teks.trim()) void kirimTyping(false); }} rows={1} maxLength={5000}
                    onKeyDown={(e) => { if (e.key === "Enter" && !e.shiftKey) { e.preventDefault(); kirim(); } }}
                    placeholder="Tulis balasan sebagai Kirana - XyCloudStore…" className="flex-1 px-3.5 py-2.5 rounded-2xl bg-white border border-[#E9E3F5] focus:border-[#7C3AED] outline-none text-[13px] resize-none max-h-28" />
                  <button onClick={() => kirim()} disabled={kirimBusy || !teks.trim()}
                    className="shrink-0 w-10 h-10 rounded-full xy-btn text-white grid place-items-center disabled:opacity-40">
                    {kirimBusy ? <Loader2 size={16} className="animate-spin" /> : <Send size={15} />}
                  </button>
                </div>
              </div>
            </>
          )}
        </div>
      </div>
    </div>
  );
}
