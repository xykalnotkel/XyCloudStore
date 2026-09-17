//! Kendali OBS untuk XyCloud Live.
//!
//! Prinsip keselamatan:
//! - hanya scene `XyCloudLive`;
//! - hanya source Game Capture `XyCloudGameCapture`;
//! - mic opsional harus sudah disiapkan sebagai `XyCloudMic` dan hanya aktif
//!   bila pengguna memberi consent;
//! - Display/Window/Browser Capture tidak pernah menjadi fallback;
//! - stream key hanya berada di memori dan konfigurasi runtime OBS, tidak
//!   pernah ditulis oleh agen ke config/state/log;
//! - saat berhenti, output diputus dan service key OBS dikosongkan.

use super::{dir_data, perintah, Konfig, Logger};
use serde_json::{json, Value};
use std::io::{Read, Write};
use std::net::{SocketAddr, TcpStream};
use std::path::PathBuf;
use std::process::{Child, Stdio};
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};

const OBS_HOST: &str = "127.0.0.1";
const OBS_PORT: u16 = 4455;
const SCENE: &str = "XyCloudLive";
const GAME: &str = "XyCloudGameCapture";
const MIC: &str = "XyCloudMic";
const INGEST_SERVER: &str = "rtmps://live.cloudflare.com:443/live/";
const WS_GUID: &str = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";
const MAX_WS: usize = 1_000_000;
const STREAM_PROFILE: [(&str, &str, &str); 9] = [
    ("Output", "Mode", "Simple"),
    ("Output", "Reconnect", "true"),
    ("Output", "RetryDelay", "2"),
    ("Output", "MaxRetries", "20"),
    ("Output", "DynamicBitrate", "true"),
    ("SimpleOutput", "VBitrate", "4500"),
    ("SimpleOutput", "ABitrate", "128"),
    ("SimpleOutput", "UseAdvanced", "true"),
    ("SimpleOutput", "EnforceBitrate", "true"),
];

#[derive(Clone, Debug)]
struct LiveState {
    live_id: String,
    managed: bool,
    mic: bool,
    cleanup_pending: bool,
}

fn state_path() -> PathBuf {
    dir_data().join("live-state.json")
}

fn state_temp_path() -> PathBuf {
    dir_data().join("live-state.tmp")
}

fn parse_state(path: &PathBuf) -> Option<(LiveState, u64)> {
    let text = std::fs::read_to_string(path).ok()?;
    if text.len() > 4096 {
        return None;
    }
    let v: Value = serde_json::from_str(&text).ok()?;
    let id = v.get("live_id")?.as_str()?.to_string();
    if !id.starts_with("live_") || id.len() > 80 {
        return None;
    }
    let revision = v.get("saved_at_ns").and_then(Value::as_u64).unwrap_or(0);
    Some((LiveState {
        live_id: id,
        managed: v.get("managed").and_then(Value::as_bool).unwrap_or(false),
        mic: v.get("mic").and_then(Value::as_bool).unwrap_or(false),
        cleanup_pending: v.get("cleanup_pending").and_then(Value::as_bool).unwrap_or(false),
    }, revision))
}

fn baca_state() -> Option<LiveState> {
    // `rename(temp, target)` tidak mengganti berkas yang sudah ada di Windows.
    // Simpanan memakai remove+rename, dan pembaca memilih revisi valid terbaru
    // dari main/temp agar crash di sela kedua operasi tidak menghilangkan state.
    let main = parse_state(&state_path());
    let temp = parse_state(&state_temp_path());
    match (main, temp) {
        (Some((a, ar)), Some((b, br))) => Some(if br > ar { b } else { a }),
        (Some((a, _)), None) => Some(a),
        (None, Some((b, _))) => Some(b),
        (None, None) => None,
    }
}

fn simpan_state(live_id: &str, managed: bool, mic: bool, cleanup_pending: bool) -> Result<(), String> {
    let dir = dir_data();
    std::fs::create_dir_all(&dir).map_err(|_| "OBS_STATE_DIR".to_string())?;
    let temp = state_temp_path();
    let revision = SystemTime::now().duration_since(UNIX_EPOCH)
        .map(|x| u64::try_from(x.as_nanos()).unwrap_or(u64::MAX)).unwrap_or(0);
    let body = serde_json::to_vec(&json!({
        "live_id": live_id,
        "managed": managed,
        "mic": mic,
        "cleanup_pending": cleanup_pending,
        "saved_at_ns": revision,
    }))
    .map_err(|_| "OBS_STATE_JSON".to_string())?;
    let mut file = std::fs::File::create(&temp).map_err(|_| "OBS_STATE_WRITE".to_string())?;
    file.write_all(&body).map_err(|_| "OBS_STATE_WRITE".to_string())?;
    file.sync_all().map_err(|_| "OBS_STATE_SYNC".to_string())?;
    drop(file);

    let target = state_path();
    #[cfg(windows)]
    if target.exists() {
        std::fs::remove_file(&target).map_err(|_| "OBS_STATE_REPLACE".to_string())?;
    }
    std::fs::rename(&temp, &target).map_err(|_| "OBS_STATE_RENAME".to_string())
}

fn hapus_state() {
    let _ = std::fs::remove_file(state_path());
    let _ = std::fs::remove_file(state_temp_path());
}

// Nonce handshake dan mask frame WebSocket wajib berasal dari CSPRNG OS.
// Tidak ada fallback berbasis waktu/counter: bila RNG gagal, kontrol OBS gagal
// aman sebelum stream key dipasang.
#[cfg(windows)]
fn isi_acak_aman(out: &mut [u8]) -> Result<(), String> {
    use std::ffi::c_void;
    #[link(name = "bcrypt")]
    extern "system" {
        fn BCryptGenRandom(
            algorithm: *mut c_void,
            buffer: *mut u8,
            length: u32,
            flags: u32,
        ) -> i32;
    }
    const BCRYPT_USE_SYSTEM_PREFERRED_RNG: u32 = 0x0000_0002;
    let length = u32::try_from(out.len()).map_err(|_| "OBS_OS_RNG".to_string())?;
    let status = unsafe {
        BCryptGenRandom(
            std::ptr::null_mut(),
            out.as_mut_ptr(),
            length,
            BCRYPT_USE_SYSTEM_PREFERRED_RNG,
        )
    };
    if status == 0 { Ok(()) } else { Err("OBS_OS_RNG".into()) }
}

#[cfg(unix)]
fn isi_acak_aman(out: &mut [u8]) -> Result<(), String> {
    let mut source = std::fs::File::open("/dev/urandom").map_err(|_| "OBS_OS_RNG".to_string())?;
    source.read_exact(out).map_err(|_| "OBS_OS_RNG".to_string())
}

#[cfg(not(any(windows, unix)))]
fn isi_acak_aman(_out: &mut [u8]) -> Result<(), String> {
    Err("OBS_OS_RNG".into())
}

// SHA-1 hanya dipakai untuk validasi Sec-WebSocket-Accept sesuai RFC 6455,
// bukan sebagai primitive autentikasi atau penyimpanan password.
fn sha1(input: &[u8]) -> [u8; 20] {
    let mut data = input.to_vec();
    let bit_len = (data.len() as u64).wrapping_mul(8);
    data.push(0x80);
    while data.len() % 64 != 56 {
        data.push(0);
    }
    data.extend_from_slice(&bit_len.to_be_bytes());
    let mut h = [
        0x6745_2301u32,
        0xefcd_ab89,
        0x98ba_dcfe,
        0x1032_5476,
        0xc3d2_e1f0,
    ];
    for chunk in data.chunks_exact(64) {
        let mut w = [0u32; 80];
        for (i, word) in w.iter_mut().take(16).enumerate() {
            let o = i * 4;
            *word = u32::from_be_bytes([chunk[o], chunk[o + 1], chunk[o + 2], chunk[o + 3]]);
        }
        for i in 16..80 {
            w[i] = (w[i - 3] ^ w[i - 8] ^ w[i - 14] ^ w[i - 16]).rotate_left(1);
        }
        let (mut a, mut b, mut c, mut d, mut e) = (h[0], h[1], h[2], h[3], h[4]);
        for (i, word) in w.iter().enumerate() {
            let (f, k) = match i {
                0..=19 => ((b & c) | ((!b) & d), 0x5a82_7999),
                20..=39 => (b ^ c ^ d, 0x6ed9_eba1),
                40..=59 => ((b & c) | (b & d) | (c & d), 0x8f1b_bcdc),
                _ => (b ^ c ^ d, 0xca62_c1d6),
            };
            let next = a.rotate_left(5)
                .wrapping_add(f)
                .wrapping_add(e)
                .wrapping_add(k)
                .wrapping_add(*word);
            e = d;
            d = c;
            c = b.rotate_left(30);
            b = a;
            a = next;
        }
        for (dst, value) in h.iter_mut().zip([a, b, c, d, e]) {
            *dst = dst.wrapping_add(value);
        }
    }
    let mut out = [0u8; 20];
    for (i, value) in h.iter().enumerate() {
        out[i * 4..i * 4 + 4].copy_from_slice(&value.to_be_bytes());
    }
    out
}

// SHA-256 kecil tanpa dependency tambahan. Dipakai hanya untuk autentikasi
// obs-websocket dan derivasi password lokal dari kode agen.
fn sha256(input: &[u8]) -> [u8; 32] {
    const K: [u32; 64] = [
        0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1,
        0x923f82a4, 0xab1c5ed5, 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
        0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174, 0xe49b69c1, 0xefbe4786,
        0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
        0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147,
        0x06ca6351, 0x14292967, 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
        0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, 0xa2bfe8a1, 0xa81a664b,
        0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
        0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a,
        0x5b9cca4f, 0x682e6ff3, 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
        0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
    ];
    let mut data = input.to_vec();
    let bit_len = (data.len() as u64).wrapping_mul(8);
    data.push(0x80);
    while data.len() % 64 != 56 {
        data.push(0);
    }
    data.extend_from_slice(&bit_len.to_be_bytes());
    let mut h = [
        0x6a09e667u32, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
        0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
    ];
    for chunk in data.chunks_exact(64) {
        let mut w = [0u32; 64];
        for (i, word) in w.iter_mut().take(16).enumerate() {
            let o = i * 4;
            *word = u32::from_be_bytes([chunk[o], chunk[o + 1], chunk[o + 2], chunk[o + 3]]);
        }
        for i in 16..64 {
            let s0 = w[i - 15].rotate_right(7) ^ w[i - 15].rotate_right(18) ^ (w[i - 15] >> 3);
            let s1 = w[i - 2].rotate_right(17) ^ w[i - 2].rotate_right(19) ^ (w[i - 2] >> 10);
            w[i] = w[i - 16]
                .wrapping_add(s0)
                .wrapping_add(w[i - 7])
                .wrapping_add(s1);
        }
        let (mut a, mut b, mut c, mut d, mut e, mut f, mut g, mut hh) =
            (h[0], h[1], h[2], h[3], h[4], h[5], h[6], h[7]);
        for i in 0..64 {
            let s1 = e.rotate_right(6) ^ e.rotate_right(11) ^ e.rotate_right(25);
            let ch = (e & f) ^ ((!e) & g);
            let t1 = hh
                .wrapping_add(s1)
                .wrapping_add(ch)
                .wrapping_add(K[i])
                .wrapping_add(w[i]);
            let s0 = a.rotate_right(2) ^ a.rotate_right(13) ^ a.rotate_right(22);
            let maj = (a & b) ^ (a & c) ^ (b & c);
            let t2 = s0.wrapping_add(maj);
            hh = g;
            g = f;
            f = e;
            e = d.wrapping_add(t1);
            d = c;
            c = b;
            b = a;
            a = t1.wrapping_add(t2);
        }
        for (dst, v) in h.iter_mut().zip([a, b, c, d, e, f, g, hh]) {
            *dst = dst.wrapping_add(v);
        }
    }
    let mut out = [0u8; 32];
    for (i, x) in h.iter().enumerate() {
        out[i * 4..i * 4 + 4].copy_from_slice(&x.to_be_bytes());
    }
    out
}

fn b64(data: &[u8]) -> String {
    const T: &[u8; 64] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    let mut out = String::with_capacity((data.len() + 2) / 3 * 4);
    for c in data.chunks(3) {
        let n = ((c[0] as u32) << 16)
            | ((c.get(1).copied().unwrap_or(0) as u32) << 8)
            | c.get(2).copied().unwrap_or(0) as u32;
        out.push(T[((n >> 18) & 63) as usize] as char);
        out.push(T[((n >> 12) & 63) as usize] as char);
        out.push(if c.len() > 1 { T[((n >> 6) & 63) as usize] as char } else { '=' });
        out.push(if c.len() > 2 { T[(n & 63) as usize] as char } else { '=' });
    }
    out
}

fn password_obs(k: &Konfig) -> String {
    b64(&sha256(format!("xycloud-obs-v1:{}", k.kode).as_bytes()))
}

#[cfg(test)]
mod protocol_tests {
    use super::{b64, sha1, WS_GUID};

    #[test]
    fn rfc6455_accept_vector() {
        let key = "dGhlIHNhbXBsZSBub25jZQ==";
        assert_eq!(b64(&sha1(format!("{key}{WS_GUID}").as_bytes())),
            "s3pPLMBiTxaQ9kYGzzhZRbK+xOo=");
    }
}

struct ObsWs {
    stream: TcpStream,
    pending: Vec<u8>,
    counter: u64,
}

impl ObsWs {
    fn raw_connect() -> Result<Self, String> {
        let addr: SocketAddr = format!("{OBS_HOST}:{OBS_PORT}")
            .parse()
            .map_err(|_| "OBS_ADDRESS".to_string())?;
        let mut stream = TcpStream::connect_timeout(&addr, Duration::from_secs(2))
            .map_err(|_| "OBS_WS_OFFLINE".to_string())?;
        stream
            .set_read_timeout(Some(Duration::from_secs(5)))
            .map_err(|_| "OBS_WS_TIMEOUT".to_string())?;
        stream
            .set_write_timeout(Some(Duration::from_secs(5)))
            .map_err(|_| "OBS_WS_TIMEOUT".to_string())?;
        let mut nonce = [0u8; 16];
        isi_acak_aman(&mut nonce)?;
        let ws_key = b64(&nonce);
        let expected_accept = b64(&sha1(format!("{ws_key}{WS_GUID}").as_bytes()));
        let req = format!(
            "GET / HTTP/1.1\r\nHost: {OBS_HOST}:{OBS_PORT}\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: {ws_key}\r\nSec-WebSocket-Version: 13\r\n\r\n"
        );
        stream
            .write_all(req.as_bytes())
            .map_err(|_| "OBS_WS_HANDSHAKE_WRITE".to_string())?;
        let mut all = Vec::with_capacity(2048);
        let split;
        loop {
            if all.len() > 16_384 {
                return Err("OBS_WS_HANDSHAKE_LARGE".into());
            }
            if let Some(pos) = all.windows(4).position(|x| x == b"\r\n\r\n") {
                split = pos + 4;
                break;
            }
            let mut buf = [0u8; 1024];
            let n = stream.read(&mut buf).map_err(|_| "OBS_WS_HANDSHAKE_READ".to_string())?;
            if n == 0 {
                return Err("OBS_WS_CLOSED".into());
            }
            all.extend_from_slice(&buf[..n]);
        }
        let header = String::from_utf8_lossy(&all[..split]);
        let status_ok = header.lines().next().map(|x| x.contains(" 101 ")).unwrap_or(false);
        let accept_ok = header.lines().any(|line| {
            line.split_once(':')
                .map(|(k, v)| k.trim().eq_ignore_ascii_case("sec-websocket-accept") && v.trim() == expected_accept)
                .unwrap_or(false)
        });
        if !status_ok || !accept_ok {
            return Err("OBS_WS_HANDSHAKE_REJECTED".into());
        }
        Ok(Self { stream, pending: all[split..].to_vec(), counter: 0 })
    }

    fn take(&mut self, n: usize) -> Result<Vec<u8>, String> {
        while self.pending.len() < n {
            let mut buf = [0u8; 4096];
            let got = self.stream.read(&mut buf).map_err(|_| "OBS_WS_READ".to_string())?;
            if got == 0 {
                return Err("OBS_WS_CLOSED".into());
            }
            self.pending.extend_from_slice(&buf[..got]);
            if self.pending.len() > MAX_WS + 32 {
                return Err("OBS_WS_MESSAGE_LARGE".into());
            }
        }
        Ok(self.pending.drain(..n).collect())
    }

    fn write_frame(&mut self, opcode: u8, payload: &[u8]) -> Result<(), String> {
        if payload.len() > MAX_WS {
            return Err("OBS_WS_MESSAGE_LARGE".into());
        }
        let mut frame = Vec::with_capacity(payload.len() + 20);
        frame.push(0x80 | (opcode & 0x0f));
        if payload.len() < 126 {
            frame.push(0x80 | payload.len() as u8);
        } else if payload.len() <= u16::MAX as usize {
            frame.push(0x80 | 126);
            frame.extend_from_slice(&(payload.len() as u16).to_be_bytes());
        } else {
            frame.push(0x80 | 127);
            frame.extend_from_slice(&(payload.len() as u64).to_be_bytes());
        }
        let mut mask = [0u8; 4];
        isi_acak_aman(&mut mask)?;
        frame.extend_from_slice(&mask);
        frame.extend(payload.iter().enumerate().map(|(i, b)| b ^ mask[i % 4]));
        self.stream.write_all(&frame).map_err(|_| "OBS_WS_WRITE".to_string())
    }

    fn read_text(&mut self) -> Result<String, String> {
        loop {
            let h = self.take(2)?;
            if h[0] & 0x70 != 0 || h[0] & 0x80 == 0 {
                return Err("OBS_WS_FRAGMENTED".into());
            }
            let opcode = h[0] & 0x0f;
            let masked = h[1] & 0x80 != 0;
            if masked {
                // RFC 6455 melarang server memask frame. Menolak bentuk ini
                // juga mengurangi ruang bagi proses lokal palsu di port OBS.
                return Err("OBS_WS_SERVER_MASKED".into());
            }
            let mut len = (h[1] & 0x7f) as u64;
            if len == 126 {
                let x = self.take(2)?;
                len = u16::from_be_bytes([x[0], x[1]]) as u64;
            } else if len == 127 {
                let x = self.take(8)?;
                len = u64::from_be_bytes(x.try_into().map_err(|_| "OBS_WS_LENGTH".to_string())?);
            }
            if len > MAX_WS as u64 || (opcode >= 0x8 && len > 125) {
                return Err("OBS_WS_MESSAGE_LARGE".into());
            }
            let mut body = self.take(len as usize)?;
            match opcode {
                0x1 => return String::from_utf8(body).map_err(|_| "OBS_WS_UTF8".to_string()),
                0x8 => return Err("OBS_WS_CLOSED".into()),
                0x9 => {
                    self.write_frame(0xA, &body)?;
                }
                0xA => {}
                _ => return Err("OBS_WS_OPCODE".into()),
            }
        }
    }

    fn read_json(&mut self) -> Result<Value, String> {
        let text = self.read_text()?;
        serde_json::from_str(&text).map_err(|_| "OBS_WS_JSON".to_string())
    }

    fn send_json(&mut self, value: &Value) -> Result<(), String> {
        let body = serde_json::to_vec(value).map_err(|_| "OBS_WS_JSON".to_string())?;
        self.write_frame(0x1, &body)
    }
}

struct ObsClient {
    ws: ObsWs,
}

impl ObsClient {
    fn connect(password: &str) -> Result<Self, String> {
        let mut ws = ObsWs::raw_connect()?;
        let hello = ws.read_json()?;
        if hello.get("op").and_then(Value::as_i64) != Some(0) {
            return Err("OBS_PROTOCOL_HELLO".into());
        }
        let auth = hello.pointer("/d/authentication").ok_or("OBS_AUTH_REQUIRED")?;
        let salt = auth.get("salt").and_then(Value::as_str).ok_or("OBS_AUTH_SALT")?;
        let challenge = auth.get("challenge").and_then(Value::as_str).ok_or("OBS_AUTH_CHALLENGE")?;
        let secret = b64(&sha256(format!("{password}{salt}").as_bytes()));
        let response = b64(&sha256(format!("{secret}{challenge}").as_bytes()));
        let identify = json!({
            "rpcVersion": 1,
            "eventSubscriptions": 0,
            "authentication": response
        });
        ws.send_json(&json!({"op": 1, "d": identify}))?;
        let identified = ws.read_json()?;
        if identified.get("op").and_then(Value::as_i64) != Some(2) {
            return Err("OBS_AUTH_FAILED".into());
        }
        Ok(Self { ws })
    }

    fn request(&mut self, kind: &str, data: Value) -> Result<Value, String> {
        self.ws.counter = self.ws.counter.wrapping_add(1);
        let id = format!("xy-{}", self.ws.counter);
        self.ws.send_json(&json!({
            "op": 6,
            "d": {"requestType": kind, "requestId": id, "requestData": data}
        }))?;
        for _ in 0..20 {
            let msg = self.ws.read_json()?;
            if msg.get("op").and_then(Value::as_i64) != Some(7)
                || msg.pointer("/d/requestId").and_then(Value::as_str) != Some(id.as_str())
            {
                continue;
            }
            let ok = msg.pointer("/d/requestStatus/result").and_then(Value::as_bool).unwrap_or(false);
            if !ok {
                let code = msg.pointer("/d/requestStatus/code").and_then(Value::as_i64).unwrap_or(0);
                let clean: String = kind.chars().filter(|x| x.is_ascii_alphanumeric()).collect();
                return Err(format!("OBS_{}_{}", clean.to_ascii_uppercase(), code));
            }
            return Ok(msg.pointer("/d/responseData").cloned().unwrap_or_else(|| json!({})));
        }
        Err("OBS_RESPONSE_MISSING".into())
    }
}

fn cari_obs_exe() -> Option<PathBuf> {
    let mut kandidat = vec![
        PathBuf::from(r"C:\Program Files\obs-studio\bin\64bit\obs64.exe"),
        PathBuf::from(r"C:\Program Files (x86)\obs-studio\bin\64bit\obs64.exe"),
    ];
    if let Ok(pf) = std::env::var("ProgramFiles") {
        kandidat.push(PathBuf::from(pf).join("obs-studio").join("bin").join("64bit").join("obs64.exe"));
    }
    if let Some(path) = kandidat.into_iter().find(|p| p.is_file()) {
        return Some(path);
    }
    let out = perintah("where").arg("obs64.exe").output().ok()?;
    String::from_utf8_lossy(&out.stdout)
        .lines()
        .map(str::trim)
        .map(PathBuf::from)
        .find(|p| p.is_file())
}

fn obs_running() -> bool {
    match perintah("tasklist")
        .args(["/FI", "IMAGENAME eq obs64.exe", "/NH"])
        .output()
    {
        Ok(out) => String::from_utf8_lossy(&out.stdout).to_ascii_lowercase().contains("obs64.exe"),
        Err(_) => false,
    }
}

fn launch_obs(exe: &PathBuf, password: &str) -> Result<Child, String> {
    let mut cmd = perintah(&exe.to_string_lossy());
    if let Some(dir) = exe.parent() {
        cmd.current_dir(dir);
    }
    cmd.arg("--minimize-to-tray")
        .arg("--disable-shutdown-check")
        .arg("--websocket_port=4455")
        .arg(format!("--websocket_password={password}"))
    .stdin(Stdio::null())
    .stdout(Stdio::null())
    .stderr(Stdio::null())
    .spawn()
    .map_err(|_| "OBS_LAUNCH_FAILED".to_string())
}

fn connect_or_launch(k: &Konfig) -> Result<(ObsClient, bool, Option<Child>), String> {
    let password = password_obs(k);
    if obs_running() {
        return ObsClient::connect(&password)
            .map(|c| (c, false, None))
            .map_err(|_| "OBS_UNMANAGED_RUNNING".to_string());
    }
    let exe = cari_obs_exe().ok_or("OBS_NOT_INSTALLED")?;
    let mut child = launch_obs(&exe, &password)?;
    let start = Instant::now();
    while start.elapsed() < Duration::from_secs(25) {
        match ObsClient::connect(&password) {
            Ok(c) => return Ok((c, true, Some(child))),
            Err(_) => std::thread::sleep(Duration::from_millis(750)),
        }
    }
    let _ = child.kill();
    let _ = child.wait();
    Err("OBS_START_TIMEOUT".into())
}

fn item_kind(obs: &mut ObsClient, name: &str) -> Result<String, String> {
    let v = obs.request("GetInputSettings", json!({"inputName": name}))?;
    Ok(v.get("inputKind").and_then(Value::as_str).unwrap_or("").to_string())
}

fn require_obs_version(obs: &mut ObsClient) -> Result<(), String> {
    // Capture Audio di dalam Game Capture baru tersedia mulai OBS 30.1.
    // Versi lebih tua akan menghasilkan video tanpa audio game bila diterima.
    let v = obs.request("GetVersion", json!({}))?;
    let raw = v.get("obsVersion").and_then(Value::as_str).ok_or("OBS_VERSION_UNKNOWN")?;
    let mut parts = raw.split('.');
    let major = parts.next().and_then(|x| x.parse::<u32>().ok()).ok_or("OBS_VERSION_UNKNOWN")?;
    let minor = parts.next().and_then(|x| x.parse::<u32>().ok()).ok_or("OBS_VERSION_UNKNOWN")?;
    if major < 30 || (major == 30 && minor < 1) {
        return Err("OBS_VERSION_REQUIRES_30_1".into());
    }
    Ok(())
}

fn game_capture_settings(obs: &mut ObsClient, mutate: bool) -> Result<(), String> {
    let expected = json!({
        "capture_mode": "any_fullscreen",
        "capture_audio": true,
        "capture_cursor": false,
        "allow_transparency": false,
        "capture_overlays": false,
        "anti_cheat_hook": true
    });
    if mutate {
        obs.request("SetInputSettings", json!({
            "inputName": GAME, "inputSettings": expected, "overlay": true
        }))?;
    }
    let v = obs.request("GetInputSettings", json!({"inputName": GAME}))?;
    if v.get("inputKind").and_then(Value::as_str) != Some("game_capture") {
        return Err("OBS_GAME_CAPTURE_WRONG_KIND".into());
    }
    let s = v.get("inputSettings").ok_or("OBS_GAME_CAPTURE_SETTINGS_MISSING")?;
    let aman = s.get("capture_mode").and_then(Value::as_str) == Some("any_fullscreen")
        && s.get("capture_audio").and_then(Value::as_bool) == Some(true)
        && s.get("capture_cursor").and_then(Value::as_bool) == Some(false)
        && s.get("allow_transparency").and_then(Value::as_bool) == Some(false)
        && s.get("capture_overlays").and_then(Value::as_bool) == Some(false)
        && s.get("anti_cheat_hook").and_then(Value::as_bool) == Some(true);
    if !aman {
        return Err("OBS_GAME_CAPTURE_SETTINGS_UNSAFE".into());
    }
    Ok(())
}

fn scene_items(obs: &mut ObsClient) -> Result<Vec<Value>, String> {
    let v = obs.request("GetSceneItemList", json!({"sceneName": SCENE}))?;
    Ok(v.get("sceneItems").and_then(Value::as_array).cloned().unwrap_or_default())
}

fn audit_input_audio(
    obs: &mut ObsClient,
    name: &str,
    expected_muted: bool,
    normalize_volume: bool,
    mutate: bool,
) -> Result<(), String> {
    if mutate {
        obs.request("SetInputMute", json!({
            "inputName": name, "inputMuted": expected_muted
        }))?;
        let track_one = !expected_muted;
        obs.request("SetInputAudioTracks", json!({
            "inputName": name,
            "inputAudioTracks": {
                "1": track_one, "2": false, "3": false,
                "4": false, "5": false, "6": false
            }
        }))?;
        if normalize_volume {
            obs.request("SetInputVolume", json!({
                "inputName": name, "inputVolumeMul": 1.0
            }))?;
        }
    }
    let muted = obs.request("GetInputMute", json!({"inputName": name}))?
        .get("inputMuted").and_then(Value::as_bool).unwrap_or(!expected_muted);
    if muted != expected_muted {
        return Err("OBS_INPUT_MUTE_MISMATCH".into());
    }
    let tracks = obs.request("GetInputAudioTracks", json!({"inputName": name}))?;
    let expected_track_one = !expected_muted;
    if tracks.pointer("/inputAudioTracks/1").and_then(Value::as_bool) != Some(expected_track_one) {
        return Err("OBS_STREAM_AUDIO_TRACK_MISMATCH".into());
    }
    for track in ["2", "3", "4", "5", "6"] {
        if tracks.pointer(&format!("/inputAudioTracks/{track}"))
            .and_then(Value::as_bool) != Some(false)
        {
            return Err("OBS_UNEXPECTED_AUDIO_TRACK_ENABLED".into());
        }
    }
    if !expected_muted {
        let volume = obs.request("GetInputVolume", json!({"inputName": name}))?
            .get("inputVolumeMul").and_then(Value::as_f64).unwrap_or(0.0);
        if !volume.is_finite() || volume <= 0.001 {
            return Err("OBS_INPUT_VOLUME_ZERO".into());
        }
    }
    Ok(())
}

fn scene_item_enabled(
    obs: &mut ObsClient,
    item_id: i64,
    expected: bool,
    mutate: bool,
) -> Result<(), String> {
    if mutate {
        obs.request("SetSceneItemEnabled", json!({
            "sceneName": SCENE, "sceneItemId": item_id, "sceneItemEnabled": expected
        }))?;
    }
    let result = obs.request("GetSceneItemEnabled", json!({
        "sceneName": SCENE, "sceneItemId": item_id
    }))?;
    if result.get("sceneItemEnabled").and_then(Value::as_bool) != Some(expected) {
        return Err("OBS_SCENE_ITEM_ENABLED_MISMATCH".into());
    }
    Ok(())
}

fn audit_scene(obs: &mut ObsClient, mic_consent: bool, mutate: bool) -> Result<(), String> {
    require_obs_version(obs)?;
    let list = obs.request("GetSceneList", json!({}))?;
    let exists = list
        .get("scenes")
        .and_then(Value::as_array)
        .map(|x| x.iter().any(|s| s.get("sceneName").and_then(Value::as_str) == Some(SCENE)))
        .unwrap_or(false);
    if !exists {
        if !mutate {
            return Err("OBS_SAFE_SCENE_MISSING".into());
        }
        obs.request("CreateScene", json!({"sceneName": SCENE}))?;
    }

    let mut items = scene_items(obs)?;
    for item in &items {
        let name = item.get("sourceName").and_then(Value::as_str).unwrap_or("");
        if name != GAME && name != MIC {
            return Err("OBS_UNSAFE_SCENE_SOURCE".into());
        }
    }

    let has_game = items.iter().any(|x| x.get("sourceName").and_then(Value::as_str) == Some(GAME));
    if !has_game {
        if !mutate {
            return Err("OBS_GAME_CAPTURE_MISSING".into());
        }
        obs.request(
            "CreateInput",
            json!({
                "sceneName": SCENE,
                "inputName": GAME,
                "inputKind": "game_capture",
                "inputSettings": {
                    "capture_mode": "any_fullscreen",
                    "capture_audio": true,
                    "capture_cursor": false,
                    "allow_transparency": false,
                    "capture_overlays": false,
                    "anti_cheat_hook": true
                },
                "sceneItemEnabled": true
            }),
        )?;
        items = scene_items(obs)?;
    }

    let game_count = items.iter()
        .filter(|x| x.get("sourceName").and_then(Value::as_str) == Some(GAME))
        .count();
    let mic_count = items.iter()
        .filter(|x| x.get("sourceName").and_then(Value::as_str) == Some(MIC))
        .count();
    if game_count != 1 || mic_count > 1 {
        return Err("OBS_SAFE_SCENE_DUPLICATE_SOURCE".into());
    }

    let mut game_ok = false;
    let mut mic_seen = false;
    for item in &items {
        let name = item.get("sourceName").and_then(Value::as_str).unwrap_or("");
        let item_id = item.get("sceneItemId").and_then(Value::as_i64).ok_or("OBS_SCENE_ITEM_ID")?;
        if name == GAME {
            game_capture_settings(obs, mutate)?;
            game_ok = true;
            scene_item_enabled(obs, item_id, true, mutate)
                .map_err(|_| "OBS_GAME_CAPTURE_DISABLED".to_string())?;
            audit_input_audio(obs, GAME, false, true, mutate).map_err(|code| match code.as_str() {
                "OBS_INPUT_MUTE_MISMATCH" => "OBS_GAME_AUDIO_MUTED".to_string(),
                "OBS_STREAM_AUDIO_TRACK_MISMATCH" => "OBS_GAME_AUDIO_TRACK_DISABLED".to_string(),
                "OBS_UNEXPECTED_AUDIO_TRACK_ENABLED" => "OBS_GAME_AUDIO_EXTRA_TRACK".to_string(),
                "OBS_INPUT_VOLUME_ZERO" => "OBS_GAME_AUDIO_VOLUME_ZERO".to_string(),
                _ => "OBS_GAME_AUDIO_UNAVAILABLE".to_string(),
            })?;
        } else if name == MIC {
            mic_seen = true;
            if item_kind(obs, MIC)? != "wasapi_input_capture" {
                return Err("OBS_MIC_WRONG_KIND".into());
            }
            scene_item_enabled(obs, item_id, mic_consent, mutate)
                .map_err(|_| "OBS_MIC_CONSENT_MISMATCH".to_string())?;
            audit_input_audio(obs, MIC, !mic_consent, false, mutate)
                .map_err(|_| "OBS_MIC_CONSENT_MISMATCH".to_string())?;
        }
    }
    if !game_ok {
        return Err("OBS_GAME_CAPTURE_MISSING".into());
    }
    if mic_consent && !mic_seen {
        return Err("OBS_MIC_NOT_CONFIGURED".into());
    }
    if !mutate {
        let current = list.get("currentProgramSceneName").and_then(Value::as_str).unwrap_or("");
        if current != SCENE {
            return Err("OBS_SCENE_CHANGED".into());
        }
        secure_global_audio(obs, false)?;
    }
    Ok(())
}

fn stream_status(obs: &mut ObsClient) -> Result<Value, String> {
    obs.request("GetStreamStatus", json!({}))
}

fn output_active(status: &Value) -> bool {
    status.get("outputActive").and_then(Value::as_bool).unwrap_or(false)
}

fn clear_service(obs: &mut ObsClient) -> Result<(), String> {
    // OBS dapat menolak SetStreamServiceSettings sesaat setelah StopStream.
    // Retry dibatasi agar command agen tidak menggantung, lalu verifikasi tanpa
    // pernah menyalin key lama ke log/error/state.
    let mut last = "OBS_STREAM_KEY_CLEANUP_FAILED".to_string();
    for attempt in 0..6 {
        match obs.request(
            "SetStreamServiceSettings",
            json!({
                "streamServiceType": "rtmp_custom",
                "streamServiceSettings": {"server": INGEST_SERVER, "key": "", "use_auth": false}
            }),
        ) {
            Ok(_) => match obs.request("GetStreamServiceSettings", json!({})) {
                Ok(v) => {
                    let key = v
                        .pointer("/streamServiceSettings/key")
                        .and_then(Value::as_str)
                        .unwrap_or("");
                    if key.is_empty() {
                        return Ok(());
                    }
                    last = "OBS_STREAM_KEY_NOT_CLEARED".to_string();
                }
                Err(code) => last = code,
            },
            Err(code) => last = code,
        }
        if attempt < 5 {
            std::thread::sleep(Duration::from_millis(600));
        }
    }
    Err(last)
}

fn service_settings(obs: &mut ObsClient) -> Result<Value, String> {
    obs.request("GetStreamServiceSettings", json!({}))
}

fn set_service_checked(
    obs: &mut ObsClient,
    ingest_url: &str,
    stream_key: &str,
) -> Result<(), String> {
    obs.request(
        "SetStreamServiceSettings",
        json!({
            "streamServiceType": "rtmp_custom",
            "streamServiceSettings": {
                "server": ingest_url, "key": stream_key, "use_auth": false
            }
        }),
    )?;
    let current = service_settings(obs)?;
    let settings = current.get("streamServiceSettings").ok_or("OBS_STREAM_SERVICE_MISSING")?;
    if current.get("streamServiceType").and_then(Value::as_str) != Some("rtmp_custom")
        || settings.get("server").and_then(Value::as_str) != Some(ingest_url)
        || settings.get("key").and_then(Value::as_str) != Some(stream_key)
        || settings.get("use_auth").and_then(Value::as_bool).unwrap_or(false)
    {
        return Err("OBS_STREAM_SERVICE_NOT_APPLIED".into());
    }
    Ok(())
}

fn audit_service_route(obs: &mut ObsClient) -> Result<(), String> {
    let current = service_settings(obs)?;
    let settings = current.get("streamServiceSettings").ok_or("OBS_STREAM_SERVICE_MISSING")?;
    let key = settings.get("key").and_then(Value::as_str).unwrap_or("");
    if current.get("streamServiceType").and_then(Value::as_str) != Some("rtmp_custom")
        || settings.get("server").and_then(Value::as_str) != Some(INGEST_SERVER)
        || key.len() < 20 || key.len() > 512
        || !key.bytes().all(|b| b.is_ascii_alphanumeric() || b"._~-".contains(&b))
        || settings.get("use_auth").and_then(Value::as_bool).unwrap_or(false)
    {
        return Err("OBS_STREAM_SERVICE_CHANGED".into());
    }
    Ok(())
}

fn set_profile_checked(obs: &mut ObsClient, category: &str, name: &str, value: &str) -> Result<(), String> {
    obs.request("SetProfileParameter", json!({
        "parameterCategory": category, "parameterName": name, "parameterValue": value
    }))?;
    let current = obs.request("GetProfileParameter", json!({
        "parameterCategory": category, "parameterName": name
    }))?;
    if current.get("parameterValue").and_then(Value::as_str)
        .map(|x| x.eq_ignore_ascii_case(value)).unwrap_or(false)
    {
        Ok(())
    } else {
        Err("OBS_PROFILE_SETTING_NOT_APPLIED".into())
    }
}

fn audit_stream_profile(obs: &mut ObsClient) -> Result<(), String> {
    for (category, name, expected) in STREAM_PROFILE {
        let current = obs.request("GetProfileParameter", json!({
            "parameterCategory": category, "parameterName": name
        }))?;
        if !current.get("parameterValue").and_then(Value::as_str)
            .map(|x| x.eq_ignore_ascii_case(expected)).unwrap_or(false)
        {
            return Err("OBS_PROFILE_SETTING_CHANGED".into());
        }
    }
    Ok(())
}

fn configure_stream_profile(obs: &mut ObsClient) -> Result<(), String> {
    // Profil sederhana yang deterministik: 1080p30 dengan headroom uplink.
    // DynamicBitrate menurunkan bitrate saat congestion daripada membuang frame;
    // reconnect dibatasi 20 kali agar live yang benar-benar putus tetap berakhir.
    for (category, name, value) in STREAM_PROFILE {
        set_profile_checked(obs, category, name, value)?;
    }
    audit_stream_profile(obs)
}

fn audit_video(obs: &mut ObsClient) -> Result<(), String> {
    let current = obs.request("GetVideoSettings", json!({}))?;
    let exact = current.get("baseWidth").and_then(Value::as_i64) == Some(1920)
        && current.get("baseHeight").and_then(Value::as_i64) == Some(1080)
        && current.get("outputWidth").and_then(Value::as_i64) == Some(1920)
        && current.get("outputHeight").and_then(Value::as_i64) == Some(1080)
        && current.get("fpsNumerator").and_then(Value::as_i64) == Some(30)
        && current.get("fpsDenominator").and_then(Value::as_i64) == Some(1);
    if !exact {
        return Err("OBS_VIDEO_SETTINGS_CHANGED".into());
    }
    Ok(())
}

fn configure_video(obs: &mut ObsClient) -> Result<(), String> {
    obs.request(
        "SetVideoSettings",
        json!({
            "baseWidth": 1920, "baseHeight": 1080,
            "outputWidth": 1920, "outputHeight": 1080,
            "fpsNumerator": 30, "fpsDenominator": 1
        }),
    )?;
    audit_video(obs).map_err(|_| "OBS_VIDEO_SETTINGS_NOT_APPLIED".to_string())
}

fn secure_global_audio(obs: &mut ObsClient, mutate: bool) -> Result<(), String> {
    // SetProfileParameter resmi tersedia sejak obs-websocket v5.0. Nilai ini
    // adalah konfigurasi basic.ini OBS; verifikasi mencegah start bila build
    // OBS tertentu mengabaikannya. Special input yang sudah hidup juga dibisukan
    // segera, karena perubahan profile dapat baru penuh setelah reload.
    for parameter in [
        "DesktopDevice1", "DesktopDevice2", "AuxDevice1",
        "AuxDevice2", "AuxDevice3", "AuxDevice4",
    ] {
        if mutate {
            obs.request("SetProfileParameter", json!({
                "parameterCategory": "Audio",
                "parameterName": parameter,
                "parameterValue": "disabled"
            }))?;
        }
        let value = obs.request("GetProfileParameter", json!({
            "parameterCategory": "Audio", "parameterName": parameter
        }))?;
        if !value.get("parameterValue")
            .and_then(Value::as_str)
            .map(|x| x.eq_ignore_ascii_case("disabled"))
            .unwrap_or(false)
        {
            return Err("OBS_GLOBAL_AUDIO_NOT_DISABLED".into());
        }
    }

    let special = obs.request("GetSpecialInputs", json!({}))?;
    for field in ["desktop1", "desktop2", "mic1", "mic2", "mic3", "mic4"] {
        let Some(name) = special.get(field).and_then(Value::as_str).filter(|x| !x.is_empty()) else {
            continue;
        };
        if mutate {
            obs.request("SetInputMute", json!({"inputName": name, "inputMuted": true}))?;
        }
        let muted = obs.request("GetInputMute", json!({"inputName": name}))?
            .get("inputMuted").and_then(Value::as_bool).unwrap_or(false);
        if !muted {
            return Err("OBS_GLOBAL_AUDIO_UNMUTED".into());
        }
    }
    Ok(())
}

fn audit_runtime(obs: &mut ObsClient, mic_consent: bool) -> Result<(), String> {
    audit_scene(obs, mic_consent, false)?;
    audit_stream_profile(obs)?;
    audit_video(obs)?;
    audit_service_route(obs)
}

fn stop_output(obs: &mut ObsClient) -> Result<(), String> {
    let initial = stream_status(obs)?;
    if output_active(&initial) {
        obs.request("StopStream", json!({}))?;
        let start = Instant::now();
        while start.elapsed() < Duration::from_secs(15) {
            if !output_active(&stream_status(obs)?) {
                break;
            }
            std::thread::sleep(Duration::from_millis(500));
        }
        if output_active(&stream_status(obs)?) {
            return Err("OBS_STOP_TIMEOUT".into());
        }
    }
    clear_service(obs)
}

fn kill_obs() {
    let _ = perintah("taskkill")
        .args(["/IM", "obs64.exe", "/T", "/F"])
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status();
}

/// Pasang OBS lewat winget saat operator menjalankan Setup Engine. Kegagalan
/// tidak mengganggu Sunshine; dashboard akan tetap menandai unit belum siap live.
pub(super) fn pastikan_terpasang(log: &Logger) -> bool {
    if cari_obs_exe().is_some() {
        log("OBS Studio terdeteksi — versi 30.1+ akan diverifikasi sebelum Game Capture dan audio game diizinkan.");
        return true;
    }
    log("OBS Studio belum ada — mencoba winget OBSProject.OBSStudio (maks 180 dtk)…");
    match super::jalankan_timeout(
        "winget",
        &[
            "install", "--id", "OBSProject.OBSStudio", "-e", "--silent",
            "--disable-interactivity", "--accept-source-agreements", "--accept-package-agreements",
        ],
        180,
        log,
    ) {
        Ok((code, _)) if code == 0 || cari_obs_exe().is_some() => {
            log("OBS Studio siap. Scene aman dibuat otomatis saat kreator mulai live.");
            true
        }
        Ok((code, _)) => {
            log(&format!("OBS belum terpasang (winget kode {code}). Instal OBS Studio resmi lalu ulangi Setup Engine."));
            false
        }
        Err(_) => {
            log("Pemasangan OBS gagal/timeout. Instal OBS Studio resmi secara manual; live akan gagal aman sampai tersedia.");
            false
        }
    }
}

/// Selama tombstone live ada, loop agen mempercepat heartbeat/audit lokal agar
/// perubahan scene berbahaya dihentikan dalam hitungan detik, bukan satu siklus idle.
pub(super) fn perlu_pantau_cepat() -> bool {
    baca_state().is_some()
}

/// Status ringan untuk diagnostik heartbeat (tanpa credential).
pub(super) fn status() -> Value {
    let state = baca_state();
    json!({
        "installed": cari_obs_exe().is_some(),
        "running": obs_running(),
        "managed_live": state.as_ref().map(|x| x.live_id.as_str()),
        "cleanup_pending": state.as_ref().map(|x| x.cleanup_pending).unwrap_or(false),
    })
}

/// Mulai output Cloudflare dari scene yang dikunci aman.
pub(super) fn mulai(
    k: &Konfig,
    live_id: &str,
    ingest_url: &str,
    stream_key: &str,
    mic_consent: bool,
    log: &Logger,
) -> Result<(), String> {
    if !live_id.starts_with("live_") || live_id.len() > 80 {
        return Err("LIVE_ID_INVALID".into());
    }
    if ingest_url != INGEST_SERVER
        || stream_key.len() < 20
        || stream_key.len() > 512
        || !stream_key.bytes().all(|b| b.is_ascii_alphanumeric() || b"._~-".contains(&b))
    {
        return Err("INGEST_CREDENTIAL_INVALID".into());
    }
    let mut prior = baca_state();
    let was_running = obs_running();
    if was_running && prior.is_none() {
        // Jangan mengambil alih OBS yang dibuka manual walaupun password lokal
        // kebetulan cocok. Operator harus menutupnya agar scene/profil pribadi
        // tidak pernah dimutasi atau disiarkan oleh agen.
        return Err("OBS_UNMANAGED_RUNNING".into());
    }
    if let Some(s) = &prior {
        if s.live_id != live_id && was_running {
            return Err("OBS_ACTIVE_OTHER_LIVE".into());
        }
        // State tidak boleh dihapus hanya karena OBS crash: service profile
        // dapat masih memuat key lama. OBS diluncurkan kembali di bawah ini,
        // lalu key wajib dibersihkan sebelum credential baru dipasang.
    }

    let (mut obs, launched, mut child) = connect_or_launch(k)?;
    if prior.is_some() && !was_running {
        if let Err(code) = stop_output(&mut obs) {
            if let Some(s) = &prior {
                let _ = simpan_state(&s.live_id, s.managed || launched, s.mic, true);
            }
            log(&format!("Pemulihan OBS tertahan ({code}); credential tidak dianggap bersih."));
            return Err("OBS_STALE_CREDENTIAL_CLEANUP_PENDING".into());
        }
        hapus_state();
        prior = None;
    }
    let prior_managed = prior.as_ref().map(|x| x.live_id == live_id && x.managed).unwrap_or(false);
    let managed = launched || prior_managed;

    let current = match stream_status(&mut obs) {
        Ok(v) => v,
        Err(code) => {
            if launched {
                if let Some(c) = child.as_mut() {
                    let _ = c.kill();
                    let _ = c.wait();
                }
            }
            return Err(code);
        }
    };
    if output_active(&current) {
        if prior.as_ref().map(|x| x.live_id.as_str()) == Some(live_id) {
            let consent = prior.as_ref().map(|x| x.mic).unwrap_or(mic_consent);
            if let Err(code) = audit_runtime(&mut obs, consent) {
                if let Err(cleanup) = stop_output(&mut obs) {
                    let _ = simpan_state(live_id, managed, consent, true);
                    log(&format!("FAIL-CLOSED OBS menunggu cleanup credential: {cleanup}."));
                    return Err("OBS_FAIL_CLOSED_CLEANUP_PENDING".into());
                }
                if managed {
                    kill_obs();
                }
                hapus_state();
                return Err(code);
            }
            // Crash dapat terjadi setelah StartStream tetapi sebelum tombstone
            // diubah menjadi sehat. Audit sukses pada replay menutup jendela itu.
            simpan_state(live_id, managed, consent, false)?;
            return Ok(());
        }
        return Err("OBS_ACTIVE_UNKNOWN_LIVE".into());
    }

    if let Some(state) = prior.as_ref() {
        // Output sudah mati, tetapi profil bisa masih membawa key. Bersihkan dan
        // verifikasi sebelum credential (meski untuk live yang sama) dipasang.
        if let Err(code) = stop_output(&mut obs) {
            let _ = simpan_state(&state.live_id, managed, state.mic, true);
            log(&format!("Pemulihan credential OBS tertahan: {code}."));
            return Err("OBS_STALE_CREDENTIAL_CLEANUP_PENDING".into());
        }
        hapus_state();
    }

    let setup = (|| -> Result<(), String> {
        audit_scene(&mut obs, mic_consent, true)?;
        // Matikan serta verifikasi seluruh global Desktop Audio/Mic agar
        // notifikasi, panggilan, atau suara ruangan tidak ikut. Audio hanya
        // boleh dari Game Capture dan source mic eksplisit di scene aman.
        secure_global_audio(&mut obs, true)?;
        configure_stream_profile(&mut obs)?;
        obs.request("SetCurrentProgramScene", json!({"sceneName": SCENE}))?;
        let program = obs.request("GetCurrentProgramScene", json!({}))?;
        if program.get("currentProgramSceneName").and_then(Value::as_str) != Some(SCENE) {
            return Err("OBS_PROGRAM_SCENE_NOT_APPLIED".into());
        }
        configure_video(&mut obs)?;
        // Tulis tombstone dan fsync SEBELUM key masuk profil OBS. Jika agen
        // mati pada instruksi berikutnya, start/end selanjutnya tahu bahwa OBS
        // wajib dibuka tanpa autostart lalu key diverifikasi kosong.
        simpan_state(live_id, managed, mic_consent, true)?;
        set_service_checked(&mut obs, ingest_url, stream_key)?;
        obs.request("StartStream", json!({}))?;
        let start = Instant::now();
        while start.elapsed() < Duration::from_secs(20) {
            if output_active(&stream_status(&mut obs)?) {
                // Tutup race antara audit awal dan StartStream: scene/audio,
                // profil video, bitrate, dan route ingest diverifikasi lagi saat
                // output benar-benar aktif.
                audit_runtime(&mut obs, mic_consent)?;
                simpan_state(live_id, managed, mic_consent, false)?;
                return Ok(());
            }
            std::thread::sleep(Duration::from_millis(750));
        }
        Err("OBS_START_STREAM_TIMEOUT".into())
    })();

    if let Err(code) = setup {
        if let Err(cleanup) = stop_output(&mut obs) {
            // Pertahankan state/proses agar heartbeat atau command berikutnya
            // dapat mencoba cleanup lagi. Jangan membunuh OBS dengan key yang
            // belum terverifikasi kosong dari profile.
            let _ = simpan_state(live_id, managed, mic_consent, true);
            log(&format!("Livestream gagal dan cleanup OBS tertahan: {cleanup}. Ingress harus tetap diblokir."));
            return Err("OBS_START_CLEANUP_PENDING".into());
        }
        if launched {
            if let Some(c) = child.as_mut() {
                let _ = c.kill();
                let _ = c.wait();
            }
        }
        hapus_state();
        log(&format!("Livestream gagal aman: {code}. Tidak ada Display Capture fallback."));
        return Err(code);
    }
    log("OBS live aktif: scene aman tervalidasi (Game Capture saja). Credential tidak dicatat.");
    Ok(())
}

/// Berhenti idempotent, kosongkan key OBS, lalu tutup OBS yang diluncurkan agen.
pub(super) fn akhiri(k: &Konfig, live_id: &str, log: &Logger) -> Result<(), String> {
    let state = baca_state();
    if state.is_none() && !obs_running() {
        return Ok(());
    }
    let state = state.ok_or("OBS_STATE_MISSING")?;
    if state.live_id != live_id {
        return Err("OBS_LIVE_ID_MISMATCH".into());
    }

    let was_running = obs_running();
    let password = password_obs(k);
    let (mut obs, launched, mut child) = if was_running {
        (ObsClient::connect(&password).map_err(|_| "OBS_CONTROL_UNAVAILABLE".to_string())?, false, None)
    } else {
        // Pulihkan OBS setelah crash hanya untuk mengosongkan service profile.
        // OBS tidak diberi --startstreaming, jadi key lama tidak diterbitkan.
        connect_or_launch(k)?
    };
    if let Err(code) = stop_output(&mut obs) {
        let _ = simpan_state(&state.live_id, state.managed || launched, state.mic, true);
        return Err(code);
    }
    if state.managed || launched {
        // Key sudah diverifikasi kosong sebelum proses ditutup paksa.
        if let Some(c) = child.as_mut() {
            let _ = c.kill();
            let _ = c.wait();
        } else {
            kill_obs();
        }
    }
    hapus_state();
    log("OBS livestream dihentikan dan credential runtime dibersihkan.");
    Ok(())
}

/// Hentikan live aktif saat sesi rental/loop agen ditutup. Kegagalan diteruskan
/// agar sesi PC tetap terkunci sampai credential OBS benar-benar bersih.
pub(super) fn akhiri_aktif(k: &Konfig, log: &Logger) -> Result<(), String> {
    if let Some(state) = baca_state() {
        if let Err(code) = akhiri(k, &state.live_id, log) {
            log(&format!("Pembersihan OBS tertunda: {code}. Ingress server tetap harus dinonaktifkan."));
            return Err(code);
        }
    }
    Ok(())
}

/// Audit tiap heartbeat. Perubahan scene/source berbahaya memicu fail-closed.
pub(super) fn pantau(k: &Konfig, log: &Logger) -> Option<Value> {
    let state = baca_state()?;
    if !obs_running() {
        // Pertahankan state: command akhir/start berikutnya harus meluncurkan
        // OBS tanpa autostart dan memverifikasi key profile sudah kosong.
        return Some(json!({
            "live_id": state.live_id, "active": false, "safe": false,
            "cleanup_pending": true, "code": "OBS_PROCESS_EXITED"
        }));
    }
    let password = password_obs(k);
    let mut obs = match ObsClient::connect(&password) {
        Ok(v) => v,
        Err(_) => {
            return Some(json!({
                "live_id": state.live_id, "active": null, "safe": null, "code": "OBS_MONITOR_UNAVAILABLE"
            }))
        }
    };
    let status = match stream_status(&mut obs) {
        Ok(v) => v,
        Err(_) => {
            return Some(json!({
                "live_id": state.live_id, "active": null, "safe": null, "code": "OBS_STATUS_UNAVAILABLE"
            }))
        }
    };
    if state.cleanup_pending {
        return Some(match stop_output(&mut obs) {
            Ok(()) => {
                // Pertahankan state sampai command akhiri_siaran memberi ACK.
                // Jika state dihapus di heartbeat, OBS milik operator yang tetap
                // berjalan akan membuat ACK berikutnya gagal dengan STATE_MISSING.
                json!({
                    "live_id": state.live_id, "active": false, "safe": false,
                    "cleanup_pending": false, "code": "OBS_CLEANUP_COMPLETED"
                })
            }
            Err(cleanup) => {
                log(&format!("Retry cleanup credential OBS tertahan: {cleanup}."));
                json!({
                    "live_id": state.live_id, "active": null, "safe": false,
                    "cleanup_pending": true, "code": "OBS_CREDENTIAL_CLEANUP_PENDING"
                })
            }
        });
    }
    let active = output_active(&status);
    if !active {
        return Some(match clear_service(&mut obs) {
            Ok(()) => {
                // Credential sudah kosong, tetapi tombstone live tetap ada
                // sampai command akhir mengonfirmasi lifecycle ke server.
                json!({
                    "live_id": state.live_id, "active": false, "safe": true,
                    "cleanup_pending": false, "code": "OBS_OUTPUT_STOPPED"
                })
            }
            Err(cleanup) => {
                let _ = simpan_state(&state.live_id, state.managed, state.mic, true);
                log(&format!("OBS output berhenti tetapi cleanup credential tertahan: {cleanup}."));
                json!({
                    "live_id": state.live_id, "active": false, "safe": false,
                    "cleanup_pending": true, "code": "OBS_CREDENTIAL_CLEANUP_PENDING"
                })
            }
        });
    }
    if let Err(code) = audit_runtime(&mut obs, state.mic) {
        return Some(match stop_output(&mut obs) {
            Ok(()) => {
                // Jangan hapus state/OBS sebelum command akhir diterima. Server
                // akan memblokir ingress lalu mengirim akhiri_siaran idempotent.
                log(&format!("FAIL-CLOSED livestream: {code}. Output dihentikan karena scene berubah."));
                json!({
                    "live_id": state.live_id, "active": false, "safe": false,
                    "cleanup_pending": false, "code": code
                })
            }
            Err(cleanup) => {
                let _ = simpan_state(&state.live_id, state.managed, state.mic, true);
                log(&format!("FAIL-CLOSED livestream menunggu cleanup credential: {cleanup}."));
                json!({
                    "live_id": state.live_id, "active": null, "safe": false,
                    "cleanup_pending": true, "cause": code,
                    "code": "OBS_FAIL_CLOSED_CLEANUP_PENDING"
                })
            }
        });
    }
    Some(json!({
        "live_id": state.live_id,
        "active": true,
        "safe": true,
        "cleanup_pending": false,
        "reconnecting": status.get("outputReconnecting").and_then(Value::as_bool).unwrap_or(false),
        "congestion": status.get("outputCongestion").and_then(Value::as_f64),
        "bytes": status.get("outputBytes").and_then(Value::as_u64),
        "duration_ms": status.get("outputDuration").and_then(Value::as_u64),
        "skipped_frames": status.get("outputSkippedFrames").and_then(Value::as_u64),
        "total_frames": status.get("outputTotalFrames").and_then(Value::as_u64),
        "code": "OK"
    }))
}
