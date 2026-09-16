package id.xycloud.stream;

import java.text.SimpleDateFormat;
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Date;
import java.util.List;
import java.util.Locale;

/**
 * Ring buffer log kejadian streaming (maks 80 baris).
 * Dibaca panel kontrol HUD dan bisa disalin pengguna.
 */
public final class XyLog {
    private static final int MAKS = 80;
    private static final ArrayDeque<String> BARIS = new ArrayDeque<>();
    private static final SimpleDateFormat FMT =
            new SimpleDateFormat("HH:mm:ss", Locale.US);

    private XyLog() {
    }

    public static synchronized void tulis(String pesan) {
        if (pesan == null) {
            return;
        }
        String baris = FMT.format(new Date()) + "  " + pesan.replace('\n', ' ');
        BARIS.addLast(baris);
        while (BARIS.size() > MAKS) {
            BARIS.removeFirst();
        }
        // turut diteruskan ke layar sesi di aplikasi (panel log singkat)
        try {
            NativeStreaming.emitLog(pesan);
        } catch (Throwable ignored) {
        }
    }

    public static synchronized List<String> semua() {
        return new ArrayList<>(BARIS);
    }

    public static synchronized String keTeks() {
        StringBuilder b = new StringBuilder();
        for (String s : BARIS) {
            b.append(s).append('\n');
        }
        return b.toString();
    }

    public static synchronized void bersihkan() {
        BARIS.clear();
    }
}
