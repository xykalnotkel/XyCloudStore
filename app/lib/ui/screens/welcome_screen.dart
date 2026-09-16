import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../providers/app_state.dart';
import '../widgets/common.dart';
import 'login_screen.dart';

/// Welcome / gerbang masuk: value proposition singkat + CTA.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _a =
      AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  void _keLogin({required bool daftar}) =>
      Navigator.push(context, xyRoute(LoginScreen(modeDaftar: daftar)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: XyTheme.of(context).ink,
      body: Stack(children: [
        const Positioned.fill(child: AuroraBackground(dark: true)),
        const Positioned.fill(child: DotGrid(color: Color(0x0AFFFFFF), gap: 28)),
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _a,
            builder: (_, __) => CustomPaint(painter: _ConstellationPainter(_a.value)),
          ),
        ),

        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(26, 0, 26, 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Spacer(flex: 3),

              FadeInUp(
                delay: const Duration(milliseconds: 80),
                child: Row(children: [
                  const XyLogo(size: 52, radius: 17, putih: true),
                  const SizedBox(width: 13),
                  const XyWordmark(tinggi: 26, putih: true),
                ]),
              ),

              const SizedBox(height: 10),

              FadeInUp(
                delay: const Duration(milliseconds: 140),
                child: Center(child: XyIlustrasi('sewa', tinggi: 210)),
              ),

              const SizedBox(height: 10),

              FadeInUp(
                delay: const Duration(milliseconds: 180),
                child: const Text(
                  'Kekuatan PC\nkelas berat,\ndi genggamanmu.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    height: 1.16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1.7,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              FadeInUp(
                delay: const Duration(milliseconds: 280),
                child: Text(
                  'Sewa cloud PC per jam, beli akun digital bergaransi, dan pantau semuanya langsung dalam satu aplikasi.',
                ),
              ),

              const SizedBox(height: 14),

              // Batch J: angka realtime dari /api/config (statistikPublik).
              FadeInUp(
                delay: const Duration(milliseconds: 340),
                child: _ChipStatistik(),
              ),


              const SizedBox(height: 30),

              // Angka nyata dari server — tidak ada lagi statistik fiksi.
              FadeInUp(
                delay: const Duration(milliseconds: 380),
                child: const _StatistikReal(),
              ),

              const Spacer(flex: 2),

              FadeInUp(
                delay: const Duration(milliseconds: 460),
                child: GradientButton(
                  label: 'Masuk ke Akun',
                  icon: Icons.login_rounded,
                  gradient: XyTheme.gradPrimary,
                  onPressed: () => _keLogin(daftar: false),
                ),
              ),
              const SizedBox(height: 12),
              FadeInUp(
                delay: const Duration(milliseconds: 540),
                child: SizedBox(
                  height: 48,
                  child: Pressable(
                    onTap: () => _keLogin(daftar: true),
                    scale: .975,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.07),
                        borderRadius: BorderRadius.circular(XyRadius.md),
                        border: Border.all(color: Colors.white.withOpacity(.14)),
                      ),
                      child: const Center(
                        child: Text('Buat Akun Baru',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Center(
                child: Text(
                  'Dengan melanjutkan, kamu menyetujui Syarat Layanan\ndan Kebijakan Privasi XyCloud.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withOpacity(.30), fontSize: 11, height: 1.6),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.nilai, this.label);
  final String nilai, label;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(nilai,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 19, letterSpacing: -.6)),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(color: Colors.white.withOpacity(.40), fontSize: 11, fontWeight: FontWeight.w600)),
    ]);
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 30,
        margin: const EdgeInsets.symmetric(horizontal: 20),
        color: Colors.white.withOpacity(.12),
      );
}

/// Statistik asli dari server (/api/config) — menggantikan angka statis
/// yang tidak nyata ("19K+ pengguna" dlm. versi lama).
class _StatistikReal extends StatelessWidget {
  const _StatistikReal();

  static String _ringkas(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1).replaceAll('.', ',')} jt';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(n >= 10000 ? 0 : 1).replaceAll('.', ',')} rb';
    return n.toString();
  }

  @override
  Widget build(BuildContext context) {
    final k = context.watch<AppState>().konfigurasi;
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      _Stat(_ringkas(k.statistikPengguna), 'Pengguna'),
      const _Divider(),
      if (k.statistikUnitOnline > 0) ...[
        _Stat('${k.statistikUnitOnline}', 'Unit Online'),
        const _Divider(),
      ],
      const _Stat('24/7', 'Support'),
    ]);
  }
}

class _ConstellationPainter extends CustomPainter {
  _ConstellationPainter(this.t);
  final double t;

  static final _rnd = math.Random(7);
  static final _pts = List.generate(18, (_) => Offset(_rnd.nextDouble(), _rnd.nextDouble()));

  @override
  void paint(Canvas canvas, Size size) {
    final pts = _pts
        .map((p) => Offset(
              p.dx * size.width + math.sin(t * math.pi * 2 + p.dx * 6) * 10,
              p.dy * size.height + math.cos(t * math.pi * 2 + p.dy * 6) * 10,
            ))
        .toList();

    final line = Paint()
      ..color = Colors.white.withOpacity(.06)
      ..strokeWidth = .9;
    for (var i = 0; i < pts.length; i++) {
      for (var j = i + 1; j < pts.length; j++) {
        final d = (pts[i] - pts[j]).distance;
        if (d < 130) canvas.drawLine(pts[i], pts[j], line);
      }
    }
    for (final p in pts) {
      canvas.drawCircle(p, 1.5, Paint()..color = Colors.white.withOpacity(.22));
    }
  }

  @override
  bool shouldRepaint(covariant _ConstellationPainter old) => old.t != t;
}


/// Baris angka realtime (Batch J): jumlah pengguna terdaftar & unit online.
class _ChipStatistik extends StatelessWidget {
  const _ChipStatistik();

  String _fmt(int n) {
    final s = n.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
      b.write(s[i]);
    }
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    final k = context.watch<AppState>().konfigurasi;
    if (k.statistikPengguna <= 0 && k.statistikUnitOnline <= 0) {
      return const SizedBox.shrink();
    }
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.10),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withOpacity(.16)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.group_rounded, size: 14, color: Colors.white70),
          const SizedBox(width: 6),
          Text('${_fmt(k.statistikPengguna)} pengguna',
              style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700)),
          if (k.statistikUnitOnline > 0) ...[
            Container(margin: const EdgeInsets.symmetric(horizontal: 8), width: 1, height: 12, color: Colors.white24),
            Container(width: 7, height: 7, decoration: const BoxDecoration(color: Color(0xFF34D399), shape: BoxShape.circle)),
            const SizedBox(width: 5),
            Text('${k.statistikUnitOnline} unit online',
                style: const TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w600)),
          ],
        ]),
      ),
    ]);
  }
}
