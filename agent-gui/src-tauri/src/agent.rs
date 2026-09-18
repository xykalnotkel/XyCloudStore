// ============================================================
//  Inti agen XyCloudStore (Rust, tanpa Python).
//  - Heartbeat ke server + proses perintah dari antrean
//  - Kontrol Sunshine lokal lewat API web (Basic auth)
//  - Setup otomatis engine (winget), autostart lewat registry
// ============================================================
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use std::io::Write;
use std::path::PathBuf;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::time::{Duration, Instant};

mod obs_live;

pub const VERSI: &str = "1.5.6-rust";

/// Batch L: semua proses anak (powershell/cmd/reg/where/sunshine) dibuat
/// dengan CREATE_NO_WINDOW supaya tidak ada jendela konsol hitam yang
/// berkedip saat agen berjalan. Selalu pakai helper ini, jangan
/// std::process::Command::new langsung.
pub fn perintah(program: &str) -> std::process::Command {
    let cmd = std::process::Command::new(program);
    #[cfg(windows)]
    let cmd = {
        use std::os::windows::process::CommandExt;
        let mut c = cmd;
        c.creation_flags(0x0800_0000); // CREATE_NO_WINDOW
        c
    };
    cmd
}
const SUNSHINE_BAWAAN: &str = "https://127.0.0.1:47990";
/// MSI resmi LizardByte (fallback bila winget hang / tidak ada).
const SUNSHINE_MSI_URL: &str =
    "https://github.com/LizardByte/Sunshine/releases/latest/download/Sunshine-Windows-AMD64-installer.msi";
const SUNSHINE_EXE_URL: &str =
    "https://github.com/LizardByte/Sunshine/releases/latest/download/Sunshine-Windows-AMD64-installer.exe";

#[derive(Clone, Debug, Default, Serialize, Deserialize)]
pub struct Konfig {
    pub kode: String,
    pub user: String,
    pub sandi: String,
    pub server: String,
}

pub type Logger = Arc<dyn Fn(&str) + Send + Sync>;

fn dir_data() -> PathBuf {
    let base = std::env::var("APPDATA")
        .map(PathBuf::from)
        .unwrap_or_else(|_| std::env::temp_dir());
    base.join("XyCloudStore").join("Agent")
}

fn jalur_config() -> PathBuf {
    dir_data().join("config.json")
}

/// Berkas log mode headless: %APPDATA%\XyCloudStore\Agent\agent.log
/// (dulu log headless cuma ke stdout yang tak ada di proses autostart).
pub fn jalur_log_headless() -> PathBuf {
    dir_data().join("agent.log")
}

/// Stempel waktu ISO-8601 UTC (tanpa dependensi chrono).
pub fn stempel_iso() -> String {
    let d = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|x| x.as_secs())
        .unwrap_or(0);
    // Algoritma civil_from_days (Howard Hinnant) — konversi epoch→tgl.
    let days = (d / 86400) as i64;
    let rem = (d % 86400) as u32;
    let (hh, mm, ss) = (rem / 3600, (rem % 3600) / 60, rem % 60);
    let z = days + 719_468;
    let era = z.div_euclid(146_097);
    let doe = z.rem_euclid(146_097);
    let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146_096) / 365;
    let mut y = yoe + era * 400;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let tgl = doy - (153 * mp + 2) / 5 + 1;
    let bulan = if mp < 10 { mp + 3 } else { mp - 9 };
    if bulan <= 2 {
        y += 1;
    }
    format!("{y:04}-{bulan:02}-{tgl:02}T{hh:02}:{mm:02}:{ss:02}Z")
}

/// Tambah satu baris ke log headless (dengan stempel waktu).
/// Rotasi sederhana: saat lewat 1MB, file lama dipindah ke agent.log.old.
/// Kegagalan menulis log TIDAK BOLEH merusak loop utama → semua error ditelan.
pub fn tulis_log_headless(teks: &str) {
    use std::io::Write;
    let p = jalur_log_headless();
    if let Some(par) = p.parent() {
        let _ = std::fs::create_dir_all(par);
    }
    if let Ok(meta) = std::fs::metadata(&p) {
        if meta.len() > 1_000_000 {
            let _ = std::fs::rename(&p, p.with_file_name("agent.log.old"));
        }
    }
    if let Ok(mut f) = std::fs::OpenOptions::new().create(true).append(true).open(&p) {
        let _ = writeln!(f, "[{}] [XYAGENT] {teks}", stempel_iso());
    }
}

pub fn muat_konfig() -> Konfig {
    if let Ok(teks) = std::fs::read_to_string(jalur_config()) {
        if let Ok(k) = serde_json::from_str::<Konfig>(&teks) {
            return k;
        }
    }
    Konfig { server: "https://api.xycloud.my.id".into(), ..Default::default() }
}

pub fn simpan_konfig(k: &Konfig) -> std::io::Result<()> {
    let dir = dir_data();
    std::fs::create_dir_all(&dir)?;
    let mut f = std::fs::File::create(jalur_config())?;
    serde_json::to_writer_pretty(&mut f, k)?;
    f.flush()?;
    Ok(())
}

fn klien(lokal: bool) -> reqwest::blocking::Client {
    let mut b = reqwest::blocking::Client::builder()
        .timeout(Duration::from_secs(10));
    if lokal {
        // API Sunshine di 127.0.0.1:47990 memakai sertifikat TLS self-signed bawaan Sunshine
        // yang wajib diizinkan agar agen bisa berkomunikasi di localhost PC.
        b = b.danger_accept_invalid_certs(true);
    }
    b.build().expect("gagal membuat klien HTTP")
}

fn minta(
    url: &str,
    data: Option<Value>,
    metode: &str,
    header: Option<Vec<(String, String)>>,
) -> Result<(u16, Value), String> {
    let lokal = url.starts_with("https://127.0.0.1")
        || url.starts_with("http://127.0.0.1")
        || url.starts_with("https://localhost")
        || url.starts_with("http://localhost");
    let c = klien(lokal);
    let mut req = c.request(
        reqwest::Method::from_bytes(metode.as_bytes()).unwrap_or(reqwest::Method::GET),
        url,
    );
    req = req.header("User-Agent", format!("XyAgent/{VERSI}"));
    if let Some(h) = header {
        for (a, b) in h {
            req = req.header(a, b);
        }
    }
    if let Some(d) = data {
        req = req.json(&d);
    }
    let resp = req.send().map_err(|e| e.to_string())?;
    let status = resp.status().as_u16();
    let teks = resp.text().map_err(|e| e.to_string())?;
    if teks.trim().is_empty() {
        return Ok((status, Value::Object(Default::default())));
    }
    match serde_json::from_str::<Value>(&teks) {
        Ok(v) => Ok((status, v)),
        Err(_) => Ok((status, Value::String(teks))),
    }
}

fn header_basic(k: &Konfig) -> Vec<(String, String)> {
    vec![(
        "Authorization".into(),
        format!("Basic {}", base64ish::encode(&format!("{}:{}", k.user, k.sandi))),
    )]
}

fn status_service_sunshine() -> String {
    service_sunshine().unwrap_or_else(|| "tidak ada".into())
}

/// Diagnosa API Sunshine (setara `--cek`).
pub fn periksa_sunshine(k: &Konfig) -> Value {
    let svc = status_service_sunshine();
    if k.user.is_empty() || k.sandi.is_empty() {
        return json!({
            "siap": false,
            "status": "KREDENSIAL_KOSONG",
            "pesan": "Kredensial Sunshine belum diisi — jalankan auto-setup.",
            "service": svc,
        });
    }
    let alamat = SUNSHINE_BAWAAN;
    match minta(&format!("{alamat}/api/apps"), None, "GET", Some(header_basic(k))) {
        Ok((status, j)) => {
            if (200..300).contains(&status) && j.get("apps").is_some() {
                json!({"siap": true, "status": "API_SIAP", "pesan": "API Sunshine merespons.", "service": svc})
            } else if (200..300).contains(&status) {
                // Beberapa build Sunshine mengembalikan objek tanpa key apps.
                json!({"siap": true, "status": "API_SIAP", "pesan": format!("API merespons HTTP {status}."), "service": svc})
            } else {
                json!({"siap": false, "status": "API_TIDAK_SESUAI", "pesan": format!("HTTP {status}: akses API ditolak / belum cocok."), "service": svc})
            }
        }
        Err(e) => {
            let info = if svc == "Stopped" {
                format!("{e} (SunshineService sedang berhenti — jalankan service atau klik Setup Engine)")
            } else if svc == "TIDAK_DITEMUKAN" {
                format!("{e} (Sunshine belum terpasang atau service belum dibuat — jalankan Setup Engine)")
            } else {
                e
            };
            json!({"siap": false, "status": "TIDAK_TERHUBUNG", "pesan": info, "service": svc})
        }
    }
}

/// Cari exe Sunshine di lokasi umum Windows.
/// Kunci rasio streaming landscape di sisi host (Sunshine).
///
/// Melepas opsi `dd_*` Sunshine: display (termasuk display virtual pada
/// PC headless) dijaga aktif + dikunci 1920x1080@60. Didampingi kunci sisi
/// client (permukaan video dipaksa 16:9 di Game.java) sehingga rasio
/// stream selalu landscape 16:9 — lebar video otomatis menyesuaikan layar.
pub fn kunci_lanskap_sunshine(k: &Konfig, log: &Logger) -> Value {
    let alamat = format!("{SUNSHINE_BAWAAN}/api/config");
    let muatan = json!({
        "dd_configuration_option": "ensure_primary",
        "dd_resolution_option": "manual",
        "dd_manual_resolution": "1920x1080",
        "dd_refresh_rate_option": "manual",
        "dd_manual_refresh_rate": 60,
    });
    match minta(&alamat, Some(muatan), "POST", Some(header_basic(k))) {
        Ok((status, _)) if (200..300).contains(&status) => {
            log("Display terkunci landscape 1920x1080@60 (termasuk headless).");
            json!({ "ok": true, "status": "OK" })
        }
        Ok((status, _)) => {
            log(&format!(
                "Sunshine menolak kunci rasio (HTTP {status}). Stream memakai rasio bawaan host."
            ));
            json!({ "ok": false, "status": format!("HTTP_{status}") })
        }
        Err(e) => {
            log(&format!("Gagal mengunci rasio display: {e}"));
            json!({ "ok": false, "status": "GAGAL", "pesan": e })
        }
    }
}

fn cari_sunshine_exe() -> Option<PathBuf> {
    let kandidat = [
        r"C:\Program Files\Sunshine\sunshine.exe",
        r"C:\Program Files (x86)\Sunshine\sunshine.exe",
    ];
    for p in kandidat {
        let pb = PathBuf::from(p);
        if pb.is_file() {
            return Some(pb);
        }
    }
    // PATH
    if let Ok(out) = perintah("where").arg("sunshine.exe").output() {
        let teks = String::from_utf8_lossy(&out.stdout);
        if let Some(baris) = teks.lines().next() {
            let pb = PathBuf::from(baris.trim());
            if pb.is_file() {
                return Some(pb);
            }
        }
    }
    // Local AppData winget / user install
    if let Ok(local) = std::env::var("LOCALAPPDATA") {
        let root = PathBuf::from(local).join("Programs");
        if let Ok(walker) = std::fs::read_dir(&root) {
            for ent in walker.flatten() {
                let coba = ent.path().join("Sunshine").join("sunshine.exe");
                if coba.is_file() {
                    return Some(coba);
                }
            }
        }
    }
    None
}

fn acak_sandi(n: usize) -> String {
    // Cukup untuk web-UI lokal; tidak perlu crypto-grade (hanya localhost).
    const AB: &[u8] = b"ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#$";
    let seed = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_nanos())
        .unwrap_or(42);
    let mut x = seed as u64 ^ 0xA5A5_5A5A_C3C3_3C3C;
    let mut out = String::with_capacity(n);
    for _ in 0..n {
        x = x
            .wrapping_mul(6364136223846793005)
            .wrapping_add(1);
        let idx = ((x >> 33) as usize) % AB.len();
        out.push(AB[idx] as char);
    }
    out
}

fn set_creds_sunshine(exe: &PathBuf, user: &str, sandi: &str, log: &Logger) -> bool {
    log(&format!("Menyetel kredensial Sunshine otomatis (user={user}) lewat --creds …"));
    // Hentikan service sebentar agar file state bisa ditulis (timeout 15s).
    let _ = jalankan_timeout(
        "powershell",
        &[
            "-NoProfile",
            "-Command",
            "Stop-Service -Name 'SunshineService' -Force -ErrorAction SilentlyContinue; Start-Sleep -Seconds 1",
        ],
        15,
        log,
    );

    let exe_s = exe.to_string_lossy().to_string();
    match jalankan_timeout(
        &exe_s,
        &["--creds", user, sandi],
        30,
        log,
    ) {
        Ok((code, msg)) => {
            for baris in msg.lines().filter(|x| !x.trim().is_empty()).take(6) {
                log(baris);
            }
            if code == 0 {
                log("Kredensial Sunshine diset tanpa buka web UI.");
            } else {
                log(&format!("sunshine --creds selesai dengan kode {code}. Mencoba lanjut."));
            }
        }
        Err(e) => {
            log(&format!("Gagal jalankan sunshine --creds: {e}"));
            return false;
        }
    }

    let _ = jalankan_timeout(
        "powershell",
        &[
            "-NoProfile",
            "-Command",
            "Start-Service -Name 'SunshineService' -ErrorAction SilentlyContinue; Start-Sleep -Seconds 2",
        ],
        20,
        log,
    );
    true
}

fn tunggu_api_siap(k: &Konfig, log: &Logger, detik: u64) -> Value {
    let mulai = Instant::now();
    let mut terakhir = json!({"siap": false, "status": "MENUNGGU", "pesan": "Menunggu API Sunshine…"});
    while mulai.elapsed() < Duration::from_secs(detik) {
        terakhir = periksa_sunshine(k);
        if terakhir.get("siap").and_then(|x| x.as_bool()).unwrap_or(false) {
            log("API Sunshine siap.");
            return terakhir;
        }
        std::thread::sleep(Duration::from_secs(2));
    }
    log("API Sunshine belum siap setelah menunggu.");
    terakhir
}


/// Batch L: cari IP Tailscale (100.64.0.0/10) di adapter lokal — untuk
/// mode relay/VPN saat host tidak punya IP publik yang bisa dijangkau.
pub fn ip_tailscale() -> Option<String> {
    let out = perintah("powershell")
        .args([
            "-NoProfile",
            "-Command",
            "(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |              Where-Object { $_.IPAddress -like '100.*' } |              Select-Object -First 1 -ExpandProperty IPAddress)",
        ])
        .output()
        .ok()?;
    let ip = String::from_utf8_lossy(&out.stdout).trim().to_string();
    // Validasi rentang CGNAT Tailscale: 100.64.0.0 – 100.127.255.255.
    let oktet: Vec<u8> = ip.split('.').filter_map(|x| x.parse().ok()).collect();
    if oktet.len() == 4 && oktet[0] == 100 && (64..=127).contains(&oktet[1]) {
        Some(ip)
    } else {
        None
    }
}

/// Batch L: apakah mode relay (Tailscale/VPN) diaktifkan di config.json.
pub fn mode_relay_aktif() -> bool {
    if let Ok(teks) = std::fs::read_to_string(jalur_config()) {
        if let Ok(v) = serde_json::from_str::<Value>(&teks) {
            return v.get("mode_relay").and_then(|x| x.as_bool()).unwrap_or(false);
        }
    }
    false
}

/// Batch L: simpan flag mode relay ke config.json tanpa mengganggu field lain.
pub fn set_mode_relay(aktif: bool) -> Result<(), String> {
    let jalur = jalur_config();
    let mut v: Value = std::fs::read_to_string(&jalur)
        .ok()
        .and_then(|t| serde_json::from_str(&t).ok())
        .unwrap_or_else(|| json!({}));
    v["mode_relay"] = json!(aktif);
    let teks = serde_json::to_string_pretty(&v).map_err(|e| e.to_string())?;
    std::fs::write(&jalur, teks).map_err(|e| e.to_string())
}

/// Alamat yang bisa dijangkau HP penyewa (bukan COMPUTERNAME Windows).
/// Prioritas: mode relay (IP Tailscale) → STREAM_HOST / XY_STREAM_HOST env
/// → config stream_host → IP publik.
fn alamat_stream(k: &Konfig) -> String {
    // Batch L: mode relay — untuk TESTING di host tanpa IP publik
    // (VM, CGNAT). Penyewa harus tergabung di tailnet yang sama.
    if mode_relay_aktif() {
        if let Some(ip) = ip_tailscale() {
            return ip;
        }
    }
    for key in ["STREAM_HOST", "XY_STREAM_HOST", "SUNSHINE_HOST"] {
        if let Ok(v) = std::env::var(key) {
            let t = v.trim().to_string();
            if !t.is_empty() {
                return t;
            }
        }
    }
    // Optional field in config.json (ignored by older agents)
    if let Ok(teks) = std::fs::read_to_string(jalur_config()) {
        if let Ok(v) = serde_json::from_str::<Value>(&teks) {
            if let Some(h) = v.get("stream_host").and_then(|x| x.as_str()) {
                let t = h.trim();
                if !t.is_empty() {
                    return t.to_string();
                }
            }
        }
    }
    // IP publik via layanan ringan (timeout pendek)
    for url in [
        "https://api.ipify.org",
        "https://ifconfig.me/ip",
        "https://icanhazip.com",
    ] {
        if let Ok((status, j)) = minta(url, None, "GET", None) {
            if (200..300).contains(&status) {
                let ip = match j {
                    Value::String(t) => t.trim().to_string(),
                    other => other.as_str().unwrap_or("").trim().to_string(),
                };
                // ipify returns plain text which minta wraps as String
                let ip = ip.lines().next().unwrap_or("").trim().to_string();
                if !ip.is_empty()
                    && ip.len() < 64
                    && !ip.contains(' ')
                    && (ip.contains('.') || ip.contains(':'))
                {
                    return ip;
                }
            }
        }
    }
    // Last resort: keep computer name only if nothing else (will fail DNS — better log)
    let _ = k; // konfig reserved for future
    std::env::var("COMPUTERNAME").unwrap_or_else(|_| "127.0.0.1".into())
}

fn spesifikasi() -> Value {
    let host = std::env::var("COMPUTERNAME").unwrap_or_else(|_| "PC-XY".into());
    let cpu = std::env::var("PROCESSOR_IDENTIFIER").unwrap_or_default();
    let mut spec = json!({
        "hostname": host,
        "os": "Windows",
        "cpu": cpu,
        "rust": true,
        "versi": VERSI,
    });
    if let Ok(out) = perintah("powershell")
        .args(["-NoProfile", "-Command", "(Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory"])
        .output()
    {
        let teks = String::from_utf8_lossy(&out.stdout).trim().to_string();
        if let Ok(v) = teks.parse::<f64>() {
            spec["ram_total_gb"] = json!(format!("{:.1}", v / 1e9));
        }
    }
    // IP LAN (fallback streaming bila host publik tertutup NAT/firewall).
    if let Ok(out) = perintah("powershell")
        .args([
            "-NoProfile",
            "-Command",
            "(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' } | Select-Object -First 3 -ExpandProperty IPAddress) -join ','",
        ])
        .output()
    {
        let teks = String::from_utf8_lossy(&out.stdout).trim().to_string();
        if !teks.is_empty() && teks.len() < 120 {
            spec["ip_lan"] = json!(teks);
        }
    }
    // Batch J: GPU + versi Windows — spek terdeteksi otomatis untuk app.
    if let Ok(out) = perintah("powershell")
        .args([
            "-NoProfile",
            "-Command",
            "(Get-CimInstance Win32_VideoController | Select-Object -First 1).Name",
        ])
        .output()
    {
        let teks = String::from_utf8_lossy(&out.stdout).trim().to_string();
        if !teks.is_empty() && teks.len() < 120 {
            spec["gpu"] = json!(teks);
        }
    }
    if let Ok(out) = perintah("powershell")
        .args([
            "-NoProfile",
            "-Command",
            "[System.Environment]::OSVersion.Version.ToString()",
        ])
        .output()
    {
        let teks = String::from_utf8_lossy(&out.stdout).trim().to_string();
        if !teks.is_empty() && teks.len() < 40 {
            spec["os_versi"] = json!(teks);
        }
    }
    spec
}

fn kirim_balasan(k: &Konfig, id: &str, hasil: Value) {
    let url = format!("{}/api/agen/perintah/{}", k.server.trim_end_matches('/'), id);
    let _ = minta(&url, Some(hasil), "POST", Some(vec![("x-agen-kode".into(), k.kode.clone())]));
}

/// Ambil credential sekali pakai langsung dari endpoint privat agen. Nilainya
/// tidak pernah diteruskan ke logger, file konfigurasi, atau payload ACK.
fn credential_livestream(k: &Konfig, live_id: &str) -> Result<(String, String, bool), String> {
    if !live_id.starts_with("live_") || live_id.len() > 80 {
        return Err("LIVE_ID_INVALID".into());
    }
    let url = format!(
        "{}/api/agen/live/{}/credential",
        k.server.trim_end_matches('/'),
        live_id
    );
    let (status, body) = minta(
        &url,
        None,
        "GET",
        Some(vec![("x-agen-kode".into(), k.kode.clone())]),
    )
    .map_err(|_| "LIVE_CREDENTIAL_NETWORK".to_string())?;
    if !(200..300).contains(&status) {
        return Err(format!("LIVE_CREDENTIAL_HTTP_{status}"));
    }
    let data = body.get("data").unwrap_or(&body);
    if data.get("live_id").and_then(Value::as_str) != Some(live_id) {
        return Err("LIVE_CREDENTIAL_MISMATCH".into());
    }
    let ingest = data
        .get("ingest_url")
        .and_then(Value::as_str)
        .unwrap_or("")
        .to_string();
    let key = data
        .get("stream_key")
        .and_then(Value::as_str)
        .unwrap_or("")
        .to_string();
    let mic = data.get("mic_consent").and_then(Value::as_bool).unwrap_or(false);
    if ingest != "rtmps://live.cloudflare.com:443/live/" || key.len() < 20 || key.len() > 512 {
        return Err("LIVE_CREDENTIAL_INVALID".into());
    }
    Ok((ingest, key, mic))
}

fn kerjakan(k: &Konfig, perintah: &Value, log: &Logger) {
    let jenis = perintah.get("jenis").and_then(|x| x.as_str()).unwrap_or("?");
    let muatan = perintah.get("muatan").cloned().unwrap_or_else(|| json!({}));
    let sesi_id = muatan.get("sesi_id").and_then(|x| x.as_str()).unwrap_or("-");
    let id_per = perintah.get("id").and_then(|x| x.as_str()).unwrap_or("");
    log(&format!("Perintah masuk: {jenis} ({sesi_id})"));

    let balas = |hasil: Value| {
        if !id_per.is_empty() {
            kirim_balasan(k, id_per, hasil);
        }
    };

    let sunshine = SUNSHINE_BAWAAN;
    match jenis {
        "mulai_sesi" => {
            let cek = periksa_sunshine(k);
            if cek.get("siap").and_then(|x| x.as_bool()).unwrap_or(false) {
                let _ = minta(&format!("{sunshine}/api/clients/unpair-all"), Some(json!({})), "POST", Some(header_basic(k)));
                let _ = minta(&format!("{sunshine}/api/apps/close"), Some(json!({})), "POST", Some(header_basic(k)));
                let stream = alamat_stream(k);
                log(&format!("Host streaming untuk penyewa: {stream}"));
                balas(json!({
                    "ok": true, "sesi_id": sesi_id, "status": "siap",
                    "host": stream,
                    "catatan": "Sunshine siap menerima sambungan",
                }));
            } else {
                balas(json!({
                    "ok": false, "sesi_id": sesi_id, "status": "gagal",
                    "catatan": cek.get("pesan").cloned().unwrap_or_else(|| json!("Sunshine tidak siap")),
                }));
            }
        }
        "pasangkan" => {
            let pin = muatan.get("pin").and_then(|x| x.as_str()).unwrap_or("").to_string();
            let mut hasil = json!({"ok": false, "sesi_id": sesi_id, "status": "siap", "catatan": "Gagal pasangkan."});
            if let Ok((_, pending)) = minta(&format!("{sunshine}/api/pin"), None, "GET", Some(header_basic(k))) {
                let pasang = pending.get("pairings").and_then(|x| x.as_array()).cloned().unwrap_or_default();
                if let Some(p) = pasang.first() {
                    let id_p = p.get("id").cloned().unwrap_or_else(|| json!(""));
                    let body = json!({"pin": pin, "name": "XyCloudStore", "pairing_id": id_p});
                    if let Ok((status, _j)) = minta(&format!("{sunshine}/api/pin"), Some(body), "POST", Some(header_basic(k))) {
                        let oke = (200..300).contains(&status);
                        hasil = json!({
                            "ok": oke, "sesi_id": sesi_id, "status": "siap",
                            "catatan": if oke { "Perangkat berhasil dipasangkan" } else { "PIN ditolak, minta penyewa mencoba lagi" },
                        });
                    }
                } else {
                    hasil = json!({"ok": false, "sesi_id": sesi_id, "status": "siap",
                        "catatan": "Belum ada permintaan pairing dari HP."});
                }
            }
            balas(hasil);
        }
        "akhiri_sesi" => {
            // Lease PC berakhir berarti siaran publik juga wajib berhenti,
            // bahkan bila command akhiri_siaran datang sesudah command ini.
            let live_bersih = obs_live::akhiri_aktif(k, log).is_ok();
            let tutup = minta(&format!("{sunshine}/api/apps/close"), Some(json!({})), "POST", Some(header_basic(k)));
            let lepas = minta(&format!("{sunshine}/api/clients/unpair-all"), Some(json!({})), "POST", Some(header_basic(k)));
            let oke = live_bersih && tutup.is_ok() && lepas.is_ok();
            balas(json!({
                "ok": oke, "sesi_id": sesi_id,
                "status": if oke { "selesai" } else { "mengakhiri" },
                "catatan": if oke { "Sesi dan OBS dibersihkan" } else { "Pembersihan Sunshine/OBS belum terverifikasi; unit tetap dikunci" },
            }));
        }
        "mulai_siaran" => {
            let live_id = muatan.get("live_id").and_then(Value::as_str).unwrap_or("");
            log(&format!("Menyiapkan XyCloud Live {} (credential tidak dicatat)…", live_id));
            let hasil = credential_livestream(k, live_id).and_then(|(ingest, key, mic)| {
                obs_live::mulai(k, live_id, &ingest, &key, mic, log)
            });
            match hasil {
                Ok(()) => balas(json!({"ok": true, "live_id": live_id, "code": "OK"})),
                Err(code) => {
                    let clean: String = code.chars()
                        .filter(|x| x.is_ascii_alphanumeric() || *x == '_')
                        .take(50)
                        .collect();
                    log(&format!("Siaran tidak dimulai ({}).", clean));
                    balas(json!({"ok": false, "live_id": live_id, "code": clean}));
                }
            }
        }
        "akhiri_siaran" => {
            let live_id = muatan.get("live_id").and_then(Value::as_str).unwrap_or("");
            match obs_live::akhiri(k, live_id, log) {
                Ok(()) => balas(json!({"ok": true, "live_id": live_id, "code": "OK"})),
                Err(code) => {
                    let clean: String = code.chars()
                        .filter(|x| x.is_ascii_alphanumeric() || *x == '_')
                        .take(50)
                        .collect();
                    balas(json!({"ok": false, "live_id": live_id, "code": clean}));
                }
            }
        }
        lainnya => balas(json!({"ok": false, "catatan": format!("Perintah {lainnya} tidak dikenal")})),
    }
}

fn detak(k: &Konfig, log: &Logger) {
    let cek = periksa_sunshine(k);
    let mut spec = spesifikasi();
    spec["sunshine"] = cek;
    spec["obs"] = obs_live::status();
    let live_health = obs_live::pantau(k, log);
    let stream = alamat_stream(k);
    spec["stream_host"] = json!(stream);
    let muatan = json!({
        "status": "online",
        "versi": VERSI,
        "spec": spec,
        "host": stream,
        "hostname": std::env::var("COMPUTERNAME").unwrap_or_default(),
        "live_health": live_health,
    });
    let url = format!("{}/api/agen/heartbeat", k.server.trim_end_matches('/'));
    match minta(&url, Some(muatan), "POST", Some(vec![("x-agen-kode".into(), k.kode.clone())])) {
        Ok((status, j)) => {
            if !(200..300).contains(&status) {
                log("Server belum mengonfirmasi heartbeat (periksa server & kode unit).");
                return;
            }
            if let Some(data) = j.get("data").and_then(|x| x.as_object()) {
                if data.get("ok").and_then(|x| x.as_bool()).unwrap_or(false) {
                    if let Some(daftar) = data.get("perintah").and_then(|x| x.as_array()) {
                        let perintah = daftar.clone();
                        for p in perintah {
                            kerjakan(k, &p, log);
                        }
                    }
                }
            }
        }
        Err(e) => log(&format!("Gagal lapor ke server: {e}")),
    }
}

/// Putaran utama agen (dijalankan di thread sendiri).
pub fn jalankan_loop(k: Konfig, log: Logger, stop: Arc<AtomicBool>) {
    log(&format!("XyCloudStore Agen {VERSI} (Rust) mulai."));
    log(&format!("Server   : {}", k.server));
    log(&format!("Sunshine : {SUNSHINE_BAWAAN}"));
    let mut terakhir = Instant::now();
    while !stop.load(Ordering::Relaxed) {
        // Idle tetap hemat (20 dtk). Selama ada tombstone OBS, audit scene,
        // audio, output, dan cleanup dilaporkan tiap 5 dtk agar fail-closed cepat.
        let interval = if obs_live::perlu_pantau_cepat() { 5 } else { 20 };
        if terakhir.elapsed() >= Duration::from_secs(interval) {
            terakhir = Instant::now();
            detak(&k, &log);
        }
        std::thread::sleep(Duration::from_secs(1));
    }
    let _ = obs_live::akhiri_aktif(&k, &log);
    log("Agen dihentikan.");
}

/// Jalankan perintah dengan batas waktu (detik). Kill bila lewat.
fn jalankan_timeout(program: &str, args: &[&str], detik: u64, log: &Logger) -> Result<(i32, String), String> {
    use std::io::Read;
    log(&format!("> {program} {}", args.join(" ")));
    let mut child = perintah(program)
        .args(args)
        .stdout(std::process::Stdio::piped())
        .stderr(std::process::Stdio::piped())
        .spawn()
        .map_err(|e| format!("gagal spawn {program}: {e}"))?;
    let mulai = Instant::now();
    loop {
        match child.try_wait() {
            Ok(Some(status)) => {
                let mut stdout = String::new();
                let mut stderr = String::new();
                if let Some(mut o) = child.stdout.take() {
                    let _ = o.read_to_string(&mut stdout);
                }
                if let Some(mut e) = child.stderr.take() {
                    let _ = e.read_to_string(&mut stderr);
                }
                return Ok((status.code().unwrap_or(-1), stdout + &stderr));
            }
            Ok(None) => {
                if mulai.elapsed() >= Duration::from_secs(detik) {
                    let _ = child.kill();
                    let _ = child.wait();
                    return Err(format!("{program} timeout setelah {detik}s — dibatalkan"));
                }
                std::thread::sleep(Duration::from_millis(400));
            }
            Err(e) => return Err(format!("gagal pantau {program}: {e}")),
        }
    }
}

fn unduh_berkas(url: &str, tujuan: &PathBuf, log: &Logger) -> Result<(), String> {
    log(&format!("Mengunduh {url} …"));
    let c = reqwest::blocking::Client::builder()
        .timeout(Duration::from_secs(180))
        .user_agent(format!("XyAgent/{VERSI}"))
        .redirect(reqwest::redirect::Policy::limited(8))
        .build()
        .map_err(|e| e.to_string())?;
    let mut resp = c.get(url).send().map_err(|e| format!("unduh gagal: {e}"))?;
    if !resp.status().is_success() {
        return Err(format!("HTTP {} saat unduh installer", resp.status()));
    }
    if let Some(parent) = tujuan.parent() {
        std::fs::create_dir_all(parent).map_err(|e| e.to_string())?;
    }
    let mut f = std::fs::File::create(tujuan).map_err(|e| e.to_string())?;
    let n = resp
        .copy_to(&mut f)
        .map_err(|e| format!("tulis berkas gagal: {e}"))?;
    log(&format!("Installer tersimpan ({n} byte) → {}", tujuan.display()));
    Ok(())
}

fn pasang_sunshine_winget(log: &Logger) -> bool {
    log("Mencoba winget install LizardByte.Sunshine (maks 90 dtk)…");
    match jalankan_timeout(
        "winget",
        &[
            "install",
            "--id",
            "LizardByte.Sunshine",
            "-e",
            "--silent",
            "--disable-interactivity",
            "--accept-source-agreements",
            "--accept-package-agreements",
        ],
        90,
        log,
    ) {
        Ok((code, teks)) => {
            for baris in teks.lines().filter(|x| !x.trim().is_empty()).take(12) {
                log(baris);
            }
            log(&format!("winget selesai (kode {code})."));
            // 0 = ok, -1978335189 often already installed
            code == 0 || code == -1978335189 || cari_sunshine_exe().is_some()
        }
        Err(e) => {
            log(&format!("winget: {e}"));
            false
        }
    }
}

fn pasang_sunshine_msi(log: &Logger) -> bool {
    let tmp = std::env::temp_dir().join("xycloud-sunshine-setup");
    let _ = std::fs::create_dir_all(&tmp);
    // Coba MSI dulu, lalu EXE NSIS
    let targets = [
        (SUNSHINE_MSI_URL, tmp.join("Sunshine-setup.msi"), true),
        (SUNSHINE_EXE_URL, tmp.join("Sunshine-setup.exe"), false),
    ];
    for (url, path, is_msi) in targets {
        if let Err(e) = unduh_berkas(url, &path, log) {
            log(&format!("Gagal unduh: {e}"));
            continue;
        }
        let ok = if is_msi {
            log("Memasang MSI diam-diam (msiexec /qn)…");
            let msi = path.to_string_lossy().to_string();
            match jalankan_timeout(
                "msiexec",
                &["/i", &msi, "/qn", "/norestart"],
                180,
                log,
            ) {
                Ok((code, teks)) => {
                    for baris in teks.lines().filter(|x| !x.trim().is_empty()).take(8) {
                        log(baris);
                    }
                    // 0 success, 3010 reboot required but installed
                    code == 0 || code == 3010
                }
                Err(e) => {
                    log(&format!("msiexec: {e}"));
                    false
                }
            }
        } else {
            log("Memasang EXE silent (/S)…");
            let path_s = path.to_string_lossy().to_string();
            match jalankan_timeout(&path_s, &["/S"], 180, log) {
                Ok((code, teks)) => {
                    for baris in teks.lines().filter(|x| !x.trim().is_empty()).take(8) {
                        log(baris);
                    }
                    code == 0
                }
                Err(e) => {
                    log(&format!("installer exe: {e}"));
                    false
                }
            }
        };
        if ok || cari_sunshine_exe().is_some() {
            return true;
        }
    }
    false
}

fn pastikan_service_sunshine(log: &Logger) {
    log("Memastikan layanan SunshineService…");
    // Jangan -Verb RunAs -Wait (bisa macet di UAC tanpa log). Coba start dulu.
    let _ = jalankan_timeout(
        "powershell",
        &[
            "-NoProfile",
            "-Command",
            "Start-Service -Name 'SunshineService' -ErrorAction SilentlyContinue; \
             $s=(Get-Service SunshineService -EA SilentlyContinue).Status; \
             if($s){Write-Output \"status=$s\"}else{Write-Output 'status=tidak-ada'}",
        ],
        20,
        log,
    );
    // Kalau belum ada service, coba install-service.bat tanpa elevasi hang
    if service_sunshine().is_none() {
        let bat = PathBuf::from(r"C:\Program Files\Sunshine\install-service.bat");
        if bat.is_file() {
            log("Menjalankan install-service.bat (tanpa tunggu UAC)…");
            let bat_s = bat.to_string_lossy().to_string();
            let _ = perintah("cmd")
                .args(["/C", &bat_s])
                .stdout(std::process::Stdio::null())
                .stderr(std::process::Stdio::null())
                .spawn();
            std::thread::sleep(Duration::from_secs(3));
            let _ = perintah("powershell")
                .args([
                    "-NoProfile",
                    "-Command",
                    "Start-Service -Name 'SunshineService' -ErrorAction SilentlyContinue",
                ])
                .output();
        }
    }
    // Fallback: jalankan sunshine.exe langsung jika service belum ada
    if service_sunshine().is_none() {
        if let Some(exe) = cari_sunshine_exe() {
            log("Service belum ada — mencoba jalankan sunshine.exe di background…");
            let _ = perintah(&exe.to_string_lossy())
                .stdout(std::process::Stdio::null())
                .stderr(std::process::Stdio::null())
                .spawn();
            std::thread::sleep(Duration::from_secs(3));
        }
    }
    log(&format!("Service: {}", status_service_sunshine()));
}

/// Hasil setup: (konfig yang mungkin diperbarui + diagnosa Sunshine).
pub fn setup_otomatis(k: &Konfig, log: Logger) -> (Konfig, Value) {
    let mut k = k.clone();
    log(&format!("=== Auto-setup Sunshine · Agen {VERSI} ==="));
    log("Langkah 1/6: deteksi engine…");

    // 1) Pastikan engine terpasang
    let sudah_exe = cari_sunshine_exe().is_some();
    let sudah_svc = service_sunshine().is_some();
    if sudah_exe || sudah_svc {
        log("Sunshine sudah terdeteksi di PC ini.");
        if let Some(p) = cari_sunshine_exe() {
            log(&format!("Path: {}", p.display()));
        }
    } else {
        log("Sunshine belum ada — pasang otomatis (winget → MSI GitHub)…");
        let mut ok = pasang_sunshine_winget(&log);
        if !ok && cari_sunshine_exe().is_none() {
            log("Winget gagal/hang — fallback unduh installer resmi GitHub…");
            ok = pasang_sunshine_msi(&log);
        }
        if !ok && cari_sunshine_exe().is_none() {
            log("GAGAL pasang otomatis. Opsi manual:");
            log("  1) winget install --id LizardByte.Sunshine -e");
            log("  2) https://github.com/LizardByte/Sunshine/releases/latest");
            log("  3) Jalankan Agent sebagai Administrator lalu ulangi setup.");
            let cek = periksa_sunshine(&k);
            return (k, cek);
        }
        std::thread::sleep(Duration::from_secs(3));
    }

    let exe = match cari_sunshine_exe() {
        Some(p) => {
            log(&format!("Sunshine exe: {}", p.display()));
            p
        }
        None => {
            log("Sunshine.exe masih belum ketemu setelah install.");
            let cek = periksa_sunshine(&k);
            return (k, cek);
        }
    };

    // 2) Kredensial
    log("Langkah 2/6: kredensial API lokal…");
    let perlu_set_creds = k.user.is_empty() || k.sandi.is_empty();
    if perlu_set_creds {
        if k.user.is_empty() {
            k.user = "xycloud".into();
        }
        if k.sandi.is_empty() {
            k.sandi = acak_sandi(18);
        }
        log("Membuat user/sandi otomatis (hanya 127.0.0.1)…");
        let _ = set_creds_sunshine(&exe, &k.user, &k.sandi, &log);
        if let Err(e) = simpan_konfig(&k) {
            log(&format!("Gagal simpan konfig setelah creds: {e}"));
        } else {
            log("Kredensial tersimpan di %APPDATA%\\XyCloudStore\\Agent\\config.json");
        }
    } else {
        log("Menyelaraskan kredensial tersimpan lewat --creds …");
        let _ = set_creds_sunshine(&exe, &k.user, &k.sandi, &log);
    }

    // 3) Service
    log("Langkah 3/6: layanan…");
    pastikan_service_sunshine(&log);

    // 4) Tunggu API
    log("Langkah 4/6: tunggu API 47990 (maks 45 dtk)…");
    let mut cek = tunggu_api_siap(&k, &log, 45);
    if cek.get("siap").and_then(|x| x.as_bool()).unwrap_or(false) {
        log("SETUP OK — Sunshine siap. Tidak perlu login web UI manual.");
        // 5) Kunci rasio landscape — display host (termasuk headless/virtual
        //    display) dipaksa 1920x1080@60 lewat opsi dd_* Sunshine.
        log("Langkah 5/6: kunci rasio landscape (termasuk headless)…");
        let _ = kunci_lanskap_sunshine(&k, &log);
    } else {
        let pesan = cek
            .get("pesan")
            .and_then(|x| x.as_str())
            .unwrap_or("API belum merespons");
        log(&format!("SETUP SEBAGIAN — {pesan}"));
        log("Tips: jalankan Agent sebagai Admin, atau buka https://127.0.0.1:47990 sekali.");
        log("Lalu klik 'Uji koneksi' / ulangi Pasang & kunci.");
    }
    log("Langkah 6/6: engine livestream gamer (OBS Studio)…");
    let obs_ok = obs_live::pastikan_terpasang(&log);
    cek["obs"] = obs_live::status();
    cek["obs"]["siap"] = json!(obs_ok);
    (k, cek)
}

fn service_sunshine() -> Option<String> {
    let out = perintah("powershell")
        .args(["-NoProfile", "-Command",
               "(Get-Service -Name 'SunshineService' -ErrorAction SilentlyContinue).Status"])
        .output()
        .ok()?;
    let teks = String::from_utf8_lossy(&out.stdout).trim().to_string();
    if teks.is_empty() { None } else { Some(teks) }
}

/// Autostart saat login lewat registry HKCU Run.
pub fn atur_autostart(aktif: bool, log: &Logger) {
    let kunci = r"HKCU\Software\Microsoft\Windows\CurrentVersion\Run";
    if aktif {
        let exe = std::env::current_exe().unwrap_or_default();
        let cmd = format!("\"{}\" -Jalankan", exe.display());
        let out = perintah("reg")
            .args(["add", kunci, "/v", "XyCloudStoreAgent", "/t", "REG_SZ", "/d", &cmd, "/f"])
            .output();
        match out {
            Ok(o) if o.status.success() => log("Autostart didaftarkan (XyCloudStoreAgent @ login)."),
            Ok(o) => log(&format!("Gagal daftar autostart: {}", String::from_utf8_lossy(&o.stderr).trim())),
            Err(e) => log(&format!("Gagal daftar autostart: {e}")),
        }
    } else {
        let out = perintah("reg")
            .args(["delete", kunci, "/v", "XyCloudStoreAgent", "/f"])
            .output();
        match out {
            Ok(_) => log("Autostart dihapus."),
            Err(e) => log(&format!("Gagal hapus autostart: {e}")),
        }
    }
}

pub fn autostart_aktif() -> bool {
    let kunci = r"HKCU\Software\Microsoft\Windows\CurrentVersion\Run";
    matches!(
        perintah("reg")
            .args(["query", kunci, "/v", "XyCloudStoreAgent"])
            .output(),
        Ok(o) if o.status.success()
    )
}

mod base64ish {
    const TBL: &[u8] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    pub fn encode(data: &str) -> String {
        let b = data.as_bytes();
        let mut out = String::with_capacity((b.len() + 2) / 3 * 4);
        for chunk in b.chunks(3) {
            let n = ((chunk[0] as u32) << 16)
                | ((if chunk.len() > 1 { chunk[1] } else { 0 }) as u32) << 8
                | (if chunk.len() > 2 { chunk[2] } else { 0 }) as u32;
            out.push(TBL[((n >> 18) & 63) as usize] as char);
            out.push(TBL[((n >> 12) & 63) as usize] as char);
            out.push(if chunk.len() > 1 { TBL[((n >> 6) & 63) as usize] as char } else { '=' });
            out.push(if chunk.len() > 2 { TBL[(n & 63) as usize] as char } else { '=' });
        }
        out
    }
}
