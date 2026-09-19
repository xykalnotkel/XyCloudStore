import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/format.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/app_state.dart';
import '../widgets/banner_slider.dart';
import '../widgets/common.dart';
import '../../core/prefs.dart';
import '../widgets/error_state.dart';
import 'akun_screen.dart';
import 'cs_screen.dart';
import 'favorit_screen.dart';
import 'follows_screen.dart';
import 'leaderboard_screen.dart';
import 'livestream_screen.dart';
import 'notifikasi_screen.dart';
import 'order_detail_screen.dart';
import 'referral_screen.dart';
import 'sewa_pc_screen.dart';
import 'statistik_screen.dart';
import 'tier_screen.dart';
import 'voucher_screen.dart';
import 'wallet_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final u = s.user!;
    final aktif = s.orderAktif;

    return Scaffold(
      backgroundColor: XyTheme.of(context).bg,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          BilahOffline(tampil: s.offline, onCoba: s.refresh),
          Expanded(
            child: RefreshIndicator(
          color: XyTheme.primary,
          onRefresh: s.refresh,
          child: ListView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            padding: const EdgeInsets.fromLTRB(XySpacing.page, 6, XySpacing.page, 120),
            children: [
              _Header(user: u, koneksi: s.koneksi, notif: s.notifBelum),
              const SizedBox(height: 20),
              FadeInUp(child: _KartuSaldo(user: u)),
              const SizedBox(height: 22),
              FadeInUp(delay: const Duration(milliseconds: 90), child: const _MenuCepat()),

              if (aktif != null) ...[
                const SectionHeader('Sesi Berjalan', sub: 'Diperbarui otomatis dari server'),
                FadeInUp(child: _KartuOrderAktif(order: aktif)),
              ],

              SectionHeader(
                'XyCloud Live',
                sub: s.liveCatalog.enabled
                    ? '${s.liveCatalog.streams.length} gamer sedang tayang'
                    : 'Main, siarkan, bangun komunitas',
                aksi: 'Buka',
                onAksi: () => Navigator.push(context, xyRoute(const XyLiveScreen())),
              ),
              FadeInUp(child: _LiveHomeCard(catalog: s.liveCatalog)),

              SectionHeader(
                'PC Siap Pakai',
                sub: 'Stok unit tersedia',
                aksi: 'Semua',
                onAksi: () => Navigator.push(context, xyRoute(const SewaPcScreen())),
              ),
              SizedBox(
                height: 198,
                child: s.plans.isEmpty
                    ? _skeletonRow()
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        clipBehavior: Clip.none,
                        itemCount: s.plans.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (_, i) => FadeInUp(
                          delay: Duration(milliseconds: 60 * i),
                          child: _KartuPlanMini(plan: s.plans[i]),
                        ),
                      ),
              ),

              BannerSlider(items: s.banners),

              SectionHeader(
                'Produk & Akun Toko',
                sub: 'Kredensial instan dikirim otomatis',
                aksi: 'Ke Toko',
                onAksi: () => Navigator.push(context, xyRoute(const AkunScreen())),
              ),
              ...s.produk.take(3).toList().asMap().entries.map(
                    (e) => FadeInUp(
                      delay: Duration(milliseconds: 60 * e.key),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 11),
                        child: _BarisProduk(produk: e.value),
                      ),
                    ),
                  ),
            ],
          ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _skeletonRow() => ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, __) => const SizedBox(width: 214, child: Shimmer(height: 198, radius: XyRadius.lg)),
      );
}

// ------------------------------------------------------------------
class _Header extends StatelessWidget {
  const _Header({required this.user, required this.koneksi, required this.notif});
  final UserProfile user;
  final dynamic koneksi;
  final int notif;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          gradient: XyTheme.gradPrimary,
          borderRadius: BorderRadius.circular(18),
          boxShadow: XyTheme.glow(XyTheme.primary, .22),
        ),
        child: Center(
          child: Text(
            user.nama.characters.first.toUpperCase(),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 19),
          ),
        ),
      ),
      const SizedBox(width: 13),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
           Text('Selamat datang', style: TextStyle(color: XyTheme.of(context).muted, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 1),
          Row(children: [
            Flexible(
              child: Text(user.nama.split(' ').first,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -.5)),
            ),
            const SizedBox(width: 7),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
              decoration: BoxDecoration(gradient: XyTheme.gradGold, borderRadius: BorderRadius.circular(10)),
              child: Text(user.tier.toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w700, letterSpacing: .8)),
            ),
          ]),
        ]),
      ),
      LiveDot(state: koneksi),
      const SizedBox(width: 6),
      // Pesan & Pertemanan — akses cepat ke teman yang diikuti & pesan pribadi
      Pressable(
        onTap: () => Navigator.push(context, xyRoute(const FollowsScreen())),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: XyTheme.of(context).surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: XyTheme.of(context).line),
          ),
          child: const Icon(Icons.people_alt_outlined, size: 20),
        ),
      ),
      const SizedBox(width: 6),
      // CS — chat langsung ke customer service
      Pressable(
        onTap: () => Navigator.push(context, xyRoute(const CsScreen())),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: XyTheme.of(context).surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: XyTheme.of(context).line),
          ),
          child: const Icon(Icons.forum_outlined, size: 20),
        ),
      ),
      const SizedBox(width: 6),
      // Notifikasi — kini di topbar, bukan tersembunyi di halaman profil
      Pressable(
        onTap: () async {
          await Navigator.push(context, xyRoute(const NotifikasiScreen()));
          if (context.mounted) context.read<AppState>().muatNotifikasi();
        },
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: XyTheme.of(context).surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: XyTheme.of(context).line),
          ),
          child: Stack(alignment: Alignment.center, children: [
            const Icon(Icons.notifications_none_rounded, size: 21),
            if (notif > 0)
              Positioned(
                right: 8,
                top: 6,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 17),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    gradient: XyTheme.gradPrimary,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: XyTheme.of(context).surface, width: 1.4),
                  ),
                  child: Text(
                    notif > 99 ? '99+' : '$notif',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ]),
        ),
      ),
    ]);
  }
}

// ------------------------------------------------------------------
class _KartuSaldo extends StatefulWidget {
  const _KartuSaldo({required this.user});
  final UserProfile user;

  @override
  State<_KartuSaldo> createState() => _KartuSaldoState();
}

class _KartuSaldoState extends State<_KartuSaldo> {
  bool tampil = true;

  @override
  void initState() {
    super.initState();
    Prefs.saldoTampil().then((v) => mounted ? setState(() => tampil = v) : null);
  }

  Future<void> _ubah() async {
    setState(() => tampil = !tampil);
    await Prefs.simpanSaldoTampil(tampil);
  }

  /// Empat kelompok angka seperti kartu sungguhan, diambil dari id akun.
  String _nomorKartu(String id) {
    final angka = id.replaceAll(RegExp(r'[^0-9]'), '').padRight(8, '4');
    final b = angka.substring(angka.length - 4);
    return '5 3 2 8   ${b.substring(0, 2)} • •   • • • •   ${b.substring(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;

    return AspectRatio(
      aspectRatio: 1.62, // perbandingan kartu asli
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          // Kartu member premium: indigo malam yang tenang (bukan neon/glass).
          gradient: LinearGradient(
            colors: [XyTheme.violetDeep2, XyTheme.primaryDark, XyTheme.midnightDeep],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: [0, .52, 1],
          ),
          boxShadow: [
            BoxShadow(
                color: XyTheme.primaryDark.withOpacity(.34),
                blurRadius: 26,
                offset: const Offset(0, 14)),
            BoxShadow(
                color: XyTheme.midnightInk.withOpacity(.9),
                blurRadius: 0,
                offset: const Offset(0, 2)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(children: [
            // kilau lembut dari atas (premium, bukan glass berlebihan)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(.12),
                        Colors.white.withOpacity(.015),
                      ],
                      begin: Alignment.topCenter,
                      end: const Alignment(0, .5),
                    ),
                  ),
                ),
              ),
            ),
            // cahaya violet halus pojok kanan atas
            Positioned(
              right: -40,
              top: -50,
              child: Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      XyTheme.lilac.withOpacity(.22),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // ---- baris atas: cip, nirsentuh, logo ----
                Row(children: [
                  // cip emas
                  Container(
                    width: 42,
                    height: 32,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: LinearGradient(
                        colors: [XyTheme.goldBright, XyTheme.goldMid, XyTheme.goldPale],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: CustomPaint(painter: _CipPainter()),
                  ),
                  const SizedBox(width: 12),
                  // lambang nirsentuh
                  SizedBox(
                    width: 20,
                    height: 22,
                    child: CustomPaint(painter: _NirsentuhPainter()),
                  ),
                  const Spacer(),
                  Image.asset('assets/brand/logo_icon_putih.png', width: 30, height: 30),
                ]),

                const Spacer(),

                // ---- saldo ----
                Text('Saldo',
                    style: TextStyle(color: Colors.white.withOpacity(.62), fontSize: 11, letterSpacing: .6)),
                const SizedBox(height: 3),
                Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: tampil
                          ? AnimatedRupiah(
                              u.saldo,
                              key: const ValueKey('tampil'),
                              format: rupiah,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 27,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -1,
                              ),
                            )
                          : const Text('Rp • • • • • • •',
                              key: ValueKey('sembunyi'),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 23,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -.4,
                              )),
                    ),
                  ),
                  Pressable(
                    onTap: _ubah,
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.14),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(.18)),
                      ),
                      child: Icon(
                        tampil ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ]),

                const SizedBox(height: 10),

                // ---- nomor kartu ----
                Text(
                  _nomorKartu(u.id),
                  style: TextStyle(
                    color: Colors.white.withOpacity(.80),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),

                const Spacer(),

                // ---- baris bawah: pemilik dan tier ----
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('PEMILIK KARTU',
                          style: TextStyle(
                              color: Colors.white.withOpacity(.45), fontSize: 8, letterSpacing: 1.2)),
                      const SizedBox(height: 3),
                      Text(
                        u.nama.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                    ]),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: XyTheme.gradGold,
                      borderRadius: BorderRadius.circular(XyRadius.pill),
                    ),
                    child: Text(u.tier.toUpperCase(),
                        style: const TextStyle(
                            color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: 1)),
                  ),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Garis tipis pada cip supaya terlihat seperti kartu sungguhan.
class _CipPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cat = Paint()
      ..color = XyTheme.goldDeep.withOpacity(.55)
      ..strokeWidth = .9;
    canvas.drawLine(Offset(0, size.height * .34), Offset(size.width, size.height * .34), cat);
    canvas.drawLine(Offset(0, size.height * .66), Offset(size.width, size.height * .66), cat);
    canvas.drawLine(Offset(size.width * .33, 0), Offset(size.width * .33, size.height), cat);
    canvas.drawLine(Offset(size.width * .67, 0), Offset(size.width * .67, size.height), cat);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// Lambang pembayaran nirsentuh.
class _NirsentuhPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cat = Paint()
      ..color = Colors.white.withOpacity(.55)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.6;
    for (var i = 1; i <= 3; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(-2, size.height / 2), radius: i * 6.0),
        -0.7,
        1.4,
        false,
        cat,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _MenuCepat extends StatelessWidget {
  const _MenuCepat();

  // Kategori cepat di bawah saldo: jalan pintas tanpa kartu/label wadah,
  // ikon 3D glossy (aset assets/ikon/3d_<id>.png) dengan fallback ikon gradien
  // bila asetnya belum ada. 8 item = 2 baris rapi.
  static const _menu = [
    ('Top Up', Icons.account_balance_wallet_rounded, WalletScreen()),
    ('Voucher', Icons.confirmation_number_rounded, VoucherScreen()),
    ('Referral', Icons.share_rounded, ReferralScreen()),
    ('Favorit', Icons.favorite_rounded, FavoritScreen()),
    ('Statistik', Icons.bar_chart_rounded, StatistikScreen()),
    ('Peringkat', Icons.leaderboard_rounded, LeaderboardScreen()),
    ('Tier Saya', Icons.workspace_premium_rounded, TierScreen()),
    ('Xy Live', Icons.live_tv_rounded, XyLiveScreen()),
  ];

  @override
  Widget build(BuildContext context) {
    Widget item(String label, IconData iconData, Widget layar) {
      return Pressable(
        onTap: () => Navigator.push(context, xyRoute(layar)),
        scale: .94,
        // Satu kartu besar bersama — item di dalamnya polos tanpa wadah
        // sendiri (permintaan pemilik: bukan 8 kartu terpisah).
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          // Ikon Material konsisten, tajam pada semua DPI, dan tidak memicu
          // decode PNG terpisah pada setiap item menu cepat.
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: XyTheme.gradPrimary,
              borderRadius: BorderRadius.circular(15),
              boxShadow: XyTheme.glow(XyTheme.primary, .22),
            ),
            child: Icon(iconData, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: -.1,
              color: XyTheme.of(context).ink,
            ),
          ),
        ]),
        ),
      );
    }

    final t = XyTheme.of(context);
    // Kartu besar satu wadah berisi seluruh kategori cepat.
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 10),
      decoration: BoxDecoration(
        color: t.dark ? Colors.white.withOpacity(.04) : Colors.white,
        border: Border.all(color: t.line.withOpacity(.55)),
        borderRadius: BorderRadius.circular(24),
        boxShadow: XyTheme.shadowSm,
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 6,
          crossAxisSpacing: 4,
          childAspectRatio: 0.78,
        ),
        itemCount: _menu.length,
        itemBuilder: (_, i) {
          final (label, iconData, layar) = _menu[i];
          return item(label, iconData, layar);
        },
      ),
    );
  }
}

class _KartuOrderAktif extends StatelessWidget {
  const _KartuOrderAktif({required this.order});
  final RentOrder order;

  @override
  Widget build(BuildContext context) {
    final aktif = order.status == OrderStatus.aktif;
    final warna = aktif ? XyTheme.success : XyTheme.warning;

    return XyCard(
      onTap: () => Navigator.push(context, xyRoute(OrderDetailScreen(orderId: order.id))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          GradientThumb(seed: order.planId, icon: Icons.memory_rounded, size: 46, radius: 14),
          const SizedBox(width: 13),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(order.planNama, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
              const SizedBox(height: 2),
              Text('${order.kode} · ${order.durasiJam} jam',
                  style:  TextStyle(color: XyTheme.of(context).muted, fontSize: 12)),
            ]),
          ),
          Pill(order.status.label,
              warna: warna, icon: aktif ? Icons.play_circle_fill_rounded : Icons.autorenew_rounded),
        ]),
        const SizedBox(height: 16),
        if (order.status == OrderStatus.provisioning)
          Row(children: [
            ProgressRing(value: order.progress / 100, size: 58),
            const SizedBox(width: 16),
             Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Menyiapkan mesin', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                SizedBox(height: 3),
                Text('Boot image, mount storage, cek driver GPU.',
                    style: TextStyle(color: XyTheme.of(context).muted, fontSize: 12, height: 1.45)),
              ]),
            ),
          ])
        else if (aktif) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: XyTheme.of(context).lineSoft,
              borderRadius: BorderRadius.circular(XyRadius.sm),
            ),
            child: Row(children: [
              Icon(Icons.timer_outlined, size: 17, color: XyTheme.primary),
              const SizedBox(width: 9),
               Text('Sisa waktu sesi', style: TextStyle(fontSize: 12.5, color: XyTheme.of(context).muted, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(order.berakhir == null ? '-' : durasiSisa(order.berakhir!),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, letterSpacing: -.3)),
            ]),
          ),
          const SizedBox(height: 13),
          GradientButton(
            label: 'Buka Kredensial Remote',
            icon: Icons.vpn_lock_rounded,
            height: 48,
            onPressed: () => Navigator.push(context, xyRoute(OrderDetailScreen(orderId: order.id))),
          ),
        ] else
          Text('Status saat ini: ${order.status.label}',
              style:  TextStyle(fontSize: 12.5, color: XyTheme.of(context).muted)),
      ]),
    );
  }
}

// ------------------------------------------------------------------
class _LiveHomeCard extends StatelessWidget {
  const _LiveHomeCard({required this.catalog});
  final LiveCatalog catalog;

  @override
  Widget build(BuildContext context) {
    final live = catalog.streams.isEmpty ? null : catalog.streams.first;
    return XyCard(
      padding: EdgeInsets.zero,
      onTap: () => Navigator.push(context, xyRoute(XyLiveScreen(fokusId: live?.id))),
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(XyRadius.lg),
          gradient: const LinearGradient(
            colors: [Color(0xFF120025), Color(0xFF4C1D95), Color(0xFF7C3AED)],
            begin: Alignment.bottomLeft,
            end: Alignment.topRight,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(XyRadius.lg),
          child: Stack(children: [
            Positioned(right: -16, bottom: -22,
              child: Icon(Icons.sports_esports_rounded, size: 150, color: Colors.white.withOpacity(.10))),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: live != null ? const Color(0xFFEF4444) : Colors.white.withOpacity(.14),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(live != null ? '● LIVE' : 'SEGERA HADIR',
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: .7)),
                  ),
                  const Spacer(),
                  if (live != null)
                    Text('${live.viewers} menonton', style: TextStyle(color: Colors.white.withOpacity(.72), fontSize: 11)),
                ]),
                const Spacer(),
                Text(live?.title ?? 'Main. Siarkan. Dapatkan dukungan.',
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 18, height: 1.15, fontWeight: FontWeight.w900, letterSpacing: -.4)),
                const SizedBox(height: 5),
                Text(live == null
                    ? 'Game Capture aman · mic default mati · payout terverifikasi'
                    : '${live.creatorName} · ${live.game}',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white.withOpacity(.68), fontSize: 11.5)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------
class _KartuPlanMini extends StatelessWidget {
  const _KartuPlanMini({required this.plan});
  final PcPlan plan;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 214,
      child: XyCard(
        padding: const EdgeInsets.all(15),
        onTap: () => Navigator.push(context, xyRoute(SewaPcScreen(fokusId: plan.id))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            GradientThumb(seed: plan.id, icon: Icons.memory_rounded, size: 40, radius: 12),
            const Spacer(),
            Pill(plan.ready ? '${plan.unitTersedia} unit' : 'Penuh',
                warna: plan.ready ? XyTheme.success : XyTheme.danger),
          ]),
          const SizedBox(height: 14),
          Text(plan.nama, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5, letterSpacing: -.3)),
          const SizedBox(height: 3),
          Text(plan.gpu,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:  TextStyle(color: XyTheme.of(context).muted, fontSize: 12)),
          const SizedBox(height: 11),
          Row(children: [
            SpecChip(Icons.memory_outlined, '${plan.ramGb}GB'),
            const SizedBox(width: 6),
            SpecChip(Icons.public_rounded, plan.region),
          ]),
          const Spacer(),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(rupiah(plan.hargaPerJam),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17, color: XyTheme.primary, letterSpacing: -.5)),
             Padding(
              padding: EdgeInsets.only(bottom: 2),
              child: Text(' /jam', style: TextStyle(color: XyTheme.of(context).muted, fontSize: 11.5, fontWeight: FontWeight.w600)),
            ),
          ]),
        ]),
      ),
    );
  }
}

// ------------------------------------------------------------------
class _BarisProduk extends StatelessWidget {
  const _BarisProduk({required this.produk});
  final AkunProduk produk;

  @override
  Widget build(BuildContext context) {
    return XyCard(
      padding: const EdgeInsets.all(13),
      onTap: () => Navigator.push(context, xyRoute(AkunScreen(fokusId: produk.id))),
      child: Row(children: [
        GradientThumb(seed: produk.id, icon: Icons.vpn_key_rounded, size: 54, radius: 14),
        const SizedBox(width: 13),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(produk.nama,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.8)),
            const SizedBox(height: 5),
            Row(children: [
              Icon(Icons.star_rounded, size: 13.5, color: XyTheme.gold),
              Text(' ${produk.rating}',
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
              Text('  ·  ${produk.terjual} terjual',
                  style:  TextStyle(fontSize: 11.5, color: XyTheme.of(context).muted)),
            ]),
            const SizedBox(height: 6),
            Text(rupiah(produk.harga),
                style: const TextStyle(fontWeight: FontWeight.w700, color: XyTheme.primary, fontSize: 14.5)),
          ]),
        ),
        Pill(produk.stok > 0 ? 'Stok ${produk.stok}' : 'Habis',
            warna: produk.stok > 0 ? XyTheme.success : XyTheme.danger),
      ]),
    );
  }
}
