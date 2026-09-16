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
