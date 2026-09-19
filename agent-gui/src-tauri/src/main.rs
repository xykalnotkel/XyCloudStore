// ============================================================
//  XyCloudStore — Agen PC Host (Tauri v2 / Rust, tanpa Python)
// ============================================================
// `#[path]` eksplisit ini wajib, bukan hiasan. Tanpa atribut path, modul
// non-inline `agent` (berkas src/agent.rs) membuat direktori anaknya menjadi
// `src/agent/`, sehingga `mod obs_live;` di dalam agent.rs dicari di
// src/agent/obs_live.rs dan gagal dengan E0583 "file not found for module
// `obs_live`". Dengan #[path], direktori modul tetap `src/` sehingga
// src/obs_live.rs ditemukan — sama seperti crate native
// (agent-gui/src-native) yang menyertakan agent.rs lewat
// `#[path = "../../src-tauri/src/agent.rs"]`. Jadi kedua crate memakai berkas
// agent.rs + obs_live.rs yang identik tanpa perlu memindahkan apa pun.
#[path = "agent.rs"]
mod agent;

use agent::{Konfig, Logger};
use serde_json::json;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};
use tauri::{Emitter, State};

struct St {
    cfg: Arc<Mutex<Konfig>>,
    stop: Arc<AtomicBool>,
    berjalan: Arc<Mutex<bool>>,
}

fn buat_log(app: tauri::AppHandle) -> Logger {
    Arc::new(move |teks: &str| {
        let _ = app.emit("log", teks.to_string());
    })
}

#[tauri::command]
fn simpan(
    kode: String,
    user: String,
    sandi: String,
    server: String,
    st: State<St>,
) -> Result<String, String> {
    let (sandi_lama, user_lama, stream_host_lama) = {
        let cfg = st.cfg.lock().unwrap();
        (cfg.sandi.clone(), cfg.user.clone(), cfg.stream_host.clone())
    };

    let mut k = Konfig {
        kode: kode.trim().into(),
        // kosong = biarkan auto-setup yang mengisi (jangan paksa "admin")
        user: user.trim().into(),
        sandi: sandi.trim().into(),
        server: if server.trim().is_empty() {
            "https://api.xycloud.my.id".into()
        } else {
            server.trim().into()
        },
        stream_host: stream_host_lama,
    };
    if k.kode.is_empty() {
        return Err("Kode unit wajib diisi.".into());
    }
    if k.sandi.is_empty() {
        k.sandi = sandi_lama;
    }
    if k.user.is_empty() {
        k.user = user_lama;
    }
    agent::simpan_konfig(&k).map_err(|e| e.to_string())?;
    *st.cfg.lock().unwrap() = k.clone();
    Ok(format!("Pengaturan tersimpan untuk unit {}", k.kode))
}

#[tauri::command]
fn status(st: State<St>) -> serde_json::Value {
    let cfg = st.cfg.lock().unwrap().clone();
    let jalan = *st.berjalan.lock().unwrap();
    // Jangan panggil HTTP Sunshine di sini (blocking) — UI pakai uji_cek / setup-selesai.
    let sunshine = if cfg.user.is_empty() || cfg.sandi.is_empty() {
        json!({
            "siap": false,
            "status": "KREDENSIAL_KOSONG",
            "pesan": "Belum di-setup",
            "service": "-"
        })
    } else {
        json!({
            "siap": serde_json::Value::Null,
            "status": "TERSIMPAN",
            "pesan": "Kredensial ada — klik Uji koneksi untuk cek live",
            "service": "-"
        })
    };
    json!({
        "kode": cfg.kode,
        "server": cfg.server,
        "user": cfg.user,
        "autostart": agent::autostart_aktif(),
        "berjalan": jalan,
        "versi": agent::VERSI,
        "sunshine": sunshine,
    })
}

#[tauri::command]
fn uji_cek(app: tauri::AppHandle, st: State<St>) -> Result<(), String> {
    let cfg = st.cfg.lock().unwrap().clone();
    if cfg.kode.is_empty() {
        return Err("Simpan pengaturan (kode unit) dulu.".into());
    }
    let log = buat_log(app.clone());
    let cfg2 = cfg.clone();
    std::thread::spawn(move || {
        log("Menjalankan uji koneksi lokal (Sunshine API)…");
        let hasil = agent::periksa_sunshine(&cfg2);
        log(&format!(
            "Hasil: {} — {}",
            hasil.get("status").and_then(|x| x.as_str()).unwrap_or("-"),
            hasil.get("pesan").and_then(|x| x.as_str()).unwrap_or("")
        ));
        let _ = app.emit("uji-selesai", hasil);
    });
    Ok(())
}

#[tauri::command]
fn setup_otomatis(app: tauri::AppHandle, st: State<St>) -> Result<(), String> {
    let cfg = st.cfg.lock().unwrap().clone();
    if cfg.kode.is_empty() {
        return Err("Simpan pengaturan (kode unit) dulu.".into());
    }
    let log = buat_log(app.clone());
    let cfg_arc = st.cfg.clone();
    std::thread::spawn(move || {
        let (k_baru, hasil) = agent::setup_otomatis(&cfg, log);
        if let Ok(mut g) = cfg_arc.lock() {
            *g = k_baru.clone();
        }
        let _ = app.emit("setup-selesai", hasil.clone());
        let _ = app.emit(
            "log",
            format!(
                "Setup selesai · unit={} · sunshine_user={} · siap={}",
                k_baru.kode,
                k_baru.user,
                hasil
                    .get("siap")
                    .and_then(|x| x.as_bool())
                    .unwrap_or(false)
            ),
        );
    });
    Ok(())
}

#[tauri::command]
fn mulai(app: tauri::AppHandle, st: State<St>) -> Result<(), String> {
    // Ambil konfig terbaru (setelah auto-creds) — prefer memori, fallback disk.
    let cfg = {
        let mem = st.cfg.lock().unwrap().clone();
        if !mem.kode.is_empty() {
            mem
        } else {
            agent::muat_konfig()
        }
    };
    // Reload disk juga jika sandi baru saja di-auto-generate di thread lain.
    let cfg = {
        let disk = agent::muat_konfig();
        if !disk.sandi.is_empty() && disk.kode == cfg.kode {
            *st.cfg.lock().unwrap() = disk.clone();
            disk
        } else {
            cfg
        }
    };
    if cfg.kode.is_empty() {
        return Err("Simpan pengaturan (kode unit) dulu.".into());
    }
    if cfg.user.is_empty() || cfg.sandi.is_empty() {
        return Err("Sunshine belum di-setup. Jalankan langkah Engine dulu.".into());
    }
    {
        let mut b = st.berjalan.lock().unwrap();
        if *b {
            return Ok(());
        }
        *b = true;
    }
    st.stop.store(false, Ordering::Relaxed);
    let log = buat_log(app.clone());
    let stop = st.stop.clone();
    let berjalan = st.berjalan.clone();
    let cfg2 = cfg.clone();
    std::thread::spawn(move || {
        agent::jalankan_loop(cfg2, log, stop);
        *berjalan.lock().unwrap() = false;
    });
    Ok(())
}

#[tauri::command]
fn henti(st: State<St>) -> Result<(), String> {
    st.stop.store(true, Ordering::Relaxed);
    Ok(())
}

#[tauri::command]
fn autostart(aktif: bool, app: tauri::AppHandle) -> Result<(), String> {
    let log = buat_log(app);
    agent::atur_autostart(aktif, &log);
    Ok(())
}

fn main() {
    // verifikasi versi (smoke-test CI & pengguna)
    if std::env::args().any(|a| a == "--veri" || a == "-V") {
        println!("XyCloudStore-Agent {}", agent::VERSI);
        println!("runtime: Rust/Tauri (tanpa Python)");
        std::process::exit(0);
    }
    // mode headless: -Jalankan (dipakai autostart/penjadwal)
    let arg_jalankan = std::env::args().any(|a| a == "-Jalankan" || a == "--jalankan");
    if arg_jalankan {
        let cfg = agent::muat_konfig();
        if cfg.kode.is_empty() {
            eprintln!("Kode unit belum diisi. Jalankan aplikasi UI dulu untuk konfigurasi.");
            std::process::exit(2);
        }
        let stop = Arc::new(AtomicBool::new(false));
        let log: Logger = Arc::new(|t| println!("[XYAGENT] {t}"));
        agent::jalankan_loop(cfg, log, stop);
        return;
    }

    let cfg = agent::muat_konfig();
    tauri::Builder::default()
        .manage(St {
            cfg: Arc::new(Mutex::new(cfg)),
            stop: Arc::new(AtomicBool::new(false)),
            berjalan: Arc::new(Mutex::new(false)),
        })
        .invoke_handler(tauri::generate_handler![
            simpan, status, uji_cek, setup_otomatis, mulai, henti, autostart
        ])
        .setup(|_app| Ok(()))
        .run(tauri::generate_context!())
        .expect("gagal menjalankan aplikasi XyCloudStore Agent");
}
