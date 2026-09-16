package id.xycloud.stream;

import android.content.Context;
import android.content.SharedPreferences;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.os.Handler;
import android.os.Looper;
import android.view.Gravity;
import android.view.KeyEvent;
import android.view.MotionEvent;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import com.limelight.Game;

import java.util.ArrayList;
import java.util.List;

/**
 * Kontrol XyCloudStore — HUD lengkap di atas video streaming.
 *
 * Berisi keyboard QWERTY penuh (huruf, angka, simbol, spasi, backspace),
 * tombol F1–F12 + Esc/Tab/Caps, numpad, serta modifikator
 * Windows/Ctrl/Alt/Shift yang bisa diaktifkan (toggle) lalu dilepas —
 * kombinasi seperti Win+R tetap jalan.
 *
 * Posisi dapat digeser (drag dari pegangan di bilah atas), ukuran dapat
 * diubah (A\u2212/A+), dan semua kondisi (panel tampil/tersembunyi, posisi,
 * skala) disimpan di SharedPreferences sehingga konsisten antar sesi.
 */
public final class XyHud {
    private static final String PREF = "xy_hud_v1";
    private static final int WARNA_LAT = 0xD91B2430;   // panel gelap tembus
    private static final int WARNA_KUNCI = 0xB3FFFFFF; // teks
    private static final int WARNA_AKIF = 0xCC7C3AED;  // ungu XyCloudStore

    private final Game game;
    private final Context ctx;
    private final SharedPreferences pref;
    private final Handler hand = new Handler(Looper.getMainLooper());

    private View toolbar;
    private LinearLayout keyboardRoot;
    private LinearLayout panelQwerty;
    private LinearLayout panelFkey;
    private LinearLayout panelNumpad;
    private LinearLayout panelSimbol;
    private Button tombolFly; // tombol melayang "XY" saat HUD disembunyikan

    private final List<Button> tombolHuruf = new ArrayList<>();
    private final List<String> labelHuruf = new ArrayList<>();
    private final List<Button> tombolMod = new ArrayList<>();

    private float skala = 1f;
    private int meta = 0; // modifikator aktif (toggle) untuk kunci berikutnya

    public XyHud(Game game) {
        this.game = game;
        this.ctx = game;
        this.pref = game.getSharedPreferences(PREF, Context.MODE_PRIVATE);
        this.skala = clamp(pref.getFloat("skala", 1f), 0.7f, 1.4f);
    }

    /** Pasang HUD ke konten activity. Panggil sekali setelah super.onCreate(). */
    public void attach(ViewGroup root) {
        // ---------- bilah atas (draggable) ----------
        toolbar = new FrameLayout(ctx);
        LinearLayout baris = new LinearLayout(ctx);
        baris.setOrientation(LinearLayout.HORIZONTAL);
        baris.setGravity(Gravity.CENTER_VERTICAL);
        baris.setPadding(dp(6), dp(4), dp(6), dp(4));
        baris.setBackground(mbulat(14, WARNA_LAT));

        Button drag = tombolTekan("\u2800\u2800");
        drag.setHint("Geser");
        drag.setOnTouchListener(new GeserPenangan());
        baris.addView(drag, new LinearLayout.LayoutParams(dp(36), dp(38)));

        baris.addView(tombolMode("ABC", pref.getBoolean("qwerty", true),
                () -> setelPanel("qwerty", panelQwerty)), dp(46));
        baris.addView(tombolMode("F", pref.getBoolean("fkey", false),
                () -> setelPanel("fkey", panelFkey)), dp(34));
        baris.addView(tombolMode("NUM", pref.getBoolean("numpad", false),
                () -> setelPanel("numpad", panelNumpad)), dp(46));
        baris.addView(pemisah());
        Button minus = tombolTekan("A\u2212");
        minus.setOnClickListener(v -> aturSkala(-0.1f));
        baris.addView(minus, new LinearLayout.LayoutParams(dp(40), dp(38)));
        Button plus = tombolTekan("A+");
        plus.setOnClickListener(v -> aturSkala(0.1f));
        baris.addView(plus, new LinearLayout.LayoutParams(dp(40), dp(38)));
        baris.addView(pemisah());
        Button panel = tombolTekan("\u2630");
        panel.setOnClickListener(v -> XyPanel.buka(game, this));
        baris.addView(panel, new LinearLayout.LayoutParams(dp(42), dp(38)));
        Button semb = tombolTekan("\u2715");
        semb.setOnClickListener(v -> sembunyikan());
        baris.addView(semb, new LinearLayout.LayoutParams(dp(40), dp(38)));

        toolbar.addView(baris, new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT,
                Gravity.TOP | Gravity.CENTER_HORIZONTAL));
        root.addView(toolbar, new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT,
                Gravity.TOP | Gravity.CENTER_HORIZONTAL));
        toolbar.setTranslationY(dp(6));

        // ---------- akar papan kontrol (bawah layar, digeser lewat bilah atas) ----------
        keyboardRoot = new LinearLayout(ctx);
        keyboardRoot.setOrientation(LinearLayout.VERTICAL);
        keyboardRoot.setPadding(dp(8), 0, dp(8), dp(8));

        panelFkey = buatPanelFkey();
        panelQwerty = buatPanelQwerty();
        panelNumpad = buatPanelNumpad();

        keyboardRoot.addView(panelFkey, lebarLengkap());
        keyboardRoot.addView(panelQwerty, lebarLengkap());
        keyboardRoot.addView(panelNumpad, lebarLengkap());

        root.addView(keyboardRoot, new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT,
                Gravity.BOTTOM | Gravity.CENTER_HORIZONTAL));

        terapkanKeadaan();

        // ---------- tombol melayang untuk memunculkan ulang ----------
        tombolFly = new Button(ctx);
        tombolFly.setText("XY");
        tombolFly.setTextSize(12);
        tombolFly.setTextColor(Color.WHITE);
        tombolFly.setBackground(mbulat(16, 0xE6263541));
        tombolFly.setOnClickListener(v -> tampilkan());
        tombolFly.setVisibility(View.GONE);
        root.addView(tombolFly, new FrameLayout.LayoutParams(
                dp(46), dp(46), Gravity.TOP | Gravity.END));
        tombolFly.setTranslationX(-dp(8));
        tombolFly.setTranslationY(dp(6));
    }

    // ================= tampil / sembunyi =================

    public void tampilkan() {
        if (toolbar == null) {
            return;
        }
        toolbar.setVisibility(View.VISIBLE);
        if (keyboardRoot != null) {
            keyboardRoot.setVisibility(View.VISIBLE);
        }
        tombolFly.setVisibility(View.GONE);
        pref.edit().putBoolean("bawaan", false).apply();
        XyLog.tulis("Kontrol XyCloudStore ditampilkan.");
    }

    public void sembunyikan() {
        if (toolbar == null) {
            return;
        }
        toolbar.setVisibility(View.GONE);
        if (keyboardRoot != null) {
            keyboardRoot.setVisibility(View.GONE);
        }
        tombolFly.setVisibility(View.VISIBLE);
        pref.edit().putBoolean("bawaan", true).apply();
        XyLog.tulis("Kontrol XyCloudStore disembunyikan (tombol XY untuk kembali).");
    }

    /** Dipanggil panel kontrol saat mode "bawaan" dipilih. */
    public void setModeBawaan(boolean bawaan) {
        if (bawaan) {
            sembunyikan();
        } else {
            tampilkan();
        }
    }

    public boolean modeBawaan() {
        return pref.getBoolean("bawaan", false);
    }

    private void terapkanKeadaan() {
        panelQwerty.setVisibility(pref.getBoolean("qwerty", true) ? View.VISIBLE : View.GONE);
        panelFkey.setVisibility(pref.getBoolean("fkey", false) ? View.VISIBLE : View.GONE);
        panelNumpad.setVisibility(pref.getBoolean("numpad", false) ? View.VISIBLE : View.GONE);
        panelSimbol.setVisibility(pref.getBoolean("simbol", false) ? View.VISIBLE : View.GONE);
        terapkanSkala();
        keyboardRoot.setTranslationX(pref.getFloat("px", 0f) * layarLebar());
        keyboardRoot.setTranslationY(-pref.getFloat("py", 0f) * layarTinggi());
    }

    private void setelPanel(String key, View panel) {
        boolean tampil = panel.getVisibility() == View.VISIBLE;
        panel.setVisibility(tampil ? View.GONE : View.VISIBLE);
        pref.edit().putBoolean(key, !tampil).apply();
    }

    private void terapkanSkala() {
        keyboardRoot.setScaleX(skala);
        keyboardRoot.setScaleY(skala);
        // pivot bawah-tengah: membesar tetap menempel ke dasar layar
        keyboardRoot.setPivotX(keyboardRoot.getWidth() / 2f);
        keyboardRoot.setPivotY(keyboardRoot.getHeight());
    }

    private void aturSkala(float delta) {
        skala = clamp(skala + delta, 0.7f, 1.4f);
        pref.edit().putFloat("skala", skala).apply();
        terapkanSkala();
    }

    // ================= pengantar kunci =================

    /** Satu ketukan (turun + naik) dengan modifikator yang sedang aktif. */
    private void ketuk(int kode) {
        int m = meta;
        game.xySendKey(kode, false, m);
        final int kodeFinal = kode;
        hand.postDelayed(() -> game.xySendKey(kodeFinal, true, 0), 55);
    }

    /** Teks apa pun (simbol tanpa pemetaan kode Android). */
    private void ketukTeks(String teks) {
        game.xySendText(teks);
    }

    /** Modifikator toggle: tekan untuk aktif, tekan lagi untuk lepas. */
    private void togelMod(int kode, int bit) {
        if ((meta & bit) != 0) {
            meta &= ~bit;
            game.xySendKey(kode, true, 0);
        } else {
            meta |= bit;
            game.xySendKey(kode, false, meta);
        }
        warnaModifikator();
        perbaruiLabelHuruf();
    }

    private void warnaModifikator() {
        for (Button b : tombolMod) {
            Object tag = b.getTag();
            if (tag instanceof Integer) {
                boolean aktif = (meta & (Integer) tag) != 0;
                b.setBackground(mbulat(9, aktif ? WARNA_AKIF : WARNA_LAT));
                b.setTextColor(aktif ? Color.WHITE : WARNA_KUNCI);
            }
        }
    }

    private void perbaruiLabelHuruf() {
        boolean shift = (meta & KeyEvent.META_SHIFT_ON) != 0;
        for (int i = 0; i < tombolHuruf.size(); i++) {
            String dasar = labelHuruf.get(i);
            tombolHuruf.get(i).setText(shift ? dasar.toUpperCase() : dasar);
        }
    }

    // ================= panel QWERTY =================

    private LinearLayout buatPanelQwerty() {
        LinearLayout p = panelBawaan();

        // baris 1: Esc Tab Q..P Backspace
        LinearLayout r1 = baris();
        r1.addView(tombolKode("Esc", KeyEvent.KEYCODE_ESCAPE, 1f));
        r1.addView(tombolKode("Tab", KeyEvent.KEYCODE_TAB, 1f));
        for (int i = 0; i < 10; i++) {
            r1.addView(tombolHuruf((char) ('q' + i), 1f));
        }
        r1.addView(tombolKode("\u232B", KeyEvent.KEYCODE_DEL, 1.15f));
        p.addView(r1, lebarLengkap());

        // baris 2: Ctrl Win A..L Enter
        LinearLayout r2 = baris();
        r2.addView(tombolMod("Ctrl", KeyEvent.KEYCODE_CTRL_LEFT,
                KeyEvent.META_CTRL_ON, 1.5f));
        r2.addView(tombolMod("Win", KeyEvent.KEYCODE_META_LEFT,
                KeyEvent.META_META_ON, 1.5f));
        for (int i = 0; i < 9; i++) {
            r2.addView(tombolHuruf((char) ('a' + i), 1f));
        }
        r2.addView(tombolKode("\u21B5", KeyEvent.KEYCODE_ENTER, 1.9f));
        p.addView(r2, lebarLengkap());

        // baris 3: Alt Shift Z..M ?123
        LinearLayout r3 = baris();
        r3.addView(tombolMod("Alt", KeyEvent.KEYCODE_ALT_LEFT,
                KeyEvent.META_ALT_ON, 1.5f));
        r3.addView(tombolMod("\u21E7", KeyEvent.KEYCODE_SHIFT_LEFT,
                KeyEvent.META_SHIFT_ON, 1.5f));
        for (int i = 0; i < 7; i++) {
            r3.addView(tombolHuruf((char) ('z' + i), 1f));
        }
        Button sim = tombolKode("?123", 0, 1.7f);
        sim.setOnClickListener(v -> {
            boolean tampil = panelSimbol.getVisibility() == View.VISIBLE;
            panelSimbol.setVisibility(tampil ? View.GONE : View.VISIBLE);
            pref.edit().putBoolean("simbol", !tampil).apply();
        });
        r3.addView(sim);
        p.addView(r3, lebarLengkap());

        // baris 4: angka 1..9 0
        LinearLayout r4 = baris();
        for (int i = 1; i <= 9; i++) {
            r4.addView(tombolKode(String.valueOf(i),
                    KeyEvent.KEYCODE_0 + i, 1f));
        }
        r4.addView(tombolKode("0", KeyEvent.KEYCODE_0, 1f));
        p.addView(r4, lebarLengkap());

        // baris 5–6: simbol (opsional)
        panelSimbol = new LinearLayout(ctx);
        panelSimbol.setOrientation(LinearLayout.VERTICAL);
        panelSimbol.setPadding(dp(2), dp(4), dp(2), dp(2));
        LinearLayout s1 = baris();
        String[][] simb1 = {
                {"!", "1"}, {"@", "2"}, {"#", "3"}, {"$", "4"}, {"%", "5"},
                {"^", "6"}, {"&", "7"}, {"*", "8"}, {"(", "9"}, {")", "0"},
                {"-", "-"}, {"=", "="}, {"[", "["}, {"]", "]"},
        };
        for (String[] s : simb1) {
            s1.addView(tombolSimbol(s[0], s[1], 1f));
        }
        panelSimbol.addView(s1, lebarLengkap());
        LinearLayout s2 = baris();
        String[][] simb2 = {
                {";", ";"}, {":", ":"}, {"'", "'"}, {"\"", "\""}, {",", ","},
                {".", "."}, {"/", "/"}, {"?", "?"}, {"_", "_"}, {"+", "+"},
                {"{", "{"}, {"}", "}"}, {"|", "|"}, {"~", "~"},
                {"\u232B", "del"},
        };
        for (String[] s : simb2) {
            s2.addView(tombolSimbol(s[0], s[1], 1f));
        }
        panelSimbol.addView(s2, lebarLengkap());
        p.addView(panelSimbol, lebarLengkap());

        return p;
    }

    private LinearLayout buatPanelFkey() {
        LinearLayout p = panelBawaan();
        LinearLayout r1 = baris();
        r1.addView(tombolKode("Esc", KeyEvent.KEYCODE_ESCAPE, 1f));
        r1.addView(tombolKode("Tab", KeyEvent.KEYCODE_TAB, 1f));
        for (int i = 1; i <= 6; i++) {
            r1.addView(tombolKode("F" + i, KeyEvent.KEYCODE_F1 + (i - 1), 1f));
        }
        r1.addView(tombolKode("Caps", KeyEvent.KEYCODE_CAPS_LOCK, 1f));
        p.addView(r1, lebarLengkap());
        LinearLayout r2 = baris();
        for (int i = 7; i <= 12; i++) {
            r2.addView(tombolKode("F" + i, KeyEvent.KEYCODE_F1 + (i - 1), 1f));
        }
        p.addView(r2, lebarLengkap());
        return p;
    }

    private LinearLayout buatPanelNumpad() {
        LinearLayout p = panelBawaan();
        int n0 = KeyEvent.KEYCODE_NUMPAD_0;

        LinearLayout r1 = baris();
        r1.addView(tombolNumpad("7", n0 + 7, 1f));
        r1.addView(tombolNumpad("8", n0 + 8, 1f));
        r1.addView(tombolNumpad("9", n0 + 9, 1f));
        r1.addView(tombolNumpad("/", KeyEvent.KEYCODE_NUMPAD_DIVIDE, 1f));
        p.addView(r1, lebarLengkap());

        LinearLayout r2 = baris();
        r2.addView(tombolNumpad("4", n0 + 4, 1f));
        r2.addView(tombolNumpad("5", n0 + 5, 1f));
        r2.addView(tombolNumpad("6", n0 + 6, 1f));
        r2.addView(tombolNumpad("*", KeyEvent.KEYCODE_NUMPAD_MULTIPLY, 1f));
        p.addView(r2, lebarLengkap());

        LinearLayout r3 = baris();
        r3.addView(tombolNumpad("1", n0 + 1, 1f));
        r3.addView(tombolNumpad("2", n0 + 2, 1f));
        r3.addView(tombolNumpad("3", n0 + 3, 1f));
        r3.addView(tombolNumpad("-", KeyEvent.KEYCODE_NUMPAD_SUBTRACT, 1f));
        p.addView(r3, lebarLengkap());

        LinearLayout r4 = baris();
        r4.addView(tombolNumpad("0", n0, 2f));
        r4.addView(tombolNumpad(".", KeyEvent.KEYCODE_NUMPAD_DOT, 1f));
        r4.addView(tombolNumpad("+", KeyEvent.KEYCODE_NUMPAD_ADD, 2f));
        p.addView(r4, lebarLengkap());

        LinearLayout r5 = baris();
        r5.addView(tombolNumpad("Enter", KeyEvent.KEYCODE_NUMPAD_ENTER, 5f));
        p.addView(r5, lebarLengkap());

        return p;
    }

    // ================= pembangun widget =================

    private LinearLayout panelBawaan() {
        LinearLayout p = new LinearLayout(ctx);
        p.setOrientation(LinearLayout.VERTICAL);
        p.setBackground(mbulat(18, WARNA_LAT));
        p.setPadding(dp(8), dp(5), dp(8), dp(5));
        return p;
    }

    private LinearLayout baris() {
        LinearLayout b = new LinearLayout(ctx);
        b.setOrientation(LinearLayout.HORIZONTAL);
        b.setPadding(0, dp(2), 0, dp(2));
        return b;
    }

    private LinearLayout.LayoutParams lebarLengkap() {
        return new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
    }

    private View pemisah() {
        View v = new View(ctx);
        v.setBackgroundColor(0x59FFFFFF);
        return v;
    }

    private LinearLayout.LayoutParams lpToolbar(int lebarDp) {
        return new LinearLayout.LayoutParams(lebarDp, dp(38));
    }

    /** Tombol mode (ABC/F/NUM): menandai panel aktif. */
    private Button tombolMode(String label, boolean awal, Runnable aksi) {
        Button b = tombolTekan(label);
        b.setTag(awal);
        catatMode(b);
        b.setOnClickListener(v -> {
            boolean aktif = Boolean.valueOf(v.getTag()) != Boolean.TRUE;
            v.setTag(aktif);
            aksi.run();
            catatMode(b);
        });
        return b;
    }

    private void catatMode(Button b) {
        boolean aktif = Boolean.valueOf(b.getTag());
        b.setBackground(mbulat(9, aktif ? WARNA_AKIF : WARNA_LAT));
        b.setTextColor(aktif ? Color.WHITE : WARNA_KUNCI);
    }

    private Button tombolTekan(String label) {
        Button b = new Button(ctx);
        b.setText(label);
        b.setTextSize(12.5f);
        b.setTextColor(WARNA_KUNCI);
        b.setBackground(mbulat(9, WARNA_LAT));
        b.setMinWidth(0);
        b.setMinHeight(0);
        b.setMinimumWidth(0);
        b.setAllCaps(false);
        b.setPadding(dp(2), 0, dp(2), 0);
        return b;
    }

    private Button tombolHuruf(char hurufBawah, float bobot) {
        Button b = kunciBasis(String.valueOf(hurufBawah), bobot, 13.5f);
        tombolHuruf.add(b);
        labelHuruf.add(String.valueOf(hurufBawah));
        final int kode = KeyEvent.KEYCODE_A + (Character.toUpperCase(hurufBawah) - 'A');
        b.setOnClickListener(v -> ketuk(kode));
        return b;
    }

    private Button tombolNumpad(String label, int kode, float bobot) {
        Button b = tombolKode(label, kode, bobot);
        b.setTextSize(14f);
        return b;
    }

    /** Kunci modifikator (Win/Ctrl/Alt/Shift) — toggle. */
    private Button tombolMod(String label, int kode, int bit, float bobot) {
        Button b = kunciBasis(label, bobot, 11.5f);
        b.setTag(bit);
        b.setOnClickListener(v -> togelMod(kode, bit));
        tombolMod.add(b);
        return b;
    }

    /** Simbol: kode dasar + shift bila perlu, atau teks langsung. */
    private Button tombolSimbol(String label, String kodeDasar, float bobot) {
        Button b = kunciBasis(label, bobot, 13f);
        b.setOnClickListener(v -> {
            int kc;
            int extra = 0;
            switch (kodeDasar) {
                case "1": case "2": case "3": case "4": case "5":
                case "6": case "7": case "8": case "9": case "0":
                    kc = KeyEvent.KEYCODE_0 + Integer.parseInt(kodeDasar);
                    extra = KeyEvent.META_SHIFT_ON;
                    break;
                case "-": kc = KeyEvent.KEYCODE_MINUS; break;
                case "=": kc = KeyEvent.KEYCODE_EQUALS; break;
                case "[": kc = KeyEvent.KEYCODE_LEFT_BRACKET; break;
                case "]": kc = KeyEvent.KEYCODE_RIGHT_BRACKET; break;
                case ";": kc = KeyEvent.KEYCODE_SEMICOLON; break;
                case ":": kc = KeyEvent.KEYCODE_SEMICOLON;
                    extra = KeyEvent.META_SHIFT_ON;
                    break;
                case "'": kc = KeyEvent.KEYCODE_APOSTROPHE; break;
                case "\"": kc = KeyEvent.KEYCODE_APOSTROPHE;
                    extra = KeyEvent.META_SHIFT_ON;
                    break;
                case ",": kc = KeyEvent.KEYCODE_COMMA; break;
                case ".": kc = KeyEvent.KEYCODE_PERIOD; break;
                case "/": kc = KeyEvent.KEYCODE_SLASH; break;
                case "?": kc = KeyEvent.KEYCODE_SLASH;
                    extra = KeyEvent.META_SHIFT_ON;
                    break;
                case "_": kc = KeyEvent.KEYCODE_MINUS;
                    extra = KeyEvent.META_SHIFT_ON;
                    break;
                case "+": kc = KeyEvent.KEYCODE_EQUALS;
                    extra = KeyEvent.META_SHIFT_ON;
                    break;
                case "del":
                    ketuk(KeyEvent.KEYCODE_DEL);
                    return;
                default:
                    ketukTeks(label);
                    return;
            }
            int m = meta | extra;
            game.xySendKey(kc, false, m);
            final int kodeAkhir = kc;
            hand.postDelayed(() -> game.xySendKey(kodeAkhir, true, 0), 55);
        });
        return b;
    }

    /** Tombol kunci standar: label + kode Android + bobot lebar. */
    private Button tombolKode(String label, int kode, float bobot) {
        Button b = kunciBasis(label, bobot, kode == 0 ? 11f : 13.5f);
        if (kode != 0) {
            b.setOnClickListener(v -> ketuk(kode));
        }
        return b;
    }

    private Button kunciBasis(String label, float bobot, float ukuran) {
        Button b = new Button(ctx);
        b.setText(label);
        b.setTextSize(ukuran);
        b.setTypeface(Typeface.DEFAULT_BOLD);
        b.setTextColor(WARNA_KUNCI);
        b.setBackground(mbulat(9, WARNA_LAT));
        b.setMinWidth(0);
        b.setMinHeight(0);
        b.setMinimumWidth(0);
        b.setAllCaps(false);
        b.setPadding(0, 0, 0, 0);
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(0, dp(48), bobot);
        lp.setMargins(dp(2), 0, dp(2), 0);
        b.setLayoutParams(lp);
        return b;
    }

    // ================= drag posisi =================

    /** Geser pegangan di bilah atas = geser seluruh papan kontrol. */
    private class GeserPenangan implements View.OnTouchListener {
        private float awalX, awalY, mulaiTx, mulaiTy;

        @Override
        public boolean onTouch(View v, MotionEvent e) {
            switch (e.getActionMasked()) {
                case MotionEvent.ACTION_DOWN:
                    awalX = e.getRawX();
                    awalY = e.getRawY();
                    mulaiTx = keyboardRoot.getTranslationX();
                    mulaiTy = keyboardRoot.getTranslationY();
                    return true;
                case MotionEvent.ACTION_MOVE:
                    keyboardRoot.setTranslationX(mulaiTx + (e.getRawX() - awalX));
                    keyboardRoot.setTranslationY(mulaiTy + (e.getRawY() - awalY));
                    return true;
                case MotionEvent.ACTION_UP:
                    pref.edit()
                            .putFloat("px", keyboardRoot.getTranslationX() / layarLebar())
                            .putFloat("py", -keyboardRoot.getTranslationY() / layarTinggi())
                            .apply();
                    XyLog.tulis("Posisi kontrol disimpan.");
                    return true;
                default:
                    return false;
            }
        }
    }

    // ================= util =================

    private GradientDrawable mbulat(int radiusDp, int warna) {
        GradientDrawable d = new GradientDrawable();
        d.setColor(warna);
        d.setCornerRadius(dp(radiusDp));
        return d;
    }

    private int dp(int n) {
        return Math.round(n * ctx.getResources().getDisplayMetrics().density);
    }

    private int layarLebar() {
        return ctx.getResources().getDisplayMetrics().widthPixels;
    }

    private int layarTinggi() {
        return ctx.getResources().getDisplayMetrics().heightPixels;
    }

    private static float clamp(float v, float min, float max) {
        return Math.max(min, Math.min(max, v));
    }
}
