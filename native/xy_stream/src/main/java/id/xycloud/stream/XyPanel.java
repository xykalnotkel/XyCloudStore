package id.xycloud.stream;

import android.app.AlertDialog;
import android.content.Context;
import android.content.DialogInterface;
import android.content.SharedPreferences;
import android.graphics.Color;
import android.text.ClipboardManager;
import android.text.method.ScrollingMovementMethod;
import android.view.View;
import android.view.ViewGroup;
import android.widget.LinearLayout;
import android.widget.RadioButton;
import android.widget.RadioGroup;
import android.widget.ScrollView;
import android.widget.TextView;
import com.limelight.Game;

/**
 * Panel kontrol XyCloudStore (tombol \u2630 di HUD):
 * pilih mode kontrol, lihat log kejadian streaming, dan akhiri video.
 */
public final class XyPanel {
    private static final String PREF = "xy_hud_v1";

    private XyPanel() {
    }

    public static void buka(final Game game, final XyHud hud) {
        final SharedPreferences pref =
                game.getSharedPreferences(PREF, Context.MODE_PRIVATE);
        ScrollView gulir = new ScrollView(game);
        LinearLayout isi = new LinearLayout(game);
        isi.setOrientation(LinearLayout.VERTICAL);
        int m = game.getResources().getDisplayMetrics().density > 1.5 ? 24 : 18;
        isi.setPadding(m, m, m, m);
        gulir.addView(isi, new ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));

        // ---------- mode kontrol ----------
        TextView judulMode = judul(isi, "Mode Kontrol");
        judulMode.setPadding(0, 0, 0, 8);
        RadioGroup grup = new RadioGroup(game);
        grup.setOrientation(LinearLayout.VERTICAL);
        RadioButton rbXy = opsi(grup, "Kontrol XyCloudStore",
                "Keyboard QWERTY, F1\u2013F12, Windows, numpad \u2014 posisi & ukuran bisa diatur",
                !pref.getBoolean("bawaan", false));
        RadioButton rbBawaan = opsi(grup, "Kontrol bawaan (Moonlight)",
                "Overlay bawaan aplikasi streaming di video",
                pref.getBoolean("bawaan", false));
        grup.setOnCheckedChangeListener((g, checkedId) -> {
            boolean bawaan = checkedId == rbBawaan.getId();
            pref.edit().putBoolean("bawaan", bawaan).apply();
            hud.setModeBawaan(bawaan);
            XyLog.tulis(bawaan
                    ? "Mode kontrol: bawaan (Moonlight)."
                    : "Mode kontrol: XyCloudStore (HUD lengkap).");
        });
        isi.addView(grup);

        // ---------- log ----------
        TextView judulLog = judul(isi, "Log Streaming");
        judulLog.setPadding(0, 14, 0, 6);
        final TextView log = new TextView(game);
        log.setTextColor(0xFFD1D5DB);
        log.setTextSize(11f);
        log.setLineSpacing(0, 1.35f);
        log.setMovementMethod(new ScrollingMovementMethod());
        log.setText(XyLog.keTeks());
        LinearLayout bingkaiLog = new LinearLayout(game);
        bingkaiLog.setOrientation(LinearLayout.VERTICAL);
        bingkaiLog.setPadding(10, 10, 10, 10);
        bingkaiLog.addView(log, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, 220));
        isi.addView(bingkaiLog);

        LinearLayout aksi = new LinearLayout(game);
        aksi.setOrientation(LinearLayout.HORIZONTAL);
        aksi.setPadding(0, 8, 0, 0);
        aksi.addView(tombol(aksi, "Muat ulang", v -> log.setText(XyLog.keTeks() + "\n")));
        aksi.addView(tombol(aksi, "Salin log", v -> {
            ClipboardManager cb = (ClipboardManager) game.getSystemService(Context.CLIPBOARD_SERVICE);
            if (cb != null) {
                cb.setText(XyLog.keTeks());
            }
        }));
        aksi.addView(tombol(aksi, "Bersihkan", v -> {
            XyLog.bersihkan();
            log.setText("");
        }));
        isi.addView(aksi);

        TextView catatan = new TextView(game);
        catatan.setTextColor(0xFF9CA3AF);
        catatan.setTextSize(10.5f);
        catatan.setText(
                "Perubahan resolusi, FPS, bitrate, codec, dan trackpad diatur di menu "
                        + "\u201CStreaming & Kontrol\u201D aplikasi dan berlaku saat koneksi berikutnya. "
                        + "Geser \u201C\u2800\u2800\u201D di bilah atas untuk memindahkan posisi kontrol. "
                        + "Tekan Win/Ctrl/Alt/\u21E7 untuk mengaktifkan, tekan lagi untuk melepas.");
        isi.addView(catatan);

        AlertDialog dialog = new AlertDialog.Builder(game)
                .setTitle("Kontrol XyCloudStore")
                .setView(gulir)
                .setPositiveButton("Tutup", null)
                .setNeutralButton("Akhiri Video", (d, w) -> {
                    new AlertDialog.Builder(game)
                            .setTitle("Akhiri video?")
                            .setMessage("Waktu sewa tetap berjalan sampai sesi diakhiri di XyCloudStore.")
                            .setNegativeButton("Batal", null)
                            .setPositiveButton("Akhiri", (d2, w2) -> game.finish())
                            .show();
                })
                .show();
        // muat ulang log otomatis tiap 1,5 dtk selama panel terbuka
        final android.os.Handler hand = new android.os.Handler();
        final Runnable hidup = new Runnable() {
            @Override
            public void run() {
                log.setText(XyLog.keTeks() + "\n");
                hand.postDelayed(this, 1500);
            }
        };
        dialog.getWindow().getDecorView().addOnAttachStateChangeListener(
                new View.OnAttachStateChangeListener() {
                    @Override
                    public void onViewAttachedToWindow(View v) {
                        hand.postDelayed(hidup, 1500);
                    }

                    @Override
                    public void onViewDetachedFromWindow(View v) {
                        hand.removeCallbacks(hidup);
                    }
                });
    }

    private static TextView judul(LinearLayout parent, String teks) {
        TextView t = new TextView(parent.getContext());
        t.setText(teks);
        t.setTextColor(Color.WHITE);
        t.setTextSize(15f);
        t.setTypeface(android.graphics.Typeface.DEFAULT_BOLD);
        return t;
    }

    private static RadioButton opsi(RadioGroup grup, String judul, String sub, boolean aktif) {
        RadioButton b = new RadioButton(grup.getContext());
        b.setText(judul + "\n" + sub);
        b.setTextColor(0xFFE5E7EB);
        b.setTextSize(12.5f);
        b.setButtonTintList(null);
        b.setChecked(aktif);
        grup.addView(b, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));
        return b;
    }

    private static TextView tombol(LinearLayout parent, String label,
                                   android.view.View.OnClickListener aksi) {
        TextView b = new TextView(parent.getContext());
        b.setText(label);
        b.setTextColor(0xFFC4B5FD);
        b.setTextSize(12.5f);
        b.setTypeface(android.graphics.Typeface.DEFAULT_BOLD);
        b.setPadding(14, 8, 14, 8);
        b.setOnClickListener(aksi);
        parent.addView(b, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT));
        return b;
    }
}
