import {build} from 'esbuild';
import {Miniflare,convertV4MiniflareOptions} from 'miniflare';
import {execFileSync} from 'node:child_process';
import {webcrypto} from 'node:crypto';

const RAHASIA_UJI = 'local-tests-only-not-production';

/**
 * Pecah berkas SQL menjadi pernyataan tunggal, sadar blok BEGIN…END milik trigger.
 * Dipakai untuk memuat `schema.sql` dan seluruh `migrations/*.sql` berurutan.
 */
export function pernyataanSkema(){
 return JSON.parse(execFileSync('python3',['-c',`
import glob,json,os,sqlite3
def pisah(jalur):
    keluar=[];buf=''
    for c in open(jalur,encoding='utf-8').read():
        buf+=c
        if c==';' and sqlite3.complete_statement(buf):
            keluar.append(buf);buf=''
    return [s for s in keluar if s.strip()]
hasil=[]
for jalur in ['schema.sql']+sorted(glob.glob('migrations/*.sql')):
    for s in pisah(jalur):
        hasil.append({'berkas':os.path.basename(jalur),'sql':s})
print(json.dumps(hasil))
`],{encoding:'utf8'}));
}

/**
 * Terapkan schema.sql LALU seluruh migrations/*.sql ke basis data D1 uji.
 *
 * Sebelumnya harness hanya memuat `schema.sql`, sehingga migrasi tidak pernah
 * dieksekusi oleh CI. Kolom yang hanya ada di migrasi (mis. `rilis.gambar` dari
 * 0004) tidak teruji, dan basis data produksi bisa tertinggal tanpa satu pun
 * pemeriksaan yang merah. Pernyataan yang gagal karena kolom/tabel sudah ada
 * ditoleransi supaya skema dasar dan migrasi boleh tumpang tindih.
 */
export async function terapkanSkema(db){
 for(const q of pernyataanSkema()){
  try{await db.prepare(q.sql).run();}
  catch(e){
   const m=String(e&&e.message||e);
   if(!/duplicate column name|already exists/i.test(m))
    throw new Error(`Skema ${q.berkas} gagal: ${m}\nSQL: ${q.sql.slice(0,300)}`);
  }
 }
 return db;
}

/** Tanda tangan token pengguna yang sama bentuknya dengan produksi. */
export async function tokenUji(id,extra={},rahasia=RAHASIA_UJI){
 const b=Buffer.from(JSON.stringify({v:2,sv:0,sub:id,exp:Date.now()+3600000,...extra})).toString('base64url');
 const k=await webcrypto.subtle.importKey('raw',new TextEncoder().encode(rahasia),{name:'HMAC',hash:'SHA-256'},false,['sign']);
 return b+'.'+Buffer.from(await webcrypto.subtle.sign('HMAC',k,new TextEncoder().encode(b))).toString('base64url');
}

export async function harness(bindings={}){
 const code=await build({entryPoints:['src/index.js'],bundle:true,format:'esm',loader:{'.html':'text','.png':'binary'},write:false});
 const secret=RAHASIA_UJI;
 // Miniflare 5 memakai skema worker baru. Konverter resmi mempertahankan
 // harness V4 yang sederhana sambil tetap menggunakan runtime terbaru/aman.
 const mf=new Miniflare(convertV4MiniflareOptions({modules:true,script:code.outputFiles[0].text,compatibilityDate:'2025-01-01',d1Databases:['DB'],durableObjects:{HUB:'RealtimeHub'},bindings:{JWT_SECRET:secret,ADMIN_KEY:'test-admin',EMAIL_ADMIN:'owner@example.invalid',...bindings}}));
 const db=await mf.getD1Database('DB');
 await terapkanSkema(db);
 const token=(id,extra={})=>tokenUji(id,extra,secret);
 const call=async(path,method='GET',body,headers={})=>{const r=await mf.dispatchFetch('https://api.example.invalid/api'+path,{method,headers:{'Content-Type':'application/json','CF-Connecting-IP':'192.0.2.123',...headers},...(body?{body:JSON.stringify(body)}:{})});return {status:r.status,headers:r.headers,json:await r.json()};};
 return {mf,db,token,call};
}
