package id.xycloud.stream;

import android.app.Activity;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Handler;
import android.os.Looper;
import android.preference.PreferenceManager;
import android.util.Base64;
import com.limelight.Game;
import com.limelight.binding.PlatformBinding;
import com.limelight.computers.IdentityManager;
import com.limelight.nvstream.http.ComputerDetails;
import com.limelight.nvstream.http.NvApp;
import com.limelight.nvstream.http.NvHTTP;
import com.limelight.nvstream.http.PairingManager;
import org.json.JSONObject;
import java.io.ByteArrayInputStream;
import java.net.URI;
import java.security.cert.CertificateFactory;
import java.security.cert.X509Certificate;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;

/** XyCloudStore's internal GameStream bridge. No external Moonlight installation is used. */
public final class NativeStreaming {
    public interface Reply { void ok(Object value); void fail(String code, String message); }
    public interface Events { void event(Map<String,Object> event); }
    private static Events events;
    private static final Handler main = new Handler(Looper.getMainLooper());
    private final Activity activity;
    private final ExecutorService executor = Executors.newSingleThreadExecutor();
    private final SharedPreferences saved;
    private Future<?> task;
    private volatile int generation;
    private ComputerDetails computer;
    private List<NvApp> apps;
    private String uniqueId, session;
    public NativeStreaming(Activity activity) {
        this.activity = activity;
        this.saved = activity.getSharedPreferences("xy_stream_hosts", 0);
    }
    public void setEvents(Events listener) { events = listener; }
    public static void emit(String type, String message) {
        Map<String,Object> map = new HashMap<>(); map.put("type",type); map.put("message",message);
        main.post(() -> { if(events != null) events.event(map); });
    }
    /** Baris log untuk panel log aplikasi (ditampilkan di layar sesi). */
    public static void emitLog(String message) {
        Map<String,Object> map = new HashMap<>(); map.put("type","log"); map.put("message",message);
        main.post(() -> { if(events != null) events.event(map); });
    }
    private void emitPin(String pin, int request) {
        main.postDelayed(() -> {
            if(request != generation) return;
            Map<String,Object> map=new HashMap<>();map.put("type","pin");map.put("pin",pin);map.put("session",session);map.put("clientId",uniqueId);
            if(events!=null)events.event(map);
        },1500);
    }
    @SuppressWarnings("unchecked")
    public void handle(String method,Object arguments,Reply reply) {
        Map<String,Object> args=arguments instanceof Map?(Map<String,Object>)arguments:new HashMap<>();
        switch(method) {
            case "available": reply.ok(true); return;
            case "prepare": prepare(args,reply); return;
            case "start": start(args,reply); return;
            case "cancel":
                generation++; if(task!=null)task.cancel(true); computer=null; apps=null; reply.ok(null); return;
            case "resetPairing": activity.deleteFile("uniqueid");activity.deleteFile("client.crt");activity.deleteFile("client.key");saved.edit().clear().apply(); computer=null;apps=null;reply.ok(null);return;
            case "setKontrol": {
                // Mode kontrol untuk sesi berikutnya: true = bawaan Moonlight,
                // false = HUD XyCloudStore (QWERTY/F/Windows/numpad).
                boolean bawaan=args.get("bawaan")instanceof Boolean?
                    (Boolean)args.get("bawaan"):false;
                activity.getSharedPreferences("xy_hud_v1",0).edit()
                    .putBoolean("bawaan",bawaan).apply();
                XyLog.tulis(bawaan?"Mode kontrol disimpan: bawaan (Moonlight).":"Mode kontrol disimpan: XyCloudStore.");
                reply.ok(null);return;
            }
            case "setHudPreset": {
                try {
                    Object data=args.get("data");
                    SharedPreferences.Editor edit=activity
                        .getSharedPreferences("xy_hud_v1",0).edit();
                    if(data instanceof Map) {
                        Object tombol=((Map<?,?>)data).get("tombol");
                        if(!(tombol instanceof List)||((List<?>)tombol).size()>48) {
                            reply.fail("HUD_INVALID","Preset HUD tidak valid atau melebihi 48 tombol.");
                            return;
                        }
                        edit.putString("preset_json",new JSONObject((Map<?,?>)data).toString())
                            .putBoolean("custom",true)
                            .putBoolean("bawaan",false)
                            // Preset bebas tampil bersih; keyboard lengkap tetap dapat
                            // dibuka kapan saja lewat ABC/F/NUM pada bilah atas.
                            .putBoolean("qwerty",false)
                            .putBoolean("fkey",false)
                            .putBoolean("numpad",false)
                            .putBoolean("simbol",false)
                            .apply();
                        XyLog.tulis("Preset HUD kustom disimpan ("+((List<?>)tombol).size()+" tombol).");
                    } else {
                        edit.remove("preset_json").putBoolean("custom",false).apply();
                        XyLog.tulis("Preset HUD kustom dinonaktifkan.");
                    }
                    reply.ok(null);
                } catch(Exception e) {
                    reply.fail("HUD_INVALID","Preset HUD gagal disimpan: "+e.getMessage());
                }
                return;
            }
            default:reply.fail("UNKNOWN","Perintah streaming tidak dikenal.");
        }
    }
    private static String text(Map<String,Object> m,String key,String fallback) {
        Object value=m.get(key);return value==null?fallback:String.valueOf(value);
    }
    private static int number(Map<String,Object> m,String key,int fallback,int min,int max) {
        Object v=m.get(key);int n=v instanceof Number?((Number)v).intValue():fallback;return Math.max(min,Math.min(max,n));
    }
    private static boolean flag(Map<String,Object> m,String key,boolean fallback) {
        return m.get(key) instanceof Boolean?(Boolean)m.get(key):fallback;
    }
    private ComputerDetails.AddressTuple address(String raw) throws Exception {
        if(raw.isEmpty()||raw.contains("/")||raw.contains("@")||raw.matches(".*\\s.*"))throw new IllegalArgumentException("Alamat host streaming tidak valid.");
        if(raw.chars().filter(c->c==':').count()>1&&!raw.startsWith("["))raw="["+raw+"]";
        URI u=new URI("http://"+raw);
        if(u.getHost()==null)throw new IllegalArgumentException("Alamat host streaming tidak valid.");
        int port=u.getPort()==-1?NvHTTP.DEFAULT_HTTP_PORT:u.getPort();
        return new ComputerDetails.AddressTuple(u.getHost(),port);
    }
    private X509Certificate certificate(String id) throws Exception {
        String b=saved.getString(id,null);if(b==null)return null;
        return (X509Certificate) CertificateFactory.getInstance("X.509").generateCertificate(new ByteArrayInputStream(Base64.decode(b,Base64.DEFAULT)));
    }
    private void prepare(Map<String,Object> args,Reply reply) {
        if(task!=null&&!task.isDone()){reply.fail("BUSY","Penyambungan sebelumnya masih ditutup. Tunggu sebentar.");return;}
        final int request=++generation;
        computer=null; apps=null;
        session=text(args,"session","");
        String host=text(args,"host","");
        String hostKey=text(args,"hostKey",host);
        task=executor.submit(() -> {
            try {
                // Wajib sebelum IdentityManager / PairingManager menyentuh RSA+BC
                XyCrypto.ensure();
                emit("stage","Menghubungkan host streaming…");
                ComputerDetails.AddressTuple address=address(host);
                try {
                    uniqueId=new IdentityManager(activity).getUniqueId();
                } catch (Throwable cryptoBoot) {
                    // Sertifikat klien rusak / BC lama — hapus & buat ulang
                    emit("stage","Memperbarui identitas klien streaming…");
                    activity.deleteFile("uniqueid");
                    activity.deleteFile("client.crt");
                    activity.deleteFile("client.key");
                    XyCrypto.ensure();
                    uniqueId=new IdentityManager(activity).getUniqueId();
                }
                X509Certificate pinned=certificate(hostKey);
                NvHTTP http=new NvHTTP(address,0,uniqueId,pinned,PlatformBinding.getCryptoProvider(activity));
                String info=http.getServerInfo(true);
                ComputerDetails details=http.getComputerDetails(info);
                details.activeAddress=address;
                details.serverCert=pinned;
                if(http.getPairState(info)!=PairingManager.PairState.PAIRED) {
                    String pin=PairingManager.generatePinString();
                    emit("stage","Memasangkan perangkat dengan host…");
                    emitPin(pin,request);
                    PairingManager pm=http.getPairingManager();
                    PairingManager.PairState state;
                    try {
                        state=pm.pair(info,pin);
                    } catch (Exception nsa) {
                        // pair() membungkus NoSuchAlgorithmException RSA/BC sebagai RuntimeException
                        String why=String.valueOf(nsa.getMessage());
                        Throwable c=nsa.getCause();
                        if(c!=null&&c.getMessage()!=null) why+=" "+c.getMessage();
                        boolean cryptoFail=why.contains("NoSuchAlgorithm")||why.contains("provider BC")||why.contains("RSA");
                        if(!cryptoFail) throw nsa;
                        // BC Android vs app — reset identity + provider, PIN baru
                        XyCrypto.ensure();
                        activity.deleteFile("uniqueid");
                        activity.deleteFile("client.crt");
                        activity.deleteFile("client.key");
                        saved.edit().remove(hostKey).apply();
                        uniqueId=new IdentityManager(activity).getUniqueId();
                        http=new NvHTTP(address,0,uniqueId,null,PlatformBinding.getCryptoProvider(activity));
                        info=http.getServerInfo(true);
                        pin=PairingManager.generatePinString();
                        emitPin(pin,request);
                        pm=http.getPairingManager();
                        state=pm.pair(info,pin);
                    }
                    if(state!=PairingManager.PairState.PAIRED)throw new IllegalStateException("Pairing belum berhasil ("+state+"). Pastikan agen berjalan dan coba lagi.");
                    details.serverCert=pm.getPairedCert();
                    if(details.serverCert!=null)saved.edit().putString(hostKey,Base64.encodeToString(details.serverCert.getEncoded(),Base64.NO_WRAP)).apply();
                }
                if(request!=generation)throw new InterruptedException();
                http=new NvHTTP(address,details.httpsPort,uniqueId,details.serverCert,PlatformBinding.getCryptoProvider(activity));
                emit("stage","Membaca aplikasi dari Sunshine…");
                List<NvApp> list=http.getAppList();
                if(list.isEmpty())throw new IllegalStateException("Sunshine belum menyediakan aplikasi. Tambahkan Desktop di web UI Sunshine.");
                if(request!=generation)throw new InterruptedException();
                computer=details;apps=list;
                List<Map<String,Object>> results=new ArrayList<>();
                for(NvApp app:list){Map<String,Object> item=new HashMap<>();item.put("id",app.getAppId());item.put("name",app.getAppName());item.put("hdr",app.isHdrSupported());results.add(item);}
                main.post(()->reply.ok(results));
            } catch(Exception e) {
                String message=e.getMessage();
                if(message==null||message.isEmpty())message=e.getClass().getSimpleName();
                // Sertakan cause BC agar diagnosa jelas di UI
                Throwable c=e.getCause();
                if(c!=null&&c.getMessage()!=null&&!c.getMessage().isEmpty()&&!message.contains(c.getMessage())){
                    message=message+" ("+c.getMessage()+")";
                }
                final String result=request!=generation?"Penyambungan dibatalkan.":
                    "Tidak bisa menyambung ke host: "+message+". Periksa port streaming, layar/encoder VM, dan koneksi internet.";
                main.post(()->reply.fail("STREAM_CONNECT",result));
            }
        });
    }
    @SuppressWarnings("unchecked")
    private void start(Map<String,Object> args,Reply reply) {
        try {
            if(computer==null||apps==null)throw new IllegalStateException("Hubungkan host terlebih dahulu.");
            int id=number(args,"appId",-1,0,Integer.MAX_VALUE);
            NvApp app=null;for(NvApp item:apps)if(item.getAppId()==id){app=item;break;}
            if(app==null)throw new IllegalArgumentException("Aplikasi host tidak ditemukan.");
            Map<String,Object> options=args.get("options") instanceof Map?(Map<String,Object>)args.get("options"):new HashMap<>();
            String resolution=text(options,"resolution","1280x720");
            if(!resolution.matches("(854x480|1280x720|1920x1080|2560x1440|3840x2160)"))resolution="1280x720";
            String codec=text(options,"codec","auto");if(!codec.matches("auto|neverh265|forceh265"))codec="auto";
            PreferenceManager.getDefaultSharedPreferences(activity).edit()
                .putString("list_resolution",resolution)
                .putString("list_fps",String.valueOf(number(options,"fps",60,30,120)))
                .putInt("seekbar_bitrate_kbps",number(options,"bitrate",10000,2000,80000))
                .putString("video_format",codec).putString("list_audio_config","2")
                .putBoolean("checkbox_show_onscreen_controls",flag(options,"gamepad",true))
                .putBoolean("checkbox_touchscreen_trackpad",flag(options,"trackpad",true))
                .putBoolean("checkbox_host_audio",flag(options,"hostAudio",false))
                .putBoolean("checkbox_enable_hdr",false)
                .putBoolean("checkbox_enable_pip",false)
                .putBoolean("checkbox_enable_perf_overlay",flag(options,"stats",false))
                .putBoolean("checkbox_vibrate_osc",flag(options,"vibration",true))
                .putBoolean("checkbox_enable_post_stream_toast",false).apply();
            Intent intent=new Intent(activity,XyGameActivity.class);
            intent.putExtra(Game.EXTRA_HOST,computer.activeAddress.address);
            intent.putExtra(Game.EXTRA_PORT,computer.activeAddress.port);
            intent.putExtra(Game.EXTRA_HTTPS_PORT,computer.httpsPort);
            intent.putExtra(Game.EXTRA_APP_ID,app.getAppId());intent.putExtra(Game.EXTRA_APP_NAME,app.getAppName());
            intent.putExtra(Game.EXTRA_UNIQUEID,uniqueId);intent.putExtra(Game.EXTRA_PC_UUID,computer.uuid);
            intent.putExtra(Game.EXTRA_PC_NAME,computer.name==null?"XyCloud PC":computer.name);
            intent.putExtra(Game.EXTRA_APP_HDR,false);
            if(computer.serverCert!=null)intent.putExtra(Game.EXTRA_SERVER_CERT,computer.serverCert.getEncoded());
            activity.startActivity(intent);reply.ok(null);
        }catch(Exception e){reply.fail("STREAM_START",e.getMessage()==null?"Gagal membuka layar streaming.":e.getMessage());}
    }
    public void detach(){generation++;if(task!=null)task.cancel(true);executor.shutdownNow();events=null;}
}
