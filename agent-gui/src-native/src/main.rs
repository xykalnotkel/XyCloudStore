// ============================================================
//  XyCloudStore — Agen PC Host (Rust + egui/eframe NATIVE)
// ============================================================
//  Pengganti build Tauri: tanpa WebView2, tanpa terminal, satu
//  exe mandiri. Logika inti (agent.rs) dipakai ulang apa adanya
//  lewat #[path] supaya kedua build tidak pernah berbeda perilaku.
//
//  Mode:
//   --veri / -V      → cetak versi lalu keluar 0 (smoke-test CI)
//   -Jalankan        → headless loop (dipakai autostart registry)
//   (tanpa argumen)  → buka jendela GUI
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

#[path = "../../src-tauri/src/agent.rs"]
mod agent;

use agent::{Konfig, Logger, VERSI};
use eframe::egui;
use serde_json::Value;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};

const UNGU: egui::Color32 = egui::Color32::from_rgb(0x7C, 0x3A, 0xED);
const UNGU_LEMBUT: egui::Color32 = egui::Color32::from_rgb(0xA7, 0x8B, 0xFA);

/// Status operasi berat yang sedang berjalan (uji/setup/loop agen).
#[derive(Clone, Copy, PartialEq, Eq)]
enum Sibuk {
    Tidak,
    Uji,
    Setup,
    CekPort,
    Upnp,
    Loop,
}

struct Keadaan {
    cfg: Arc<Mutex<Konfig>>,
    stop: Arc<AtomicBool>,
    berjalan: Arc<AtomicBool>,
    sibuk: Arc<Mutex<Sibuk>>,
    log: Arc<Mutex<Vec<String>>>,
    hasil_uji: Arc<Mutex<Option<Value>>>,
    hasil_setup: Arc<Mutex<Option<Value>>>,
    sinkron_draft: Arc<AtomicBool>,
}

impl Keadaan {
    fn baru(cfg: Konfig) -> Arc<Self> {
        Arc::new(Self {
            cfg: Arc::new(Mutex::new(cfg)),
            stop: Arc::new(AtomicBool::new(false)),
            berjalan: Arc::new(AtomicBool::new(false)),
            sibuk: Arc::new(Mutex::new(Sibuk::Tidak)),
            log: Arc::new(Mutex::new(Vec::new())),
            hasil_uji: Arc::new(Mutex::new(None)),
            hasil_setup: Arc::new(Mutex::new(None)),
            sinkron_draft: Arc::new(AtomicBool::new(false)),
        })
    }

    fn cfg(&self) -> Konfig {
        self.cfg.lock().unwrap().clone()
    }

    fn set_sibuk(&self, s: Sibuk) {
        *self.sibuk.lock().unwrap() = s;
    }

    fn log_push(&self, teks: &str, ctx: &egui::Context) {
        let jam = jam_wib();
        let mut l = self.log.lock().unwrap();
        l.push(format!("[{jam}] {teks}"));
        if l.len() > 600 {
            let buang = l.len() - 600;
            l.drain(0..buang);
        }
        drop(l);
        ctx.request_repaint();
    }
}

/// Logger yang menulis ke panel log + minta repaint.
fn logger_gui(st: Arc<Keadaan>, ctx: egui::Context) -> Logger {
    Arc::new(move |teks: &str| st.log_push(teks, &ctx))
}

struct Aplikasi {
    ctx: egui::Context,
    st: Arc<Keadaan>,
    // Draft isian pengaturan (disinkron dari cfg saat perlu).
    d_kode: String,
    d_server: String,
    d_user: String,
    d_sandi: String,
    d_stream_host: String,
    tampil_sandi: bool,
    autostart: bool,
    // Batch L: mode relay Tailscale (host tanpa IP publik — untuk testing).
    mode_relay: bool,
    status_simpan: Option<(bool, String)>,
    // Mode --gui-tes: tutup otomatis setelah beberapa frame (smoke-test CI).
    tes_gui: bool,
    keluar_total: bool,
    frame: u32,
    logo_tex: Option<egui::TextureHandle>,
}

impl Aplikasi {
    fn baru(cc: &eframe::CreationContext<'_>, st: Arc<Keadaan>, tes_gui: bool) -> Self {
        terapkan_tema(&cc.egui_ctx);
        let cfg = st.cfg();
        let autostart = agent::autostart_aktif();
        let mode_relay = agent::mode_relay_aktif();
        let logo_tex = image::load_from_memory(include_bytes!("../../src-tauri/icons/icon.png"))
            .ok()
            .map(|img| {
                let img = img.to_rgba8();
                let size = [img.width() as usize, img.height() as usize];
                let pixels = img.into_raw();
                let color_image = egui::ColorImage::from_rgba_unmultiplied(size, &pixels);
                cc.egui_ctx
                    .load_texture("logo_xycloud", color_image, egui::TextureOptions::LINEAR)
            });
        Self {
            ctx: cc.egui_ctx.clone(),
            st,
            d_kode: cfg.kode,
            d_server: cfg.server,
            d_user: cfg.user,
            d_sandi: cfg.sandi,
            d_stream_host: cfg.stream_host.unwrap_or_default(),
            tampil_sandi: false,
            autostart,
            mode_relay,
            status_simpan: None,
            tes_gui,
            keluar_total: false,
            frame: 0,
            logo_tex,
        }
    }

    fn sinkron_draft(&mut self) {
        let cfg = self.st.cfg();
        self.d_kode = cfg.kode;
        self.d_server = cfg.server;
        self.d_user = cfg.user;
        self.d_sandi = cfg.sandi;
        self.d_stream_host = cfg.stream_host.unwrap_or_default();
    }

    fn simpan(&mut self) {
        let lama = self.st.cfg();
        let mut k = Konfig {
            kode: self.d_kode.trim().into(),
            user: self.d_user.trim().into(),
            sandi: self.d_sandi.trim().into(),
            server: if self.d_server.trim().is_empty() {
                "https://api.xycloud.my.id".into()
            } else {
                self.d_server.trim().into()
            },
            stream_host: if self.d_stream_host.trim().is_empty() {
                None
            } else {
                Some(self.d_stream_host.trim().into())
            },
        };
        if k.kode.is_empty() {
            self.status_simpan = Some((false, "Kode unit wajib diisi.".into()));
            return;
        }
        // Kosong = pertahankan kredensial lama (sama seperti build Tauri).
        if k.sandi.is_empty() {
            k.sandi = lama.sandi;
        }
        if k.user.is_empty() {
            k.user = lama.user;
        }
        match agent::simpan_konfig(&k) {
            Ok(_) => {
                *self.st.cfg.lock().unwrap() = k.clone();
                self.d_sandi = k.sandi;
                self.d_user = k.user;
                self.d_server = k.server;
                self.status_simpan =
                    Some((true, format!("Pengaturan tersimpan untuk unit {}", k.kode)));
            }
            Err(e) => self.status_simpan = Some((false, format!("Gagal menyimpan: {e}"))),
        }
    }

    fn uji_koneksi(&self) {
        {
            let mut s = self.st.sibuk.lock().unwrap();
            if *s != Sibuk::Tidak {
                return;
            }
            *s = Sibuk::Uji;
        }
        *self.st.hasil_uji.lock().unwrap() = None;
        let cfg = self.st.cfg();
        let st = self.st.clone();
        let ctx = self.ctx.clone();
        std::thread::spawn(move || {
            st.log_push("Menjalankan uji koneksi lokal (Sunshine API)…", &ctx);
            let hasil = agent::periksa_sunshine(&cfg);
            {
                *st.hasil_uji.lock().unwrap() = Some(hasil.clone());
                st.set_sibuk(Sibuk::Tidak);
            }
            st.log_push(
                &format!(
                    "Hasil uji: {} — {}",
                    hasil.get("status").and_then(|x| x.as_str()).unwrap_or("-"),
                    hasil.get("pesan").and_then(|x| x.as_str()).unwrap_or("")
                ),
                &ctx,
            );
        });
        self.ctx.request_repaint();
    }

    fn setup_engine(&self) {
        {
            let mut s = self.st.sibuk.lock().unwrap();
            if *s != Sibuk::Tidak {
                return;
            }
            *s = Sibuk::Setup;
        }
        *self.st.hasil_setup.lock().unwrap() = None;
        let cfg = self.st.cfg();
        let st = self.st.clone();
        let ctx = self.ctx.clone();
        std::thread::spawn(move || {
            let log = logger_gui(st.clone(), ctx.clone());
            let (k_baru, hasil) = agent::setup_otomatis(&cfg, log);
            {
                *st.cfg.lock().unwrap() = k_baru.clone();
                *st.hasil_setup.lock().unwrap() = Some(hasil.clone());
                st.set_sibuk(Sibuk::Tidak);
                st.sinkron_draft.store(true, Ordering::Relaxed);
            }
            st.log_push(
                &format!(
                    "Setup selesai · unit={} · sunshine_user={} · siap={}",
                    k_baru.kode,
                    k_baru.user,
                    hasil.get("siap").and_then(|x| x.as_bool()).unwrap_or(false)
                ),
                &ctx,
            );
        });
        self.ctx.request_repaint();
    }

    /// Port streaming dicek DARI SERVER (bukan dari PC ini) — meniru tombol
    /// "Cek port dari internet" di UI Tauri lama (POST /api/agen/cek-port).
    fn cek_port(&self) {
        let cfg = self.st.cfg();
        if cfg.kode.is_empty() {
            self.st
                .log_push("Isi & simpan kode unit dulu sebelum cek port.", &self.ctx);
            return;
        }
        {
            let mut s = self.st.sibuk.lock().unwrap();
            if *s != Sibuk::Tidak {
                return;
            }
            *s = Sibuk::CekPort;
        }
        let st = self.st.clone();
        let ctx = self.ctx.clone();
        std::thread::spawn(move || {
            // Batch L: cek port menguji jangkauan dari INTERNET publik —
            // pada mode relay hasilnya pasti TERTUTUP (itu normal).
            if agent::mode_relay_aktif() {
                st.log_push(
                    "Catatan: Mode Relay aktif — cek port dari internet biasanya                      TERTUTUP dan itu normal. Streaming berjalan lewat tailnet.",
                    &ctx,
                );
            }
            st.log_push("Meminta server memeriksa port streaming dari internet…", &ctx);
            let server = cfg.server.trim_end_matches('/');
            let url = format!("{server}/api/agen/cek-port");
            let klien = reqwest::blocking::Client::builder()
                .timeout(std::time::Duration::from_secs(90))
                .build();
            let hasil = klien
                .and_then(|k| k.post(&url).header("x-agen-kode", &cfg.kode).send());
            match hasil {
                Ok(r) if r.status().is_success() => match r.json::<serde_json::Value>() {
                    Ok(j) => {
                        let host = j.get("host").and_then(|x| x.as_str()).unwrap_or("?");
                        let mut tutup = 0u32;
                        let mut total = 0u32;
                        if let Some(arr) = j.get("hasil").and_then(|x| x.as_array()) {
                            for h in arr {
                                total += 1;
                                let port = h.get("port").and_then(|x| x.as_i64()).unwrap_or(0);
                                let terbuka =
                                    h.get("terbuka").and_then(|x| x.as_bool()).unwrap_or(false);
                                if !terbuka {
                                    tutup += 1;
                                }
                                st.log_push(
                                    &format!(
                                        "Port {port}/TCP → {host}: {}",
                                        if terbuka { "TERBUKA" } else { "TERTUTUP" }
                                    ),
                                    &ctx,
                                );
                            }
                        }
                        if tutup > 0 {
                            st.log_push(
                                "Ada port tertutup → HP penyewa tidak bisa menyambung dari internet. Buka/forward port 47984–47990 TCP+UDP & 48010 (router: UPnP/port-forward; VM cloud: inbound rule NSG/Security Group; Windows Firewall: izinkan Sunshine).",
                                &ctx,
                            );
                        } else if total > 0 {
                            st.log_push(
                                "Semua port penting terbuka — streaming dari HP bisa menyambung dari mana pun.",
                                &ctx,
                            );
                        }
                    }
                    Err(e) => st.log_push(&format!("Gagal baca hasil cek port: {e}"), &ctx),
                },
                Ok(r) => {
                    // Tampilkan pesan server (mis. "Unit belum punya host…"),
                    // bukan cuma status HTTP polos.
                    let status = r.status();
                    let pesan = r
                        .text()
                        .ok()
                        .and_then(|t| serde_json::from_str::<serde_json::Value>(&t).ok())
                        .and_then(|j| {
                            j.get("error")
                                .and_then(|x| x.as_str())
                                .map(|x| x.to_string())
                        })
                        .unwrap_or_default();
                    st.log_push(
                        &if pesan.is_empty() {
                            format!("Gagal cek port: HTTP {status}")
                        } else {
                            format!("Gagal cek port: HTTP {status} — {pesan}")
                        },
                        &ctx,
                    );
                }
                Err(e) => st.log_push(&format!("Gagal cek port: {e}"), &ctx),
            }
            st.set_sibuk(Sibuk::Tidak);
            ctx.request_repaint();
        });
        self.ctx.request_repaint();
    }

    fn jalankan_upnp(&self) {
        {
            let mut s = self.st.sibuk.lock().unwrap();
            if *s != Sibuk::Tidak {
                return;
            }
            *s = Sibuk::Upnp;
        }
        let cfg = self.st.cfg();
        let st = self.st.clone();
        let ctx = self.ctx.clone();
        std::thread::spawn(move || {
            let log = logger_gui(st.clone(), ctx.clone());
            st.log_push("=== Menjalankan Auto-UPnP Router & Windows Firewall ===", &ctx);
            let hasil = agent::buka_upnp_firewall(&cfg, &log);
            st.set_sibuk(Sibuk::Tidak);
            let ok = hasil.get("ok").and_then(|x| x.as_bool()).unwrap_or(false);
            let pesan = hasil.get("pesan").and_then(|x| x.as_str()).unwrap_or("");
            st.log_push(
                &format!("Hasil Auto-UPnP: {}", if ok { "BERHASIL" } else { "INFORMASI" }),
                &ctx,
            );
            if !pesan.is_empty() {
                st.log_push(pesan, &ctx);
            }
            ctx.request_repaint();
        });
        self.ctx.request_repaint();
    }

    fn buka_web_sunshine(&self) {
        #[cfg(windows)]
        {
            let _ = std::process::Command::new("cmd")
                .args(["/C", "start", "https://localhost:47990"])
                .spawn();
        }
        #[cfg(not(windows))]
        {
            let _ = std::process::Command::new("xdg-open")
                .arg("https://localhost:47990")
                .spawn();
        }
    }

    fn mulai_loop(&self) {
        // Ambil konfig terbaru (memori → disk), sama seperti build Tauri.
        let cfg = {
            let mem = self.st.cfg();
            if !mem.kode.is_empty() {
                mem
            } else {
                agent::muat_konfig()
            }
        };
        if cfg.kode.is_empty() {
            self.st
                .log_push("Simpan pengaturan (kode unit) dulu.", &self.ctx);
            return;
        }
        if cfg.user.is_empty() || cfg.sandi.is_empty() {
            self.st.log_push(
                "Sunshine belum di-setup. Jalankan Setup Engine dulu.",
                &self.ctx,
            );
            return;
        }
        {
            let mut s = self.st.sibuk.lock().unwrap();
            if *s != Sibuk::Tidak {
                return;
            }
            *s = Sibuk::Loop;
        }
        self.st.stop.store(false, Ordering::Relaxed);
        self.st.berjalan.store(true, Ordering::Relaxed);
        let st = self.st.clone();
        let ctx = self.ctx.clone();
        std::thread::spawn(move || {
            let log = logger_gui(st.clone(), ctx.clone());
            agent::jalankan_loop(cfg, log, st.stop.clone());
            st.berjalan.store(false, Ordering::Relaxed);
            st.set_sibuk(Sibuk::Tidak);
            ctx.request_repaint();
        });
        self.ctx.request_repaint();
    }

    fn hentikan(&self) {
        self.st.stop.store(true, Ordering::Relaxed);
        self.st.log_push("Menghentikan agen…", &self.ctx);
    }

    fn toggle_autostart(&mut self, aktif: bool) {
        self.autostart = aktif;
        let st = self.st.clone();
        let ctx = self.ctx.clone();
        std::thread::spawn(move || {
            let log = logger_gui(st.clone(), ctx.clone());
            agent::atur_autostart(aktif, &log);
        });
    }
}

impl eframe::App for Aplikasi {
    fn update(&mut self, ctx: &egui::Context, _frame: &mut eframe::Frame) {
        // Smoke-test CI: jendela terbukti hidup beberapa frame → tutup sendiri.
        if self.tes_gui {
            self.frame += 1;
            log_gui(&format!("gui-tes frame {}", self.frame));
            if self.frame >= 5 {
                log_gui("gui-tes OK — jendela dibuat & dirender, menutup");
                ctx.send_viewport_cmd(egui::ViewportCommand::Close);
                return;
            }
        }

        // Cegah agen terhenti jika jendela ditutup (tombol 'X') — minimalkan ke latar belakang
        if !self.tes_gui && ctx.input(|i| i.viewport().close_requested()) {
            if !self.keluar_total {
                ctx.send_viewport_cmd(egui::ViewportCommand::CancelClose);
                ctx.send_viewport_cmd(egui::ViewportCommand::Minimized(true));
                log_gui("Jendela diminimalkan ke latar belakang. Agen tetap aktif melayani streaming.");
                log_gui("Gunakan tombol 'Tutup Total' di antarmuka bila ingin menghentikan agen sepenuhnya.");
            }
        }

        if self
            .st
            .sinkron_draft
            .swap(false, Ordering::Relaxed)
        {
            self.sinkron_draft();
        }
        let sibuk = *self.st.sibuk.lock().unwrap();
        let berjalan = self.st.berjalan.load(Ordering::Relaxed);
        // Repaint berkala agar indikator & log tetap hidup.
        ctx.request_repaint_after(std::time::Duration::from_millis(500));

        egui::CentralPanel::default().show(ctx, |ui| {
            ui.add_space(8.0);

            // ==================== HEADER ====================
            ui.horizontal(|ui| {
                let (kotak, _) = ui.allocate_exact_size(
                    egui::vec2(38.0, 38.0),
                    egui::Sense::hover(),
                );
                if let Some(tex) = &self.logo_tex {
                    ui.painter().image(
                        tex.id(),
                        kotak,
                        egui::Rect::from_min_max(egui::pos2(0.0, 0.0), egui::pos2(1.0, 1.0)),
                        egui::Color32::WHITE,
                    );
                } else {
                    ui.painter().rect(
                        kotak,
                        10.0,
                        UNGU,
                        egui::Stroke::new(1.4_f32, UNGU_LEMBUT),
                    );
                    ui.painter().text(
                        kotak.center(),
                        egui::Align2::CENTER_CENTER,
                        "XY",
                        egui::FontId::proportional(16.0),
                        egui::Color32::WHITE,
                    );
                }
                ui.add_space(8.0);
                ui.vertical(|ui| {
                    ui.label(
                        egui::RichText::new("XyCloudStore Host Agent")
                            .strong()
                            .size(17.0)
                            .color(egui::Color32::WHITE),
                    );
                    ui.label(
                        egui::RichText::new(format!(
                            "v{VERSI} · Native Host Controller"
                        ))
                        .size(11.0)
                        .color(egui::Color32::from_rgb(0x8B, 0x94, 0x9E)),
                    );
                });
                ui.with_layout(egui::Layout::right_to_left(egui::Align::Center), |ui| {
                    let (bg, warna, teks) = if berjalan {
                        (egui::Color32::from_rgb(0x06, 0x4E, 0x3B), egui::Color32::from_rgb(0x34, 0xD3, 0x99), "●  ONLINE / AKTIF")
                    } else if sibuk != Sibuk::Tidak {
                        (egui::Color32::from_rgb(0x37, 0x24, 0x61), UNGU_LEMBUT, "⟳  MEMPROSES…")
                    } else {
                        (egui::Color32::from_rgb(0x21, 0x26, 0x2D), egui::Color32::from_rgb(0x8B, 0x94, 0x9E), "○  STANDBY")
                    };
                    egui::Frame::none()
                        .fill(bg)
                        .rounding(egui::Rounding::same(6.0))
                        .inner_margin(egui::Margin::symmetric(9.0, 4.0))
                        .show(ui, |ui| {
                            ui.label(egui::RichText::new(teks).color(warna).strong().size(11.0));
                        });
                });
            });

            ui.add_space(10.0);

            // ==================== 1. KENDALI UTAMA ====================
            kartu(ui, |ui| {
                ui.vertical(|ui| {
                    let mati = sibuk != Sibuk::Tidak;
                    if berjalan {
                        let btn = ui.add(
                            egui::Button::new(
                                egui::RichText::new("⏹  HENTIKAN LAYANAN AGEN HOST")
                                    .size(13.0)
                                    .strong()
                                    .color(egui::Color32::WHITE),
                            )
                            .fill(egui::Color32::from_rgb(0xDC, 0x26, 0x26))
                            .min_size(egui::vec2(ui.available_width(), 38.0)),
                        );
                        if btn.clicked() {
                            self.hentikan();
                        }
                        ui.add_space(4.0);
                        ui.label(
                            egui::RichText::new("● Layanan aktif: PC siap menerima streaming dari aplikasi HP penyewa.")
                                .size(11.0)
                                .color(egui::Color32::from_rgb(0x34, 0xD3, 0x99)),
                        );
                    } else {
                        ui.add_enabled_ui(!mati, |ui| {
                            let btn = ui.add(
                                egui::Button::new(
                                    egui::RichText::new("▶  MULAI LAYANAN AGEN HOST")
                                        .size(13.0)
                                        .strong()
                                        .color(egui::Color32::WHITE),
                                )
                                .fill(UNGU)
                                .min_size(egui::vec2(ui.available_width(), 38.0)),
                            );
                            if btn.clicked() {
                                self.mulai_loop();
                            }
                        });
                        ui.add_space(4.0);
                        ui.label(
                            egui::RichText::new("○ Layanan standby: klik tombol di atas untuk mulai menerima koneksi sewa.")
                                .size(11.0)
                                .color(egui::Color32::from_rgb(0x8B, 0x94, 0x9E)),
                        );
                    }
                });
            });

            ui.add_space(10.0);

            // ==================== 2. ALAT & DIAGNOSTIK ====================
            ui.label(
                egui::RichText::new("ALAT & DIAGNOSTIK ENGINE")
                    .size(11.0)
                    .color(egui::Color32::from_rgb(0x8B, 0x94, 0x9E))
                    .strong(),
            );
            ui.add_space(4.0);
            kartu(ui, |ui| {
                let mati = sibuk != Sibuk::Tidak;
                ui.add_enabled_ui(!mati, |ui| {
                    let lebar_setengah = (ui.available_width() - 8.0) * 0.5;
                    ui.horizontal(|ui| {
                        if ui
                            .add(
                                egui::Button::new("🔌  Uji Sunshine")
                                    .min_size(egui::vec2(lebar_setengah, 32.0)),
                            )
                            .on_hover_text("Periksa API lokal Sunshine dan verifikasi kredensial")
                            .clicked()
                        {
                            self.uji_koneksi();
                        }
                        if ui
                            .add(
                                egui::Button::new("⚙  Setup Engine")
                                    .min_size(egui::vec2(lebar_setengah, 32.0)),
                            )
                            .on_hover_text("Unduh dan pasang Sunshine engine secara otomatis jika belum ada")
                            .clicked()
                        {
                            self.setup_engine();
                        }
                    });
                    ui.add_space(6.0);
                    ui.horizontal(|ui| {
                        if ui
                            .add(
                                egui::Button::new("🌐  Cek Port Publik")
                                    .min_size(egui::vec2(lebar_setengah, 32.0)),
                            )
                            .on_hover_text("Minta server menguji keterjangkauan port streaming dari internet")
                            .clicked()
                        {
                            self.cek_port();
                        }
                        if ui
                            .add(
                                egui::Button::new("🔓  Auto-UPnP")
                                    .min_size(egui::vec2(lebar_setengah, 32.0)),
                            )
                            .on_hover_text("Buka port otomatis di router via UPnP & Windows Firewall")
                            .clicked()
                        {
                            self.jalankan_upnp();
                        }
                    });
                });

                // Badge hasil uji / setup.
                badge_hasil(ui, "Uji koneksi", &self.st.hasil_uji.lock().unwrap());
                badge_hasil(ui, "Setup engine", &self.st.hasil_setup.lock().unwrap());

                if sibuk != Sibuk::Tidak {
                    ui.add_space(6.0);
                    ui.horizontal(|ui| {
                        ui.spinner();
                        ui.label(
                            egui::RichText::new(match sibuk {
                                Sibuk::Uji => "Menguji koneksi ke Sunshine…",
                                Sibuk::Setup => "Setup otomatis berjalan (unduh/pasang Sunshine bisa beberapa menit)…",
                                Sibuk::CekPort => "Server sedang memeriksa port streaming dari internet…",
                                Sibuk::Upnp => "Membuka port via UPnP router & Windows Firewall…",
                                Sibuk::Loop => "Agen berjalan…",
                                Sibuk::Tidak => "",
                            })
                            .size(11.5)
                            .color(UNGU_LEMBUT),
                        );
                    });
                }

                ui.add_space(8.0);
                ui.horizontal(|ui| {
                    if ui
                        .add(egui::Button::new("🌐  Buka Web Sunshine (localhost:47990)").small())
                        .on_hover_text("Buka panel Sunshine di browser default untuk pairing PIN & konfigurasi resolusi")
                        .clicked()
                    {
                        self.buka_web_sunshine();
                    }
                    ui.with_layout(egui::Layout::right_to_left(egui::Align::Center), |ui| {
                        if ui
                            .add(
                                egui::Button::new(
                                    egui::RichText::new("🚪  Tutup Total")
                                        .color(egui::Color32::from_rgb(0xF8, 0x71, 0x71)),
                                )
                                .small(),
                            )
                            .on_hover_text("Hentikan agen dan tutup seluruh proses background")
                            .clicked()
                        {
                            self.keluar_total = true;
                            self.hentikan();
                            ctx.send_viewport_cmd(egui::ViewportCommand::Close);
                        }
                    });
                });
            });

            ui.add_space(10.0);

            // ==================== 3. PENGATURAN UNIT ====================
            ui.label(
                egui::RichText::new("KONFIGURASI UNIT & KONEKSI")
                    .size(11.0)
                    .color(egui::Color32::from_rgb(0x8B, 0x94, 0x9E))
                    .strong(),
            );
            ui.add_space(4.0);
            kartu(ui, |ui| {
                egui::Grid::new("grid_cfg")
                    .num_columns(2)
                    .spacing([12.0, 8.0])
                    .show(ui, |ui| {
                        ui.label("Kode Unit:");
                        ui.add(
                            egui::TextEdit::singleline(&mut self.d_kode)
                                .desired_width(f32::INFINITY)
                                .hint_text("contoh: UNIT-01 / PC-RTX-01"),
                        );
                        ui.end_row();

                        ui.label("Server API:");
                        ui.add(
                            egui::TextEdit::singleline(&mut self.d_server)
                                .desired_width(f32::INFINITY)
                                .hint_text("https://api.xycloud.my.id"),
                        );
                        ui.end_row();

                        ui.label("User Sunshine:");
                        ui.add(
                            egui::TextEdit::singleline(&mut self.d_user)
                                .desired_width(f32::INFINITY)
                                .hint_text("kosongkan = auto-setup"),
                        );
                        ui.end_row();

                        ui.label("Sandi Sunshine:");
                        ui.horizontal(|ui| {
                            ui.add(
                                egui::TextEdit::singleline(&mut self.d_sandi)
                                    .password(!self.tampil_sandi)
                                    .desired_width(210.0)
                                    .hint_text("kosongkan = dipertahankan"),
                            );
                            if ui.small_button(if self.tampil_sandi { "🔒" } else { "👁" }).clicked() {
                                self.tampil_sandi = !self.tampil_sandi;
                            }
                        });
                        ui.end_row();

                        ui.label("Host / Relay:");
                        ui.add(
                            egui::TextEdit::singleline(&mut self.d_stream_host)
                                .desired_width(f32::INFINITY)
                                .hint_text("kosongkan = auto IP publik, atau domain playit"),
                        );
                        ui.end_row();
                    });

                ui.add_space(10.0);
                ui.horizontal(|ui| {
                    if ui
                        .add(egui::Button::new("💾  Simpan Konfigurasi").min_size(egui::vec2(140.0, 30.0)))
                        .clicked()
                    {
                        self.simpan();
                    }
                    if let Some((ok, pesan)) = &self.status_simpan {
                        ui.label(
                            egui::RichText::new(pesan)
                                .size(11.5)
                                .color(if *ok {
                                    egui::Color32::from_rgb(0x34, 0xD3, 0x99)
                                } else {
                                    egui::Color32::from_rgb(0xF8, 0x71, 0x71)
                                }),
                        );
                    }
                });

                ui.add_space(8.0);
                let cb = ui.checkbox(
                    &mut self.autostart,
                    "Jalankan otomatis saat login Windows",
                );
                if cb.changed() {
                    let a = self.autostart;
                    self.toggle_autostart(a);
                }

                let cb2 = ui.checkbox(
                    &mut self.mode_relay,
                    "Mode Relay (Tailscale) — host dilaporkan pakai IP tailnet 100.x",
                );
                if cb2.changed() {
                    let aktif = self.mode_relay;
                    match agent::set_mode_relay(aktif) {
                        Ok(_) => {
                            if aktif {
                                match agent::ip_tailscale() {
                                    Some(ip) => log_gui(&format!(
                                        "Mode relay AKTIF — IP Tailscale terdeteksi: {ip}. Penyewa harus tergabung di tailnet yang sama. Hanya untuk testing, bukan produksi."
                                    )),
                                    None => log_gui(
                                        "Mode relay AKTIF tapi IP Tailscale tidak ditemukan. Pastikan Tailscale terpasang & login, lalu coba lagi.",
                                    ),
                                }
                            } else {
                                log_gui("Mode relay dimatikan — kembali pakai IP publik.");
                            }
                        }
                        Err(e) => log_gui(&format!("Gagal simpan mode relay: {e}")),
                    }
                }
            });

            ui.add_space(10.0);

            // ==================== 4. LOG AKTIVITAS ====================
            let log_len = self.st.log.lock().unwrap().len();
            ui.horizontal(|ui| {
                ui.label(
                    egui::RichText::new(format!("LOG AKTIVITAS ({log_len})"))
                        .size(11.0)
                        .color(egui::Color32::from_rgb(0x8B, 0x94, 0x9E))
                        .strong(),
                );
                ui.with_layout(egui::Layout::right_to_left(egui::Align::Center), |ui| {
                    if ui.small_button("Bersihkan").clicked() {
                        self.st.log.lock().unwrap().clear();
                    }
                });
            });
            ui.add_space(4.0);

            kartu(ui, |ui| {
                let tinggi = ui.available_height() - 4.0;
                egui::ScrollArea::vertical()
                    .max_height(tinggi.max(90.0))
                    .stick_to_bottom(true)
                    .auto_shrink([false, false])
                    .show(ui, |ui| {
                        let log = self.st.log.lock().unwrap();
                        if log.is_empty() {
                            ui.label(
                                egui::RichText::new(
                                    "Belum ada aktivitas. Simpan kode unit → Setup Engine → Mulai Agen.",
                                )
                                .italics()
                                .color(egui::Color32::from_rgb(0x8B, 0x94, 0x9E)),
                            );
                        }
                        for baris in log.iter() {
                            ui.label(
                                egui::RichText::new(baris)
                                    .monospace()
                                    .size(11.0)
                                    .color(egui::Color32::from_rgb(0xC9, 0xD1, 0xD9)),
                            );
                        }
                    });
            });
        });
    }
}

fn badge_hasil(ui: &mut egui::Ui, judul: &str, hasil: &Option<Value>) {
    let Some(h) = hasil else { return };
    let siap = h.get("siap").and_then(|x| x.as_bool());
    let status = h
        .get("status")
        .and_then(|x| x.as_str())
        .unwrap_or("SELESAI");
    let pesan = h.get("pesan").and_then(|x| x.as_str()).unwrap_or("");
    let warna = match siap {
        Some(true) => egui::Color32::from_rgb(0x34, 0xD3, 0x99),
        Some(false) => egui::Color32::from_rgb(0xF8, 0x71, 0x71),
        None => UNGU_LEMBUT,
    };
    ui.add_space(6.0);
    ui.horizontal(|ui| {
        ui.label(egui::RichText::new(format!("{judul}: ")).size(11.5).strong());
        ui.label(egui::RichText::new(status).size(11.5).color(warna).strong());
        if !pesan.is_empty() {
            ui.label(egui::RichText::new(format!("— {pesan}")).size(11.5).color(egui::Color32::GRAY));
        }
    });
}

fn terapkan_tema(ctx: &egui::Context) {
    let mut v = egui::Visuals::dark();
    v.panel_fill = egui::Color32::from_rgb(0x0D, 0x11, 0x17);
    v.window_fill = egui::Color32::from_rgb(0x16, 0x1B, 0x22);
    v.widgets.noninteractive.bg_fill = v.panel_fill;
    v.widgets.noninteractive.bg_stroke =
        egui::Stroke::new(1.0_f32, egui::Color32::from_rgb(0x21, 0x26, 0x2D));
    v.widgets.inactive.bg_fill = egui::Color32::from_rgb(0x1B, 0x20, 0x2B);
    v.widgets.inactive.bg_stroke = egui::Stroke::new(1.0_f32, egui::Color32::from_rgb(0x30, 0x36, 0x3D));
    v.widgets.inactive.rounding = egui::Rounding::same(8.0);
    v.widgets.hovered.rounding = egui::Rounding::same(8.0);
    v.widgets.hovered.bg_fill = egui::Color32::from_rgb(0x26, 0x2D, 0x3D);
    v.widgets.active.rounding = egui::Rounding::same(8.0);
    v.widgets.active.bg_fill = UNGU;
    v.selection.bg_fill = UNGU.linear_multiply(0.35);
    v.hyperlink_color = UNGU_LEMBUT;
    ctx.set_visuals(v);

    let mut gaya = (*ctx.style()).clone();
    gaya.spacing.item_spacing = egui::vec2(8.0, 8.0);
    gaya.spacing.button_padding = egui::vec2(12.0, 6.0);
    gaya.text_styles
        .insert(egui::TextStyle::Body, egui::FontId::proportional(12.8));
    ctx.set_style(gaya);
}

/// Kartu rapi GitHub Dark: latar `#161B22`, garis tepi `#30363D`, sudut 10px.
fn kartu<R>(
    ui: &mut egui::Ui,
    isi: impl FnOnce(&mut egui::Ui) -> R,
) -> egui::InnerResponse<R> {
    egui::Frame::none()
        .fill(egui::Color32::from_rgb(0x16, 0x1B, 0x22))
        .stroke(egui::Stroke::new(1.0, egui::Color32::from_rgb(0x30, 0x36, 0x3D)))
        .rounding(egui::Rounding::same(10.0))
        .inner_margin(egui::Margin::symmetric(14.0, 12.0))
        .show(ui, isi)
}

/// Jam WIB (UTC+7) HH:MM:SS tanpa dependensi chrono.
fn jam_wib() -> String {
    use std::time::{SystemTime, UNIX_EPOCH};
    let s = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0);
    let lokal = (s + 7 * 3600) % 86400;
    format!("{:02}:{:02}:{:02}", lokal / 3600, (lokal % 3600) / 60, lokal % 60)
}

fn ikon_aplikasi() -> Option<egui::IconData> {
    let png = include_bytes!("../../src-tauri/icons/icon.png");
    let img = image::load_from_memory(png).ok()?.to_rgba8();
    let (w, h) = (img.width(), img.height());
    Some(egui::IconData {
        rgba: img.into_raw(),
        width: w,
        height: h,
    })
}

/// Log startup/galat ke %APPDATA%\XyCloudStore\Agent\gui.log — supaya
/// kegagalan tetap terlacak walau jendela tak muncul (exe tanpa konsol).
fn log_gui(teks: &str) {
    use std::io::Write;
    let dir = std::env::var("APPDATA")
        .map(std::path::PathBuf::from)
        .unwrap_or_else(|_| std::env::temp_dir())
        .join("XyCloudStore")
        .join("Agent");
    let _ = std::fs::create_dir_all(&dir);
    if let Ok(mut f) = std::fs::OpenOptions::new()
        .create(true)
        .append(true)
        .open(dir.join("gui.log"))
    {
        let _ = writeln!(f, "[{}] v{VERSI} {teks}", jam_wib());
    }
}

/// Dialog error native Windows — jalur terakhir supaya app tidak "mati diam".
#[cfg(windows)]
fn dialog_error(pesan: &str) {
    #[link(name = "user32")]
    extern "system" {
        fn MessageBoxW(
            hwnd: *mut core::ffi::c_void,
            text: *const u16,
            caption: *const u16,
            utype: u32,
        ) -> i32;
    }
    let judul: Vec<u16> = "XyCloudStore Agent"
        .encode_utf16()
        .chain(std::iter::once(0))
        .collect();
    let isi: Vec<u16> = pesan.encode_utf16().chain(std::iter::once(0)).collect();
    unsafe {
        MessageBoxW(std::ptr::null_mut(), isi.as_ptr(), judul.as_ptr(), 0x10);
    }
}

#[cfg(not(windows))]
fn dialog_error(pesan: &str) {
    eprintln!("{pesan}");
}

/// Laporkan kegagalan fatal startup: log + dialog + exit code 1.
/// Penerus crate `log` (wgpu/eframe/egui-wgpu) ke gui.log — tanpanya,
/// warn!/error! diagnostik dari wgpu tidak terlihat di CI maupun pengguna.
struct LoggerGui;

impl log::Log for LoggerGui {
    fn enabled(&self, _: &log::Metadata) -> bool {
        true
    }
    fn log(&self, r: &log::Record) {
        if r.level() <= log::Level::Warn {
            log_gui(&format!("{} [{}] {}", r.level(), r.target(), r.args()));
        }
    }
    fn flush(&self) {}
}

/// Dump semua adapter wgpu yang terlihat ke gui.log (diagnostik stage 3).
fn dump_adapter() {
    let inst = wgpu::Instance::new(wgpu::InstanceDescriptor {
        backends: wgpu::Backends::all(),
        ..Default::default()
    });
    let daftar = inst.enumerate_adapters(wgpu::Backends::all());
    log_gui(&format!(
        "diagnostik: {} adapter wgpu terlihat di proses ini",
        daftar.len()
    ));
    for a in &daftar {
        let i = a.get_info();
        log_gui(&format!(
            "  - {:?} | {} | vendor=0x{:04x} device=0x{:04x} | {:?}",
            i.backend, i.name, i.vendor, i.device, i.device_type
        ));
    }
}

fn gagal_mulai(tahap: &str, err: &dyn std::fmt::Display) -> ! {
    let pesan = format!(
        "Agen gagal memulai ({tahap}).\n\n{err}\n\n         Log lengkap: %APPDATA%\\XyCloudStore\\Agent\\gui.log\n         Coba jalankan dari PowerShell: .\\XyCloudStore-Agent.exe --gui-tes"
    );
    log_gui(&format!("GAGAL {tahap}: {err}"));
    // Mode --gui-tes (CI headless): jangan tampilkan dialog — bisa memblokir
    // proses tanpa ada yang menekan OK. Log + exit code sudah cukup.
    if !std::env::args().any(|a| a == "--gui-tes") {
        dialog_error(&pesan);
    }
    std::process::exit(1);
}

fn opsi_native() -> eframe::NativeOptions {
    let mut viewport = egui::ViewportBuilder::default()
        .with_inner_size([480.0, 720.0])
        .with_min_inner_size([420.0, 560.0])
        .with_title("XyCloudStore Host Agent");
    if let Some(ikon) = ikon_aplikasi() {
        viewport = viewport.with_icon(ikon);
    }
    eframe::NativeOptions {
        viewport,
        ..Default::default()
    }
}

fn main() {
    // Teruskan log wgpu/eframe ke gui.log (diagnostik renderer terlihat).
    let _ = log::set_boxed_logger(Box::new(LoggerGui));
    log::set_max_level(log::LevelFilter::Info);

    // Hook panic: crash tidak lagi diam — selalu tercatat di log + dialog.
    std::panic::set_hook(Box::new(|info| {
        log_gui(&format!("PANIC: {info}"));
        if !std::env::args().any(|a| a == "--gui-tes") {
            dialog_error(&format!(
                "Agen crash.\n\n{info}\n\nLog: %APPDATA%\\XyCloudStore\\Agent\\gui.log"
            ));
        }
    }));

    // Smoke-test versi (CI & pengguna) — tanpa membuka jendela.
    if std::env::args().any(|a| a == "--veri" || a == "-V") {
        println!("XyCloudStore-Agent {VERSI}");
        println!("runtime: Rust/egui-native (tanpa Tauri, tanpa WebView, tanpa terminal)");
        std::process::exit(0);
    }
    // Mode headless: -Jalankan (dipakai entri autostart registry).
    if std::env::args().any(|a| a == "-Jalankan" || a == "--jalankan") {
        let cfg = agent::muat_konfig();
        if cfg.kode.is_empty() {
            eprintln!("Kode unit belum diisi. Jalankan aplikasi UI dulu untuk konfigurasi.");
            std::process::exit(2);
        }
        let stop = Arc::new(AtomicBool::new(false));
        // Log headless TIDAK boleh cuma ke stdout — proses autostart registry
        // tak punya terminal, pesan akan hilang. Tulis juga ke
        // %APPDATA%\XyCloudStore\Agent\agent.log (rotasi 1MB, stempel waktu).
        let log: Logger = Arc::new(|t| {
            println!("[XYAGENT] {t}");
            agent::tulis_log_headless(t);
        });
        agent::tulis_log_headless(&format!(
            "Mulai headless — agen v{VERSI}, kode unit terpasang={}",
            !cfg.kode.is_empty()
        ));
        agent::jalankan_loop(cfg, log, stop);
        return;
    }

    let tes_gui = std::env::args().any(|a| a == "--gui-tes");
    let paksa_wgpu = std::env::args().any(|a| a == "--wgpu");
    let paksa_warp = std::env::args().any(|a| a == "--warp");
    log_gui(&format!(
        "mulai (gui-tes={tes_gui} wgpu={paksa_wgpu} warp={paksa_warp}) os={}",
        std::env::consts::OS
    ));

    let st = Keadaan::baru(agent::muat_konfig());

    // Renderer bertingkat:
    //   1. glow (OpenGL 2.0+) — paling ringan, jalan di hampir semua PC
    //   2. --wgpu  (DirectX/Vulkan/GL modern)
    //   3. --warp  (wgpu adapter software — WARP bawaan Windows, selalu ada)
    // winit hanya mengizinkan satu EventLoop per proses → tiap tingkat naik
    // dilakukan dengan re-exec exe ini sebagai proses baru (--wgpu/--warp).
    let mut opsi = opsi_native();
    let renderer = if paksa_warp {
        opsi.renderer = eframe::Renderer::Wgpu;
        opsi.wgpu_options.force_fallback_adapter = true;
        "wgpu+warp"
    } else if paksa_wgpu {
        opsi.renderer = eframe::Renderer::Wgpu;
        "wgpu"
    } else {
        opsi.renderer = eframe::Renderer::Glow;
        "glow"
    };
    log_gui(&format!("konfig dimuat, membuka jendela (renderer {renderer})…"));

    let st1 = st.clone();
    let hasil = eframe::run_native(
        "XyCloudStore Agent",
        opsi,
        Box::new(move |cc| Ok(Box::new(Aplikasi::baru(cc, st1.clone(), tes_gui)))),
    );
    if hasil.is_ok() {
        log_gui("jendela ditutup normal");
        return;
    }
    let e1 = hasil.unwrap_err();
    log_gui(&format!("{renderer} gagal: {e1}"));

    if !paksa_wgpu && !paksa_warp {
        jalankan_ulang(&["--wgpu"], &format!("glow: {e1}"));
    }
    if paksa_wgpu && !paksa_warp {
        jalankan_ulang(&["--warp"], &format!("wgpu: {e1}"));
    }
    dump_adapter();
    gagal_mulai("glow, wgpu, dan WARP (software) semuanya gagal", &e1);
}

/// Re-exec exe ini sebagai proses baru dengan argumen tambahan `tambah`
/// (winit: satu EventLoop per proses). Exit code anak diteruskan.
fn jalankan_ulang(tambah: &[&str], err_sebelum: &dyn std::fmt::Display) -> ! {
    let exe = match std::env::current_exe() {
        Ok(e) => e,
        Err(e) => gagal_mulai("tidak tahu lokasi exe sendiri", &e),
    };
    let mut cmd = std::process::Command::new(exe);
    cmd.args(std::env::args_os().skip(1)).args(tambah);
    log_gui(&format!("re-exec fallback {} …", tambah.join(" ")));
    match cmd.status() {
        Ok(status) if status.success() => {
            log_gui("proses fallback selesai normal");
            std::process::exit(0);
        }
        Ok(status) => gagal_mulai(
            &format!("renderer fallback {} ikut gagal (exit {status})", tambah.join(" ")),
            err_sebelum,
        ),
        Err(e) => gagal_mulai("gagal menjalankan ulang proses fallback", &e),
    }
}
