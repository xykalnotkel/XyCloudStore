/** Kontrak API galeri HUD: publik/privat, suka, impor, ubah, dan hapus. */
import test from 'node:test';
import assert from 'node:assert/strict';
import { harness } from './harness.mjs';

const layout = {
  versi: 1,
  tombol: [
    { id: 'w', label: 'W', kode: 51, x: .1, y: .5, lebar: 56, tinggi: 56, opacity: .86, cara: 'tahan' },
    { id: 'jump', label: 'Space', kode: 62, x: .65, y: .8, lebar: 120, tinggi: 44, opacity: .9, cara: 'ketuk' },
  ],
};

test('HUD: preset lokal dapat diterbitkan, disukai, diimpor, diprivatkan, dan dihapus', async () => {
  const { mf, db, token, call } = await harness();
  try {
    await db.prepare("INSERT INTO users(id,nama,email,password,username) VALUES('a','Ayu','a@hud.invalid','x','ayu')").run();
    await db.prepare("INSERT INTO users(id,nama,email,password,username) VALUES('b','Budi','b@hud.invalid','x','budi')").run();
    const ta = await token('a'), tb = await token('b');
    const A = (p, m, b) => call(p, m, b, { Authorization: 'Bearer ' + ta });
    const B = (p, m, b) => call(p, m, b, { Authorization: 'Bearer ' + tb });

    let r = await A('/hud/presets', 'POST', {
      nama: 'FPS Ayu', deskripsi: 'WASD ringkas', game: 'Valorant', data: layout, publik: true,
    });
    assert.equal(r.status, 201);
    const id = r.json.data.id;
    assert.equal(r.json.data.data.tombol.length, 2);
    assert.equal(r.json.data.saya, true);

    r = await B('/hud/presets?urut=populer');
    assert.equal(r.status, 200);
    assert.equal(r.json.data[0].id, id);
    assert.equal(r.json.data[0].pembuat_username, 'ayu');

    r = await B(`/hud/presets/${id}/suka`, 'POST');
    assert.equal(r.json.data.disukai, true);
    assert.equal(r.json.data.suka, 1);
    r = await B(`/hud/presets/${id}/pakai`, 'POST');
    assert.equal(r.status, 200);
    assert.equal(r.json.data.dipakai, 1);
    assert.equal(r.json.data.data.tombol[1].cara, 'ketuk');

    r = await A(`/hud/presets/${id}`, 'PATCH', { publik: false, data: layout });
    assert.equal(r.status, 200);
    assert.equal(r.json.data.publik, false);
    assert.equal((await B('/hud/presets')).json.data.length, 0);
    assert.equal((await B(`/hud/presets/${id}/pakai`, 'POST')).status, 404);
    assert.equal((await A('/me/hud-presets')).json.data[0].id, id);

    // Payload di luar kanvas tidak boleh masuk komunitas.
    const rusak = structuredClone(layout);
    rusak.tombol[0].x = 2;
    assert.equal((await A('/hud/presets', 'POST', {
      nama: 'Rusak', data: rusak,
    })).status, 422);

    assert.equal((await A(`/hud/presets/${id}`, 'DELETE')).status, 200);
    assert.equal((await A('/me/hud-presets')).json.data.length, 0);
  } finally {
    await mf.dispose();
  }
});
