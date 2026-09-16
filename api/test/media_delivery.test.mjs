import test from 'node:test';
import assert from 'node:assert/strict';
import {samarkanGambar,imageVariant} from '../src/upload.js';
const env={CLOUDINARY_CLOUD:'owned',PUBLIC_URL:'https://api.example.invalid'};
test('Static delivery resizes/converts while keeping original image identity',()=>{
 const url=samarkanGambar(env,'https://res.cloudinary.com/owned/image/upload/v123/xycloudstore/paket/a.png','t');
 assert.equal(url,'https://api.example.invalid/img/t/v123/xycloudstore/paket/a.png?v=26');
 const image=imageVariant(env,new URL(url).pathname,'image/webp');
 assert.ok(image.url.includes('f_webp,q_78,c_limit,w_360,h_360/'));
 assert.ok(!image.url.includes('dpr_2'));
 assert.equal(imageVariant(env,new URL(url).pathname,'image/avif').format,'avif');
 assert.equal(samarkanGambar(env,url,'s'),'https://api.example.invalid/img/s/v123/xycloudstore/paket/a.png?v=26');
});
test('Animation is preserved and unsafe proxy targets are rejected',()=>{
 const animated=imageVariant(env,'/img/m/v1/xycloudstore/stiker/a.gif','image/avif',true);
 assert.equal(animated.format,'original');assert.equal(animated.url,'https://res.cloudinary.com/owned/image/upload/v1/xycloudstore/stiker/a.gif');
 assert.equal(imageVariant(env,'/img/m/../secret.png'),null);
 assert.equal(imageVariant(env,'/img/m/xycloudstore/%2e%2e/secret.png'),null);
 assert.equal(samarkanGambar(env,'https://res.cloudinary.com/other/image/upload/a.png'),'https://res.cloudinary.com/other/image/upload/a.png');
});

import {samarkanKMedia, samarkanBannerMedia, layaniMedia} from '../src/upload.js';

test('Media non-gambar (video) disamarkan ke jalur /media/ milik sendiri', () => {
  const video = 'https://res.cloudinary.com/owned/video/upload/v123/xycloudstore/banner-profil/abc.mp4';
  const hasil = samarkanKMedia(env, video);
  assert.equal(hasil, 'https://api.example.invalid/media/v123/xycloudstore/banner-profil/abc.mp4');
  // transform aman ikut lolos
  const transform = 'https://res.cloudinary.com/owned/video/upload/f_gif,fps_12,w_480,c_limit/v123/xycloudstore/banner-profil/x.mp4';
  assert.equal(samarkanKMedia(env, transform), 'https://api.example.invalid/media/f_gif,fps_12,w_480,c_limit/v123/xycloudstore/banner-profil/x.mp4');
  // host lain / jalur di luar xycloudstore dibiarkan
  assert.equal(samarkanKMedia(env, 'https://res.cloudinary.com/other/video/upload/v1/x.mp4'), 'https://res.cloudinary.com/other/video/upload/v1/x.mp4');
  assert.equal(samarkanKMedia(env, 'https://res.cloudinary.com/owned/image/upload/v1/xycloudstore/produk/a.png'), 'https://api.example.invalid/img/m/v1/xycloudstore/produk/a.png?v=26');
});

test('banner_media JSON disamarkan tanpa kebocoran URL cloud', () => {
  const raw = JSON.stringify({tipe:'video', url:'https://res.cloudinary.com/owned/video/upload/v9/xycloudstore/banner-profil/a.mp4', gif:'https://res.cloudinary.com/owned/video/upload/f_gif/v9/xycloudstore/banner-profil/a.mp4'});
  const j = JSON.parse(samarkanBannerMedia(env, raw));
  assert.ok(!j.url.includes('res.cloudinary.com'));
  assert.ok(!j.gif.includes('res.cloudinary.com'));
  assert.ok(j.url.startsWith('https://api.example.invalid/media/'));
  // nilai non-JSON / kosong tidak rusak
  assert.equal(samarkanBannerMedia(env, null), null);
  assert.equal(samarkanBannerMedia(env, ''), '');
});

test('layaniMedia menolak jalur di luar xycloudstore', async () => {
  const r1 = await layaniMedia(env, '../secret/x.mp4');
  assert.equal(r1.status, 404);
  const r2 = await layaniMedia(env, 'v1/rahasia/x.mp4');
  assert.equal(r2.status, 404);
  const r3 = await layaniMedia(env, 'v1/xycloudstore/%2e%2e/x.mp4');
  assert.equal(r3.status, 404);
});
