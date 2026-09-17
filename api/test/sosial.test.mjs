/**
 * Uji fitur sosial Batch D: profil publik, follow, DM (termasuk suara),
 * dan simpan posting. Menjamin kontrak endpoint yang dipakai aplikasi.
 */
import test from 'node:test';
import assert from 'node:assert/strict';
import { harness } from './harness.mjs';

test('Sosial: profil publik, follow dua arah, DM, dan simpan posting', async () => {
  const { mf, db, token, call } = await harness();
  try {
    await db.prepare("INSERT INTO users(id,nama,email,password,foto,bio) VALUES('a','Andi','a@example.invalid','x','https://img/a.png','Halo')").run();
    await db.prepare("INSERT INTO users(id,nama,email,password) VALUES('b','Budi','b@example.invalid','x')").run();
    const ta = await token('a'), tb = await token('b');
    const A = (p, m, b) => call(p, m, b, { Authorization: 'Bearer ' + ta });
    const B = (p, m, b) => call(p, m, b, { Authorization: 'Bearer ' + tb });

    // profil publik: field sosial lengkap
    let r = await B('/users/a/profil');
    assert.equal(r.status, 200);
    assert.equal(r.json.data.nama, 'Andi');
    assert.equal(r.json.data.bio, 'Halo');
    assert.equal(r.json.data.pengikut, 0);
    assert.equal(r.json.data.sayaIkuti, false);

    // follow: b mengikuti a
    r = await B('/users/a/ikuti', 'POST', { ikuti: true });
    assert.equal(r.status, 200);
    r = await B('/users/a/profil');
    assert.equal(r.json.data.sayaIkuti, true);
    assert.equal(r.json.data.pengikut, 1);
    r = await B('/me/follows?arah=mengikuti');
    assert.equal(r.json.data.length, 1);
    r = await A('/me/follows?arah=pengikut');
    assert.equal(r.json.data[0].id, 'b');
    // ikuti diri sendiri ditolak
    assert.equal((await A('/users/a/ikuti', 'POST', { ikuti: true })).status, 422);
    // unfollow
    await B('/users/a/ikuti', 'POST', { ikuti: false });
    assert.equal((await B('/users/a/profil')).json.data.pengikut, 0);
    await B('/users/a/ikuti', 'POST', { ikuti: true });

    // DM teks + baca
    r = await A('/dm/b', 'POST', { teks: 'Halo Budi, jadi main nanti?' });
    assert.equal(r.status, 201);
    r = await B('/dm/a');
    assert.equal(r.json.data.length, 1);
    assert.equal(r.json.data[0].teks, 'Halo Budi, jadi main nanti?');
    assert.equal(r.json.data[0].dibaca, 0);
    r = await B('/dm/a/dibaca', 'POST');
    assert.equal(r.json.data.baru, 1);
    // DM suara tanpa durasi dan teks pelecehan/phishing yang dikenal ditolak
    assert.equal((await A('/dm/b', 'POST', { tipe: 'audio', audio: 'data:audio/mp4;base64,AAAA' })).status, 400);
    assert.equal((await A('/dm/b', 'POST', { teks: 'dasar anjing' })).status, 400);
    // DM ke diri sendiri ditolak
    assert.equal((await A('/dm/a', 'POST', { teks: 'tes' })).status, 422);

    // simpan posting: toggle
    await db.prepare("INSERT INTO forum_post(id,user_id,nama,kategori,judul,isi) VALUES('p1','b','Budi','Umum','Judul','Isi')").run();
    r = await A('/forum/p1/simpan', 'POST');
    assert.equal(r.json.data.disimpan, true);
    r = await A('/me/simpan');
    assert.deepEqual(r.json.data, ['p1']);
    await A('/forum/p1/simpan', 'POST');
    assert.deepEqual((await A('/me/simpan')).json.data, []);

    // bio & banner lewat PATCH me
    r = await A('/me', 'PATCH', { bio: 'Suka streaming & kopi', banner: 'senja' });
    assert.equal(r.status, 200);
    assert.equal((await B('/users/a/profil')).json.data.banner, 'senja');
    assert.equal((await A('/me', 'PATCH', { banner: 'pelangi' })).status, 422);

    // toggle notifikasi DM (0008) + manajemen bisukan
    r = await A('/me', 'PATCH', { notif_dm: false });
    assert.equal(r.status, 200);
    assert.equal(r.json.data.notif_dm, 0);
    r = await A('/me', 'PATCH', { notif_dm: true });
    assert.equal(r.json.data.notif_dm, 1);

    r = await A('/me/bisukan', 'POST', { thread: 'dm:b', menit: 60 });
    assert.equal(r.json.data.ok, true);
    r = await A('/me/bisukan');
    assert.equal(r.json.data.length, 1);
    assert.equal(r.json.data[0].thread, 'dm:b');
    await A('/me/bisukan', 'POST', { thread: 'dm:b', menit: 0 });
    assert.deepEqual((await A('/me/bisukan')).json.data, []);

    // ---- Batch E: username, cek-nama, kata terlarang, lapor pengguna ----
    r = await A('/cek-nama', 'POST', { nama: 'Budi Santoso', username: 'budi.kece' });
    assert.equal(r.status, 200);
    assert.equal(r.json.data.nama.bersih, true);
    assert.equal(r.json.data.username.tersedia, true);

    // username porno ditolak + terdeteksi katanya
    r = await A('/cek-nama', 'POST', { username: 'bokep123' });
    assert.equal(r.json.data.username.tersedia, false);
    assert.equal(r.json.data.username.kata, 'bokep');

    // format username salah
    r = await A('/cek-nama', 'POST', { username: 'AB' });
    assert.equal(r.json.data.username.tersedia, false);

    // pasang username lewat PATCH me
    r = await A('/me', 'PATCH', { username: 'budi.kece' });
    assert.equal(r.status, 200);
    assert.equal(r.json.data.username, 'budi.kece');
    // muncul di profil publik
    assert.equal((await B('/users/a/profil')).json.data.username, 'budi.kece');
    // ditolak saat sudah dipakai orang lain
    assert.equal((await B('/me', 'PATCH', { username: 'budi.kece' })).status, 409);
    // Batch I: penggantian username dibatasi 30 hari sekali (pemilik lama
    // yang baru memasang username tidak bisa langsung mengganti lagi).
    r = await A('/me', 'PATCH', { username: 'andi_ganteng' });
    assert.equal(r.status, 429);

    // nama & bio dengan kata kasar/SARA/porno ditolak
    assert.equal((await A('/me', 'PATCH', { nama: 'Anjing Gila' })).status, 422);
    assert.equal((await A('/me', 'PATCH', { bio: 'jual bokep murah' })).status, 422);
    assert.equal((await A('/me', 'PATCH', { username: 'pki.123' })).status, 422);
    // nama sah yang memuat substring pendek tidak ikut terjaring
    r = await A('/me', 'PATCH', { nama: 'Nasution Andi' });
    assert.equal(r.status, 200);

    // lapor pengguna masuk moderasi
    r = await A('/users/b/lapor', 'POST', { alasan: 'Spam di forum komunitas' });
    assert.equal(r.status, 201);
    assert.equal((await A('/users/a/lapor', 'POST', { alasan: 'lapor diri sendiri' })).status, 422);
    assert.equal((await A('/users/b/lapor', 'POST', { alasan: 'x' })).status, 422);
  } finally {
    await mf.dispose();
  }
});
