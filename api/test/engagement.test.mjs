import test from 'node:test';
import assert from 'node:assert/strict';
import { webcrypto } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { build } from 'esbuild';
import { Miniflare, convertV4MiniflareOptions } from 'miniflare';
import { httpsAman, urlStikerAman, tipeBerkasStiker } from '../src/engagement.js';

const cloud = { CLOUDINARY_CLOUD:'jxjvz3qi' };
test('URL dan format stiker dibatasi, tidak menerima SVG/file/host lain',()=>{
  assert.equal(httpsAman('javascript:alert(1)'),false);
  assert.equal(httpsAman('https://u:p@host.test/a'),false);
  assert.equal(urlStikerAman(cloud,'https://media.giphy.com/media/a/giphy.webp'),true);
  assert.equal(urlStikerAman(cloud,'https://media.giphy.com.evil.test/a.gif'),false);
  assert.equal(urlStikerAman(cloud,'https://res.cloudinary.com/other/image/upload/xycloudstore/stiker/a.webp'),false);
  assert.equal(urlStikerAman(cloud,'http://127.0.0.1/a.gif'),false);
  assert.equal(tipeBerkasStiker(new TextEncoder().encode('<svg>unsafe</svg>')),null);
  assert.equal(tipeBerkasStiker(new TextEncoder().encode('RIFF1234WEBPanything')),'image/webp');
  assert.equal(tipeBerkasStiker(new TextEncoder().encode('GIF89a123456789')),'image/gif');
});

test('Integrasi D1: rename, thread, stiker+teks, promo, GIPHY belum aktif, hapus akun', {timeout:120000}, async()=>{
  const out=await build({entryPoints:['src/index.js'],bundle:true,format:'esm',target:'es2022',platform:'browser',loader:{'.html':'text','.png':'binary'},write:false});
  const secret='test-only-signing-key-never-production';
  const mf=new Miniflare(convertV4MiniflareOptions({modules:true,script:out.outputFiles[0].text,compatibilityDate:'2025-01-01',
    d1Databases:['DB'],durableObjects:{HUB:'RealtimeHub'},bindings:{...cloud,JWT_SECRET:secret,ADMIN_KEY:'test-only-admin',PUBLIC_URL:'https://api.example.test'}}));
  try{
    const db=await mf.getD1Database('DB');
    const sql=JSON.parse(execFileSync('python3',['-c',`import sqlite3,json\ns=open('schema.sql').read();a=[];b=''\nfor c in s:\n b+=c\n if c==';' and sqlite3.complete_statement(b):a.append(b);b=''\nprint(json.dumps(a))`],{encoding:'utf8'}));
    for(const q of sql)await db.prepare(q).run();
    await db.prepare("INSERT INTO users(id,nama,email,password,email_verified) VALUES ('test-a','Nama Lama','a@example.invalid','password-test',1),('test-b','Pengguna B','b@example.invalid','password-test',1)").run();
    await db.prepare("INSERT INTO forum_post(id,user_id,nama,kategori,judul,isi) VALUES('post-a','test-a','Nama Lama','Umum','Judul pengujian','Isi untuk pengujian lokal'),('post-b','test-b','Pengguna B','Umum','Diskusi lainnya','Konten pengujian lokal')").run();
    await db.prepare("INSERT INTO forum_balasan(id,post_id,user_id,nama,isi) VALUES('reply-a','post-b','test-a','Nama Lama','Komentar sebelum rename')").run();
    const token=async id=>{
      const body=Buffer.from(JSON.stringify({v:2,sv:0,sub:id,email:id+'@example.invalid',exp:Date.now()+3600000})).toString('base64url');
      const key=await webcrypto.subtle.importKey('raw',new TextEncoder().encode(secret),{name:'HMAC',hash:'SHA-256'},false,['sign']);
      return body+'.'+Buffer.from(await webcrypto.subtle.sign('HMAC',key,new TextEncoder().encode(body))).toString('base64url');
    };
    const a=await token('test-a'),b=await token('test-b');
    const call=async(path,{method='GET',body,auth,admin=false}={})=>{
      const r=await mf.dispatchFetch('https://api.example.test/api'+path,{method,headers:{'Content-Type':'application/json',...(auth?{Authorization:'Bearer '+auth}:{}),...(admin?{'x-admin-key':'test-only-admin'}:{})},...(body?{body:JSON.stringify(body)}:{})});
      return {status:r.status,json:await r.json()};
    };
    let r=await call('/me',{method:'PATCH',auth:a,body:{nama:'Nama Terbaru'}});assert.equal(r.status,200,JSON.stringify(r.json));
    r=await call('/forum/post-b');assert.equal(r.json.data.balasan[0].nama,'Nama Terbaru');
    r=await call('/forum?cari=Judul');assert.equal(r.status,200,JSON.stringify(r.json));assert.equal(r.json.data[0].nama,'Nama Terbaru');
    r=await call('/forum/post-b/balas',{method:'POST',auth:b,body:{isi:'Teks di atas stiker',balas_ke:'reply-a',stiker:{url:'https://res.cloudinary.com/jxjvz3qi/image/upload/v123/xycloudstore/stiker/test.webp'}}});
    assert.equal(r.status,201,JSON.stringify(r.json));assert.equal(r.json.data.isi,'Teks di atas stiker');assert.ok(r.json.data.stiker.url);
    r=await call('/forum/post-a/balas',{method:'POST',auth:a,body:{isi:'Parent salah',balas_ke:'reply-a'}});assert.equal(r.status,400);
    r=await call('/forum/post-b/balas',{method:'POST',auth:a,body:{stiker:{url:'https://media.giphy.com/media/a/giphy.gif'}}});assert.equal(r.status,201);
    r=await call('/forum/post-b/balas',{method:'POST',auth:a,body:{isi:'',stiker:{url:'http://127.0.0.1/a.gif'}}});assert.equal(r.status,400);
    r=await call('/stiker/giphy',{auth:a});assert.equal(r.status,200);assert.equal(r.json.data.siap,false);
    r=await call('/stiker/giphy');assert.equal(r.status,401);
    r=await call('/admin/promosi',{admin:true,method:'POST',body:{gambar:'https://example.invalid/promo.webp',target:'https://xycloud.my.id/sewa',jenis:'popup'}});assert.equal(r.status,201,JSON.stringify(r.json));
    const promoId=r.json.data.id;
    r=await call('/promosi');assert.equal(r.json.data[0].jenis,'popup');assert.equal(r.json.data[0].revisi,1);
    r=await call('/admin/promosi',{admin:true,method:'POST',body:{id:promoId,gambar:'https://example.invalid/promo.webp',target:'https://xycloud.my.id/sewa',aktif:0}});assert.equal(r.status,201);
    r=await call('/promosi');assert.deepEqual(r.json.data,[]);
    r=await call('/admin/promosi',{admin:true,method:'POST',body:{gambar:'https://example.invalid/a.png',target:'javascript:alert(1)'}});assert.equal(r.status,400);
    r=await call('/me',{method:'DELETE',auth:a,body:{password:'password-test'}});assert.equal(r.status,400);
    await db.prepare("UPDATE users SET saldo=5000 WHERE id='test-a'").run();
    r=await call('/me',{method:'DELETE',auth:a,body:{konfirmasi:'HAPUS',password:'password-test',paksa:true}});assert.equal(r.status,409);
    await db.prepare("UPDATE users SET saldo=0 WHERE id='test-a'").run();
    r=await call('/me',{method:'DELETE',auth:a,body:{konfirmasi:'HAPUS',password:'wrong'}});assert.equal(r.status,401);
    r=await call('/me',{method:'DELETE',auth:a,body:{konfirmasi:'HAPUS',password:'password-test'}});assert.equal(r.status,200,JSON.stringify(r.json));
    r=await call('/me',{auth:a});assert.equal(r.status,401);
    r=await call('/forum/post-a');assert.equal(r.status,404);
    r=await call('/forum/post-b');assert.equal(r.status,200);assert.equal(r.json.data.balasan.length,1);assert.equal(r.json.data.balasan[0].user_id,'test-b');assert.equal(r.json.data.balasan[0].balas_ke,null);
    assert.equal(await db.prepare("SELECT COUNT(*) n FROM users WHERE id='test-b'").first('n'),1);
    assert.ok(!readFileSync('src/index.js','utf8').includes('laporanHarian'));
  } finally {await mf.dispose();}
});
