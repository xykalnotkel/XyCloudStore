package id.xycloud.stream;
import android.app.Activity;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.content.Intent;
import android.media.AudioAttributes;
import android.media.Ringtone;
import android.media.RingtoneManager;
import android.os.Build;
import android.provider.Settings;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/** Android owns notification sound/vibration settings; the UI never pretends to override user choices. */
public final class NotificationSettings {
    private final Activity activity;
    private final String[][] channels={{"xy_orders_v1","Pesanan dan saldo"},{"xy_cs_v1","Chat CS"},{"xy_forum_v1","Komunitas"},{"xy_promo_v1","Promo dan info"},{"xy_system_v1","Sistem"}};
    public NotificationSettings(Activity a){activity=a;}
    public void ensureChannels(){
        if(Build.VERSION.SDK_INT<26)return;
        NotificationManager manager=activity.getSystemService(NotificationManager.class);
        for(String[] item:channels){
            if(manager.getNotificationChannel(item[0])!=null)continue;
            NotificationChannel c=new NotificationChannel(item[0],item[1],NotificationManager.IMPORTANCE_DEFAULT);
            c.setDescription("Notifikasi "+item[1]+" dari XyCloudStore");c.enableVibration(true);
            c.setSound(Settings.System.DEFAULT_NOTIFICATION_URI,new AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_NOTIFICATION).build());
            c.setLockscreenVisibility(android.app.Notification.VISIBILITY_PRIVATE);manager.createNotificationChannel(c);
        }
    }
    @SuppressWarnings("unchecked") public Object handle(String method,Object arguments){
        Map<String,Object> args=arguments instanceof Map?(Map<String,Object>)arguments:new HashMap<>();
        if(method.equals("deviceIdentity")){
            try {
                String raw=Settings.Secure.getString(activity.getContentResolver(),Settings.Secure.ANDROID_ID);
                String kind="android";
                if(raw==null||raw.isEmpty()||raw.equals("9774d56d682e549c")){
                    kind="install";
                    android.content.SharedPreferences sp=activity.getSharedPreferences("xy_device",0);
                    raw=sp.getString("identity",null);
                    if(raw==null){raw=java.util.UUID.randomUUID().toString();sp.edit().putString("identity",raw).apply();}
                }
                byte[] hash=java.security.MessageDigest.getInstance("SHA-256").digest((activity.getPackageName()+":"+raw).getBytes(java.nio.charset.StandardCharsets.UTF_8));
                StringBuilder id=new StringBuilder();for(byte b:hash)id.append(String.format(java.util.Locale.ROOT,"%02x",b&255));
                Map<String,Object> result=new HashMap<>();result.put("id",id.toString());result.put("kind",kind);result.put("model",Build.MANUFACTURER+" "+Build.MODEL);return result;
            }catch(Exception e){throw new IllegalStateException("Identitas perangkat belum tersedia");}
        }
        if(method.equals("referralAttribution")){
            android.content.SharedPreferences sp=activity.getSharedPreferences(ReferralActivity.PREFS,0);
            String ticket=sp.getString(ReferralActivity.KEY_TICKET,"");
            long captured=sp.getLong(ReferralActivity.KEY_CAPTURED_AT,0L);
            // Server tetap sumber kebenaran expiry; pembersihan lokal ini hanya
            // mencegah capability basi tinggal tanpa batas di perangkat.
            if(captured<=0L||System.currentTimeMillis()-captured>8L*24L*60L*60L*1000L){
                sp.edit().clear().apply();return null;
            }
            if(ticket==null||!ticket.matches("^[a-f0-9]{64}$"))return null;
            Map<String,Object> result=new HashMap<>();
            result.put("ticket",ticket);result.put("code",sp.getString(ReferralActivity.KEY_CODE,""));
            result.put("capturedAt",captured);
            try {
                android.content.pm.PackageInfo pkg=activity.getPackageManager().getPackageInfo(activity.getPackageName(),0);
                result.put("packageInstalledAt",pkg.firstInstallTime);
                result.put("packageUpdatedAt",pkg.lastUpdateTime);
            }catch(Exception e){throw new IllegalStateException("Waktu pemasangan aplikasi tidak tersedia");}
            return result;
        }
        if(method.equals("clearReferralAttribution")){
            activity.getSharedPreferences(ReferralActivity.PREFS,0).edit().clear().commit();return null;
        }
        if(method.equals("notificationStatus")){
            ensureChannels();List<Map<String,Object>> out=new ArrayList<>();
            NotificationManager manager=(NotificationManager)activity.getSystemService(Activity.NOTIFICATION_SERVICE);
            boolean permission=Build.VERSION.SDK_INT<24||manager.areNotificationsEnabled();
            for(String[] item:channels){
                Map<String,Object> m=new HashMap<>();m.put("id",item[0]);m.put("name",item[1]);m.put("enabled",permission);m.put("sound","Diatur Android");
                if(Build.VERSION.SDK_INT>=26){NotificationChannel c=manager.getNotificationChannel(item[0]);
                    m.put("enabled",permission&&c.getImportance()!=NotificationManager.IMPORTANCE_NONE);m.put("vibration",c.shouldVibrate());
                    try { Ringtone ring=c.getSound()==null?null:RingtoneManager.getRingtone(activity,c.getSound());m.put("sound",ring==null?"Senyap":ring.getTitle(activity)); } catch(Exception e) {m.put("sound","Suara pilihan Android");}}
                out.add(m);
            }
            Map<String,Object> result=new HashMap<>();result.put("enabled",permission);result.put("channels",out);return result;
        }
        if(method.equals("notificationSettings")){
            String id=String.valueOf(args.get("channel")==null?"":args.get("channel"));boolean valid=false;for(String[] c:channels)if(c[0].equals(id))valid=true;
            Intent i;
            if(Build.VERSION.SDK_INT>=26){i=new Intent(valid?Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS:Settings.ACTION_APP_NOTIFICATION_SETTINGS);i.putExtra(Settings.EXTRA_APP_PACKAGE,activity.getPackageName());if(valid)i.putExtra(Settings.EXTRA_CHANNEL_ID,id);}
            else{i=new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,android.net.Uri.parse("package:"+activity.getPackageName()));}
            activity.startActivity(i);return null;
        }
        if(method.equals("storageSettings")){activity.startActivity(new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,android.net.Uri.parse("package:"+activity.getPackageName())));return null;}
        throw new IllegalArgumentException("Pengaturan tidak dikenal");
    }
}
