import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:provider/provider.dart';
import '../../core/biometrik.dart';
import '../../core/cache.dart';
import '../../core/keamanan.dart';
import '../../core/kompres.dart';
import '../../core/media_lokal.dart';
import '../../core/pengaturan.dart';
import '../../core/prefs.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/app_state.dart';
import '../widgets/banner_profil.dart';
import '../widgets/bingkai_profil.dart';
import '../widgets/gaya_nama.dart';
import '../widgets/common.dart';
import '../widgets/galeri_picker.dart';
import '../widgets/lembar.dart';
import '../widgets/transfer_sheet.dart';
import 'bantuan_screen.dart';
import 'legal_screen.dart';
import 'pembaruan_screen.dart';
import 'tentang_screen.dart';
import 'tier_screen.dart';
import 'opsi_screen.dart';
import 'hapus_akun_screen.dart';
import 'stiker_library_screen.dart';

/// ============================================================
///  Pengaturan: daftar utama dan halaman turunannya
/// ============================================================
///  Setiap pengaturan punya halamannya sendiri supaya nyaman dibaca
///  dan tidak menumpuk lembar bawah.
class PengaturanScreen extends StatelessWidget {
  const PengaturanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
        children: [
          const _Judul('Akun'),
          XyBarisMenu(
            ikon: Icons.badge_outlined,
            judul: 'Identitas Profil',
            sub: 'Nama, username, WhatsApp, bio, foto, dan tautan',
            tujuan: const UbahProfilScreen(),
          ),
          const XyBarisMenu(
            ikon: Icons.auto_awesome_rounded,
            judul: 'Kustomisasi Profil',
            sub: 'Badge, bingkai, lencana, style nama, banner, dan tema',
            tujuan: KustomProfilScreen(),
          ),
          XyBarisMenu(
            ikon: Icons.lock_outline_rounded,
            judul: 'Keamanan',
            sub: 'Ganti password dan info sesi',
            tujuan: const KeamananScreen(),
          ),
          XyBarisMenu(
            ikon: Icons.screenshot_monitor_outlined,
            judul: 'Mode Privasi',
            sub: 'Blokir screenshot & rekaman layar',
            tujuan: const ModePrivasiScreen(),
          ),
          const _Judul('Tampilan'),
          XyBarisMenu(
            ikon: Icons.dark_mode_outlined,
            judul: 'Tema Aplikasi',
            sub: 'Terang, gelap, atau ikut sistem',
            tujuan: const TemaScreen(),
          ),
          XyBarisMenu(ikon:Icons.text_fields_rounded,judul:'Teks & Gerakan',sub:'Ukuran teks dan animasi halaman',tujuan:const OpsiTampilanScreen()),
          XyBarisMenu(ikon:Icons.sports_esports_rounded,judul:'Streaming & Kontrol',sub:'Resolusi, FPS, bitrate, gamepad, dan keyboard',tujuan:const OpsiStreamingScreen()),
          const _Judul('Aplikasi'),
          XyBarisMenu(
            ikon: Icons.chat_bubble_outline_rounded,
            judul: 'Komunitas & Percakapan',
            sub: 'Izin DM, tanda dibaca, dan filter keamanan',
            tujuan: const PengaturanChatScreen(),
          ),
          XyBarisMenu(
            ikon: Icons.volume_up_outlined,
            judul: 'Suara & Getaran',
            sub: 'Efek suara tombol, audio feedback, dan haptic',
            tujuan: const SuaraGetaranScreen(),
          ),
          XyBarisMenu(ikon:Icons.emoji_emotions_outlined,judul:'Stiker & Penyimpanan',sub:'Koleksi otomatis, folder internal, dan cache',tujuan:const StikerLibraryScreen()),
          XyBarisMenu(
            ikon: Icons.notifications_none_rounded,
            judul: 'Notifikasi',
            sub: 'Atur pemberitahuan komunitas',
            tujuan: const OpsiNotifikasiScreen(),
          ),
          XyBarisMenu(
            ikon: Icons.data_saver_on_rounded,
            judul: 'Data dan Penyimpanan',
            sub: 'Mode hemat data dan data tersimpan',
            tujuan: const DataScreen(),
          ),
          XyBarisMenu(
            ikon: Icons.shield_moon_outlined,
            judul: 'Privasi dan Konten',
            sub: 'Saringan konten dewasa dan laporan',
            tujuan: const PrivasiScreen(),
          ),
          XyBarisMenu(
            ikon: Icons.system_update_alt_rounded,
            judul: 'Cek Pembaruan',
            sub: 'Pastikan aplikasimu versi terbaru',
            tujuan: const PembaruanScreen(),
          ),
          const _Judul('Sesi dan akun'),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8)),
                onPressed: () => Navigator.push(
                    context, xyRoute(const HapusAkunScreen())),
                icon: const Icon(Icons.delete_forever_outlined,
                    size: 18, color: XyTheme.danger),
                label: const Text('Hapus Akun',
                    style: TextStyle(
                        color: XyTheme.danger, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8)),
                onPressed: () async {
                  final keluar = await konfirmasi(context,
                      judul: 'Keluar dari akun?',
                      pesan: 'Data sesi di HP akan dibersihkan. Akunmu tidak dihapus.',
                      tombolYa: 'Keluar',
                      bahaya: true);
                  if (keluar && context.mounted) {
                    await context.read<AppState>().logout();
                  }
                },
                icon: const Icon(Icons.logout_rounded,
                    size: 18, color: XyTheme.danger),
                label: const Text('Keluar',
                    style: TextStyle(
                        color: XyTheme.danger, fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
          const _Judul('Legal dan kebijakan'),
          XyBarisMenu(
            ikon: Icons.description_outlined,
            judul: 'Syarat dan Ketentuan',
            sub: 'Aturan pemakaian layanan',
            tujuan: const LegalScreen(jenis: 'syarat'),
          ),
          XyBarisMenu(
            ikon: Icons.privacy_tip_outlined,
            judul: 'Kebijakan Privasi',
            sub: 'Data apa yang kami simpan dan untuk apa',
            tujuan: const LegalScreen(jenis: 'privasi'),
          ),
          XyBarisMenu(
            ikon: Icons.currency_exchange_rounded,
            judul: 'Kebijakan Pengembalian Dana',
            sub: 'Refund sewa PC, akun digital, dan saldo',
            tujuan: const LegalScreen(jenis: 'refund'),
          ),
          const _Judul('Lainnya'),
          XyBarisMenu(
            ikon: Icons.help_outline_rounded,
            judul: 'Pusat Bantuan',
            sub: 'Pertanyaan yang sering ditanyakan',
            tujuan: const BantuanScreen(),
          ),
          XyBarisMenu(
            ikon: Icons.info_outline_rounded,
            judul: 'Tentang Aplikasi',
            sub: 'Versi, legal, dan lisensi',
            tujuan: const TentangScreen(),
          ),
        ],
      ),
    );
  }
}

class _Judul extends StatelessWidget {
  const _Judul(this.teks);
  final String teks;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
        child: Text(teks.toUpperCase(),
            style:  TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: XyTheme.of(context).muted)),
      );
}


// ============================================================
//  Kustomisasi profil — setiap kategori membuka layar yang relevan
// ============================================================
class KustomProfilScreen extends StatelessWidget {
  const KustomProfilScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final u = context.watch<AppState>().user;
    if (u == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Kustomisasi Profil')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
        children: [
          BannerProfil(
            tema: u.banner,
            media: u.bannerMedia,
            borderRadius: BorderRadius.circular(XyRadius.xl),
            child: SizedBox(
              height: 190,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(children: [
                  SizedBox(
                    width: 112,
                    height: 112,
                    child: Center(
                      child: AvatarBingkai(
                        bingkai: u.bingkai,
                        size: 84,
                        child: (u.foto ?? '').isNotEmpty
                            ? Image.network(u.foto!, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _InisialKustom(u.nama))
                            : _InisialKustom(u.nama),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GayaNama(
                          u.nama,
                          gaya: u.gayaNama,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text('@${u.username ?? 'username'}',
                            style: TextStyle(
                                color: Colors.white.withOpacity(.78),
                                fontSize: 12)),
                        const SizedBox(height: 10),
                        Wrap(spacing: 6, runSpacing: 6, children: [
                          _ChipKustom(u.tier.toUpperCase()),
                          if (u.badge != null) _ChipKustom(u.badge!),
                        ]),
                      ],
                    ),
                  ),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Pratinjau langsung. Bingkai dan elemen animasi berada di depan foto.',
            textAlign: TextAlign.center,
            style: TextStyle(color: XyTheme.of(context).muted, fontSize: 11.5),
          ),
          const _Judul('Pilih kategori'),
          XyBarisMenu(
            ikon: Icons.workspace_premium_outlined,
            judul: 'Badge',
            sub: u.badge == null
                ? 'Belum ada badge khusus'
                : 'Aktif: ${u.badge}',
            tujuan: const _StatusKustomScreen(jenis: _StatusKustomJenis.badge),
          ),
          XyBarisMenu(
            ikon: Icons.filter_frames_rounded,
            judul: 'Bingkai',
            sub: 'Pilih bingkai statis, animasi, atau premium',
            tujuan: const UbahProfilScreen(fokus: FokusProfil.bingkai),
          ),
          XyBarisMenu(
            ikon: Icons.military_tech_outlined,
            judul: 'Lencana',
            sub: 'Lencana tier ${u.tier.toUpperCase()} dan benefit',
            tujuan: const _StatusKustomScreen(jenis: _StatusKustomJenis.lencana),
          ),
          XyBarisMenu(
            ikon: Icons.text_fields_rounded,
            judul: 'Style Nama',
            sub: 'Font, gradasi, neon, pelangi, ombak, dan ketik',
            tujuan: const UbahProfilScreen(fokus: FokusProfil.gayaNama),
          ),
          XyBarisMenu(
            ikon: Icons.panorama_outlined,
            judul: 'Banner',
            sub: 'Warna, GIF, atau video yang otomatis menjadi GIF',
            tujuan: const UbahProfilScreen(fokus: FokusProfil.banner),
          ),
          const XyBarisMenu(
            ikon: Icons.palette_outlined,
            judul: 'Tema Aplikasi',
            sub: 'Terang, gelap, atau mengikuti sistem',
            tujuan: TemaScreen(),
          ),
        ],
      ),
    );
  }
}

class _InisialKustom extends StatelessWidget {
  const _InisialKustom(this.nama);
  final String nama;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: XyTheme.violet,
        child: Center(
          child: Text(
            nama.isEmpty ? 'X' : nama[0].toUpperCase(),
            style: const TextStyle(
                color: Colors.white, fontSize: 31, fontWeight: FontWeight.w900),
          ),
        ),
      );
}

class _ChipKustom extends StatelessWidget {
  const _ChipKustom(this.teks);
  final String teks;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(.28),
          borderRadius: BorderRadius.circular(XyRadius.pill),
          border: Border.all(color: Colors.white.withOpacity(.30)),
        ),
        child: Text(teks,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: .5)),
      );
}

enum _StatusKustomJenis { badge, lencana }

class _StatusKustomScreen extends StatelessWidget {
  const _StatusKustomScreen({required this.jenis});
  final _StatusKustomJenis jenis;

  @override
  Widget build(BuildContext context) {
    final u = context.watch<AppState>().user;
    final badge = jenis == _StatusKustomJenis.badge;
    final nilai = badge ? (u?.badge ?? 'Belum punya badge') : (u?.tier ?? 'basic').toUpperCase();
    return Scaffold(
      appBar: AppBar(title: Text(badge ? 'Badge Profil' : 'Lencana Tier')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 34, 22, 30),
        children: [
          Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: .86, end: 1),
              duration: const Duration(milliseconds: 520),
              curve: Curves.easeOutBack,
              builder: (_, skala, child) => Transform.scale(scale: skala, child: child),
              child: Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  gradient: badge ? XyTheme.gradPrimary : XyTheme.gradGold,
                  shape: BoxShape.circle,
                  boxShadow: XyTheme.shadowMd,
                ),
                child: Icon(
                  badge ? Icons.workspace_premium_rounded : Icons.military_tech_rounded,
                  color: Colors.white,
                  size: 48,
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),
          Text(nilai,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
          const SizedBox(height: 9),
          Text(
            badge
                ? 'Badge khusus diberikan oleh admin untuk kreator, staf, moderator, event, atau pencapaian tertentu. Badge aktif tampil di samping namamu dan tidak bisa dipalsukan.'
                : 'Lencana mengikuti tier akun secara otomatis dari transaksi yang valid. Makin tinggi tier, makin banyak bingkai, style nama, dan benefit yang terbuka.',
            textAlign: TextAlign.center,
            style: TextStyle(color: XyTheme.of(context).muted, height: 1.55, fontSize: 13),
          ),
          if (!badge) ...[
            const SizedBox(height: 24),
            GradientButton(
              label: 'Lihat Tier & Benefit',
              icon: Icons.diamond_outlined,
              onPressed: () => Navigator.push(context, xyRoute(const TierScreen())),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================
//  Ubah profil — bisa dibuka langsung ke kategori tertentu
// ============================================================
enum FokusProfil { identitas, bingkai, gayaNama, banner }

class UbahProfilScreen extends StatefulWidget {
  const UbahProfilScreen({super.key, this.fokus = FokusProfil.identitas});

  final FokusProfil fokus;

  @override
  State<UbahProfilScreen> createState() => _UbahProfilScreenState();
}

class _UbahProfilScreenState extends State<UbahProfilScreen> {
  final _scrollProfil = ScrollController();
  late final TextEditingController _nama;
  late final TextEditingController _phone;
  late final TextEditingController _bio;
  late final TextEditingController _slogan;
  late final TextEditingController _bioLink;
  late final TextEditingController _username;
  late String _gayaNama;
  late String _banner;
  late String? _bingkai;
  Timer? _cekTimer;
  String? _cekStatus; // null | 'cek' | 'ok' | 'galat'
  String _cekPesan = '';
  bool proses = false;
  String? pesan;
  bool _sibukBanner = false;
  double? _progresBanner; // 0..1; null = tidak sedang unggah
  String _tahapBanner = '';

  /// Fase setelah byte selesai: server mengonversi video → GIF. Progress bar
  /// jadi indeterminat dan penghitung detik berjalan, supaya tidak terlihat
  /// "mentok 90%" (laporan pemilik 2026-09-18).
  bool _konversiBanner = false;
  int _detikKonversi = 0;
  Timer? _timerKonversi;

  void _mulaiFaseKonversi() {
    if (_konversiBanner) return;
    _konversiBanner = true;
    _detikKonversi = 0;
    _timerKonversi?.cancel();
    _timerKonversi = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _detikKonversi++);
    });
  }

  void _akhirFaseKonversi() {
    _timerKonversi?.cancel();
    _timerKonversi = null;
    _konversiBanner = false;
    _detikKonversi = 0;
  }

  /// Salinan aturan validasi username dari server (Batch I) supaya umpan
  /// balik instan tanpa menunggu jaringan; keputusan akhir tetap di server.
  static final RegExp _formatUsername = RegExp(r'^[a-z0-9_.]{3,20}$');

  @override
  void initState() {
    super.initState();
    // Semua controller dibuat saat context masih aktif. Editor kategori hanya
    // membangun sebagian field, tetapi penyimpanan tetap memakai snapshot utuh.
    final u = context.read<AppState>().user;
    _nama = TextEditingController(text: u?.nama ?? '');
    _phone = TextEditingController(text: u?.phone ?? '');
    _bio = TextEditingController(text: u?.bio ?? '');
    _slogan = TextEditingController(text: u?.slogan ?? '');
    _bioLink = TextEditingController(text: u?.bioLink ?? '');
    _username = TextEditingController(text: u?.username ?? '');
    _gayaNama = u?.gayaNama ?? 'normal';
    _banner = u?.banner ?? 'ungu';
    _bingkai = u?.bingkai ?? 'polos';
  }

  @override
  void dispose() {
    _timerKonversi?.cancel();
    _scrollProfil.dispose();
    _nama.dispose();
    _phone.dispose();
    _bio.dispose();
    _slogan.dispose();
    _bioLink.dispose();
    _username.dispose();
    _cekTimer?.cancel();
    super.dispose();
  }

  // ---------------- pendinginan (Batch I) ----------------
  DateTime? _parseIso(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    return DateTime.tryParse(iso.contains('T') ? iso : '${iso.replaceFirst(' ', 'T')}Z');
  }

  /// Sisa hari pendinginan; null bila sudah boleh ganti lagi / belum pernah.
  int? _sisaHari(String? iso, int hari) {
    final d = _parseIso(iso);
    if (d == null) return null;
    final lewat = DateTime.now().difference(d.toLocal());
    final batas = Duration(days: hari);
    if (lewat >= batas) return null;
    return (batas - lewat).inDays + 1;
  }

  String _tanggalBoleh(String? iso, int hari) {
    final d = _parseIso(iso);
    if (d == null) return '';
    final boleh = d.toLocal().add(Duration(days: hari));
    const bulan = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
        'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    return '${boleh.day} ${bulan[boleh.month - 1]} ${boleh.year}';
  }

  // ---------------- username ----------------
  String? _alasanUsernameLokal(String un) {
    if (!_formatUsername.hasMatch(un)) {
      return 'Format: 3–20 karakter, huruf kecil a–z, angka, strip bawah, atau titik.';
    }
    if (!RegExp(r'^[a-z0-9]').hasMatch(un)) return 'Harus diawali huruf atau angka.';
    if (RegExp(r'[._]$').hasMatch(un)) return 'Tidak boleh diakhiri titik atau strip bawah.';
    if (un.contains('..')) return 'Titik berurutan tidak diperbolehkan.';
    return null;
  }

  /// Cek ketersediaan username ke server (debounce 650 ms) sekaligus
  /// menyaring kata kasar/SARA/pornografi lewat endpoint /cek-nama.
  /// Aturan format diperiksa lokal lebih dulu agar umpan baliknya instan.
  void _jadwalCekUsername() {
    _cekTimer?.cancel();
    final un = _username.text.trim().toLowerCase();
    if (un.isEmpty) {
      setState(() {
        _cekStatus = null;
        _cekPesan = '';
      });
      return;
    }
    final lokal = _alasanUsernameLokal(un);
    if (lokal != null) {
      setState(() {
        _cekStatus = 'galat';
        _cekPesan = lokal;
      });
      return;
    }
    setState(() {
      _cekStatus = 'cek';
      _cekPesan = '';
    });
    _cekTimer = Timer(const Duration(milliseconds: 650), () async {
      try {
        final h = await context.read<AppState>().repo.cekNama(username: un);
        final u = Map<String, dynamic>.from(h['username'] ?? {});
        if (!mounted) return;
        setState(() {
          _cekStatus = u['tersedia'] == true ? 'ok' : 'galat';
          _cekPesan = u['tersedia'] == true
              ? 'Username tersedia!'
              : '${u['alasan'] ?? 'Username tidak tersedia.'}';
        });
      } catch (_) {
        if (mounted) {
          setState(() {
            _cekStatus = null;
            _cekPesan = '';
          });
        }
      }
    });
  }

  // ---------------- foto profil ----------------
  Future<void> _gantiFoto() async {
    final f = await GaleriPicker.pilihGambar(context, judul: 'Pilih Foto Profil');
    if (f == null || !mounted) return;
    setState(() => proses = true);
    try {
      final bytes = await f.readAsBytes();
      final namaBerkas = f.uri.pathSegments.isNotEmpty ? f.uri.pathSegments.last : 'foto.jpg';
      final fotoUri = await Kompres.dataUri(bytes, namaBerkas, maxSisi: 700, kualitas: 78);
      if (!mounted) return;
      final galat = await context.read<AppState>().perbaruiProfil(foto: fotoUri);
      if (!mounted) return;
      setState(() => pesan = galat);
      if (galat == null) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Foto profil diperbarui.')));
      }
    } finally {
      if (mounted) setState(() => proses = false);
    }
  }

  // ---------------- banner media (Batch I) ----------------
  Future<void> _unggahBanner({required bool video}) async {
    final u = context.read<AppState>().user;
    if (u == null) return;
    if (u.tier == 'basic' && video) {
      setState(() => pesan = 'Banner video khusus langganan Pro & VIP.');
      return;
    }
    final f = await GaleriPicker.pilihGambar(
      context,
      jenis: video
          ? const {JenisGaleri.video, JenisGaleri.gif}
          : const {JenisGaleri.gif},
      awal: video ? JenisGaleri.video : JenisGaleri.gif,
      judul: video ? 'Pilih Video / GIF' : 'Pilih GIF',
    );
    if (f == null || !mounted) return;

    final nama = f.uri.pathSegments.isNotEmpty
        ? f.uri.pathSegments.last.toLowerCase()
        : '';
    final bytes = await f.readAsBytes();
    if (!mounted) return;
    final mb = bytes.length / (1024 * 1024);

    String mime;
    if (video) {
      final okVideo = nama.endsWith('.mp4') || nama.endsWith('.mov') || nama.endsWith('.webm');
      final okGif = nama.endsWith('.gif');
      if (!okVideo && !okGif) {
        setState(() => pesan = 'Pilih berkas MP4 atau GIF untuk banner bergerak.');
        return;
      }
      if (mb > 15) {
        setState(() => pesan = 'Video maksimal 15MB (terpilih ${mb.toStringAsFixed(1)}MB).');
        return;
      }
      mime = okGif ? 'image/gif' : 'video/mp4';
    } else {
      if (!nama.endsWith('.gif')) {
        setState(() => pesan = 'Pilih berkas GIF (animasi). Foto biasa pakai tema warna saja.');
        return;
      }
      if (mb > 8) {
        setState(() => pesan = 'GIF maksimal 8MB (terpilih ${mb.toStringAsFixed(1)}MB).');
        return;
      }
      mime = 'image/gif';
    }

    setState(() {
      _sibukBanner = true;
      _progresBanner = 0;
      _tahapBanner = 'Menyiapkan berkas…';
      pesan = null;
    });
    final dataUri = 'data:$mime;base64,${base64Encode(bytes)}';
    final mulai = DateTime.now();
    String? galat;
    try {
      galat = await context
          .read<AppState>()
          .unggahBannerMedia(
      dataUri,
      onProgress: (terkirim, total) {
        if (!mounted) return;
        // Byte selesai = masuk fase konversi server: bar indeterminat +
        // penghitung detik, bukan angka persen yang berhenti di 90%.
        if (total > 0 && terkirim >= total) {
          _mulaiFaseKonversi();
          setState(() {
            _progresBanner = null;
            _tahapBanner =
                'Berkas selesai diunggah — server sedang mengonversi video → GIF…';
          });
          return;
        }
        final p = total <= 0 ? 0.0 : (terkirim / total).clamp(0.0, .89);
        setState(() {
          _progresBanner = p;
          _tahapBanner =
              'Mengunggah ${(terkirim / 1048576).toStringAsFixed(1)} / ${(total / 1048576).toStringAsFixed(1)} MB';
        });
      },
          ).timeout(const Duration(seconds: 240));
    } on TimeoutException {
      _akhirFaseKonversi();
      galat =
          'Konversi melebihi 4 menit tanpa respons. Server mungkin masih bekerja — muat ulang profil untuk mengecek, atau pakai video yang lebih pendek.';
    }
    if (!mounted) return;
    final detik = DateTime.now().difference(mulai).inMilliseconds / 1000;
    setState(() {
      _sibukBanner = false;
      _progresBanner = null;
      _akhirFaseKonversi();
      pesan = galat;
    });
    if (galat == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(video && mime == 'video/mp4'
              ? 'Banner terpasang! Video diconvert ke GIF dan MP4 dihapus dari cloud (${detik.toStringAsFixed(0)} dtk).'
              : 'Banner GIF terpasang!')));
    }
  }

  Future<void> _hapusBannerMedia() async {
    final galat = await context.read<AppState>().hapusBannerMedia();
    if (!mounted) return;
    setState(() => pesan = galat);
  }

  Future<void> _simpan() async {
    if (_nama.text.trim().length < 3) {
      setState(() => pesan = 'Nama minimal 3 karakter');
      return;
    }
    setState(() {
      proses = true;
      pesan = null;
    });
    final galat = await context.read<AppState>().perbaruiProfil(
          nama: _nama.text.trim(),
          phone: _phone.text.trim(),
          bio: _bio.text.trim(),
          banner: _banner,
          username: _username.text.trim().toLowerCase(),
          bingkai: _bingkai ?? 'polos',
          slogan: _slogan.text.trim(),
          bioLink: _bioLink.text.trim(),
          gayaNama: _gayaNama,
        );
    if (!mounted) return;
    setState(() {
      proses = false;
      pesan = galat;
    });
    if (galat == null) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil diperbarui.')),
      );
    }
  }

  String get _judulHalaman => switch (widget.fokus) {
        FokusProfil.identitas => 'Identitas Profil',
        FokusProfil.bingkai => 'Bingkai Profil',
        FokusProfil.gayaNama => 'Style Nama',
        FokusProfil.banner => 'Banner Profil',
      };

  String get _labelSimpan => switch (widget.fokus) {
        FokusProfil.identitas => 'Simpan Identitas',
        FokusProfil.bingkai => 'Pakai Bingkai',
        FokusProfil.gayaNama => 'Pakai Style Nama',
        FokusProfil.banner => 'Simpan Banner',
      };

  @override
  Widget build(BuildContext context) {
    final u = context.watch<AppState>().user;
    final t = XyTheme.of(context);
    final sisaNama = _sisaHari(u?.namaDiubahPada, 7);
    final namaTerkunci = sisaNama != null &&
        _nama.text.trim().toLowerCase() != (u?.nama ?? '').trim().toLowerCase();
    final pernahUsername = (u?.username ?? '').isNotEmpty;
    final sisaUsername = _sisaHari(u?.usernameDiubahPada, 30);
    final usernameTerkunci = pernahUsername && sisaUsername != null;
    final langganan = u != null && u.tier != 'basic';

    return Scaffold(
      appBar: AppBar(title: Text(_judulHalaman)),
      body: ListView(
        controller: _scrollProfil,
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
        children: [
          // ---------- avatar / pratinjau bingkai ----------
          if (widget.fokus == FokusProfil.identitas ||
              widget.fokus == FokusProfil.bingkai)
            Center(
              child: Stack(children: [
              AvatarBingkai(
                bingkai: _bingkai,
                size: 104,
                child: Container(
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: t.primarySoft,
                    image: (u?.foto ?? '').isNotEmpty
                        ? DecorationImage(image: NetworkImage(u!.foto!), fit: BoxFit.cover)
                        : null,
                  ),
                  child: (u?.foto ?? '').isEmpty
                      ? Icon(Icons.person_rounded, size: 44, color: t.muted)
                      : null,
                ),
              ),
              if (widget.fokus == FokusProfil.identitas)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Pressable(
                    onTap: proses ? null : _gantiFoto,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: t.line),
                      boxShadow: XyTheme.shadowSm,
                    ),
                    child: const Icon(Icons.camera_alt_rounded,
                        size: 16, color: XyTheme.primary),
                  ),
                ),
              ),
              ]),
            ),
          if (widget.fokus == FokusProfil.identitas ||
              widget.fokus == FokusProfil.bingkai)
            const SizedBox(height: 16),
          if (widget.fokus == FokusProfil.bingkai) ...[
          const XyLabel('Bingkai Profil'),
          PilihBingkai(
            nilai: _bingkai,
            foto: u?.foto,
            tier: u?.tier ?? 'basic',
            onPilih: (v) => setState(() => _bingkai = v ?? 'polos'),
          ),
          const SizedBox(height: 6),
          Text(
            'Pilihan bingkai avatar: Polos, Gradasi Ungu/Emas/Neon, Cyberpunk, Hologram, Kristal Es, Pelangi RGB, Permata Ruby, Zamrud Hijau, Sakura, Sirkuit, Sayap, Petir, serta Mahkota Raja & Naga Emas. Tampil konsisten di profil, feed, pesan, dan leaderboard.',
            style: TextStyle(color: t.muted, fontSize: 11.5, height: 1.5),
          ),
          const SizedBox(height: 18),
          ],

          if (widget.fokus == FokusProfil.identitas) ...[
          // ---------- nama ----------
          XyLabel(namaTerkunci
              ? 'Nama Tampilan / Display Name (bisa diganti lagi ${_tanggalBoleh(u?.namaDiubahPada, 7)})'
              : 'Nama Tampilan (Display Name)'),
          TextField(
            controller: _nama,
            readOnly: namaTerkunci,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: 'Nama yang dilihat pengguna lain di feed & komunitas',
              prefixIcon: const Icon(Icons.person_outline_rounded),
              suffixIcon: namaTerkunci
                  ? Icon(Icons.lock_rounded, size: 18, color: t.muted)
                  : null,
              helperText: namaTerkunci
                  ? 'Display name hanya bisa diganti 7 hari sekali (sisa $sisaNama hari).'
                  : 'Nama tampilan publik. Maksimal diganti 7 hari sekali setelah disimpan.',
              helperMaxLines: 2,
            ),
          ),
          const SizedBox(height: 18),
          const XyLabel('Nomor WhatsApp'),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              hintText: '08xxxxxxxxxx',
              prefixIcon: Icon(Icons.phone_iphone_rounded),
            ),
          ),
          const SizedBox(height: 18),

          // ---------- username ----------
          XyLabel(usernameTerkunci
              ? 'Username (bisa diganti lagi ${_tanggalBoleh(u?.usernameDiubahPada, 30)})'
              : 'Username'),
          TextField(
            controller: _username,
            onChanged: (_) => _jadwalCekUsername(),
            readOnly: usernameTerkunci,
            autocorrect: false,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              hintText: 'pilih_username',
              prefixIcon: const Icon(Icons.alternate_email_rounded),
              suffixIcon: usernameTerkunci
                  ? Icon(Icons.lock_rounded, size: 18, color: t.muted)
                  : _cekStatus == 'cek'
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: XyTheme.primary)),
                        )
                      : _cekStatus == 'ok'
                          ? const Icon(Icons.check_circle_rounded,
                              color: Color(0xFF2D7357))
                          : _cekStatus == 'galat'
                              ? const Icon(Icons.cancel_rounded,
                                  color: Color(0xFFB54450))
                              : null,
              helperText: usernameTerkunci
                  ? 'Username hanya bisa diganti 30 hari sekali (sisa $sisaUsername hari).'
                  : '3–20 karakter: huruf kecil, angka, strip bawah, titik. Tidak boleh diawali/diakhiri titik.',
              helperMaxLines: 2,
            ),
          ),
          if (_cekPesan.isNotEmpty && !usernameTerkunci)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text(_cekPesan,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _cekStatus == 'ok'
                          ? const Color(0xFF2D7357)
                          : const Color(0xFFB54450))),
            ),
          const SizedBox(height: 18),
          const XyLabel('Bio'),
          TextField(
            controller: _bio,
            maxLines: 3,
            maxLength: 160,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Ceritakan sedikit tentang dirimu — tampil di profil publik dan komunitas',
              prefixIcon: Padding(
                padding: EdgeInsets.only(bottom: 44),
                child: Icon(Icons.edit_note_rounded),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // ---------- slogan (Batch L) ----------
          const XyLabel('Slogan'),
          TextField(
            controller: _slogan,
            maxLength: 60,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Kalimat singkat khas kamu — tampil di bawah nama',
              prefixIcon: Icon(Icons.format_quote_rounded),
            ),
          ),
          const SizedBox(height: 10),

          // ---------- bio link (Batch L) ----------
          const XyLabel('Bio Link'),
          TextField(
            controller: _bioLink,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: const InputDecoration(
              hintText: 'https://instagram.com/namamu',
              prefixIcon: Icon(Icons.link_rounded),
              helperText:
                  'Satu tautan publik (Instagram, YouTube, toko, dll). Kosongkan untuk menghapus.',
              helperMaxLines: 2,
            ),
          ),
          const SizedBox(height: 18),
          ],

          if (widget.fokus == FokusProfil.gayaNama) ...[
          // ---------- gaya nama (Batch L) ----------
          const XyLabel('Gaya Nama'),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: t.line),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // pratinjau langsung nama dengan gaya terpilih
              Center(
                child: GayaNama(
                  _nama.text.trim().isEmpty ? 'Nama Kamu' : _nama.text.trim(),
                  gaya: _gayaNama,
                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final g in daftarGayaNama)
                    Builder(builder: (context) {
                      final pilih = _gayaNama == g.id;
                      final kunci = g.langganan && !langganan;
                      return GestureDetector(
                        onTap: () {
                          if (kunci) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                content: Text(
                                    'Gaya nama beranimasi khusus pelanggan Pro/VIP. Naikkan tier dulu ya.')));
                            return;
                          }
                          setState(() => _gayaNama = g.id);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            gradient: pilih ? XyTheme.gradPrimary : null,
                            color: pilih ? null : t.bg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: pilih ? Colors.transparent : t.line),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            if (kunci) ...[
                              Icon(Icons.lock_rounded, size: 12, color: t.muted),
                              const SizedBox(width: 4),
                            ],
                            Text(g.label,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: pilih
                                      ? Colors.white
                                      : (kunci ? t.muted : t.ink),
                                )),
                          ]),
                        ),
                      );
                    }),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Gaya nama tampil di profil, komunitas, dan leaderboard. Gaya beranimasi (Gradasi, Emas, Neon, Pelangi, Ombak, Ketik) khusus Pro/VIP.',
                style: TextStyle(color: t.muted, fontSize: 11.5, height: 1.5),
              ),
            ]),
          ),
          const SizedBox(height: 18),
          ],

          if (widget.fokus == FokusProfil.banner) ...[
          // ---------- banner ----------
          const XyLabel('Banner Profil'),
          if (u?.bannerMedia != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(XyRadius.md),
              child: Stack(children: [
                SizedBox(
                  height: 96,
                  width: double.infinity,
                  child: Image.network(u!.bannerMedia!.gif,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                            color: t.primarySoft,
                            alignment: Alignment.center,
                            child: Text('Banner gagal dimuat',
                                style: TextStyle(color: t.muted, fontSize: 12)),
                          )),
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: Row(children: [
                    _PillBanner(
                      ikon: u.bannerMedia!.tipe == 'video'
                          ? Icons.movie_filter_rounded
                          : Icons.gif_box_rounded,
                      label: u.bannerMedia!.tipe == 'video' ? 'VIDEO→GIF' : 'GIF',
                    ),
                    const SizedBox(width: 6),
                    Pressable(
                      onTap: _sibukBanner ? null : _hapusBannerMedia,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(.55),
                          borderRadius: BorderRadius.circular(XyRadius.pill),
                        ),
                        child: const Row(children: [
                          Icon(Icons.delete_outline_rounded,
                              size: 13, color: Colors.white),
                          SizedBox(width: 4),
                          Text('Hapus',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700)),
                        ]),
                      ),
                    ),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 10),
          ],
          SizedBox(
            height: 58,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: XyBannerTema.peta.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final id = XyBannerTema.peta.keys.elementAt(i);
                final warna = XyBannerTema.peta[id]!;
                final pilih = _banner == id;
                return GestureDetector(
                  onTap: () => setState(() => _banner = id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: 92,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(XyRadius.sm),
                      border: Border.all(
                        color: pilih ? XyTheme.primary : Colors.transparent,
                        width: 2.4,
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(XyRadius.sm - 4),
                        gradient: LinearGradient(
                          colors: warna,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      alignment: Alignment.bottomLeft,
                      padding: const EdgeInsets.all(6),
                      child: Row(children: [
                        Text(XyBannerTema.label[id] ?? id,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700)),
                        const Spacer(),
                        if (pilih)
                          const Icon(Icons.check_circle_rounded,
                              size: 14, color: Colors.white),
                      ]),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          // Banner bergerak: GIF / MP4→GIF (khusus langganan).
          XyCard(
            padding: const EdgeInsets.all(15),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: XyTheme.plum.withOpacity(.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.auto_awesome_motion_rounded,
                      size: 19, color: XyTheme.plum),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Text('Banner Bergerak',
                            style: TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 13.5)),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            gradient: XyTheme.gradGold,
                            borderRadius:
                                BorderRadius.circular(XyRadius.pill),
                          ),
                          child: const Text('PRO/VIP',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: .8)),
                        ),
                      ]),
                      const SizedBox(height: 2),
                      Text(
                          'Pakai GIF, atau MP4 yang otomatis diconvert jadi GIF.',
                          style: TextStyle(
                              color: t.muted, fontSize: 11.3, height: 1.4)),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              if (!langganan)
                Row(children: [
                  Icon(Icons.lock_outline_rounded, size: 15, color: t.muted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Khusus pelanggan Pro & VIP. Belanja Rp300.000 untuk naik ke Pro.',
                      style: TextStyle(color: t.muted, fontSize: 11),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.push(
                        context, xyRoute(const TierScreen())),
                    child: const Text('Lihat Tier',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ])
              else
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _sibukBanner ? null : () => _unggahBanner(video: false),
                      icon: const Icon(Icons.gif_box_rounded, size: 17),
                      label: const Text('Dari GIF',
                          style: TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GradientButton(
                      label: 'Dari Video',
                      icon: Icons.movie_rounded,
                      height: 46,
                      loading: _sibukBanner,
                      onPressed: _sibukBanner ? null : () => _unggahBanner(video: true),
                    ),
                  ),
                ]),
            ]),
          ),
          // Progres unggah banner: progress bar + persen + tahap (jelas).
          if (_progresBanner != null || _konversiBanner) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(XyRadius.pill),
              child: LinearProgressIndicator(
                // Fase konversi: indeterminat (value null) + penghitung detik.
                value: _konversiBanner ? null : _progresBanner,
                minHeight: 8,
                backgroundColor: t.lineSoft,
                valueColor: const AlwaysStoppedAnimation<Color>(XyTheme.primary),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(_tahapBanner,
                      style: TextStyle(color: t.muted, fontSize: 11.5)),
                ),
                Text(
                    _konversiBanner
                        ? '${_detikKonversi} dtk'
                        : '${(_progresBanner! * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: XyTheme.primary,
                        fontSize: 12)),
              ],
            ),
          ],
          const SizedBox(height: 10),
          ],

          if (widget.fokus == FokusProfil.identitas) ...[
          Text('Nomor WhatsApp dipakai admin untuk menghubungimu soal pesanan.',
              style: TextStyle(color: t.muted, fontSize: 12, height: 1.5)),
          if (u?.email != null) ...[
            const SizedBox(height: 18),
            const XyLabel('Email'),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              decoration: BoxDecoration(
                color: t.lineSoft,
                borderRadius: BorderRadius.circular(XyRadius.md),
              ),
              child: Row(children: [
                Icon(Icons.mail_outline_rounded, size: 19, color: t.muted),
                const SizedBox(width: 12),
                Expanded(child: Text(u!.email, style: const TextStyle(fontWeight: FontWeight.w600))),
                const Icon(Icons.verified_rounded, size: 17, color: XyTheme.success),
              ]),
            ),
            const SizedBox(height: 6),
            Text('Email tidak bisa diubah sendiri. Hubungi admin kalau perlu diganti.',
                style: TextStyle(color: t.muted, fontSize: 11.5)),
          ],
          ],
          if (pesan != null) ...[
            const SizedBox(height: 16),
            _KotakGalat(pesan!),
          ],
          const SizedBox(height: 24),
          GradientButton(
            label: _labelSimpan,
            icon: Icons.check_rounded,
            loading: proses,
            onPressed: _simpan,
          ),
        ],
      ),
    );
  }
}

class _PillBanner extends StatelessWidget {
  const _PillBanner({required this.ikon, required this.label});
  final IconData ikon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(.55),
          borderRadius: BorderRadius.circular(XyRadius.pill),
        ),
        child: Row(children: [
          Icon(ikon, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .5)),
        ]),
      );
}

// ============================================================
//  Keamanan
// ============================================================
class KeamananScreen extends StatefulWidget {
  const KeamananScreen({super.key});

  @override
  State<KeamananScreen> createState() => _KeamananScreenState();
}

class _KeamananScreenState extends State<KeamananScreen> {
  final _lama = TextEditingController();
  final _baru = TextEditingController();
  final _ulang = TextEditingController();
  bool lihat = false;
  bool proses = false;
  String? pesan;
  bool _bioSibuk = false;
  String? _bioGalat;

  @override
  void dispose() {
    _lama.dispose();
    _baru.dispose();
    _ulang.dispose();
    super.dispose();
  }

  /// Toggle "login sidik jari/wajah" (Batch I). Menyalakan selalu meminta
  /// verifikasi biometrik lebih dulu supaya tidak diaktifkan diam-diam.
  Future<void> _toggleBiometrik(bool v) async {
    if (_bioSibuk) return;
    if (v) {
      final ada = await Biometrik.tersedia();
      if (!ada) {
        setState(() => _bioGalat =
            'Perangkat ini belum punya sidik jari/wajah (atau kunci layar) yang terdaftar. Daftarkan dulu di pengaturan Android.');
        return;
      }
      final ok = await Biometrik.autentikasi(
          alasan: 'Verifikasi untuk mengaktifkan login sidik jari XyCloudStore');
      if (!ok) {
        setState(() => _bioGalat = 'Verifikasi gagal/dibatalkan. Coba lagi.');
        return;
      }
      setState(() => _bioGalat = null);
      await context.read<AppState>().setelKunciBiometrik(true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Passkey aktif! Mulai sekarang app dibuka dengan sidik jari/wajah.')));
      }
    } else {
      final yakin = await konfirmasi(
        context,
        judul: 'Matikan login sidik jari?',
        pesan: 'Aplikasi akan terbuka langsung tanpa verifikasi biometrik.',
        tombolYa: 'Matikan',
        ikon: Icons.fingerprint_rounded,
      );
      if (!yakin) return;
      await context.read<AppState>().setelKunciBiometrik(false);
      setState(() => _bioGalat = null);
    }
  }

  Future<void> _simpan() async {
    if (_baru.text.length < 8 || _baru.text.length > 128) {
      setState(() => pesan = 'Password baru harus 8–128 karakter');
      return;
    }
    if (_baru.text != _ulang.text) {
      setState(() => pesan = 'Ulangi password belum sama');
      return;
    }
    setState(() {
      proses = true;
      pesan = null;
    });
    final galat = await context.read<AppState>().gantiPassword(_lama.text, _baru.text);
    if (!mounted) return;
    setState(() {
      proses = false;
      pesan = galat;
    });
    if (galat == null) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password berhasil diganti.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Keamanan')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
        children: [
          XyCard(
            child: Row(children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: XyTheme.success.withOpacity(.10), shape: BoxShape.circle),
                child: Icon(Icons.shield_rounded, color: XyTheme.success, size: 21),
              ),
              const SizedBox(width: 13),
               Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Akunmu terlindungi', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  SizedBox(height: 3),
                  Text('Password disimpan terenkripsi dan sesi otomatis kedaluwarsa 30 hari.',
                      style: TextStyle(color: XyTheme.of(context).muted, fontSize: 11.8, height: 1.45)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          // ---------- passkey / sidik jari + PIN transfer (Batch I) ----------
          XyCard(
            padding: const EdgeInsets.all(15),
            child: Column(children: [
              Row(children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: XyTheme.violet.withOpacity(.12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(Icons.fingerprint_rounded,
                      color: XyTheme.violet, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Login Sidik Jari / Wajah',
                            style: TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 13.5)),
                        const SizedBox(height: 2),
                        Text(
                            'Passkey perangkat ini — buka aplikasi tanpa mengetik password.',
                            style: TextStyle(
                                color: XyTheme.of(context).muted,
                                fontSize: 11.3,
                                height: 1.4)),
                      ]),
                ),
                Switch(
                  value: st.kunciBiometrikAktif,
                  onChanged: _bioSibuk ? null : _toggleBiometrik,
                ),
              ]),
              if (_bioGalat != null) ...[
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 14, color: XyTheme.warning),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(_bioGalat!,
                        style: const TextStyle(
                            color: XyTheme.warning,
                            fontSize: 11.5,
                            height: 1.4,
                            fontWeight: FontWeight.w600)),
                  ),
                ]),
              ],
              const SizedBox(height: 6),
              Divider(color: XyTheme.of(context).line),
              const SizedBox(height: 6),
              Pressable(
                onTap: () => bukaSetPin(context),
                child: Row(children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: XyTheme.goldSoft.withOpacity(.14),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(Icons.pin_rounded,
                        color: XyTheme.goldMid, size: 21),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('PIN Transfer Saldo',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13.5)),
                          const SizedBox(height: 2),
                          Text(
                              st.user?.pinTransferAktif == true
                                  ? 'Sudah dipasang — dipakai saat kirim saldo.'
                                  : 'Belum dipasang. Wajib untuk kirim saldo antar teman.',
                              style: TextStyle(
                                  color: XyTheme.of(context).muted,
                                  fontSize: 11.3,
                                  height: 1.4)),
                        ]),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      color: XyTheme.of(context).muted),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 22),
          const Text('Ganti Password',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, letterSpacing: -.3)),
          const SizedBox(height: 4),
           Text('Kosongkan password lama kalau kamu mendaftar lewat Google.',
              style: TextStyle(color: XyTheme.of(context).muted, fontSize: 12.5, height: 1.5)),
          const SizedBox(height: 18),
          Text('Setelah password disimpan, semua sesi dicabut dan kamu perlu masuk lagi.',style:TextStyle(color:XyTheme.of(context).muted,height:1.5)),
          TextButton(onPressed:()async{final e=await context.read<AppState>().kodePasswordSosial();if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e??'Kode dikirim. Masukkan pada kolom password lama.')));},child:const Text('Akun Google tanpa password? Kirim kode email')),
          const XyLabel('Password Lama'),
          TextField(
            controller: _lama,
            obscureText: !lihat,
            decoration: InputDecoration(
              hintText: 'Password sekarang',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                icon: Icon(lihat ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                onPressed: () => setState(() => lihat = !lihat),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const XyLabel('Password Baru'),
          TextField(
            controller: _baru,
            obscureText: !lihat,
            decoration: const InputDecoration(
              hintText: '8–128 karakter',
              prefixIcon: Icon(Icons.lock_reset_rounded),
            ),
          ),
          const SizedBox(height: 18),
          const XyLabel('Ulangi Password Baru'),
          TextField(
            controller: _ulang,
            obscureText: !lihat,
            decoration: const InputDecoration(
              hintText: 'Ketik ulang password baru',
              prefixIcon: Icon(Icons.lock_reset_rounded),
            ),
          ),
          if (pesan != null) ...[
            const SizedBox(height: 16),
            _KotakGalat(pesan!),
          ],
          const SizedBox(height: 24),
          GradientButton(label: 'Simpan Password', icon: Icons.check_rounded, loading: proses, onPressed: _simpan),

          const SizedBox(height: 34),
          const Text('Zona Berbahaya',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: XyTheme.danger)),
          const SizedBox(height: 10),
          XyCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
               Text(
                'Menghapus akun akan menghilangkan profil, riwayat chat, diskusi, ulasan, dan pemberitahuanmu '
                'secara permanen. Riwayat pembayaran disamarkan untuk keperluan pembukuan. '
                'Pastikan saldomu sudah habis sebelum menghapus.',
                style: TextStyle(color: XyTheme.of(context).muted, fontSize: 12.5, height: 1.6),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () => _hapusAkun(context),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: XyTheme.danger)),
                  icon: Icon(Icons.delete_forever_rounded, size: 18, color: XyTheme.danger),
                  label: const Text('Hapus Akun Saya',
                      style: TextStyle(color: XyTheme.danger, fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Future<void> _hapusAkun(BuildContext context) async {
    await Navigator.push(context, xyRoute(const HapusAkunScreen()));
  }

}

// ============================================================
//  Notifikasi
// ============================================================
class PengaturanNotifikasiScreen extends StatefulWidget {
  const PengaturanNotifikasiScreen({super.key});

  @override
  State<PengaturanNotifikasiScreen> createState() =>
      _PengaturanNotifikasiScreenState();
}

class _PengaturanNotifikasiScreenState extends State<PengaturanNotifikasiScreen> {
  List<BisukanItem> _bisu = [];
  bool _muatBisu = true;

  @override
  void initState() {
    super.initState();
    _muatBisuDaftar();
  }

  Future<void> _muatBisuDaftar() async {
    try {
      final daftar = await context.read<AppState>().repo.bisukanDaftar();
      if (mounted) {
        setState(() {
          _bisu = daftar;
          _muatBisu = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _muatBisu = false);
    }
  }

  Future<void> _nyalakanLagi(String thread) async {
    setState(() => _bisu = _bisu.where((b) => b.thread != thread).toList());
    try {
      await context.read<AppState>().repo.bisukan(thread, 0);
    } catch (_) {}
  }

  String _labelThread(String thread) {
    if (thread == 'cs') return 'Chat CS';
    if (thread.startsWith('dm:')) return 'Pesan langsung';
    if (thread.startsWith('forum:')) return 'Balasan diskusi';
    return thread;
  }

  String _sisaBisu(int sampai) {
    final sisa = sampai - DateTime.now().millisecondsSinceEpoch;
    if (sisa <= 0) return 'selesai';
    final menit = (sisa / 60000).ceil();
    return menit < 60 ? '$menit menit lagi' : '${(menit / 60).floor()} jam lagi';
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final u = s.user;

    return Scaffold(
      appBar: AppBar(title: const Text('Notifikasi')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
        children: [
          Center(child: XyIlustrasi('notifikasi', tinggi: 150)),
          const SizedBox(height: 16),
          XyCard(
            padding: const EdgeInsets.fromLTRB(15, 6, 8, 6),
            child: Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: XyTheme.of(context).primarySoft, borderRadius: BorderRadius.circular(14)),
                child: Icon(Icons.groups_2_outlined, size: 20, color: XyTheme.primary),
              ),
              const SizedBox(width: 13),
               Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Komunitas', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  SizedBox(height: 3),
                  Text('Balasan diskusi, suka, dan pengumuman admin',
                      style: TextStyle(color: XyTheme.of(context).muted, fontSize: 11.5, height: 1.4)),
                ]),
              ),
              Switch(
                value: u?.notifForum ?? true,
                activeColor: XyTheme.primary,
                onChanged: (v) async {
                  final galat = await s.perbaruiProfil(notifForum: v);
                  if (galat != null && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(galat)));
                  }
                },
              ),
            ]),
          ),
          const SizedBox(height: 12),
          XyCard(
            padding: const EdgeInsets.fromLTRB(15, 6, 8, 6),
            child: Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: XyTheme.of(context).primarySoft, borderRadius: BorderRadius.circular(14)),
                child: Icon(Icons.live_tv_rounded, size: 20, color: XyTheme.primary),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('XyCloud Live', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  SizedBox(height: 3),
                  Text('Kabar saat kreator yang kamu ikuti mulai live',
                      style: TextStyle(color: XyTheme.of(context).muted, fontSize: 11.5, height: 1.4)),
                ]),
              ),
              Switch(
                value: u?.notifLive ?? true,
                activeColor: XyTheme.primary,
                onChanged: (v) async {
                  final galat = await s.perbaruiProfil(notifLive: v);
                  if (galat != null && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(galat)));
                  }
                },
              ),
            ]),
          ),
          const SizedBox(height: 12),
          XyCard(
            padding: const EdgeInsets.fromLTRB(15, 6, 8, 6),
            child: Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: XyTheme.of(context).primarySoft, borderRadius: BorderRadius.circular(14)),
                child: Icon(Icons.chat_bubble_outline_rounded, size: 20, color: XyTheme.primary),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Pesan Langsung', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  SizedBox(height: 3),
                  Text('Pesan pribadi dari pengguna lain: teks, gambar, dan suara',
                      style: TextStyle(color: XyTheme.of(context).muted, fontSize: 11.5, height: 1.4)),
                ]),
              ),
              Switch(
                value: u?.notifDm ?? true,
                activeColor: XyTheme.primary,
                onChanged: (v) async {
                  final galat = await s.perbaruiProfil(notifDm: v);
                  if (galat != null && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(galat)));
                  }
                },
              ),
            ]),
          ),
          const SizedBox(height: 12),
          XyCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.volume_off_rounded, size: 18, color: XyTheme.of(context).muted),
                SizedBox(width: 9),
                Text('Sedang dibisukan', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                Spacer(),
                if (_muatBisu)
                  SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: XyTheme.primary)),
              ]),
              const SizedBox(height: 10),
              if (_bisu.isEmpty && !_muatBisu)
                Text(
                  'Tidak ada percakapan yang dibisukan. Tombol "Bisukan 1 jam" pada notifikasi akan muncul di sini supaya bisa dinyalakan lagi kapan saja.',
                  style: TextStyle(color: XyTheme.of(context).muted, fontSize: 12.5, height: 1.6),
                ),
              for (final b in _bisu)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(children: [
                    Icon(Icons.notifications_off_outlined, size: 16, color: XyTheme.of(context).muted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(_labelThread(b.thread),
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                        Text(_sisaBisu(b.sampai),
                            style: TextStyle(color: XyTheme.of(context).muted, fontSize: 11)),
                      ]),
                    ),
                    TextButton(
                      onPressed: () => _nyalakanLagi(b.thread),
                      child: const Text('Nyalakan lagi'),
                    ),
                  ]),
                ),
            ]),
          ),
          const SizedBox(height: 12),
          XyCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children:  [
                Icon(Icons.lock_clock_rounded, size: 18, color: XyTheme.of(context).muted),
                SizedBox(width: 9),
                Text('Selalu aktif', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
              ]),
              const SizedBox(height: 10),
               Text(
                'Pemberitahuan pesanan, balasan admin, dan perubahan saldo tetap dikirim karena '
                'bersifat penting. Kamu masih bisa mematikannya lewat pengaturan Android.',
                style: TextStyle(color: XyTheme.of(context).muted, fontSize: 12.5, height: 1.6),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

// ============================================================
//  Data dan penyimpanan
// ============================================================
class DataScreen extends StatefulWidget {
  const DataScreen({super.key});

  @override
  State<DataScreen> createState() => _DataScreenState();
}

class _DataScreenState extends State<DataScreen> {
  int kb = 0;
  String? _pathMedia;
  int _mediaBytes = 0;

  @override
  void initState() {
    super.initState();
    _hitung();
  }

  Future<void> _hitung() async {
    final n = await Cache.ukuranKb();
    String? path;
    var mediaBytes = 0;
    try {
      final akar = await MediaLokal.siapkan();
      path = akar.path;
      final per = await MediaLokal.ukuranPerFolder();
      per.forEach((_, v) => mediaBytes += v);
    } catch (_) {}
    if (mounted) {
      setState(() {
        kb = n;
        _pathMedia = path;
        _mediaBytes = mediaBytes;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final t = XyTheme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Data dan Penyimpanan')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
        children: [
          XyCard(
            padding: const EdgeInsets.fromLTRB(15, 6, 8, 6),
            child: Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: XyTheme.of(context).primarySoft, borderRadius: BorderRadius.circular(14)),
                child: Icon(Icons.data_saver_on_rounded, size: 20, color: XyTheme.primary),
              ),
              const SizedBox(width: 13),
               Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Mode Hemat Data', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  SizedBox(height: 3),
                  Text('Gambar produk dan komunitas tidak diunduh otomatis',
                      style: TextStyle(color: XyTheme.of(context).muted, fontSize: 11.5, height: 1.4)),
                ]),
              ),
              Switch(value: s.hematData, activeColor: XyTheme.primary, onChanged: s.setHematData),
            ]),
          ),
          const SizedBox(height: 12),
          XyCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.sd_storage_outlined, size: 19, color: XyTheme.primary),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Data tersimpan di perangkat',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                ),
                Text('$kb KB', style: const TextStyle(fontWeight: FontWeight.w700, color: XyTheme.primary)),
              ]),
              const SizedBox(height: 10),
               Text(
                'Katalog, pesanan, dan diskusi disimpan supaya aplikasi langsung terisi saat dibuka '
                'dan tetap bisa dilihat ketika sedang tanpa internet.',
                style: TextStyle(color: XyTheme.of(context).muted, fontSize: 12.5, height: 1.6),
              ),
              // Batch N: jelaskan letak folder media lokal (struktur ala WA).
              if (_pathMedia != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: t.lineSoft,
                    borderRadius: BorderRadius.circular(XyRadius.md),
                    border: Border.all(color: t.line),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(Icons.folder_rounded, size: 15, color: t.muted),
                      const SizedBox(width: 6),
                      const Text('Folder media lokal',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      const Spacer(),
                      Text('${(_mediaBytes / 1048576).toStringAsFixed(1)} MB',
                          style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: XyTheme.primary)),
                    ]),
                    const SizedBox(height: 6),
                    Text('Stiker · Video · Image · Voicenote · Document · Database '
                        '(tersembunyi dari galeri lewat .nomedia)',
                        style: TextStyle(color: t.muted, fontSize: 11, height: 1.45)),
                    const SizedBox(height: 4),
                    Text(_pathMedia!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: t.muted, fontSize: 10)),
                  ]),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                height: 46,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final yakin = await konfirmasi(
                      context,
                      judul: 'Bersihkan data tersimpan?',
                      pesan: 'Katalog offline dan cache gambar dibuang; aplikasi akan mengunduh ulang saat dibuka lagi. Akunmu tidak terpengaruh.',
                      tombolYa: 'Bersihkan',
                      ikon: Icons.cleaning_services_outlined,
                    );
                    if (!yakin) return;
                    await Cache.bersihkan();
                    try {
                      await DefaultCacheManager().emptyCache();
                    } catch (_) {}
                    PaintingBinding.instance.imageCache.clear();
                    PaintingBinding.instance.imageCache.clearLiveImages();
                    await _hitung();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Data tersimpan dan cache gambar dibersihkan.')),
                      );
                    }
                  },
                  icon: const Icon(Icons.cleaning_services_outlined, size: 18),
                  label: const Text('Bersihkan Sekarang'),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

// ============================================================
//  Privasi dan konten
// ============================================================
class PrivasiScreen extends StatefulWidget {
  const PrivasiScreen({super.key});

  @override
  State<PrivasiScreen> createState() => _PrivasiScreenState();
}

class _PrivasiScreenState extends State<PrivasiScreen> {
  bool saringan = true;

  @override
  void initState() {
    super.initState();
    Prefs.saringKonten().then((v) => mounted ? setState(() => saringan = v) : null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privasi dan Konten')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
        children: [
          XyCard(
            padding: const EdgeInsets.fromLTRB(15, 6, 8, 6),
            child: Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: XyTheme.of(context).primarySoft, borderRadius: BorderRadius.circular(14)),
                child: Icon(Icons.shield_moon_outlined, size: 20, color: XyTheme.primary),
              ),
              const SizedBox(width: 13),
               Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Saringan Konten Dewasa', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  SizedBox(height: 3),
                  Text('Gambar yang ditandai sensitif ditutup dulu, ketuk untuk melihat',
                      style: TextStyle(color: XyTheme.of(context).muted, fontSize: 11.5, height: 1.4)),
                ]),
              ),
              Switch(
                value: saringan,
                activeColor: XyTheme.primary,
                onChanged: (v) async {
                  setState(() => saringan = v);
                  await Prefs.simpanSaringKonten(v);
                },
              ),
            ]),
          ),
          const SizedBox(height: 12),
          XyCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:  [
              Row(children: [
                Icon(Icons.flag_outlined, size: 18, color: XyTheme.primary),
                SizedBox(width: 9),
                Text('Melaporkan konten', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
              ]),
              SizedBox(height: 10),
              Text(
                'Setiap diskusi dan komentar punya tombol Laporkan. Pilih alasannya, admin akan meninjau '
                'lalu menandai konten sebagai sensitif atau menghapusnya. Kami tidak memblokir gambar secara '
                'membabi buta supaya diskusi tetap hidup.',
                style: TextStyle(color: XyTheme.of(context).muted, fontSize: 12.5, height: 1.6),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          XyCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: const [
                Icon(Icons.download_for_offline_outlined, size: 18, color: XyTheme.primary),
                SizedBox(width: 9),
                Text('Unduh dataku', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
              ]),
              const SizedBox(height: 10),
               Text(
                'Ambil seluruh data yang kami simpan tentangmu: profil, pesanan, transaksi, '
                'percakapan, diskusi, dan ulasan. Hasilnya disalin ke papan klip dalam bentuk JSON.',
                style: TextStyle(color: XyTheme.of(context).muted, fontSize: 12.5, height: 1.6),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 46,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Mengumpulkan datamu...'), duration: Duration(seconds: 1)),
                    );
                    final data = await context.read<AppState>().dataSaya();
                    if (!context.mounted) return;
                    if (data == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Gagal mengambil data, coba lagi.')),
                      );
                      return;
                    }
                    final teks = const JsonEncoder.withIndent('  ').convert(data);
                    await Clipboard.setData(ClipboardData(text: teks));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Data disalin, ${(teks.length / 1024).ceil()} KB. '
                          'Tempel ke aplikasi catatan untuk menyimpannya.')),
                    );
                  },
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text('Ambil Data Saya'),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          XyCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:  [
              Row(children: [
                Icon(Icons.privacy_tip_outlined, size: 18, color: XyTheme.primary),
                SizedBox(width: 9),
                Text('Data yang kami simpan', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
              ]),
              SizedBox(height: 10),
              Text(
                'Nama, email, nomor WhatsApp, riwayat pesanan, dan percakapan dengan admin. '
                'Kami tidak pernah menjual data dan tidak memasang pelacak pihak ketiga.',
                style: TextStyle(color: XyTheme.of(context).muted, fontSize: 12.5, height: 1.6),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

// ============================================================
//  Pusat bantuan
// ============================================================
// ============================================================
//  Tema tampilan
// ============================================================
class TemaScreen extends StatefulWidget {
  const TemaScreen({super.key});

  @override
  State<TemaScreen> createState() => _TemaScreenState();
}

class _TemaScreenState extends State<TemaScreen> {
  String pilihan = 'sistem';

  @override
  void initState() {
    super.initState();
    Prefs.tema().then((v) => mounted ? setState(() => pilihan = v) : null);
  }

  @override
  Widget build(BuildContext context) {
    const opsi = [
      ('sistem', 'Ikut Sistem', 'Mengikuti pengaturan gelap atau terang di HP', Icons.brightness_auto_rounded),
      ('terang', 'Terang', 'Latar putih keunguan, nyaman di siang hari', Icons.light_mode_rounded),
      ('gelap', 'Gelap', 'Latar ungu tua, enak dipakai malam hari', Icons.dark_mode_rounded),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Tema Aplikasi')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
        children: opsi.map((o) {
          final aktif = o.$1 == pilihan;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: XyCard(
              padding: const EdgeInsets.all(16),
              onTap: () async {
                setState(() => pilihan = o.$1);
                await context.read<AppState>().setTema(o.$1);
              },
              child: Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: aktif ? XyTheme.primary : XyTheme.of(context).primarySoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(o.$4, size: 21, color: aktif ? Colors.white : XyTheme.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(o.$2, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                    const SizedBox(height: 3),
                    Text(o.$3, style:  TextStyle(color: XyTheme.of(context).muted, fontSize: 11.8, height: 1.4)),
                  ]),
                ),
                Icon(aktif ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                    color: aktif ? XyTheme.primary : XyTheme.of(context).line),
              ]),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ============================================================
//  Cek pembaruan aplikasi
// ============================================================
// ============================================================
//  Potongan kecil
// ============================================================

class _KotakGalat extends StatelessWidget {
  const _KotakGalat(this.pesan);
  final String pesan;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: XyTheme.danger.withOpacity(.07),
          borderRadius: BorderRadius.circular(XyRadius.sm),
          border: Border.all(color: XyTheme.danger.withOpacity(.22)),
        ),
        child: Row(children: [
          Icon(Icons.error_outline_rounded, size: 18, color: XyTheme.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(pesan,
                style: const TextStyle(color: XyTheme.danger, fontSize: 12.5, fontWeight: FontWeight.w600)),
          ),
        ]),
      );
}

/// Dipakai halaman lain untuk menyalin teks singkat.
Future<void> salinTeks(BuildContext context, String teks, String label) async {
  await Clipboard.setData(ClipboardData(text: teks));
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label disalin'), duration: const Duration(seconds: 1)),
    );
  }
}


/// Mode privasi: FLAG_SECURE Android — tangkapan layar dan perekaman
/// layar menghasilkan hitam, pratinjau di daftar aplikasi baru disembunyikan.
/// Diterapkan instan lewat channel native (tools/siapkan_keamanan.py).
class ModePrivasiScreen extends StatefulWidget {
  const ModePrivasiScreen({super.key});

  @override
  State<ModePrivasiScreen> createState() => _ModePrivasiScreenState();
}

class _ModePrivasiScreenState extends State<ModePrivasiScreen> {
  bool aktif = false;
  bool siap = false;

  @override
  void initState() {
    super.initState();
    Prefs.modePrivasi().then((v) {
      if (mounted) {
        setState(() {
          aktif = v;
          siap = true;
        });
      }
    });
  }

  Future<void> _setel(bool v) async {
    setState(() => aktif = v);
    HapticFeedback.lightImpact();
    await Prefs.simpanModePrivasi(v);
    await Keamanan.setelPrivasi(v);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(v
            ? 'Mode privasi aktif — screenshot & rekaman layar diblokir.'
            : 'Mode privasi dimatikan.')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mode Privasi')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
        children: [
          XyCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      gradient: XyTheme.gradPrimary,
                      borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.screenshot_monitor_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                    child: Text('Anti Screenshot & Rekaman Layar',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14.5))),
              ]),
              const SizedBox(height: 10),
              Text(
                'Saat aktif, jendela aplikasi ditandai aman oleh Android '
                '(FLAG_SECURE): tangkapan layar dan perekaman layar menghasilkan '
                'gambar hitam, dan pratinjau di daftar aplikasi baru disembunyikan. '
                'Cocok untuk menjaga saldo, chat, dan kredensial akunmu.',
                style: TextStyle(
                    color: XyTheme.of(context).muted, fontSize: 12.8, height: 1.6),
              ),
              const SizedBox(height: 4),
              SwitchListTile(
                value: aktif,
                onChanged: siap ? _setel : null,
                contentPadding: EdgeInsets.zero,
                title: const Text('Mode Privasi',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                subtitle: Text(
                    aktif ? 'Aktif — layar dilindungi' : 'Nonaktif',
                    style: TextStyle(
                        color: XyTheme.of(context).muted, fontSize: 11.5)),
              ),
            ]),
          ),
          const SizedBox(height: 14),
              Text(
                  'Catatan: perlindungan diterapkan instan tanpa perlu memulai ulang aplikasi.',
                  style: TextStyle(color: XyTheme.of(context).muted, fontSize: 11.5)),
            ],
          ),
        );
      }
    }

/// Layar pengaturan preferensi chat, DM, dan feed komunitas
class PengaturanChatScreen extends StatefulWidget {
  const PengaturanChatScreen({super.key});

  @override
  State<PengaturanChatScreen> createState() => _PengaturanChatScreenState();
}

class _PengaturanChatScreenState extends State<PengaturanChatScreen> {
  Future<void> _set(String key, dynamic value) async {
    await PengaturanLokal.set(key, value);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final p = PengaturanLokal.nilai;
    final t = XyTheme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Komunitas & Percakapan')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
        children: [
          const _Judul('Pesan Langsung (DM)'),
          XyCard(
            child: Column(
              children: [
                SwitchListTile(
                  value: p['dm_hanya_teman'] != true,
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.people_alt_outlined, color: XyTheme.primary),
                  title: const Text('Terima DM dari Semua Orang', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                  subtitle: Text(
                    p['dm_hanya_teman'] == true
                        ? 'Hanya pengguna yang kamu ikuti yang dapat mengirimkan DM.'
                        : 'Siapa saja di komunitas dapat mengirimkan pesan ke akunmu.',
                    style: TextStyle(color: t.muted, fontSize: 11.5),
                  ),
                  onChanged: (v) => _set('dm_hanya_teman', !v),
                ),
                const Divider(),
                SwitchListTile(
                  value: p['tanda_dibaca'] != false,
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.done_all_rounded, color: XyTheme.primary),
                  title: const Text('Kirim Tanda Dibaca', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                  subtitle: Text(
                    'Pengirim akan tahu saat kamu sudah membuka dan membaca pesan mereka.',
                    style: TextStyle(color: t.muted, fontSize: 11.5),
                  ),
                  onChanged: (v) => _set('tanda_dibaca', v),
                ),
                const Divider(),
                SwitchListTile(
                  value: p['notif_dm_popup'] != false,
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.mark_chat_unread_outlined, color: XyTheme.primary),
                  title: const Text('Notifikasi Suara Pesan Baru', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                  subtitle: Text(
                    'Bunyikan nada saat ada pesan obrolan atau balasan komentar baru.',
                    style: TextStyle(color: t.muted, fontSize: 11.5),
                  ),
                  onChanged: (v) => _set('notif_dm_popup', v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _Judul('Feed & Media Komunitas'),
          XyCard(
            child: Column(
              children: [
                SwitchListTile(
                  value: p['filter_konten_aman'] != false,
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.shield_outlined, color: XyTheme.primary),
                  title: const Text('Sensor Kata Kurang Pantas', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                  subtitle: Text(
                    'Secara otomatis menyamarkan kata kasar di feed dan komentar publik.',
                    style: TextStyle(color: t.muted, fontSize: 11.5),
                  ),
                  onChanged: (v) => _set('filter_konten_aman', v),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Layar pengaturan suara efek dan getaran haptic aplikasi
class SuaraGetaranScreen extends StatefulWidget {
  const SuaraGetaranScreen({super.key});

  @override
  State<SuaraGetaranScreen> createState() => _SuaraGetaranScreenState();
}

class _SuaraGetaranScreenState extends State<SuaraGetaranScreen> {
  Future<void> _set(String key, dynamic value) async {
    await PengaturanLokal.set(key, value);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final p = PengaturanLokal.nilai;
    final t = XyTheme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Suara & Getaran')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
        children: [
          const _Judul('Audio Aplikasi'),
          XyCard(
            child: Column(
              children: [
                SwitchListTile(
                  value: p['suara_efek'] != false,
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.volume_up_outlined, color: XyTheme.primary),
                  title: const Text('Efek Suara Tombol', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                  subtitle: Text(
                    'Bunyi klik halus saat menekan tombol utama dan konfirmasi.',
                    style: TextStyle(color: t.muted, fontSize: 11.5),
                  ),
                  onChanged: (v) => _set('suara_efek', v),
                ),
                const Divider(),
                SwitchListTile(
                  value: p['suara_transaksi'] != false,
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.account_balance_wallet_outlined, color: XyTheme.primary),
                  title: const Text('Suara Transaksi Sukses', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                  subtitle: Text(
                    'Mainkan notifikasi audio saat pembayaran atau topup saldo berhasil.',
                    style: TextStyle(color: t.muted, fontSize: 11.5),
                  ),
                  onChanged: (v) => _set('suara_transaksi', v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _Judul('Getaran Haptic'),
          XyCard(
            child: Column(
              children: [
                SwitchListTile(
                  value: p['haptic_global'] != false,
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.vibration_rounded, color: XyTheme.primary),
                  title: const Text('Getaran Sentuh (Haptic Feedback)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                  subtitle: Text(
                    'Umpan balik getar responsif saat mengetuk elemen interaktif.',
                    style: TextStyle(color: t.muted, fontSize: 11.5),
                  ),
                  onChanged: (v) => _set('haptic_global', v),
                ),
                const Divider(),
                SwitchListTile(
                  value: p['vibration_hud'] != false,
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.sports_esports_outlined, color: XyTheme.primary),
                  title: const Text('Getaran HUD & Tombol Streaming', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                  subtitle: Text(
                    'Sensasi taktil saat menekan tombol HUD game di layar streaming.',
                    style: TextStyle(color: t.muted, fontSize: 11.5),
                  ),
                  onChanged: (v) => _set('vibration_hud', v),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
