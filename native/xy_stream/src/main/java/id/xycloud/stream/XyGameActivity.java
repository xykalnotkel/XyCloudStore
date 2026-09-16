package id.xycloud.stream;

import android.os.Bundle;
import com.limelight.Game;
import java.util.HashMap;
import java.util.Map;

/**
 * Renderer full-screen + kontrol XyCloudStore, dalam satu APK yang sama.
 * HUD lengkap (QWERTY/F1-F12/Windows/numpad, posisi & ukuran dapat diatur)
 * dipasang oleh XyHud; panel kontrol oleh XyPanel; log kejadian oleh XyLog.
 */
public class XyGameActivity extends Game {
    private XyHud hud;
    private boolean connected;
    private boolean terminated;

    @Override
    public void onCreate(Bundle state) {
        XyCrypto.ensure();
        String namaApp = "?";
        if (getIntent() != null) {
            namaApp = getIntent().getStringExtra(Game.EXTRA_APP_NAME);
            if (namaApp == null) {
                namaApp = "?";
            }
        }
        XyLog.tulis("Layar streaming dibuka (aplikasi host: " + namaApp + ").");
        super.onCreate(state);
        hud = new XyHud(this);
        hud.attach(findViewById(android.R.id.content));
        if (hud.modeBawaan()) {
            XyLog.tulis("Mode kontrol: bawaan (Moonlight).");
        } else {
            XyLog.tulis("Kontrol XyCloudStore siap — tombol \u2630 membuka panel kontrol.");
        }
    }

    @Override
    public void connectionStarted() {
        connected = true;
        super.connectionStarted();
        XyLog.tulis("Video terhubung ke host. Mulai main!");
        Map<String,Object> info = new HashMap<>();
        info.put("reconnectable", false);
        NativeStreaming.emit("connected", "Video terhubung.", info);
    }

    @Override
    public void stageFailed(String stage, int ports, int code) {
        XyLog.tulis("Tahap " + stage + " gagal (kode " + code + ").");
        Map<String,Object> info = new HashMap<>();
        info.put("stage", stage);info.put("ports", ports);info.put("code", code);
        info.put("reconnectable", true);
        NativeStreaming.emit("error", "Tahap " + stage + " gagal (" + code + "). Port streaming host kemungkinan tertutup dari internet: buka/forward 47984-47990 (TCP+UDP) dan 48010 di PC (router/firewall, atau NSG/Security Group untuk VM cloud), lalu coba lagi.", info);
        super.stageFailed(stage, ports, code);
    }

    @Override
    public void connectionTerminated(int code) {
        terminated = true;
        XyLog.tulis("Koneksi video berakhir (kode " + code + ").");
        Map<String,Object> info = new HashMap<>();
        info.put("code", code);info.put("reconnectable", true);
        NativeStreaming.emit("disconnected", "Koneksi video berakhir (" + code + ").", info);
        super.connectionTerminated(code);
    }

    @Override
    protected void onPause() {
        if (hud != null) hud.lepasSemua();
        super.onPause();
    }

    @Override
    protected void onDestroy() {
        XyLog.tulis("Layar streaming ditutup.");
        if (hud != null) hud.lepasSemua();
        super.onDestroy();
        Map<String,Object> info = new HashMap<>();
        info.put("manual", !terminated);info.put("reconnectable", terminated);
        NativeStreaming.emit("closed",
                connected && !terminated ? "Kembali ke sesi. Waktu sewa tetap berjalan." : "Layar streaming ditutup.", info);
    }
}
