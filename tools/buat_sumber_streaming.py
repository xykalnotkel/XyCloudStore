#!/usr/bin/env python3
"""Release the corresponding application/native sources; never include signing keys/secrets."""
from pathlib import Path
import subprocess,zipfile,urllib.request,json,hashlib,sys
root=Path(__file__).resolve().parent.parent
out=Path(sys.argv[1] if len(sys.argv)>1 else root/'dist/XyCloudStore-source.zip');out.parent.mkdir(parents=True,exist_ok=True)
up=root/'.cache/moonlight'
if not up.exists():raise SystemExit('Run tools/siapkan_streaming.py first')
sources={
 'openssl-1.1.1q.tar.gz':'https://codeload.github.com/openssl/openssl/tar.gz/refs/tags/OpenSSL_1_1_1q',
 'opus-1.3.tar.gz':'https://codeload.github.com/xiph/opus/tar.gz/refs/tags/v1.3',
 'bcprov-1.70-sources.jar':'https://repo.maven.apache.org/maven2/org/bouncycastle/bcprov-jdk15on/1.70/bcprov-jdk15on-1.70-sources.jar',
 'bcpkix-1.70-sources.jar':'https://repo.maven.apache.org/maven2/org/bouncycastle/bcpkix-jdk15on/1.70/bcpkix-jdk15on-1.70-sources.jar',
 'bcutil-1.70-sources.jar':'https://repo.maven.apache.org/maven2/org/bouncycastle/bcutil-jdk15on/1.70/bcutil-jdk15on-1.70-sources.jar',
 'jcodec-0.2.3-sources.jar':'https://repo.maven.apache.org/maven2/org/jcodec/jcodec/0.2.3/jcodec-0.2.3-sources.jar',
 'okhttp-3.12.13-sources.jar':'https://repo.maven.apache.org/maven2/com/squareup/okhttp3/okhttp/3.12.13/okhttp-3.12.13-sources.jar',
 'okio-1.17.5-sources.jar':'https://repo.maven.apache.org/maven2/com/squareup/okio/okio/1.17.5/okio-1.17.5-sources.jar',
 'jmdns-3.5.7-sources.jar':'https://repo.maven.apache.org/maven2/org/jmdns/jmdns/3.5.7/jmdns-3.5.7-sources.jar',
 'shield-extensions-1.0.1.tar.gz':'https://codeload.github.com/cgutman/ShieldControllerExtensions/tar.gz/refs/tags/1.0.1',
}
cache=root/'.cache/corresponding-source';cache.mkdir(parents=True,exist_ok=True)
manifest={}
for name,url in sources.items():
 p=cache/name
 if not p.exists():
  req=urllib.request.Request(url,headers={'User-Agent':'XyCloudStore-Source-Distribution'})
  with urllib.request.urlopen(req,timeout=90) as r,p.open('wb') as f:
   while chunk:=r.read(1024*1024):f.write(chunk)
 manifest[name]={'url':url,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}
tracked=subprocess.check_output(['git','ls-files','-z'],cwd=root).decode().split('\0')
# Corresponding source hanya berisi program GPL yang masuk APK dan tool yang
# benar-benar dibutuhkan untuk merekonstruksinya. Backend Worker, dashboard,
# agent host, runbook operasi, serta workflow deployment bukan bagian APK dan
# sengaja tidak boleh bocor lewat bundle publik.
build_tools={
 'tools/buat_sumber_streaming.py','tools/patch_manifest.py','tools/patch_signing.py',
 'tools/siapkan_biometrik.py','tools/siapkan_ikon_push.py','tools/siapkan_keamanan.py',
 'tools/siapkan_pembaruan.py','tools/siapkan_streaming.py',
}
with zipfile.ZipFile(out,'w',zipfile.ZIP_DEFLATED) as z:
 for name in tracked:
  if not name or not (name.startswith(('app/','native/')) or name in build_tools):continue
  p=root/name
  if p.is_file():z.write(p,name)
 if (root/'app/pubspec.lock').exists():z.write(root/'app/pubspec.lock','app/pubspec.lock')
 for p in up.rglob('*'):
  if p.is_file() and not any(x in {'.git','.gradle','build','__pycache__'} for x in p.relative_to(up).parts):z.write(p,Path('third_party/moonlight')/p.relative_to(up))
 for name in sources:z.write(cache/name,Path('third_party/library-sources')/name)
 z.writestr('third_party/SOURCES.json',json.dumps(manifest,indent=2))
 z.writestr('BUILD-SOURCE.txt','XyCloudStore application is GPL-3.0. See app/LICENSE and native/README.md.\nPinned engine and submodule sources, integration patches, required build tools, dependencies, and lockfile are included.\nUse Flutter 3.24.5, Java 17 and Android NDK 23.2.8568313. Private release signing keys are deliberately excluded; sign your rebuilt APK with your own key.\nTo build offline from the included engine source, copy third_party/moonlight to .cache/moonlight, then follow native/README.md (fetch step can be skipped with --offline).\n')
with zipfile.ZipFile(out) as z:
 names=z.namelist()
 forbidden=('api/','dashboard/','agent-gui/','docs/','.github/')
 bocor=sorted(n for n in names if n.startswith(forbidden))
 wajib={'app/LICENSE','app/pubspec.yaml','app/pubspec.lock','native/README.md','BUILD-SOURCE.txt'}
 kurang=sorted(wajib-set(names))
 if bocor or kurang:
  out.unlink(missing_ok=True)
  raise SystemExit(f'Bundle source tidak aman/lengkap: forbidden={len(bocor)}, missing={kurang}')
print('Corresponding source bundle:',out.name,out.stat().st_size)
