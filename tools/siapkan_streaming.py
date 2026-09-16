#!/usr/bin/env python3
"""Fetch immutable GPL source and wire the embedded Android library into Flutter.
No keys or credentials are downloaded/written by this script.
"""
from pathlib import Path
import subprocess, json, re, sys
ROOT=Path(__file__).resolve().parent.parent
cfg=json.loads((ROOT/'native/moonlight.lock.json').read_text())
vendor=ROOT/'.cache/moonlight'
def run(*args,cwd=None):subprocess.run(args,cwd=cwd,check=True)
if '--offline' not in sys.argv:
 if not (vendor/'.git').exists():
  vendor.mkdir(parents=True,exist_ok=True)
  run('git','init',str(vendor))
  run('git','remote','add','origin',cfg['repository'],cwd=vendor)
 run('git','fetch','--depth','1','origin',cfg['revision'],cwd=vendor)
 run('git','checkout','--detach',cfg['revision'],cwd=vendor)
 run('git','submodule','update','--init','--recursive','--depth','1',cwd=vendor)
 assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=vendor,text=True).strip()==cfg['revision']
# Minimal reproducible integration patches. Original copyright notices are retained.
game=vendor/'app/src/main/java/com/limelight/Game.java'
s=game.read_text()
if 'xySendKey' not in s:
 pos=s.rfind('}')
 s=s[:pos]+'''
    // XyCloudStore integration: direct key send for the custom on-screen HUD.
    // Bypasses the keyboard-grab gate so HUD taps always reach the host,
    // and honors the modifier state (Win/Ctrl/Alt/Shift) from the HUD.
    public void xySendKey(int keyCode, boolean isUp, int metaState) {
        try {
            if (conn == null) return;
            long now = android.os.SystemClock.uptimeMillis();
            android.view.KeyEvent ev = new android.view.KeyEvent(now, now,
                    isUp ? android.view.KeyEvent.ACTION_UP : android.view.KeyEvent.ACTION_DOWN,
                    keyCode, 0, metaState);
            short translated = keyboardTranslator.translate(keyCode, -1);
            if (translated != 0) {
                conn.sendKeyboardInput(translated,
                        isUp ? com.limelight.nvstream.input.KeyboardPacket.KEY_UP
                             : com.limelight.nvstream.input.KeyboardPacket.KEY_DOWN,
                        getModifierState(ev),
                        keyboardTranslator.hasNormalizedMapping(keyCode, -1)
                                ? (byte) 0 : (byte) MoonBridge.SS_KBE_FLAG_NON_NORMALIZED);
            } else if (!isUp) {
                int ch = ev.getUnicodeChar(metaState);
                if (ch > 0) conn.sendUtf8Text(String.valueOf((char) ch));
            }
        } catch (Throwable ignored) { }
    }

    public void xySendText(String text) {
        try {
            if (conn != null && text != null && !text.isEmpty()) conn.sendUtf8Text(text);
        } catch (Throwable ignored) { }
    }
'''+s[pos:]
 game.write_text(s)
# XyCloudStore (Batch M): kunci rasio stream landscape 16:9 — "lock di rasio
# landscape walaupun headless, lebarnya sesuaikan". Sisi host sudah dikunci
# 1920x1080@60 oleh Agent (opsi dd_* Sunshine); di sini permukaan video
# dipaksa 16:9 landscape juga sehingga walau host mengirim rasio lain
# (mis. display virtual portrait), lebar video tetap auto-fit ke layar dan
# rasio tidak pernah ikut-ikutan. optimizeGameSettings dinyalakan agar
# Sunshine menerapkan resolusi manual-nya saat stream mulai.
if 'xy_lanskap' not in s:
    s=s.replace('''        if (prefConfig.stretchVideo || aspectRatioMatch) {
            // Set the surface to the size of the video
            streamView.getHolder().setFixedSize(prefConfig.width, prefConfig.height);
        }
        else {
            // Set the surface to scale based on the aspect ratio of the stream
            streamView.setDesiredAspectRatio((double)prefConfig.width / (double)prefConfig.height);
        }''','''        // XyCloudStore (xy_lanskap): permukaan video selalu landscape 16:9.
        if (prefConfig.stretchVideo) {
            // Set the surface to the size of the video
            streamView.getHolder().setFixedSize(prefConfig.width, prefConfig.height);
        }
        else {
            // Lebar auto-fit ke layar; video di-letterbox di dalam permukaan 16:9.
            streamView.setDesiredAspectRatio(16.0 / 9.0);
        }''')
    # Note: v12.1 tidak punya prefConfig.optimizeGameSettings (dihapus Moonlight);
    # kunci resolusi host tetap via opsi dd_* Sunshine (dipasang Agent).
    game.write_text(s)
# Bounded pairing wait (the UI can cancel rather than waiting forever).
http=vendor/'app/src/main/java/com/limelight/nvstream/http/NvHTTP.java'
s=http.read_text().replace('.readTimeout(0, TimeUnit.MILLISECONDS)', '.readTimeout(90_000, TimeUnit.MILLISECONDS)').replace('.readTimeout(0, TimeUnit.SECONDS)', '.readTimeout(90, TimeUnit.SECONDS)')
s=s.replace('this.uniqueId = "0123456789ABCDEF";', 'this.uniqueId = uniqueId;')
s=s.replace('"devicename=roth&updateState=1&" + additionalArguments', '"devicename=XyCloudStore-" + uniqueId + "&updateState=1&" + additionalArguments')
http.write_text(s)
# Android ships a stripped "BC" provider. Moonlight pairing needs full BouncyCastle RSA.
# Force-install the app-bundled BC before any KeyPairGenerator("RSA", BC) call.
crypto=vendor/'app/src/main/java/com/limelight/binding/crypto/AndroidCryptoProvider.java'
if crypto.exists():
 s=crypto.read_text()
 if 'XyCloudStore BC bootstrap' not in s:
  needle='private static final Provider bcProvider = new BouncyCastleProvider();'
  inject='''private static final Provider bcProvider = new BouncyCastleProvider();

    // XyCloudStore BC bootstrap: Android registers a truncated BC under the same name.
    // Replace it with the full bcprov we ship, otherwise KeyPairGenerator("RSA","BC") fails
    // with NoSuchAlgorithmException during Sunshine pairing.
    static {
        try {
            final Provider existing = java.security.Security.getProvider(BouncyCastleProvider.PROVIDER_NAME);
            if (existing == null || !existing.getClass().equals(BouncyCastleProvider.class)) {
                java.security.Security.removeProvider(BouncyCastleProvider.PROVIDER_NAME);
                java.security.Security.insertProviderAt(new BouncyCastleProvider(), 1);
            }
        } catch (Throwable ignored) {
            try {
                java.security.Security.insertProviderAt(new BouncyCastleProvider(), 1);
            } catch (Throwable ignored2) {}
        }
    }'''
  if needle in s:
   s=s.replace(needle, inject, 1)
   crypto.write_text(s)
mk=vendor/'app/src/main/jni/moonlight-core/Android.mk'
s=mk.read_text().replace('LOCAL_LDFLAGS += -Wl,--exclude-libs,ALL','LOCAL_LDFLAGS += -Wl,--exclude-libs,ALL -Wl,-z,max-page-size=16384');mk.write_text(s)
# Flutter regenerates android/, so changes must be recreated on each build.
android=ROOT/'app/android'
settings=android/'settings.gradle'
if settings.exists():
 s=settings.read_text()
 if "include ':xy_stream'" not in s:s+="\ninclude ':xy_stream'\nproject(':xy_stream').projectDir = file('../../native/xy_stream')\n"
 settings.write_text(s)
project_gradle=android/'build.gradle'
if project_gradle.exists():
 s=project_gradle.read_text()
 if 'https://jitpack.io' not in s:s=s.replace('mavenCentral()', "mavenCentral()\n        maven { url 'https://jitpack.io' }")
 project_gradle.write_text(s)
gradle=android/'app/build.gradle'
if gradle.exists():
 s=gradle.read_text()
 if "implementation project(':xy_stream')" not in s:s+="\ndependencies { implementation project(':xy_stream') }\n"
 gradle.write_text(s)
main=android/'app/src/main/kotlin/id/xycloud/xycloud_order/MainActivity.kt'
main.parent.mkdir(parents=True,exist_ok=True)
main.write_text('''package id.xycloud.xycloud_order
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import id.xycloud.stream.NativeStreaming
import id.xycloud.stream.NotificationSettings
import id.xycloud.stream.XyCrypto
class MainActivity: FlutterActivity() {
    private lateinit var stream: NativeStreaming
    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        // Full BouncyCastle before any GameStream pairing / cert generation
        XyCrypto.ensure()
        stream = NativeStreaming(this)
        val channel = MethodChannel(engine.dartExecutor.binaryMessenger, "xycloud/stream")
        stream.setEvents { event -> channel.invokeMethod("event", event) }
        channel.setMethodCallHandler { call, result ->
            stream.handle(call.method, call.arguments, object: NativeStreaming.Reply {
                override fun ok(value: Any?) { result.success(value) }
                override fun fail(code: String, message: String) { result.error(code, message, null) }
            })
        }
        val notif = NotificationSettings(this)
        notif.ensureChannels()
        MethodChannel(engine.dartExecutor.binaryMessenger, "xycloud/settings").setMethodCallHandler { call, result ->
            try { result.success(notif.handle(call.method, call.arguments)) }
            catch (e: Exception) { result.error("SETTINGS", e.message, null) }
        }
    }
    override fun onDestroy() { if (::stream.isInitialized) stream.detach(); super.onDestroy() }
}
''')
print('Pinned streaming library configured:',cfg['revision'])
