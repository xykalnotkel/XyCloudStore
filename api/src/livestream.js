const CF_API = 'https://api.cloudflare.com/client/v4';

function clampInt(v, min, max, fallback) {
  const n = Number(v);
  return Number.isSafeInteger(n) ? Math.max(min, Math.min(max, n)) : fallback;
}

function customerHost(env) {
  const raw = String(env.CF_STREAM_CUSTOMER_HOST || '').trim().toLowerCase();
  return /^customer-[a-z0-9]{6,64}\.cloudflarestream\.com$/.test(raw) ? raw : '';
}

function accountId(env) {
  const raw = String(env.CF_STREAM_ACCOUNT_ID || '').trim();
  return /^[a-f0-9]{32}$/i.test(raw) ? raw : '';
}

async function settings(env) {
  const defaults = {
    livestream_enabled: '0',
    livestream_platform_fee_bps: '2000',
    livestream_min_tip: '5000',
    livestream_max_tip: '500000',
    livestream_min_payout: '100000',
    livestream_max_minutes: '240',
    livestream_max_concurrent: '2',
  };
  try {
    const { results } = await env.DB.prepare(
      `SELECT kunci,nilai FROM setelan WHERE kunci IN
       ('livestream_enabled','livestream_platform_fee_bps','livestream_min_tip',
        'livestream_max_tip','livestream_min_payout','livestream_max_minutes','livestream_max_concurrent')`,
    ).all();
    for (const r of results || []) defaults[r.kunci] = String(r.nilai ?? defaults[r.kunci]);
  } catch (_) { /* defaults aman */ }
  const minTip = clampInt(Number(defaults.livestream_min_tip), 1000, 1_000_000, 5000);
  const maxTip = Math.max(minTip,
    clampInt(Number(defaults.livestream_max_tip), 1000, 5_000_000, 500000));
  return {
    enabled: defaults.livestream_enabled === '1',
    feeBps: clampInt(Number(defaults.livestream_platform_fee_bps), 0, 5000, 2000),
    minTip,
    maxTip,
    minPayout: clampInt(Number(defaults.livestream_min_payout), 50_000, 10_000_000, 100000),
    maxMinutes: clampInt(Number(defaults.livestream_max_minutes), 15, 360, 240),
    maxConcurrent: clampInt(Number(defaults.livestream_max_concurrent), 1, 10, 2),
  };
}

export async function konfigurasiLivestream(env) {
  const cfg = await settings(env);
  const configured = Boolean(env.CF_STREAM_API_TOKEN && accountId(env) && customerHost(env));
  return {
    ...cfg,
    provider: 'cloudflare_stream',
    configured,
    account_configured: Boolean(accountId(env)),
    customer_host_configured: Boolean(customerHost(env)),
    token_configured: Boolean(env.CF_STREAM_API_TOKEN),
    effective: cfg.enabled && configured,
    playback_signed: true,
    playback_token_ttl_max_minutes: 360,
    recording_days: 30,
    creator_hold_days: 7,
  };
}

function cfError(status) {
  if (status === 401 || status === 403) return 'AUTH';
  if (status === 404) return 'NOT_FOUND';
  if (status === 409) return 'CONFLICT';
  if (status === 429) return 'RATE_LIMIT';
  if (status >= 500) return 'UPSTREAM';
  return `HTTP_${status}`;
}

async function cfRequest(env, path, { method = 'GET', body } = {}) {
  const aid = accountId(env);
  if (!aid || !env.CF_STREAM_API_TOKEN) return { ok: false, code: 'NOT_CONFIGURED' };
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 8000);
  try {
    const r = await fetch(`${CF_API}/accounts/${aid}/stream${path}`, {
      method,
      signal: controller.signal,
      headers: {
        Authorization: `Bearer ${env.CF_STREAM_API_TOKEN}`,
        'Content-Type': 'application/json',
        'User-Agent': 'XyCloudStore-Worker/1.0',
      },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    const len = Number(r.headers.get('content-length') || 0);
    if (len > 128_000) {
      try { await r.body?.cancel(); } catch (_) { /* noop */ }
      return { ok: false, code: 'RESPONSE_TOO_LARGE' };
    }
    const text = await r.text();
    if (text.length > 128_000) return { ok: false, code: 'RESPONSE_TOO_LARGE' };
    let j = null;
    try { j = text ? JSON.parse(text) : {}; } catch (_) { /* provider body tidak diteruskan */ }
    if (!r.ok || j?.success !== true) return { ok: false, code: cfError(r.status) };
    return { ok: true, data: j.result || {} };
  } catch (e) {
    return { ok: false, code: e?.name === 'AbortError' ? 'TIMEOUT' : 'NETWORK' };
  } finally {
    clearTimeout(timer);
  }
}

export async function buatInputLivestream(env, liveId) {
  const cfg = await konfigurasiLivestream(env);
  if (!cfg.effective) return { ok: false, code: 'FEATURE_NOT_READY' };
  const r = await cfRequest(env, '/live_inputs', {
    method: 'POST',
    body: {
      enabled: true,
      deleteRecordingAfterDays: 30,
      preferLowLatency: false,
      meta: { name: `XyCloudStore ${String(liveId).slice(0, 40)}` },
      recording: {
        mode: 'automatic',
        // Input ID dan semua rekaman turunannya tidak boleh diputar hanya
        // dengan menebak/menyalin UID. Halaman player menukar tiket aplikasi
        // dengan token playback Cloudflare yang dibatasi akhir sesi.
        requireSignedURLs: true,
        allowedOrigins: ['api.xycloud.my.id', 'xycloud.my.id', 'www.xycloud.my.id'],
        hideLiveViewerCount: true,
        timeoutSeconds: 0,
      },
    },
  });
  if (!r.ok) return r;
  const uid = String(r.data?.uid || '');
  if (!/^[a-f0-9]{32}$/i.test(uid)) return { ok: false, code: 'INVALID_PROVIDER_RESPONSE' };
  // rtmps.streamKey sengaja tidak dikembalikan dari fungsi create dan tidak disimpan.
  return { ok: true, uid };
}

/** Hanya dipakai endpoint agen terautentikasi tepat sebelum OBS dimulai. */
export async function credentialInputLivestream(env, inputUid) {
  if (!/^[a-f0-9]{32}$/i.test(String(inputUid || ''))) return { ok: false, code: 'INVALID_INPUT' };
  const r = await cfRequest(env, `/live_inputs/${inputUid}`);
  if (!r.ok) return r;
  const url = String(r.data?.rtmps?.url || '');
  const streamKey = String(r.data?.rtmps?.streamKey || '');
  if (url !== 'rtmps://live.cloudflare.com:443/live/' || !/^[A-Za-z0-9._~-]{20,512}$/.test(streamKey)) {
    return { ok: false, code: 'INVALID_INGEST_CREDENTIAL' };
  }
  return { ok: true, url, streamKey };
}

export async function setInputLivestream(env, inputUid, enabled) {
  if (!/^[a-f0-9]{32}$/i.test(String(inputUid || ''))) return { ok: false, code: 'INVALID_INPUT' };
  return cfRequest(env, `/live_inputs/${inputUid}`, { method: 'PUT', body: { enabled: enabled === true } });
}

/** Setelah OBS berhenti, hapus Live Input agar stream key lama tidak dapat dipakai ulang. */
export async function hapusInputLivestream(env, inputUid) {
  if (!/^[a-f0-9]{32}$/i.test(String(inputUid || ''))) return { ok: false, code: 'INVALID_INPUT' };
  return cfRequest(env, `/live_inputs/${inputUid}`, { method: 'DELETE' });
}

export async function statusInputLivestream(env, inputUid) {
  if (!/^[a-f0-9]{32}$/i.test(String(inputUid || ''))) return { ok: false, code: 'INVALID_INPUT' };
  const r = await cfRequest(env, `/live_inputs/${inputUid}`);
  if (!r.ok) return r;
  return {
    ok: true,
    status: String(r.data?.status || 'idle').slice(0, 40),
    enabled: r.data?.enabled !== false,
  };
}

/**
 * Tukar UID privat menjadi token playback Cloudflare. Masa token dibatasi oleh
 * akhir sesi (maksimal enam jam); UID asli tidak pernah dipakai sebagai
 * capability playback publik. Untuk skala >1.000 player/hari, rollout wajib
 * beralih ke signing key/Stream binding sesuai runbook tanpa menurunkan
 * requireSignedURLs.
 */
export async function tokenPlaybackLivestream(env, inputUid, expiresAtMs) {
  const uid = String(inputUid || '');
  if (!/^[a-f0-9]{32}$/i.test(uid)) return { ok: false, code: 'INVALID_INPUT' };
  const requested = Number(expiresAtMs);
  const expMs = Number.isFinite(requested)
    ? Math.max(Date.now() + 600_000, Math.min(Date.now() + 6 * 3600_000, requested))
    : Date.now() + 3600_000;
  const r = await cfRequest(env, `/${uid}/token`, {
    method: 'POST', body: { exp: Math.floor(expMs / 1000) },
  });
  if (!r.ok) return r;
  const token = String(r.data?.token || '');
  const bagian = token.split('.');
  if (bagian.length !== 3 || token.length < 80 || token.length > 4096
      || bagian.some((x) => !/^[A-Za-z0-9_-]+$/.test(x))) {
    return { ok: false, code: 'INVALID_PLAYBACK_TOKEN' };
  }
  return { ok: true, token };
}

export function bentukLivestreamPublik(env, row) {
  const base = String(env.PUBLIC_URL || 'https://api.xycloud.my.id').replace(/\/$/, '');
  return {
    id: row.id,
    creator_id: row.user_id || null,
    creator_name: row.creator_name || 'Kreator XyCloud',
    creator_photo: row.creator_photo || null,
    title: row.title,
    game: row.game,
    status: row.status,
    started_at: row.started_at,
    scheduled_end: row.scheduled_end,
    viewers: Number(row.viewers || 0),
    viewer_peak: Number(row.viewer_peak || 0),
    gross_tip: Number(row.gross_tip || 0),
    share_url: `${base}/live/watch/${encodeURIComponent(row.id)}`,
    can_watch: ['starting', 'live'].includes(row.status),
  };
}

function esc(value) {
  return String(value ?? '')
    .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
}

function rupiah(n) {
  return `Rp${Math.max(0, Number(n) || 0).toLocaleString('id-ID')}`;
}

export async function responsHalamanLivestream(env, live, { tracked = false, playbackAllowed = true } = {}) {
  const host = customerHost(env);
  const input = String(live.provider_input_uid || '');
  const liveNow = ['starting', 'live'].includes(String(live.status));
  const akhir = Date.parse(String(live.scheduled_end || ''));
  const playbackExpires = Number.isFinite(akhir) ? akhir + 3600_000 : Date.now() + 3600_000;
  const playback = tracked && liveNow && host && playbackAllowed
    ? await tokenPlaybackLivestream(env, input, playbackExpires)
    : { ok: false, code: playbackAllowed ? 'NOT_REQUESTED' : 'PLAYER_PAGE_RATE_LIMIT' };
  const iframe = playback.ok
    ? `https://${host}/${playback.token}/iframe?autoplay=true&muted=false&preload=metadata`
    : '';
  const nonce = [...crypto.getRandomValues(new Uint8Array(16))]
    .map((b) => b.toString(16).padStart(2, '0')).join('');
  const heartbeatPath = `/live/watch/${encodeURIComponent(live.id)}/heartbeat`;
  const heartbeat = tracked ? `
    let aktif=!document.hidden;
    document.addEventListener('visibilitychange',()=>{aktif=!document.hidden});
    const detak=()=>{if(aktif)fetch('${heartbeatPath}',{method:'POST',credentials:'same-origin',keepalive:true}).catch(()=>{})};
    detak();setInterval(detak,15000);` : '';
  const playbackGagal = tracked && liveNow && !iframe;
  const selesai = !liveNow;
  const bodyPlayer = iframe && liveNow && tracked
    ? `<iframe src="${esc(iframe)}" title="Livestream ${esc(live.title)}" allow="autoplay; encrypted-media; picture-in-picture" allowfullscreen></iframe>`
    : `<div class="idle"><div class="pulse"></div><b>${selesai ? 'Siaran telah selesai' : (playbackGagal ? 'Token player aman belum tersedia' : (tracked ? 'Menunggu sinyal dari PC kreator' : 'Buka aplikasi untuk menonton'))}</b><span>${selesai ? 'Buka aplikasi untuk menemukan siaran lain yang masih berlangsung.' : (playbackGagal ? `Cloudflare Stream menolak token (${esc(playback.code)}). Coba segarkan halaman.` : (tracked ? 'Segarkan halaman beberapa saat lagi.' : 'Login aplikasi menerbitkan tiket player singkat dan terlacak.'))}</span></div>`;
  const playerOrigin = host ? ` https://${host}` : '';
  const html = `<!doctype html><html lang="id"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
<title>${esc(live.title)} — XyCloud Live</title><meta name="description" content="${liveNow ? 'Tonton' : 'Lihat'} ${esc(live.creator_name)} bermain ${esc(live.game)} dari PC rental XyCloudStore.">
<meta property="og:title" content="${esc(live.title)}"><meta property="og:description" content="${esc(live.creator_name)} ${liveNow ? 'sedang bermain' : 'telah bersiaran memainkan'} ${esc(live.game)} di XyCloud Live.">
<meta name="referrer" content="strict-origin"><style nonce="${nonce}">
*{box-sizing:border-box}body{margin:0;background:#100030;color:#fff;font-family:Inter,system-ui,sans-serif;min-height:100vh}.wrap{max-width:1120px;margin:auto;padding:20px}.brand{display:flex;align-items:center;gap:10px;color:#d8caff;font-weight:800}.brand img{width:34px;height:34px}.live{margin-left:auto;background:#ef4444;border-radius:999px;padding:6px 10px;font-size:11px;letter-spacing:.8px}.live.off{background:#554a68}.top{display:flex;align-items:center;margin-bottom:16px}.player{aspect-ratio:16/9;background:#05010d;border:1px solid #45237e;border-radius:22px;overflow:hidden;box-shadow:0 22px 70px #0008}.player iframe{border:0;width:100%;height:100%}.idle{height:100%;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:8px;color:#d8caff}.idle span{font-size:13px;color:#9387aa}.pulse{width:18px;height:18px;border-radius:50%;background:#8b5cf6;box-shadow:0 0 0 0 #8b5cf688;animation:p 1.6s infinite}@keyframes p{70%{box-shadow:0 0 0 18px #8b5cf600}}.info{margin-top:18px;background:#1a0a3a;border:1px solid #3e2369;border-radius:18px;padding:18px}.info h1{font-size:22px;margin:0 0 8px}.meta{display:flex;gap:8px;flex-wrap:wrap;color:#b9afca;font-size:13px}.chip{background:#2d1552;border:1px solid #51317e;border-radius:999px;padding:6px 10px}.notice{margin-top:14px;color:#9e94ae;font-size:12px;line-height:1.55}.cta{display:inline-flex;margin-top:14px;text-decoration:none;color:white;font-weight:800;background:linear-gradient(135deg,#7c3aed,#a855f7);padding:12px 18px;border-radius:999px}.cta.alt{margin-left:8px;background:#2d1552;border:1px solid #64449a}@media(max-width:600px){.wrap{padding:12px}.player{border-radius:14px}.info h1{font-size:18px}}
</style></head><body><main class="wrap"><div class="top"><div class="brand"><img src="/brand/logo.png" alt=""><span>XyCloud Live</span></div><span class="live${liveNow ? '' : ' off'}">${liveNow ? '● LIVE' : 'SELESAI'}</span></div><div class="player">${bodyPlayer}</div><section class="info"><h1>${esc(live.title)}</h1><div class="meta"><span class="chip">${esc(live.creator_name)}</span><span class="chip">${esc(live.game)}</span><span class="chip">${liveNow ? `${Number(live.viewers || 0)} penonton aktif` : `Puncak ${Number(live.viewer_peak || 0)} penonton`}</span><span class="chip">${rupiah(live.gross_tip)} dukungan</span></div><p class="notice">Siaran berasal dari game capture PC rental. Jangan membagikan data pribadi atau kredensial. Rekaman disimpan maksimal 30 hari untuk replay/moderasi. Dukungan kreator hanya dilakukan melalui aplikasi resmi.</p><a class="cta" href="xycloudstore://live?id=${encodeURIComponent(live.id)}">Buka di aplikasi</a><a class="cta alt" href="https://xycloud.my.id/unduh">Unduh aplikasi</a></section></main><script nonce="${nonce}">history.replaceState({},document.title,location.pathname);${heartbeat}</script></body></html>`;
  return new Response(html, {
    status: 200,
    headers: {
      'Content-Type': 'text/html; charset=utf-8',
      'Cache-Control': 'no-store, private',
      'Content-Security-Policy': `default-src 'none'; base-uri 'none'; object-src 'none'; frame-ancestors 'none'; frame-src${playerOrigin}; img-src 'self'; style-src 'nonce-${nonce}'; script-src 'nonce-${nonce}'; connect-src 'self'; form-action 'none'`,
      // Cloudflare allowedOrigins memerlukan origin pemutar, tetapi path dan
      // tiket aplikasi tetap tidak ikut terkirim sebagai Referer.
      'Referrer-Policy': 'strict-origin',
      'X-Frame-Options': 'DENY',
      'X-Content-Type-Options': 'nosniff',
      'Permissions-Policy': 'camera=(), microphone=(), geolocation=(), payment=()',
      'Cross-Origin-Opener-Policy': 'same-origin',
      'Strict-Transport-Security': 'max-age=31536000; includeSubDomains',
    },
  });
}
