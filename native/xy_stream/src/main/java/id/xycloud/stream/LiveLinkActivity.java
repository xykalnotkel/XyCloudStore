package id.xycloud.stream;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;

import java.util.regex.Pattern;

/** Menangkap xycloudstore://live?id=... tanpa membawa token atau stream key. */
public final class LiveLinkActivity extends Activity {
    static final String PREFS = "xycloud_live_link";
    static final String KEY_ID = "live_id";
    private static final Pattern LIVE_ID = Pattern.compile("^[A-Za-z0-9_-]{8,80}$");

    @Override
    protected void onCreate(Bundle state) {
        super.onCreate(state);
        Uri uri = getIntent() == null ? null : getIntent().getData();
        if (uri != null && "xycloudstore".equalsIgnoreCase(uri.getScheme())
                && "live".equalsIgnoreCase(uri.getHost())) {
            String id = uri.getQueryParameter("id");
            if (id != null && LIVE_ID.matcher(id).matches()) {
                // Commit sebelum membuka MainActivity: proses dapat dihentikan
                // sesaat setelah activity trampoline selesai, jadi apply() tidak
                // cukup kuat untuk menjamin handoff deep-link tetap tersedia.
                getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                        .putString(KEY_ID, id).commit();
            }
        }
        Intent launch = getPackageManager().getLaunchIntentForPackage(getPackageName());
        if (launch != null) {
            launch.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP | Intent.FLAG_ACTIVITY_SINGLE_TOP);
            startActivity(launch);
        }
        finish();
    }
}
