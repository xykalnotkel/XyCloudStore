/**
 * XyCloudStore — adaptor penyedia pembayaran.
 *
 * Secret hanya dibaca dari environment Cloudflare Worker. Modul ini tidak
 * pernah menyimpan atau mengembalikan API key. Setiap status "lunas" juga
 * membawa hasil pencocokan order + nominal agar pemanggil tidak mengkredit
 * saldo berdasarkan webhook semata.
 */

const PAKASIR_API = 'https://app.pakasir.com/api';
const PAKASIR_METHODS = new Set([
  'qris', 'bni_va', 'bri_va', 'cimb_niaga_va', 'maybank_va', 'permata_va',
  'sampoerna_va', 'bnc_va', 'atm_bersama_va', 'artha_graha_va',
]);

const enc = new TextEncoder();

function nilaiAda(v) {
  return typeof v === 'string' && v.trim().length > 0;
}

function pakasirSiap(env) {
  return nilaiAda(env?.PAKASIR_PROJECT) && nilaiAda(env?.PAKASIR_API_KEY)
    && /^[a-z0-9][a-z0-9_-]{1,79}$/i.test(String(env.PAKASIR_PROJECT).trim());
}

function tripaySiap(env) {
  return nilaiAda(env?.TRIPAY_API_KEY) && nilaiAda(env?.TRIPAY_PRIVATE_KEY)
    && nilaiAda(env?.TRIPAY_MERCHANT_CODE);
}

function midtransSiap(env) {
  return nilaiAda(env?.MIDTRANS_SERVER_KEY);
}

function tripayBase(env) {
  const khusus = String(env?.TRIPAY_BASE || '').trim().replace(/\/+$/, '');
  if (khusus.startsWith('https://')) return khusus;
  return env?.TRIPAY_SANDBOX === '1'
    ? 'https://tripay.co.id/api-sandbox'
    : 'https://tripay.co.id/api';
}

function midtransProduksi(env) {
  return env?.MIDTRANS_PRODUCTION === '1' || env?.MIDTRANS_PRODUKSI === 'true';
}

/** Ringkasan aman untuk diagnostik admin — hanya boolean, tidak ada nilai secret. */
export function infoKonfigurasiPembayaran(env) {
  return {
    pilihan: String(env?.PAYMENT_PROVIDER || '').trim().toLowerCase() || 'otomatis',
    pakasir: {
      siap: pakasirSiap(env),
      project: nilaiAda(env?.PAKASIR_PROJECT),
      api_key: nilaiAda(env?.PAKASIR_API_KEY),
      webhook_bertanda_tangan: false,
    },
    tripay: {
      siap: tripaySiap(env),
      api_key: nilaiAda(env?.TRIPAY_API_KEY),
      private_key: nilaiAda(env?.TRIPAY_PRIVATE_KEY),
      merchant_code: nilaiAda(env?.TRIPAY_MERCHANT_CODE),
    },
    midtrans: {
      siap: midtransSiap(env),
      server_key: nilaiAda(env?.MIDTRANS_SERVER_KEY),
    },
  };
}

/** Provider dipilih eksplisit bila PAYMENT_PROVIDER valid; fallback deterministik. */
export function penyediaBayar(env) {
  const siap = {
    pakasir: pakasirSiap(env),
    tripay: tripaySiap(env),
    midtrans: midtransSiap(env),
  };
  const pilihan = String(env?.PAYMENT_PROVIDER || '').trim().toLowerCase();
  if (pilihan === 'manual') return 'manual';
  if (siap[pilihan]) return pilihan;
  if (siap.pakasir) return 'pakasir';
  if (siap.tripay) return 'tripay';
  if (siap.midtrans) return 'midtrans';
  return 'manual';
}

export function metodeTersedia(env) {
  switch (penyediaBayar(env)) {
    case 'pakasir':
      return [
        { kode: 'qris', nama: 'QRIS' },
        { kode: 'bri_va', nama: 'BRI Virtual Account' },
        { kode: 'bni_va', nama: 'BNI Virtual Account' },
        { kode: 'cimb_niaga_va', nama: 'CIMB Niaga VA' },
        { kode: 'maybank_va', nama: 'Maybank Virtual Account' },
        { kode: 'permata_va', nama: 'Permata Virtual Account' },
        { kode: 'sampoerna_va', nama: 'Bank Sampoerna VA' },
        { kode: 'bnc_va', nama: 'Bank Neo Commerce VA' },
        { kode: 'atm_bersama_va', nama: 'ATM Bersama VA' },
        { kode: 'artha_graha_va', nama: 'Bank Artha Graha VA' },
      ];
    case 'tripay':
      return [
        { kode: 'QRIS', nama: 'QRIS' },
        { kode: 'DANA', nama: 'DANA' },
        { kode: 'SHOPEEPAY', nama: 'ShopeePay' },
        { kode: 'BRIVA', nama: 'BRI Virtual Account' },
        { kode: 'BNIVA', nama: 'BNI Virtual Account' },
        { kode: 'BCAVA', nama: 'BCA Virtual Account' },
        { kode: 'MANDIRIVA', nama: 'Mandiri Virtual Account' },
      ];
    case 'midtrans':
      return [{ kode: 'SNAP', nama: 'QRIS / E-wallet / Bank' }];
    default:
      return [];
  }
}

function metodePakasir(mentah) {
  const m = String(mentah || '').trim().toLowerCase();
  // Kompatibilitas APK lama yang mengirim default "transfer".
  if (!m || m === 'transfer' || m === 'snap') return 'qris';
  return PAKASIR_METHODS.has(m) ? m : '';
}

function integerUang(v) {
  const n = Number(v);
  return Number.isSafeInteger(n) && n > 0 ? n : 0;
}

function transaksiDari(data) {
  if (!data || typeof data !== 'object') return null;
  const calon = data.transaction || data.payment || data?.data?.transaction || data?.data?.payment || data.data;
  return calon && typeof calon === 'object' && !Array.isArray(calon) ? calon : null;
}

async function fetchJson(url, init = {}) {
  let response;
  try {
    const signal = typeof AbortSignal !== 'undefined' && typeof AbortSignal.timeout === 'function'
      ? AbortSignal.timeout(10_000)
      : undefined;
    response = await fetch(url, {
      ...init,
      signal: init.signal || signal,
      headers: {
        Accept: 'application/json',
        'User-Agent': 'XyCloudStore-Payment/1.0',
        ...(init.headers || {}),
      },
    });
  } catch (_) {
    return { ok: false, status: 0, data: null, alasan: 'Penyedia tidak dapat dihubungi.' };
  }

  const text = await response.text().catch(() => '');
  let data = null;
  if (text && text.length <= 512_000) {
    try { data = JSON.parse(text); } catch (_) { data = null; }
  }
  return {
    ok: response.ok,
    status: response.status,
    data,
    alasan: response.ok ? '' : `Penyedia membalas HTTP ${response.status}.`,
  };
}

function urlBayarPakasir(env, { id, nominal, metode }) {
  const project = String(env.PAKASIR_PROJECT).trim();
  const u = new URL(`https://app.pakasir.com/pay/${encodeURIComponent(project)}/${nominal}`);
  u.searchParams.set('order_id', id);
  if (metode === 'qris') u.searchParams.set('qris_only', '1');
  return u.toString();
}

/** Buat tagihan. QRIS Pakasir memakai checkout resmi; VA memakai API create. */
export async function buatTagihan(env, { id, nominal, metode, nama, email, phone, keterangan }) {
  const provider = penyediaBayar(env);
  const jumlah = integerUang(nominal);
  if (!id || !jumlah) return { ok: false, alasan: 'ID atau nominal tagihan tidak valid.' };

  if (provider === 'pakasir') {
    const channel = metodePakasir(metode);
    if (!channel) return { ok: false, alasan: 'Metode Pakasir tidak didukung.' };

    // Checkout resmi adalah cara paling kompatibel untuk QRIS: QR dirender oleh
    // Pakasir dan API key tidak pernah masuk URL/aplikasi.
    if (channel === 'qris') {
      return {
        ok: true,
        penyedia: 'pakasir',
        metode: channel,
        referensi: id,
        url: urlBayarPakasir(env, { id, nominal: jumlah, metode: channel }),
        qr: null,
        kode_bayar: null,
        total_bayar: jumlah,
        biaya: null,
        kedaluwarsa: null,
      };
    }

    const r = await fetchJson(`${PAKASIR_API}/transactioncreate/${encodeURIComponent(channel)}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        project: String(env.PAKASIR_PROJECT).trim(),
        order_id: id,
        amount: jumlah,
        api_key: String(env.PAKASIR_API_KEY),
      }),
    });
    const tr = transaksiDari(r.data);
    const cocok = tr
      && String(tr.project || '') === String(env.PAKASIR_PROJECT).trim()
      && String(tr.order_id || '') === String(id)
      && integerUang(tr.amount) === jumlah;
    if (!r.ok || !cocok || !nilaiAda(String(tr.payment_number || ''))) {
      return { ok: false, alasan: 'Pakasir belum dapat membuat nomor pembayaran. Coba lagi.' };
    }
    return {
      ok: true,
      penyedia: 'pakasir',
      metode: channel,
      referensi: String(tr.order_id),
      url: null,
      qr: null,
      kode_bayar: String(tr.payment_number),
      total_bayar: integerUang(tr.total_payment) || jumlah,
      biaya: Math.max(0, Number(tr.fee) || 0),
      kedaluwarsa: tr.expired_at || tr.expired || null,
    };
  }

  if (provider === 'tripay') {
    const channel = String(metode || 'QRIS').toUpperCase();
    const diizinkan = new Set(metodeTersedia(env).map((m) => m.kode));
    if (!diizinkan.has(channel)) return { ok: false, alasan: 'Metode Tripay tidak didukung.' };
    const sig = await hmacHex(env.TRIPAY_PRIVATE_KEY, env.TRIPAY_MERCHANT_CODE + id + jumlah);
    const r = await fetchJson(`${tripayBase(env)}/transaction/create`, {
      method: 'POST',
      headers: {
        Authorization: 'Bearer ' + env.TRIPAY_API_KEY,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        method: channel,
        merchant_ref: id,
        amount: jumlah,
        customer_name: nama || 'Pengguna XyCloudStore',
        customer_email: email || 'customer@xycloud.my.id',
        customer_phone: phone || '',
        order_items: [{ sku: id, name: keterangan || 'Isi saldo XyCloudStore', price: jumlah, quantity: 1 }],
        return_url: env.WEB_URL || 'https://xycloud.my.id',
        callback_url: `${env.PUBLIC_URL || 'https://api.xycloud.my.id'}/bayar/webhook/tripay`,
        expired_time: Math.floor(Date.now() / 1000) + 86400,
        signature: sig,
      }),
    });
    const d = r.data?.data;
    if (!r.ok || !r.data?.success || !d) return { ok: false, alasan: 'Tripay gagal membuat tagihan.' };
    return {
      ok: true, penyedia: 'tripay', metode: channel,
      referensi: d.reference || id,
      url: d.checkout_url || null,
      qr: d.qr_url || null,
      kode_bayar: d.pay_code || null,
      total_bayar: integerUang(d.amount) || jumlah,
      biaya: Math.max(0, Number(d.total_fee) || 0),
      kedaluwarsa: d.expired_time ? new Date(Number(d.expired_time) * 1000).toISOString() : null,
    };
  }

  if (provider === 'midtrans') {
    const host = midtransProduksi(env)
      ? 'https://app.midtrans.com/snap/v1/transactions'
      : 'https://app.sandbox.midtrans.com/snap/v1/transactions';
    const r = await fetchJson(host, {
      method: 'POST',
      headers: {
        Authorization: 'Basic ' + btoa(env.MIDTRANS_SERVER_KEY + ':'),
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        transaction_details: { order_id: id, gross_amount: jumlah },
        customer_details: { first_name: nama || 'Pengguna', email: email || '', phone: phone || '' },
        item_details: [{ id: 'SALDO', price: jumlah, quantity: 1, name: keterangan || 'Isi saldo XyCloudStore' }],
        expiry: { unit: 'hours', duration: 24 },
      }),
    });
    if (!r.ok || !r.data?.redirect_url) return { ok: false, alasan: 'Midtrans gagal membuat tagihan.' };
    return {
      ok: true, penyedia: 'midtrans', metode: 'SNAP',
      referensi: id, url: r.data.redirect_url, qr: null, kode_bayar: null,
      total_bayar: jumlah, biaya: null, kedaluwarsa: null,
    };
  }

  return { ok: false, alasan: 'Penyedia pembayaran otomatis belum dikonfigurasi.' };
}

async function hmacHex(secret, message) {
  const key = await crypto.subtle.importKey('raw', enc.encode(String(secret || '')),
    { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  const out = await crypto.subtle.sign('HMAC', key, enc.encode(String(message || '')));
  return [...new Uint8Array(out)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

function hexBytes(v) {
  const s = String(v || '').toLowerCase();
  if (!/^[a-f0-9]+$/.test(s) || s.length % 2) return null;
  const out = new Uint8Array(s.length / 2);
  for (let i = 0; i < out.length; i++) out[i] = parseInt(s.slice(i * 2, i * 2 + 2), 16);
  return out;
}

function bytesSama(a, b) {
  if (!(a instanceof Uint8Array) || !(b instanceof Uint8Array) || a.length !== b.length) return false;
  let beda = 0;
  for (let i = 0; i < a.length; i++) beda |= a[i] ^ b[i];
  return beda === 0;
}

async function sha512Hex(message) {
  const out = await crypto.subtle.digest('SHA-512', enc.encode(String(message || '')));
  return [...new Uint8Array(out)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

/**
 * Baca webhook secara defensif. Pakasir tidak mendokumentasikan signature;
 * hasilnya hanya dianggap bentuk/project valid dan WAJIB dicek ulang melalui
 * Transaction Detail API sebelum saldo boleh dikreditkan.
 */
export async function bacaPemberitahuan(env, provider, req, bodyText) {
  const p = String(provider || '').toLowerCase();
  let d;
  try { d = JSON.parse(bodyText); } catch (_) {
    return { sah: false, alasan: 'JSON webhook tidak valid.' };
  }
  if (!d || typeof d !== 'object' || Array.isArray(d)) {
    return { sah: false, alasan: 'Payload webhook tidak valid.' };
  }

  if (p === 'pakasir') {
    if (!pakasirSiap(env)) return { sah: false, alasan: 'Pakasir belum dikonfigurasi.' };
    const project = String(d.project || '');
    const id = String(d.order_id || '');
    const nominal = integerUang(d.amount);
    if (project !== String(env.PAKASIR_PROJECT).trim() || !id || !nominal) {
      return { sah: false, alasan: 'Project, order, atau nominal Pakasir tidak cocok.' };
    }
    return {
      sah: true,
      id,
      nominal,
      status: String(d.status || '').toLowerCase(),
      metode: String(d.payment_method || '').slice(0, 64),
      harus_verifikasi: true,
      bertanda_tangan: false,
    };
  }

  if (p === 'tripay') {
    if (!tripaySiap(env)) return { sah: false, alasan: 'Tripay belum dikonfigurasi.' };
    const supplied = hexBytes(req.headers.get('x-callback-signature'));
    const expected = hexBytes(await hmacHex(env.TRIPAY_PRIVATE_KEY, bodyText));
    if (!bytesSama(supplied, expected)) return { sah: false, alasan: 'Signature Tripay salah.' };
    const id = String(d.merchant_ref || '');
    if (!id) return { sah: false, alasan: 'Order Tripay tidak ada.' };
    return {
      sah: true, id,
      nominal: integerUang(d.amount) || integerUang(d.total_amount) || integerUang(d.amount_received),
      status: String(d.status || '').toLowerCase(),
      metode: String(d.payment_method || '').slice(0, 64),
      harus_verifikasi: true,
      bertanda_tangan: true,
    };
  }

  if (p === 'midtrans') {
    if (!midtransSiap(env)) return { sah: false, alasan: 'Midtrans belum dikonfigurasi.' };
    const expected = hexBytes(await sha512Hex(
      String(d.order_id || '') + String(d.status_code || '') + String(d.gross_amount || '') + env.MIDTRANS_SERVER_KEY,
    ));
    const supplied = hexBytes(d.signature_key);
    if (!bytesSama(supplied, expected)) return { sah: false, alasan: 'Signature Midtrans salah.' };
    const id = String(d.order_id || '');
    if (!id) return { sah: false, alasan: 'Order Midtrans tidak ada.' };
    return {
      sah: true, id,
      nominal: integerUang(String(d.gross_amount || '').split('.')[0]),
      status: String(d.transaction_status || '').toLowerCase(),
      metode: String(d.payment_type || '').slice(0, 64),
      harus_verifikasi: true,
      bertanda_tangan: true,
    };
  }

  return { sah: false, alasan: 'Provider webhook tidak dikenal.' };
}

function providerUntukTopup(env, topup) {
  const tersimpan = String(topup?.provider || '').toLowerCase();
  if (['pakasir', 'tripay', 'midtrans'].includes(tersimpan)) return tersimpan;
  if ((tersimpan === 'legacy' || !tersimpan) && Number(topup?.kode_unik) === 0) return penyediaBayar(env);
  return 'manual';
}

function statusPakasir(v) {
  const s = String(v || '').toLowerCase();
  if (['completed', 'success', 'paid', 'settlement'].includes(s)) return 'lunas';
  if (['canceled', 'cancelled', 'expired', 'failed', 'deny', 'failure'].includes(s)) return 'gagal';
  return 'menunggu';
}

/** Tanya provider dan cocokkan response dengan transaksi lokal. */
export async function cekStatusPenyedia(env, topup) {
  const provider = providerUntukTopup(env, topup);
  const id = String(topup?.provider_ref || topup?.id || '');
  const idLokal = String(topup?.id || id);
  const nominal = integerUang(topup?.nominal);
  if (!id || !nominal || provider === 'manual') {
    return { status: 'tidak_diketahui', cocok: false, ditemukan: false, provider, alasan: 'Top up bukan transaksi gateway yang valid.' };
  }

  if (provider === 'pakasir') {
    if (!pakasirSiap(env)) return { status: 'tidak_diketahui', cocok: false, provider, alasan: 'Secret Pakasir belum lengkap.' };
    const u = new URL(`${PAKASIR_API}/transactiondetail`);
    u.searchParams.set('project', String(env.PAKASIR_PROJECT).trim());
    u.searchParams.set('amount', String(nominal));
    u.searchParams.set('order_id', id);
    u.searchParams.set('api_key', String(env.PAKASIR_API_KEY));
    const r = await fetchJson(u.toString());
    const tr = transaksiDari(r.data);
    // Checkout belum pernah dibuka / transaksi belum terbentuk: tetap pending,
    // bukan gagal, agar pengguna masih dapat melanjutkan pembayaran.
    if (!tr) {
      const authDitolak = r.status === 401 || r.status === 403;
      const gangguan = r.status === 0 || r.status >= 500;
      return {
        status: authDitolak || gangguan ? 'tidak_diketahui' : 'menunggu',
        cocok: !authDitolak,
        ditemukan: false,
        provider,
        alasan: authDitolak ? 'Pakasir menolak kredensial.'
          : gangguan ? 'Pakasir sementara tidak dapat diperiksa.'
            : 'Transaksi belum tersedia di Pakasir.',
      };
    }
    const cocok = String(tr.project || '') === String(env.PAKASIR_PROJECT).trim()
      && String(tr.order_id || '') === id
      && id === idLokal
      && integerUang(tr.amount) === nominal;
    return {
      status: cocok ? statusPakasir(tr.status) : 'tidak_diketahui',
      cocok,
      ditemukan: true,
      provider,
      referensi: String(tr.order_id || ''),
      nominal: integerUang(tr.amount),
      total: integerUang(tr.total_payment) || null,
      biaya: Math.max(0, Number(tr.fee) || 0),
      metode: String(tr.payment_method || '').slice(0, 64),
      status_asli: String(tr.status || '').slice(0, 40),
      kedaluwarsa: tr.expired_at || tr.expired || null,
      alasan: cocok ? '' : 'Detail Pakasir tidak cocok dengan top up lokal.',
    };
  }

  if (provider === 'tripay') {
    if (!tripaySiap(env)) return { status: 'tidak_diketahui', cocok: false, provider, alasan: 'Secret Tripay belum lengkap.' };
    const host = tripayBase(env);
    const u = new URL(`${host}/transaction/detail`);
    // Tripay detail menerima reference provider. Baris lama memakai merchant_ref;
    // fallback dilakukan tanpa pernah mengirim secret di query.
    u.searchParams.set('reference', id);
    let r = await fetchJson(u.toString(), { headers: { Authorization: 'Bearer ' + env.TRIPAY_API_KEY } });
    let d = r.data?.data;
    if ((!r.ok || !d) && id === idLokal) {
      // Sebagian akun/API Tripay menerima merchant_ref pada endpoint detail.
      const alt = new URL(`${host}/transaction/detail`);
      alt.searchParams.set('merchant_ref', idLokal);
      r = await fetchJson(alt.toString(), { headers: { Authorization: 'Bearer ' + env.TRIPAY_API_KEY } });
      d = r.data?.data;
    }
    if (!r.ok || !d) {
      const gangguan = r.status === 0 || r.status >= 500;
      const authDitolak = r.status === 401 || r.status === 403;
      return {
        status: gangguan || authDitolak ? 'tidak_diketahui' : 'menunggu',
        cocok: !(gangguan || authDitolak), ditemukan: false, provider,
        alasan: authDitolak ? 'Tripay menolak kredensial.'
          : gangguan ? 'Tripay sementara tidak dapat diperiksa.' : 'Detail Tripay belum tersedia.',
      };
    }
    const refCocok = String(d.merchant_ref || '') === idLokal;
    const nominalProvider = integerUang(d.amount);
    const cocok = refCocok && nominalProvider === nominal;
    const st = String(d.status || '').toUpperCase();
    return {
      status: cocok ? (['PAID', 'SETTLED'].includes(st) ? 'lunas' : (['EXPIRED', 'FAILED', 'REFUND'].includes(st) ? 'gagal' : 'menunggu')) : 'tidak_diketahui',
      cocok, ditemukan: true, provider,
      referensi: String(d.reference || id), nominal: nominalProvider,
      total: integerUang(d.amount_received) || nominalProvider,
      biaya: Math.max(0, Number(d.total_fee) || 0),
      metode: String(d.payment_method || '').slice(0, 64),
      status_asli: st.slice(0, 40),
      kedaluwarsa: d.expired_time ? new Date(Number(d.expired_time) * 1000).toISOString() : null,
      alasan: cocok ? '' : 'Detail Tripay tidak cocok dengan top up lokal.',
    };
  }

  if (provider === 'midtrans') {
    if (!midtransSiap(env)) return { status: 'tidak_diketahui', cocok: false, provider, alasan: 'Secret Midtrans belum lengkap.' };
    const host = midtransProduksi(env) ? 'https://api.midtrans.com' : 'https://api.sandbox.midtrans.com';
    const r = await fetchJson(`${host}/v2/${encodeURIComponent(id)}/status`, {
      headers: { Authorization: 'Basic ' + btoa(env.MIDTRANS_SERVER_KEY + ':') },
    });
    const d = r.data;
    if (!r.ok || !d?.transaction_status) {
      const gangguan = r.status === 0 || r.status >= 500;
      const authDitolak = r.status === 401 || r.status === 403;
      return {
        status: gangguan || authDitolak ? 'tidak_diketahui' : 'menunggu',
        cocok: !(gangguan || authDitolak), ditemukan: false, provider,
        alasan: authDitolak ? 'Midtrans menolak kredensial.'
          : gangguan ? 'Midtrans sementara tidak dapat diperiksa.' : 'Detail Midtrans belum tersedia.',
      };
    }
    const nominalProvider = integerUang(String(d.gross_amount || '').split('.')[0]);
    const cocok = String(d.order_id || '') === idLokal && nominalProvider === nominal;
    const st = String(d.transaction_status || '').toLowerCase();
    const fraud = String(d.fraud_status || '').toLowerCase();
    const lunas = st === 'settlement' || (st === 'capture' && fraud === 'accept');
    const gagal = ['deny', 'cancel', 'expire', 'failure', 'refund', 'partial_refund', 'chargeback'].includes(st);
    return {
      status: cocok ? (lunas ? 'lunas' : (gagal ? 'gagal' : 'menunggu')) : 'tidak_diketahui',
      cocok, ditemukan: true, provider,
      referensi: String(d.order_id || id), nominal: nominalProvider,
      total: nominalProvider, biaya: null,
      metode: String(d.payment_type || '').slice(0, 64),
      status_asli: st.slice(0, 40), kedaluwarsa: d.expiry_time || null,
      alasan: cocok ? '' : 'Detail Midtrans tidak cocok dengan top up lokal.',
    };
  }

  return { status: 'tidak_diketahui', cocok: false, ditemukan: false, provider, alasan: 'Provider tidak dikenal.' };
}

/** Batalkan transaksi Pakasir sebelum top up lokal ditolak. */
export async function batalkanTagihan(env, topup) {
  const provider = providerUntukTopup(env, topup);
  const id = String(topup?.provider_ref || topup?.id || '');
  const nominal = integerUang(topup?.nominal);
  if (provider !== 'pakasir' || !pakasirSiap(env) || !id || !nominal) {
    return { ok: false, didukung: false, provider, alasan: 'Pembatalan otomatis tidak didukung.' };
  }
  const r = await fetchJson(`${PAKASIR_API}/transactioncancel`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      project: String(env.PAKASIR_PROJECT).trim(),
      order_id: id,
      amount: nominal,
      api_key: String(env.PAKASIR_API_KEY),
    }),
  });
  const tr = transaksiDari(r.data);
  const cocok = !tr || (String(tr.order_id || '') === id && integerUang(tr.amount) === nominal);
  if (!r.ok || !cocok) {
    return {
      ok: false, didukung: true, provider,
      status: tr ? String(tr.status || '').toLowerCase() : '',
      alasan: 'Pakasir tidak menerima permintaan pembatalan.',
    };
  }

  // HTTP 2xx saja belum membuktikan tagihan sudah tidak dapat dibayar. Terima
  // pembatalan hanya bila body atau Transaction Detail mengonfirmasi status
  // final gagal. Ini penting untuk hosted checkout yang mungkin belum pernah
  // dibuka dan karena tautannya dapat tersimpan di luar aplikasi.
  if (tr && statusPakasir(tr.status) === 'gagal') {
    return { ok: true, didukung: true, provider, status: String(tr.status || '').toLowerCase(), alasan: '' };
  }
  const konfirmasi = await cekStatusPenyedia(env, topup);
  const dibatalkan = konfirmasi.cocok && konfirmasi.ditemukan && konfirmasi.status === 'gagal';
  return {
    ok: dibatalkan,
    didukung: true,
    provider,
    status: String(konfirmasi.status_asli || konfirmasi.status || ''),
    alasan: dibatalkan ? ''
      : konfirmasi.status === 'lunas'
        ? 'Transaksi sudah dibayar dan tidak boleh ditolak.'
        : 'Pembatalan belum dapat diverifikasi melalui Transaction Detail.',
  };
}
