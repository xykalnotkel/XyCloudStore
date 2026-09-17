import test from 'node:test';
import assert from 'node:assert/strict';
import {
  penyediaBayar,
  metodeTersedia,
  buatTagihan,
  bacaPemberitahuan,
  cekStatusPenyedia,
  batalkanTagihan,
} from '../src/bayar.js';

const env = {
  PAYMENT_PROVIDER: 'pakasir',
  PAKASIR_PROJECT: 'xycloud-test',
  PAKASIR_API_KEY: 'rahasia-hanya-untuk-test',
};

function jawaban(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'content-type': 'application/json' },
  });
}

test('Pakasir hanya aktif dengan kedua secret dan checkout QRIS tidak membocorkan API key', async () => {
  assert.equal(penyediaBayar({ PAYMENT_PROVIDER: 'pakasir' }), 'manual');
  assert.equal(penyediaBayar({ ...env, PAKASIR_API_KEY: '' }), 'manual');
  assert.equal(penyediaBayar(env), 'pakasir');
  assert.ok(metodeTersedia(env).some((x) => x.kode === 'qris'));
  assert.ok(metodeTersedia(env).some((x) => x.kode === 'bri_va'));

  const hasil = await buatTagihan(env, {
    id: 'tp_qris_1', nominal: 50_000, metode: 'qris', nama: 'Uji', email: 'uji@example.invalid',
  });
  assert.equal(hasil.ok, true);
  assert.equal(hasil.penyedia, 'pakasir');
  assert.equal(hasil.total_bayar, 50_000);
  const url = new URL(hasil.url);
  assert.equal(url.origin, 'https://app.pakasir.com');
  assert.equal(url.searchParams.get('order_id'), 'tp_qris_1');
  assert.equal(url.searchParams.get('qris_only'), '1');
  assert.equal(url.href.includes(env.PAKASIR_API_KEY), false);
  assert.equal(JSON.stringify(hasil).includes(env.PAKASIR_API_KEY), false);
});

test('Pakasir VA menerima hanya respons project, order, nominal, dan nomor yang cocok', async () => {
  const asli = globalThis.fetch;
  let badan;
  try {
    globalThis.fetch = async (url, init) => {
      assert.equal(String(url), 'https://app.pakasir.com/api/transactioncreate/bri_va');
      badan = JSON.parse(init.body);
      return jawaban({ transaction: {
        project: env.PAKASIR_PROJECT,
        order_id: 'tp_va_1',
        amount: 75_000,
        total_payment: 75_750,
        fee: 750,
        payment_number: '1234567890',
        expired_at: '2026-09-18T00:00:00Z',
      } });
    };
    const hasil = await buatTagihan(env, { id: 'tp_va_1', nominal: 75_000, metode: 'bri_va' });
    assert.equal(hasil.ok, true);
    assert.equal(hasil.kode_bayar, '1234567890');
    assert.equal(hasil.total_bayar, 75_750);
    assert.equal(hasil.biaya, 750);
    assert.equal(badan.api_key, env.PAKASIR_API_KEY);
    assert.equal(JSON.stringify(hasil).includes(env.PAKASIR_API_KEY), false);

    globalThis.fetch = async () => jawaban({ transaction: {
      project: env.PAKASIR_PROJECT,
      order_id: 'tp_lain', amount: 75_000, payment_number: '123',
    } });
    const salah = await buatTagihan(env, { id: 'tp_va_1', nominal: 75_000, metode: 'bri_va' });
    assert.equal(salah.ok, false);
  } finally {
    globalThis.fetch = asli;
  }
});

test('Webhook Pakasir hanyalah sinyal; Transaction Detail wajib cocok sebelum lunas', async () => {
  const req = new Request('https://api.example.invalid/bayar/webhook/pakasir', { method: 'POST' });
  const webhook = await bacaPemberitahuan(env, 'pakasir', req, JSON.stringify({
    project: env.PAKASIR_PROJECT,
    order_id: 'tp_detail_1',
    amount: 100_000,
    status: 'completed',
    payment_method: 'qris',
  }));
  assert.equal(webhook.sah, true);
  assert.equal(webhook.harus_verifikasi, true);
  assert.equal(webhook.bertanda_tangan, false);

  const palsu = await bacaPemberitahuan(env, 'pakasir', req, JSON.stringify({
    project: 'project-penyerang', order_id: 'tp_detail_1', amount: 100_000, status: 'completed',
  }));
  assert.equal(palsu.sah, false);

  const asli = globalThis.fetch;
  try {
    globalThis.fetch = async (url) => {
      const u = new URL(url);
      assert.equal(u.pathname, '/api/transactiondetail');
      assert.equal(u.searchParams.get('project'), env.PAKASIR_PROJECT);
      assert.equal(u.searchParams.get('order_id'), 'tp_detail_1');
      assert.equal(u.searchParams.get('amount'), '100000');
      assert.equal(u.searchParams.get('api_key'), env.PAKASIR_API_KEY);
      return jawaban({ transaction: {
        project: env.PAKASIR_PROJECT,
        order_id: 'tp_detail_1',
        amount: 100_000,
        total_payment: 101_000,
        fee: 1_000,
        status: 'completed',
        payment_method: 'qris',
      } });
    };
    const cocok = await cekStatusPenyedia(env, {
      id: 'tp_detail_1', provider: 'pakasir', provider_ref: 'tp_detail_1', nominal: 100_000, kode_unik: 0,
    });
    assert.equal(cocok.cocok, true);
    assert.equal(cocok.ditemukan, true);
    assert.equal(cocok.status, 'lunas');
    assert.equal(JSON.stringify(cocok).includes(env.PAKASIR_API_KEY), false);

    globalThis.fetch = async () => jawaban({ transaction: {
      project: env.PAKASIR_PROJECT, order_id: 'tp_detail_1', amount: 99_999, status: 'completed',
    } });
    const beda = await cekStatusPenyedia(env, {
      id: 'tp_detail_1', provider: 'pakasir', provider_ref: 'tp_detail_1', nominal: 100_000, kode_unik: 0,
    });
    assert.equal(beda.cocok, false);
    assert.equal(beda.status, 'tidak_diketahui');
  } finally {
    globalThis.fetch = asli;
  }
});

test('Penolakan lokal tidak diteruskan bila pembatalan Pakasir belum final atau sudah lunas', async () => {
  const asli = globalThis.fetch;
  const topup = {
    id: 'tp_cancel_1', provider: 'pakasir', provider_ref: 'tp_cancel_1', nominal: 125_000, kode_unik: 0,
  };
  let panggilan = 0;
  try {
    globalThis.fetch = async (url) => {
      panggilan += 1;
      if (String(url).endsWith('/transactioncancel')) {
        return jawaban({ transaction: {
          project: env.PAKASIR_PROJECT, order_id: topup.id, amount: topup.nominal, status: 'pending',
        } });
      }
      return jawaban({ transaction: {
        project: env.PAKASIR_PROJECT, order_id: topup.id, amount: topup.nominal, status: 'completed',
      } });
    };
    const hasil = await batalkanTagihan(env, topup);
    assert.equal(panggilan, 2);
    assert.equal(hasil.ok, false);
    assert.match(hasil.alasan, /sudah dibayar/i);
  } finally {
    globalThis.fetch = asli;
  }
});
