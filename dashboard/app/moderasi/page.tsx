"use client";
import { useEffect, useState } from "react";
import { adminFetch } from "@/lib/api";
import {
  BrainCircuit, CheckCheck, Database, Flag, Gavel, Inbox, RefreshCw, ShieldCheck,
  Trash2, Wifi, XCircle,
} from "lucide-react";
import {
  Btn, Chip, EmptyBox, ErrBox, Header, jam, Load, MsgOk, toneStatus, useAdminList,
} from "@/components/ui/kit";
import { konfirm, mintaTeks } from "@/components/ui/dialog";

export default function ModerasiPage() {
  const [tab, setTab] = useState<"laporan" | "banding" | "ai">("laporan");
  return (
    <div className="space-y-4 font-[var(--font-inter)]">
      <Header
        icon={Flag}
        title="Moderasi"
        sub="Laporan konten forum / spam / sensitif, serta banding pengguna yang dibekukan"
        right={
          <div className="flex rounded-full border border-[#E9E3F5] bg-white p-1">
            {([["laporan", "Laporan", Flag], ["banding", "Banding", Gavel], ["ai", "AI Safety", BrainCircuit]] as const).map(([k, label, Icon]) => (
              <button
                key={k}
                onClick={() => setTab(k)}
                className={`inline-flex items-center gap-1.5 px-3.5 py-1.5 rounded-full text-[12px] font-semibold transition ${
                  tab === k ? "bg-[#6D5AE0] text-white shadow-sm" : "text-[#6B5A8A] hover:bg-[#F5F3FF]"
                }`}
              >
                <Icon size={12} /> {label}
              </button>
            ))}
          </div>
        }
      />
      {tab === "laporan" ? <TabLaporan /> : tab === "banding" ? <TabBanding /> : <TabAi />}
    </div>
  );
}

// ---------------------------------------------------------------------------
//  Tab laporan konten (perilaku lama)
// ---------------------------------------------------------------------------
function TabLaporan() {
  const { rows, loading, err, setErr, reload } = useAdminList("/api/admin/laporan");
  const [ok, setOk] = useState("");
  const [busy, setBusy] = useState(false);

  async function selesai(id: string) {
    setBusy(true); setErr(""); setOk("");
    try {
      await adminFetch(`/api/admin/laporan/${id}`, { method: "PATCH", body: { status: "selesai" } });
      setOk("Laporan ditutup");
      await reload();
    } catch (e: any) { setErr(e.message); }
    finally { setBusy(false); }
  }

  async function hapusKonten(l: any) {
    if (!await konfirm({ pesan: "Hapus konten terkait laporan ini? Permanen.", bahaya: true })) return;
    setBusy(true); setErr(""); setOk("");
    try {
      const jenis = String(l.jenis || l.tipe || "");
      const ref = l.ref_id || l.target_id;
      if (jenis.includes("balasan")) {
        await adminFetch(`/api/admin/forum/balasan/${ref}`, { method: "DELETE" });
      } else if (jenis.includes("forum") || jenis.includes("post")) {
        await adminFetch(`/api/admin/forum/${ref}`, { method: "DELETE" });
      } else if (l.konten_path) {
        await adminFetch(`/api/admin/konten/${l.konten_path}`, { method: "DELETE" });
      }
      await adminFetch(`/api/admin/laporan/${l.id}`, { method: "PATCH", body: { status: "selesai" } });
      setOk("Konten dihapus & laporan ditutup");
      await reload();
    } catch (e: any) { setErr(e.message); }
    finally { setBusy(false); }
  }

  const open = rows.filter((r) => !["selesai", "ditutup", "closed"].includes(String(r.status || "").toLowerCase()));

  return (
    <div className="space-y-4">
      <div className="flex gap-2">
        <span className="text-xs px-3 py-1.5 rounded-full bg-amber-500/15 border border-amber-500/30 text-amber-700 font-semibold">{open.length} terbuka</span>
        <span className="text-xs px-3 py-1.5 rounded-full bg-[#F3F0FF] border border-[#E9E3F5] font-medium">{rows.length} total</span>
      </div>
      {ok && <MsgOk msg={ok} />}
      {err && <ErrBox msg={err} />}
      {loading ? <Load /> : rows.length === 0 ? <EmptyBox msg="Belum ada laporan konten." /> : (
        <div className="space-y-3">
          {rows.map((l) => (
            <div key={l.id} className="xy-card rounded-[16px] p-4 space-y-2">
              <div className="flex flex-wrap items-start justify-between gap-2">
                <div>
                  <div className="flex items-center gap-2 flex-wrap">
                    <span className="font-semibold text-[#1E1B2E]">{l.judul || l.jenis || l.id}</span>
                    <Chip tone={toneStatus(l.status)}>{l.status || "baru"}</Chip>
                  </div>
                  <div className="text-[11px] text-[#7C738F] mt-0.5">
                    {l.pelapor || l.nama_pelapor || "anon"} · {l.jenis} · {jam(l.dibuat || l.created_at)}
                  </div>
                </div>
                <div className="flex gap-1.5">
                  <Btn tone="ok" className="!h-8" disabled={busy} onClick={() => selesai(l.id)}>
                    <CheckCheck size={12} /> Tutup
                  </Btn>
                  {(String(l.jenis || l.tipe || "").includes("balasan")
                    || String(l.jenis || l.tipe || "").includes("forum")
                    || String(l.jenis || l.tipe || "").includes("post")
                    || Boolean(l.konten_path)) && (
                    <Btn tone="bahaya" className="!h-8" disabled={busy} onClick={() => hapusKonten(l)}>
                      <Trash2 size={12} /> Hapus konten
                    </Btn>
                  )}
                </div>
              </div>
              {l.alasan && <div className="text-[12px] text-[#4B445F] bg-[#F5F3FF] border border-[#E9E3F5] rounded-xl px-3 py-2">{l.alasan}</div>}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

// ---------------------------------------------------------------------------
//  Tab banding pengguna yang dibekukan
// ---------------------------------------------------------------------------
function TabBanding() {
  const [status, setStatus] = useState("baru");
  const { rows, loading, err, setErr, reload } = useAdminList(
    `/api/admin/moderasi/banding${status ? `?status=${status}` : ""}`, [status]);
  const [busy, setBusy] = useState<string | null>(null);
  const [ok, setOk] = useState("");

  async function tanggapi(b: any, terima: boolean) {
    const t = await mintaTeks({
      judul: terima ? "Terima banding" : "Tolak banding",
      pesan: terima
        ? `Akun ${b.nama || b.email || b.user_id} akan AKTIF kembali. Tuliskan catatan untuk pengguna (opsional):`
        : `Tuliskan alasan penolakan untuk ${b.nama || b.email || b.user_id} (opsional):`,
      okLabel: terima ? "Terima & aktifkan" : "Tolak",
      bahaya: !terima,
      placeholder: "Catatan untuk pengguna…",
    });
    if (t === null) return;
    setBusy(b.id); setErr(""); setOk("");
    try {
      await adminFetch(`/api/admin/moderasi/banding/${b.id}`, {
        method: "POST",
        body: { status: terima ? "diterima" : "ditolak", tanggapan: t || "" },
      });
      setOk(terima ? "Banding diterima — akun aktif kembali." : "Banding ditolak.");
      await reload();
    } catch (e: any) { setErr(e.message); }
    finally { setBusy(null); }
  }

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap gap-1.5">
        {[["baru", "Baru"], ["diterima", "Diterima"], ["ditolak", "Ditolak"], ["", "Semua"]].map(([v, label]) => (
          <button
            key={v || "semua"}
            onClick={() => setStatus(v)}
            className={`px-3 py-1.5 rounded-full text-[11.5px] font-semibold border transition ${
              status === v ? "bg-[#6D5AE0] text-white border-[#6D5AE0]" : "bg-white border-[#E9E3F5] text-[#6B5A8A] hover:border-[#C4B5FD]"
            }`}
          >
            {label}
          </button>
        ))}
      </div>
      {ok && <MsgOk msg={ok} />}
      {err && <ErrBox msg={err} />}
      {loading ? <Load /> : rows.length === 0 ? (
        <EmptyBox msg="Tidak ada banding pada saringan ini." sub="Banding masuk dari layar Akun Dibekukan di aplikasi." />
      ) : (
        <div className="space-y-3">
          {rows.map((b: any) => (
            <div key={b.id} className="xy-card rounded-[16px] p-4 space-y-2">
              <div className="flex flex-wrap items-start justify-between gap-2">
                <div className="min-w-0">
                  <div className="flex items-center gap-2 flex-wrap">
                    <span className="font-semibold text-[#1E1B2E]">{b.nama || "(akun terhapus)"}</span>
                    <span className="text-[11px] text-[#7C738F] font-mono">{b.email}</span>
                    <Chip tone={b.status === "baru" ? "warn" : b.status === "diterima" ? "ok" : "bad"}>{b.status}</Chip>
                  </div>
                  <div className="text-[11px] text-[#7C738F] mt-0.5">diajukan {jam(b.waktu)}</div>
                </div>
                {b.status === "baru" && (
                  <div className="flex gap-1.5">
                    <Btn tone="ok" className="!h-8" disabled={busy === b.id} onClick={() => tanggapi(b, true)}>
                      <CheckCheck size={12} /> Terima
                    </Btn>
                    <Btn tone="bahaya" className="!h-8" disabled={busy === b.id} onClick={() => tanggapi(b, false)}>
                      <XCircle size={12} /> Tolak
                    </Btn>
                  </div>
                )}
              </div>
              <div className="text-[12.5px] text-[#332D47] bg-[#F5F3FF] border border-[#E9E3F5] rounded-xl px-3 py-2 whitespace-pre-wrap leading-relaxed">
                {b.pesan}
              </div>
              {b.tanggapan && (
                <div className="text-[11.5px] text-[#4B445F] flex items-start gap-1.5">
                  <Inbox size={12} className="mt-0.5 shrink-0" />
                  <span>Tanggapan admin: {b.tanggapan} · {jam(b.waktu_tanggapan)}</span>
                </div>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

function TabAi() {
  const [data, setData] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState("");
  const [err, setErr] = useState("");
  const [ok, setOk] = useState("");

  async function muat() {
    setLoading(true); setErr("");
    try { setData(await adminFetch("/api/admin/moderasi/ai")); }
    catch (e: any) { setErr(e.message); }
    finally { setLoading(false); }
  }
  useEffect(() => { void muat(); }, []);

  async function ubahMode(mode: "off" | "shadow" | "enforce") {
    if (!data?.boleh_mengubah || busy) return;
    setBusy(mode); setErr(""); setOk("");
    try {
      await adminFetch("/api/admin/moderasi/ai/mode", { method: "POST", body: { mode } });
      setOk(mode === "off" ? "Moderasi AI dimatikan; filter lokal tetap aktif."
        : mode === "shadow" ? "Mode bayangan aktif—AI mencatat tanpa memblokir."
        : "Mode penegakan aktif—verdict berkeyakinan tinggi dapat menolak konten.");
      await muat();
    } catch (e: any) { setErr(e.message); }
    finally { setBusy(""); }
  }

  async function verifikasi() {
    if (!data?.boleh_mengubah || busy) return;
    setBusy("verify"); setErr(""); setOk("");
    try {
      await adminFetch("/api/admin/moderasi/ai/verifikasi", { method: "POST" });
      setOk("Credential OpenRouter valid dan endpoint dapat dijangkau tanpa mengirim konten.");
    } catch (e: any) { setErr(`Verifikasi gagal: ${e.message}`); }
    finally { setBusy(""); }
  }

  if (loading && !data) return <Load />;
  const s = data?.statistik || {};
  const events = Array.isArray(data?.event) ? data.event : [];
  const modeTone = data?.mode === "enforce" ? "bad" : data?.mode === "shadow" ? "warn" : "netral";
  return (
    <div className="space-y-4">
      {ok && <MsgOk msg={ok} />}
      {err && <ErrBox msg={err} />}

      <div className="grid gap-3 lg:grid-cols-[1.2fr_.8fr]">
        <div className="xy-card rounded-[18px] p-5 space-y-4">
          <div className="flex flex-wrap items-start justify-between gap-3">
            <div>
              <div className="flex items-center gap-2">
                <BrainCircuit size={18} className="text-[#6D5AE0]" />
                <h3 className="font-bold text-[#241E37]">Grok via OpenRouter</h3>
                <Chip tone={modeTone as any}>{data?.mode || "off"}</Chip>
              </div>
              <p className="text-[12px] text-[#746B86] mt-1">
                Filter lokal selalu aktif. AI hanya membaca teks publik saat mode shadow/enforce.
              </p>
            </div>
            <Chip tone={data?.key_configured ? "ok" : "warn"}>
              {data?.key_configured ? "Secret tersedia" : "Secret belum ada"}
            </Chip>
          </div>

          <div className="grid sm:grid-cols-2 gap-2 text-[12px]">
            <InfoAi icon={BrainCircuit} label="Model" value={data?.model || "—"} />
            <InfoAi icon={ShieldCheck} label="Kebijakan gagal" value="Filter lokal lalu fail-open AI" />
            <InfoAi icon={Database} label="Penyimpanan" value="Hash HMAC + metadata; tanpa teks mentah" />
            <InfoAi icon={Wifi} label="Privasi upstream" value="Data collection deny + ZDR" />
          </div>

          <div className="flex flex-wrap gap-2">
            {(["off", "shadow", "enforce"] as const).map((m) => (
              <Btn key={m} tone={m === "enforce" ? "bahaya" : m === "shadow" ? "utama" : "ghost"}
                disabled={!data?.boleh_mengubah || Boolean(busy) || (m !== "off" && !data?.key_configured)}
                onClick={() => ubahMode(m)}>
                {busy === m ? <RefreshCw size={13} className="animate-spin" /> : null}
                {m === "off" ? "Matikan AI" : m === "shadow" ? "Mode bayangan" : "Terapkan verdict"}
              </Btn>
            ))}
            <Btn tone="ghost" disabled={!data?.boleh_mengubah || !data?.key_configured || Boolean(busy)} onClick={verifikasi}>
              <Wifi size={13} /> Verifikasi koneksi
            </Btn>
            <Btn tone="ghost" disabled={loading || Boolean(busy)} onClick={muat}>
              <RefreshCw size={13} className={loading ? "animate-spin" : ""} /> Segarkan
            </Btn>
          </div>
          {!data?.boleh_mengubah && <p className="text-[11px] text-amber-700">Moderator dapat melihat audit; hanya pemilik yang boleh mengubah mode.</p>}
        </div>

        <div className="grid grid-cols-2 gap-2">
          <StatAi label="24 jam" value={s.total_24h} />
          <StatAi label="30 hari" value={s.total_30d} />
          <StatAi label="Diblokir" value={s.diblokir} tone="text-red-600" />
          <StatAi label="Perlu tinjau" value={s.ditinjau} tone="text-amber-600" />
          <StatAi label="Galat provider" value={s.galat} tone="text-rose-600" />
          <StatAi label="Cache hit" value={s.cache_hit} />
          <StatAi label="Latency rata-rata" value={s.rata_latency_ms ? `${s.rata_latency_ms} ms` : "—"} />
          <StatAi label="Token 30 hari" value={Number(s.prompt_tokens || 0) + Number(s.completion_tokens || 0)} />
        </div>
      </div>

      <div className="rounded-[15px] border border-blue-200 bg-blue-50 px-4 py-3 text-[12px] text-blue-900 leading-relaxed">
        AI tidak memindai gambar, tidak menghukum akun, dan tidak menggantikan keputusan moderator. Mode shadow wajib dipakai lebih dahulu untuk mengukur false positive sebelum enforce.
      </div>

      <div className="xy-card rounded-[18px] overflow-hidden">
        <div className="px-4 py-3 border-b border-[#EEE9F7] flex items-center justify-between">
          <div className="font-semibold text-[13px] text-[#332D47]">Audit klasifikasi terbaru</div>
          <span className="text-[11px] text-[#827894]">tanpa konten mentah</span>
        </div>
        {events.length === 0 ? <EmptyBox msg="Belum ada event moderasi AI." /> : (
          <div className="divide-y divide-[#F0ECF7]">
            {events.map((e: any) => (
              <div key={e.id} className="px-4 py-3 flex flex-wrap items-center justify-between gap-3 text-[11.5px]">
                <div className="min-w-0">
                  <div className="flex flex-wrap gap-1.5 items-center">
                    <Chip tone={e.verdict === "block" ? "bad" : e.verdict === "error" ? "warn" : e.verdict === "allow" ? "ok" : "info"}>{e.verdict}</Chip>
                    <span className="font-semibold text-[#3A334E]">{e.konteks}</span>
                    <span className="text-[#81778F]">{e.user_nama || e.user_id || "akun terhapus"}</span>
                    {e.cached ? <Chip tone="netral">cache</Chip> : null}
                  </div>
                  <div className="text-[#8B829A] mt-1">
                    {e.sumber} · {e.kategori || e.error_code || "—"} · severity {e.severity ?? "—"} · confidence {e.confidence == null ? "—" : `${Math.round(Number(e.confidence) * 100)}%`}
                  </div>
                </div>
                <div className="text-right text-[#8B829A]">
                  <div>{jam(e.waktu)}</div>
                  <div>{e.latency_ms == null ? "—" : `${e.latency_ms} ms`} · {e.model || "lokal"}</div>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}

function InfoAi({ icon: Icon, label, value }: { icon: any; label: string; value: any }) {
  return <div className="rounded-xl border border-[#ECE6F6] bg-[#FAF9FD] p-3 flex gap-2">
    <Icon size={14} className="text-[#7967DD] mt-0.5 shrink-0" />
    <div><div className="text-[10px] uppercase tracking-wide text-[#8D849C]">{label}</div><div className="font-medium text-[#413951] mt-0.5">{String(value)}</div></div>
  </div>;
}

function StatAi({ label, value, tone = "text-[#332D47]" }: { label: string; value: any; tone?: string }) {
  return <div className="xy-card rounded-[14px] p-3">
    <div className={`text-xl font-bold ${tone}`}>{value ?? 0}</div>
    <div className="text-[10.5px] text-[#81778F] mt-0.5">{label}</div>
  </div>;
}
