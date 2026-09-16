import 'hapus_akun_screen.dart';
import 'voucher_screen.dart';
import 'leaderboard_screen.dart';
import 'live_unit_screen.dart';
import 'bantuan_screen.dart';
import 'pembaruan_screen.dart';
import 'favorit_screen.dart';
import 'follows_screen.dart';
import 'profil_publik_screen.dart';
import 'statistik_screen.dart';
import 'tier_screen.dart';
import 'aktivitas_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/format.dart';
import '../../core/kompres.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../providers/app_state.dart';
import '../widgets/banner_profil.dart';
import '../widgets/gaya_nama.dart';
import '../widgets/bingkai_profil.dart';
import '../widgets/common.dart';
import '../widgets/galeri_picker.dart';
import '../widgets/lembar.dart';
import 'order_list_screen.dart';
import 'pengaturan_screen.dart' as pengaturan;
import 'referral_screen.dart';
import 'tentang_screen.dart';
import 'wallet_screen.dart';

/// ============================================================
///  Profil pengguna: identitas, ringkasan, dan pengaturan
/// ============================================================
class ProfilScreen extends StatefulWidget {
  const ProfilScreen({super.key});

  @override
  State<ProfilScreen> createState() => _ProfilScreenState();
}

class _ProfilScreenState extends State<ProfilScreen> {
  Future<void> _gantiFoto() async {
    // Batch I: galeri kustom (photo_manager) dulu; izin ditolak → picker sistem.
    final f = await GaleriPicker.pilihGambar(context, judul: 'Pilih Foto Profil');
    if (f == null || !mounted) return;
    final bytes = await f.readAsBytes();
    // Foto profil cukup kecil — kompres lebih agresif.
    final nama = f.uri.pathSegments.isNotEmpty ? f.uri.pathSegments.last : 'foto.jpg';
    final fotoUri = await Kompres.dataUri(bytes, nama, maxSisi: 700, kualitas: 78);
    if (!mounted) return;

    final s = context.read<AppState>();
    final galat = await s.perbaruiProfil(foto: fotoUri);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(galat ?? 'Foto profil diperbarui.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final u = s.user;
    if (u == null) return const SizedBox.shrink();

    final jumlahOrder = s.orders.length;
    final jumlahAktif = s.orders.where((o) => o.status.name == 'aktif').length;

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // ---------- kepala (Batch I: banner bisa GIF/video + bingkai avatar) ----------
          BannerProfil(
            tema: u.banner,
            media: u.bannerMedia,
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
            child: Padding(
            padding: EdgeInsets.fromLTRB(22, MediaQuery.of(context).padding.top + 22, 22, 26),
            child: Stack(children: [
              Column(children: [
              Row(children: [
                Stack(children: [
                  // Foto polos tanpa latar bulat — hanya inisial yang
                  // memakai wadah gradien ketika belum ada foto.
                  AvatarBingkai(
                    bingkai: u.bingkai,
                    size: 72,
                    child: ClipOval(
                      child: (u.foto ?? '').isNotEmpty
                          ? Image.network(
                              u.foto!,
                              width: 72,
                              height: 72,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _WadahInisial(u.nama),
                            )
                          : _WadahInisial(u.nama),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Pressable(
                      onTap: _gantiFoto,
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: XyTheme.shadowSm,
                        ),
                        child: Icon(Icons.camera_alt_rounded, size: 14, color: XyTheme.primary),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // Urutan rapi: nama → display name (@username) → slogan
                    // → email → bio. Dulu display name nyelip di bawah email.
                    GayaNama(u.nama,
                        gaya: u.gayaNama,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700, fontSize: 19, letterSpacing: -.5)),
                    if ((u.username ?? '').isNotEmpty)
                      Text('@${u.username}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Color(0xFFC4B5FD),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: .2)),
                    // Batch L: slogan tampil persis di bawah nama.
                    if ((u.slogan ?? '').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text('“${u.slogan}”',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: Colors.white.withOpacity(.85),
                                fontSize: 11.5,
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.w600)),
                      ),
                    const SizedBox(height: 4),
                    Text(u.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white.withOpacity(.62), fontSize: 12.5)),
                    if ((u.bio ?? '').isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(u.bio!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: Colors.white.withOpacity(.82),
                              fontSize: 12,
                              height: 1.4)),
                    ],
                    const SizedBox(height: 8),
                    Wrap(spacing: 7, runSpacing: 6, children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(.16),
                          borderRadius: BorderRadius.circular(XyRadius.pill),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.workspace_premium_rounded, size: 13, color: XyTheme.goldSoft),
                          const SizedBox(width: 5),
                          Text('Member ${u.tier.toUpperCase()}',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: .4)),
                        ]),
                      ),
                      if (u.badge != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(XyRadius.pill),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.verified_rounded, size: 13, color: XyTheme.primary),
                            const SizedBox(width: 5),
                            Text(u.badge!.toUpperCase(),
                                style: const TextStyle(
                                    color: XyTheme.primary,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: .4)),
                          ]),
                        ),
                    ]),
                  ]),
                ),
              ]),
              const SizedBox(height: 22),
              Row(children: [
                _Statistik('Saldo', rupiah(u.saldo)),
                _Pemisah(),
                _Statistik('Order', '$jumlahOrder'),
                _Pemisah(),
                _Statistik('Aktif', '$jumlahAktif'),
              ]),
            ]),
              // Pensil edit profil di pojok kanan atas header.
              Positioned(
                top: 0,
                right: 0,
                child: Pressable(
                  onTap: () => Navigator.push(context,
                      xyRoute(const pengaturan.UbahProfilScreen())),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.18),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(.32)),
                    ),
                    child: const Icon(Icons.edit_rounded,
                        size: 18, color: Colors.white),
                  ),
                ),
              ),
            ]),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
            child: Column(children: [
              // Pemberitahuan kini ada di tombol lonceng pada bar atas beranda,
              // supaya selalu terlihat dan cepat dijangkau dari mana pun.

              // ---------- grup Akun ----------
              const SectionHeader('Akun'),
              XyBarisMenu(
                ikon: Icons.badge_outlined,
                judul: 'Identitas Profil',
                sub: 'Nama, username, WhatsApp, bio, foto, dan tautan',
                onTap: () => Navigator.push(context,
                    xyRoute(const pengaturan.UbahProfilScreen())),
              ),
              XyBarisMenu(
                ikon: Icons.auto_awesome_rounded,
                judul: 'Kustomisasi Profil',
                sub: 'Badge, bingkai, lencana, style nama, banner, dan tema',
                onTap: () => Navigator.push(context,
                    xyRoute(const pengaturan.KustomProfilScreen())),
              ),
              XyBarisMenu(
                ikon: Icons.language_rounded,
                judul: 'Profil Publik',
                sub: 'Tampilan profilmu di mata pengguna lain',
                onTap: () => Navigator.push(context, xyRoute(ProfilPublikScreen(userId: u.id))),
              ),
              XyBarisMenu(
                ikon: Icons.lock_outline_rounded,
                judul: 'Keamanan',
                sub: 'Ganti password dan info sesi',
                onTap: () => Navigator.push(context, xyRoute(const pengaturan.KeamananScreen())),
              ),
              XyBarisMenu(
                ikon: Icons.security_rounded,
                judul: 'Aktivitas & Keamanan',
                sub: 'Perangkat, riwayat login, anti-abuse',
                onTap: () => Navigator.push(context, xyRoute(const AktivitasScreen())),
              ),

              // ---------- grup Komunitas ----------
              const SectionHeader('Komunitas'),
              XyBarisMenu(
                ikon: Icons.forum_outlined,
                judul: 'Mengikuti & Pesan',
                sub: 'Teman yang diikuti, pengikut, dan pesan langsung',
                onTap: () => Navigator.push(context, xyRoute(const FollowsScreen())),
              ),
              XyBarisMenu(
                ikon: Icons.leaderboard_rounded,
                judul: 'Leaderboard',
                sub: 'Top spender & poin',
                onTap: () => Navigator.push(context, xyRoute(const LeaderboardScreen())),
              ),
              XyBarisMenu(
                ikon: Icons.diamond_outlined,
                judul: 'Tier & Benefit',
                sub: 'Bronze → Platinum benefit',
                onTap: () => Navigator.push(context, xyRoute(const TierScreen())),
              ),

              // ---------- grup Transaksi ----------
              const SectionHeader('Transaksi'),
              XyBarisMenu(
                ikon: Icons.account_balance_wallet_outlined,
                judul: 'Dompet dan Riwayat',
                sub: 'Saldo ${rupiah(u.saldo)}',
                onTap: () => Navigator.push(context, xyRoute(const WalletScreen())),
              ),
              XyBarisMenu(
                ikon: Icons.receipt_long_outlined,
                judul: 'Pesanan Saya',
                sub: '$jumlahOrder pesanan tercatat',
                onTap: () => Navigator.push(context, xyRoute(const OrderListScreen())),
              ),
              XyBarisMenu(
                ikon: Icons.local_offer_rounded,
                judul: 'Voucher Saya',
                sub: 'Klaim & pakai potongan',
                onTap: () => Navigator.push(context, xyRoute(const VoucherScreen())),
              ),
              XyBarisMenu(
                ikon: Icons.favorite_rounded,
                judul: 'Favorit Saya',
                sub: '${s.favorit.length} produk disukai',
                onTap: () => Navigator.push(context, xyRoute(const FavoritScreen())),
              ),
              XyBarisMenu(
                ikon: Icons.bar_chart_rounded,
                judul: 'Statistik & Pengeluaran',
                sub: 'Ringkasan belanja & hemat tier',
                onTap: () => Navigator.push(context, xyRoute(const StatistikScreen())),
              ),
              XyBarisMenu(
                ikon: Icons.card_giftcard_rounded,
                judul: 'Undang Teman',
                sub: 'Bagi kode, kalian berdua dapat saldo',
                onTap: () => Navigator.push(context, xyRoute(const ReferralScreen())),
              ),
              XyBarisMenu(
                ikon: Icons.sensors_rounded,
                judul: 'Status Unit Live',
                sub: '${s.orders.isEmpty ? '' : s.plans.fold(0, (a, p) => a + p.unitTersedia)} unit ready — realtime',
                onTap: () => Navigator.push(context, xyRoute(const LiveUnitScreen())),
              ),

              // ---------- grup Aplikasi ----------
              const SectionHeader('Aplikasi'),
              XyBarisMenu(
                ikon: Icons.tune_rounded,
                judul: 'Pengaturan',
                sub: 'Notifikasi, hemat data, penyimpanan',
                onTap: () => Navigator.push(context, xyRoute(const pengaturan.PengaturanScreen())),
              ),
              XyBarisMenu(
                ikon: Icons.dark_mode_outlined,
                judul: 'Tema Aplikasi',
                sub: 'Terang, gelap, atau ikuti sistem',
                onTap: () => Navigator.push(context, xyRoute(const pengaturan.TemaScreen())),
              ),
              XyBarisMenu(ikon: Icons.system_update_rounded, judul: 'Pembaruan Aplikasi', sub: 'Cek versi & update APK', onTap: () => Navigator.push(context, xyRoute(const PembaruanScreen()))),
              XyBarisMenu(
                ikon: Icons.info_outline_rounded,
                judul: 'Tentang Aplikasi',
                sub: 'Versi, syarat, privasi, lisensi',
                onTap: () => Navigator.push(context, xyRoute(const TentangScreen())),
              ),
              XyBarisMenu(
                ikon: Icons.help_center_rounded,
                judul: 'Pusat Bantuan',
                sub: 'FAQ, tutorial, CS',
                onTap: () => Navigator.push(context, xyRoute(const BantuanScreen())),
              ),
              const SizedBox(height: 18),
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
                            color: XyTheme.danger,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8)),
                    onPressed: () async {
                      final yakin = await konfirmasi(
                        context,
                        judul: 'Keluar dari akun?',
                        pesan: 'Kamu perlu masuk lagi untuk memakai aplikasi.',
                        tombolYa: 'Keluar',
                        ikon: Icons.logout_rounded,
                        bahaya: true,
                      );
                      if (yakin && context.mounted) {
                        context.read<AppState>().logout();
                      }
                    },
                    icon: const Icon(Icons.logout_rounded,
                        size: 18, color: XyTheme.danger),
                    label: const Text('Keluar',
                        style: TextStyle(
                            color: XyTheme.danger,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
            ]),
          ),
        ],
      ),
    );
  }
}

// ---------------- potongan kecil ----------------
/// Wadah inisial: gradien ungu lembut, dipakai hanya ketika belum ada foto.
class _WadahInisial extends StatelessWidget {
  const _WadahInisial(this.nama);
  final String nama;

  @override
  Widget build(BuildContext context) => Container(
        width: 72,
        height: 72,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: XyTheme.gradPrimary,
        ),
        child: Center(
          child: Text(
            nama.isEmpty ? 'X' : nama[0].toUpperCase(),
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 26),
          ),
        ),
      );
}

class _Statistik extends StatelessWidget {
  const _Statistik(this.label, this.nilai);
  final String label, nilai;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Text(nilai,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15.5, letterSpacing: -.4)),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(color: Colors.white.withOpacity(.55), fontSize: 11)),
        ]),
      );
}

class _Pemisah extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 26, color: Colors.white.withOpacity(.16));
}

