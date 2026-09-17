import test from 'node:test';
import assert from 'node:assert/strict';
import { webcrypto } from 'node:crypto';
import { periksaKontenPublik } from '../src/ai-moderasi.js';

if (!globalThis.crypto) globalThis.crypto = webcrypto;

function envMock(mode = 'off') {
  const binds = [];
  const DB = {
    prepare(sql) {
      return {
        bind(...args) {
          binds.push({ sql, args });
          return this;
        },
        async first() {
          if (sql.includes("kunci='ai_moderation_mode'")) return { nilai: mode };
          return null;
        },
        async run() { return { success: true }; },
      };
    },
  };
  return { env: { DB, JWT_SECRET: 'test-only-secret' }, binds };
}

test('filter lokal memblokir sebelum AI dan audit tidak menyimpan teks mentah', async () => {
  const { env, binds } = envMock('enforce');
  const teks = 'kata sangat rahasia lalu anjing';
  const hasil = await periksaKontenPublik(env, { userId: 'u_test', konteks: 'forum_post', teks });
  assert.equal(hasil.ok, false);
  assert.equal(hasil.sumber, 'local');
  assert.equal(JSON.stringify(binds).includes(teks), false);
});

test('mode off melewatkan teks aman tanpa subrequest AI', async () => {
  const { env } = envMock('off');
  const hasil = await periksaKontenPublik(env, {
    userId: 'u_test', konteks: 'forum_reply', teks: 'Terima kasih, panduannya sangat membantu.',
  });
  assert.deepEqual(hasil, { ok: true });
});

test('mode enforce tanpa secret fail-open setelah filter lokal', async () => {
  const { env, binds } = envMock('enforce');
  const hasil = await periksaKontenPublik(env, {
    userId: 'u_test', konteks: 'review_product', teks: 'Produknya sesuai deskripsi.',
  });
  assert.equal(hasil.ok, true);
  assert.equal(hasil.ai.status, 'unavailable');
  assert.equal(JSON.stringify(binds).includes('MISSING_KEY'), true);
});

test('Groq memakai model aktif dan Structured Outputs ketat', async () => {
  const { env } = envMock('enforce');
  Object.assign(env, {
    AI_MODERATION_PROVIDER: 'groq',
    GROQ_API_KEY: 'gsk_test-only-never-production',
    GROQ_ZDR_CONFIRMED: '1',
  });
  const fetchAsli = globalThis.fetch;
  let permintaan;
  globalThis.fetch = async (url, init) => {
    permintaan = { url: String(url), body: JSON.parse(init.body) };
    return new Response(JSON.stringify({
      model: 'openai/gpt-oss-20b',
      choices: [{ message: { content: JSON.stringify({
        verdict: 'allow', category: 'safe', severity: 0,
        confidence: 0.99, reason_code: 'NONE',
      }) } }],
      usage: { prompt_tokens: 20, completion_tokens: 12 },
    }), { status: 200, headers: { 'content-type': 'application/json' } });
  };
  try {
    const hasil = await periksaKontenPublik(env, {
      userId: 'u_test', konteks: 'forum_post', teks: 'Selamat datang di komunitas.',
    });
    assert.equal(hasil.ok, true);
    assert.equal(hasil.ai.status, 'allow');
    assert.equal(permintaan.url, 'https://api.groq.com/openai/v1/chat/completions');
    assert.equal(permintaan.body.model, 'openai/gpt-oss-20b');
    assert.equal(permintaan.body.response_format.type, 'json_schema');
    assert.equal(permintaan.body.response_format.json_schema.strict, true);
    assert.deepEqual(
      permintaan.body.response_format.json_schema.schema.required,
      ['verdict', 'category', 'severity', 'confidence', 'reason_code'],
    );
  } finally {
    globalThis.fetch = fetchAsli;
  }
});
