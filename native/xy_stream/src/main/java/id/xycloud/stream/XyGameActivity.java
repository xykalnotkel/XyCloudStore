package id.xycloud.stream;

import android.os.Bundle;
import com.limelight.Game;

/**
 * Renderer full-screen + kontrol XyCloudStore, dalam satu APK yang sama.
 * HUD lengkap (QWERTY/F1-F12/Windows/numpad, posisi & ukuran dapat diatur)
 * dipasang oleh XyHud; panel kontrol oleh XyPanel; log kejadian oleh XyLog.
 */
public class XyGameActivity extends Game {
    private XyHud hud;
    private boolean connected;

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
        NativeStreaming.emit("connected", "Video terhubung.");
    }

    @Override
    public void stageFailed(String stage, int ports, int code) {
        XyLog.tulis("Tahap " + stage + " gagal (kode " + code + ").");
        NativeStreaming.emit("error", "Tahap " + stage + " gagal (" + code + "). Port streaming host kemungkinan tertutup dari internet: buka/forward 47984-47990 (TCP+UDP) dan 48010 di PC (router/firewall, atau NSG/Security Group untuk VM cloud), lalu coba lagi.");
        super.stageFailed(stage, ports, code);
    }

    @Override
    public void connectionTerminated(int code) {
        XyLog.tulis("Koneksi video berakhir (kode " + code + ").");
        NativeStreaming.emit("disconnected", "Koneksi video berakhir (" + code + ").");
        super.connectionTerminated(code);
    }

    @Override
    protected void onDestroy() {
        XyLog.tulis("Layar streaming ditutup.");
        super.onDestroy();
        NativeStreaming.emit("closed",
                connected ? "Kembali ke sesi. Waktu sewa tetap berjalan." : "Layar streaming ditutup.");
    }
}
