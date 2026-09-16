package id.xycloud.stream;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;

import java.util.Locale;
import java.util.regex.Pattern;

/**
 * Penerima deep link atribusi referral untuk APK sideload.
 *
 * Activity ini tidak mempercayai kode referral dan tidak memberi reward.
 * Ia hanya menyimpan capability ticket ke SharedPreferences privat. Flutter
 * kemudian mengikat ticket ke identitas instalasi lewat API; server tetap
 * memeriksa unduhan, umur akun, verifikasi email, perangkat, dan single-use.
 */
public final class ReferralActivity extends Activity {
    static final String PREFS = "xycloud_referral_attribution";
    static final String KEY_TICKET = "ticket";
    static final String KEY_CODE = "code";
    static final String KEY_CAPTURED_AT = "captured_at";
    private static final Pattern TICKET = Pattern.compile("^[a-fA-F0-9]{64}$");
    private static final Pattern CODE = Pattern.compile("^[A-Z0-9]{6,16}$");

    @Override
    protected void onCreate(Bundle state) {
        super.onCreate(state);
        capture(getIntent());
        openApplication();
        finish();
    }

    private void capture(Intent intent) {
        Uri uri = intent == null ? null : intent.getData();
        if (uri == null || !"xycloudstore".equalsIgnoreCase(uri.getScheme())
                || !"referral".equalsIgnoreCase(uri.getHost())) return;

        String ticket = uri.getQueryParameter("ticket");
        if (ticket == null || !TICKET.matcher(ticket).matches()) return;
        ticket = ticket.toLowerCase(Locale.US);

        String code = uri.getQueryParameter("code");
        code = code == null ? "" : code.trim().toUpperCase(Locale.US);
        if (!CODE.matcher(code).matches()) code = "";

        getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                .putString(KEY_TICKET, ticket)
                .putString(KEY_CODE, code)
                .putLong(KEY_CAPTURED_AT, System.currentTimeMillis())
                .apply();
    }

    private void openApplication() {
        Intent launch = getPackageManager().getLaunchIntentForPackage(getPackageName());
        if (launch == null) return;
        launch.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP | Intent.FLAG_ACTIVITY_SINGLE_TOP);
        startActivity(launch);
    }
}
