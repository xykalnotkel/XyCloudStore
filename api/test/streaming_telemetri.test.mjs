/** Kontrak telemetri klien streaming: kepemilikan, sanitasi, dan nilai monotonik. */
import test from 'node:test';
import assert from 'node:assert/strict';
import { harness } from './harness.mjs';

test('telemetri streaming hanya menerima metadata aman milik penyewa', async () => {
  const { mf, db, token, call } = await harness();
  try {
    await db.prepare("INSERT INTO users(id,nama,email,password) VALUES('u1','Satu','satu@stream.invalid','x')").run();
    await db.prepare("INSERT INTO users(id,nama,email,password) VALUES('u2','Dua','dua@stream.invalid','x')").run();
    await db.prepare("INSERT INTO sesi(id,order_id,user_id,status) VALUES('s_live','o1','u1','siap')").run();
    const t1 = await token('u1');
    const t2 = await token('u2');
    const U1 = (p, m, b) => call(p, m, b, { Authorization: `Bearer ${t1}` });
    const U2 = (p, m, b) => call(p, m, b, { Authorization: `Bearer ${t2}` });

    let r = await U1('/sesi/s_live/telemetri', 'POST', {
      status: 'connected',
      route: 'Publik · pc.example.test\nheader-palsu',
      latency_ms: 84,
      quality: '1920x1080 · 60 FPS · 18 Mbps',
      disconnects: 2,
      reconnect_attempt: 1,
    });
    assert.equal(r.status, 200);
    let row = await db.prepare('SELECT * FROM sesi WHERE id=?').bind('s_live').first();
    assert.equal(row.client_state, 'connected');
    assert.equal(row.client_latency_ms, 84);
    assert.equal(row.client_disconnects, 2);
    assert.equal(row.client_route.includes('\n'), false);

    // Angka disconnect tidak boleh mundur akibat event jaringan yang datang terlambat.
    await U1('/sesi/s_live/telemetri', 'POST', {
      status: 'closed', disconnects: 0, reconnect_attempt: 0,
    });
    row = await db.prepare('SELECT * FROM sesi WHERE id=?').bind('s_live').first();
    assert.equal(row.client_disconnects, 2);

    assert.equal((await U1('/sesi/s_live/telemetri', 'POST', { status: 'mengintip' })).status, 400);
    assert.equal((await U2('/sesi/s_live/telemetri', 'POST', { status: 'connected' })).status, 404);
  } finally {
    await mf.dispose();
  }
});
