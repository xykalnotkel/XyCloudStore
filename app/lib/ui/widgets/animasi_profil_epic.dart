import 'dart:math' as math;
import 'package:flutter/material.dart';

/// ============================================================
///  Animasi Profil Epik (Cinematic Frame Overlay)
/// ============================================================
///  Menghadirkan efek sinematik dramatis sesuai bingkai avatar:
///  - naga        : Naga emas meliuk melintasi layar dengan bara api
///  - inferno/api : Kobaran api neraka, lava pijar, dan percikan magma
///  - matrix      : Hujan digital kode biner cyberpunk hijau neon
///  - samurai     : Tebasan pedang katana berkilau & kelopak sakura
///  - nebula/galaksi : Pusaran galaksi kosmik, debu bintang & komet jatuh
///  - phantom     : Roh hantu violet-cyan melayang dengan asap mistis
///  - petir       : Sambaran kilat listrik biru bercabang
///  - sayap       : Sorotan cahaya suci ilahi dan bulu malaikat emas
///  - sakura      : Pusaran badai kelopak bunga sakura melayang
class AnimasiProfilEpic extends StatefulWidget {
  const AnimasiProfilEpic({
    super.key,
    required this.bingkai,
    this.tinggi = 220,
  });

  final String? bingkai;
  final double tinggi;

  @override
  State<AnimasiProfilEpic> createState() => _AnimasiProfilEpicState();
}

class _AnimasiProfilEpicState extends State<AnimasiProfilEpic>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.bingkai ?? 'polos';
    if (b == 'polos' || b.isEmpty) return const SizedBox.shrink();

    return RepaintBoundary(
      child: IgnorePointer(
        child: SizedBox(
          height: widget.tinggi,
          width: double.infinity,
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (context, _) {
              return CustomPaint(
                painter: _EpicPainter(
                  bingkai: b,
                  progress: _ctrl.value,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _EpicPainter extends CustomPainter {
  _EpicPainter({required this.bingkai, required this.progress});

  final String bingkai;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    switch (bingkai) {
      case 'naga':
        _gambarNaga(canvas, size);
        break;
      case 'inferno':
      case 'api':
        _gambarInferno(canvas, size);
        break;
      case 'matrix':
      case 'sirkuit':
        _gambarMatrix(canvas, size);
        break;
      case 'samurai':
        _gambarSamurai(canvas, size);
        break;
      case 'nebula':
      case 'galaksi':
      case 'celestial':
        _gambarNebula(canvas, size);
        break;
      case 'phantom':
        _gambarPhantom(canvas, size);
        break;
      case 'petir':
        _gambarPetir(canvas, size);
        break;
      case 'sayap':
      case 'mahkota':
        _gambarSayap(canvas, size);
        break;
      case 'sakura':
      case 'sakura_angin':
        _gambarSakura(canvas, size);
        break;
      default:
        _gambarPartikelDefault(canvas, size);
        break;
    }
  }

  // 1. Naga Emas Meliuk (The Golden Dragon)
  void _gambarNaga(Canvas canvas, Size size) {
    final paintNaga = Paint()
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    final paintMata = Paint()..color = const Color(0xFFFFE066);

    // Lintasan sinus naga meluncur dari kanan ke kiri
    final p = progress;
    final startX = size.width * (1.2 - p * 1.5);
    final segmen = 18;

    for (var i = segmen; i >= 0; i--) {
      final tSeg = i / segmen;
      final x = startX + (i * 14.0);
      final y = (size.height * 0.45) +
          math.sin((p * 2 * math.pi) + (i * 0.35)) * (size.height * 0.28);
      final radius = (i == 0) ? 14.0 : math.max(4.0, (1.0 - tSeg * 0.7) * 11.0);

      // Tubuh naga emas bersisik
      paintNaga.color = Color.lerp(
        const Color(0xFFFFD700),
        const Color(0xFFFF7700),
        tSeg,
      )!.withOpacity(math.max(0.0, math.min(1.0, 1.0 - (x / size.width).abs() * 0.4)));

      canvas.drawCircle(Offset(x, y), radius, paintNaga);

      // Mata naga menyala pada kepala
      if (i == 0) {
        canvas.drawCircle(Offset(x - 3, y - 3), 3, paintMata);
        // Sungut / kumis naga emas
        final kumisPaint = Paint()
          ..color = const Color(0xFFFFF099).withOpacity(0.9)
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke;
        final path = Path();
        path.moveTo(x - 4, y - 1);
        path.quadraticBezierTo(x - 18, y - 8 + math.sin(p * 8) * 4, x - 26, y - 14);
        canvas.drawPath(path, kumisPaint);
      }

      // Percikan api / bara di sekitar ekor
      if (i % 3 == 0) {
        final baraX = x + math.sin(p * 12 + i) * 12;
        final baraY = y + math.cos(p * 10 + i) * 10;
        final baraPaint = Paint()
          ..color = const Color(0xFFFF3300).withOpacity(0.7)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
        canvas.drawCircle(Offset(baraX, baraY), 2.5, baraPaint);
      }
    }
  }

  // 2. Inferno & Api Neraka
  void _gambarInferno(Canvas canvas, Size size) {
    final flamePaint = Paint()..style = PaintingStyle.fill;
    final count = 12;

    for (var i = 0; i < count; i++) {
      final pOffset = (progress + (i / count)) % 1.0;
      final x = (size.width / count) * i + (math.sin(pOffset * 4 * math.pi) * 8);
      final y = size.height - (pOffset * size.height * 0.85);
      final radius = (1.0 - pOffset) * 16.0;

      flamePaint.color = Color.lerp(
        const Color(0xFFFF2200),
        const Color(0xFFFFCC00),
        1.0 - pOffset,
      )!.withOpacity((1.0 - pOffset) * 0.75);

      flamePaint.maskFilter = MaskFilter.blur(BlurStyle.normal, 4 + (pOffset * 4));
      canvas.drawCircle(Offset(x, y), radius, flamePaint);

      // Percikan lava naik tinggi
      final sparkY = size.height - ((progress * 1.6 + i * 0.2) % 1.0) * size.height;
      final sparkX = x + math.sin(progress * 6 + i) * 16;
      final sparkPaint = Paint()..color = const Color(0xFFFFE600).withOpacity(0.85);
      canvas.drawCircle(Offset(sparkX, sparkY), 2.0, sparkPaint);
    }
  }

  // 3. Matrix & Cyber Circuit Rain
  void _gambarMatrix(Canvas canvas, Size size) {
    final colCount = 14;
    final paintGlow = Paint()
      ..color = const Color(0xFF00FF66).withOpacity(0.85)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    final paintTrail = Paint()..strokeWidth = 2.0;

    for (var i = 0; i < colCount; i++) {
      final speed = 0.8 + ((i % 5) * 0.3);
      final pCol = (progress * speed + (i * 0.17)) % 1.0;
      final x = (size.width / colCount) * (i + 0.5);
      final y = pCol * (size.height + 40) - 20;

      // Garis kepala laser
      canvas.drawCircle(Offset(x, y), 3.5, paintGlow);

      // Jejak terminal
      final gradient = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          const Color(0xFF00FF66).withOpacity(0.6),
          Colors.transparent,
        ],
      );
      paintTrail.shader = gradient.createShader(Rect.fromLTWH(x - 1, y - 35, 2, 35));
      canvas.drawLine(Offset(x, y), Offset(x, y - 35), paintTrail);
    }
  }

  // 4. Samurai Katana Slash & Petals
  void _gambarSamurai(Canvas canvas, Size size) {
    final slashP = (progress * 1.5) % 1.0;
    if (slashP < 0.45) {
      final t = slashP / 0.45;
      final start = Offset(size.width * 0.1, size.height * 0.2);
      final end = Offset(size.width * 0.9, size.height * 0.85);
      final currentEnd = Offset.lerp(start, end, t)!;

      final slashPaint = Paint()
        ..color = Colors.white.withOpacity((1.0 - t) * 0.9)
        ..strokeWidth = 3.5
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

      canvas.drawLine(start, currentEnd, slashPaint);

      final glowPaint = Paint()
        ..color = const Color(0xFF60A5FA).withOpacity((1.0 - t) * 0.7)
        ..strokeWidth = 9.0
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawLine(start, currentEnd, glowPaint);
    }

    // Kelopak darah/bunga samurai
    for (var i = 0; i < 7; i++) {
      final pKelopak = (progress + i * 0.15) % 1.0;
      final x = size.width * (0.15 + (i * 0.12)) + math.sin(pKelopak * 4) * 14;
      final y = pKelopak * size.height;
      final petalPaint = Paint()..color = const Color(0xFFE11D48).withOpacity(0.7);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, y), width: 6, height: 10),
        petalPaint,
      );
    }
  }

  // 5. Nebula & Galaxy Vortex
  void _gambarNebula(Canvas canvas, Size size) {
    final cx = size.width * 0.5;
    final cy = size.height * 0.5;
    final starCount = 20;

    for (var i = 0; i < starCount; i++) {
      final angle = (progress * 2 * math.pi) + (i * (2 * math.pi / starCount));
      final dist = (30.0 + (i * 5.0)) * (0.8 + 0.2 * math.sin(progress * 4 * math.pi));
      final x = cx + math.cos(angle) * dist * 1.5;
      final y = cy + math.sin(angle) * dist * 0.6;
      final opacity = (0.4 + 0.6 * math.sin((progress * 3 + i) * math.pi)).clamp(0.0, 1.0);

      final starPaint = Paint()
        ..color = (i % 2 == 0 ? const Color(0xFFC084FC) : const Color(0xFF38BDF8)).withOpacity(opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

      canvas.drawCircle(Offset(x, y), 2.5 + (i % 3), starPaint);
    }

    // Komet jatuh melintas
    final kometP = (progress * 1.2) % 1.0;
    final kometX = size.width * (1.1 - kometP * 1.4);
    final kometY = size.height * (kometP * 0.9);
    final kometPaint = Paint()
      ..color = Colors.white.withOpacity(0.85)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(Offset(kometX, kometY), 3, kometPaint);

    final kometTrail = Paint()
      ..color = const Color(0xFFE879F9).withOpacity(0.5)
      ..strokeWidth = 2.0;
    canvas.drawLine(Offset(kometX, kometY), Offset(kometX + 35, kometY - 18), kometTrail);
  }

  // 6. Phantom Ghost Wraith
  void _gambarPhantom(Canvas canvas, Size size) {
    for (var i = 0; i < 6; i++) {
      final pGhost = (progress + (i * 0.18)) % 1.0;
      final x = size.width * (0.2 + (i * 0.14)) + math.sin(pGhost * 3 * math.pi + i) * 20;
      final y = size.height - (pGhost * (size.height + 30));
      final alpha = math.sin(pGhost * math.pi).clamp(0.0, 1.0) * 0.7;

      final ghostPaint = Paint()
        ..color = (i % 2 == 0 ? const Color(0xFFA855F7) : const Color(0xFF06B6D4)).withOpacity(alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

      canvas.drawCircle(Offset(x, y), 12 + (i % 4) * 3, ghostPaint);

      // Mata roh menyala
      final eyePaint = Paint()..color = Colors.white.withOpacity(alpha);
      canvas.drawCircle(Offset(x - 3, y - 2), 1.8, eyePaint);
      canvas.drawCircle(Offset(x + 3, y - 2), 1.8, eyePaint);
    }
  }

  // 7. Petir Badai Listrik
  void _gambarPetir(Canvas canvas, Size size) {
    final petirP = (progress * 2.5) % 1.0;
    if (petirP < 0.25) {
      final pLight = Paint()
        ..color = const Color(0xFF38BDF8).withOpacity(0.9)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

      final path = Path();
      var curX = size.width * 0.65;
      var curY = 0.0;
      path.moveTo(curX, curY);

      for (var seg = 0; seg < 6; seg++) {
        curX += (math.sin(seg * 2.8 + progress * 10) * 28);
        curY += (size.height / 6);
        path.lineTo(curX, curY);
      }
      canvas.drawPath(path, pLight);
    }
  }

  // 8. Sayap Surgawi & Cahaya Ilahi
  void _gambarSayap(Canvas canvas, Size size) {
    final beamPaint = Paint()
      ..color = const Color(0xFFFFE066).withOpacity(0.18 + 0.1 * math.sin(progress * 2 * math.pi))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

    final path = Path();
    path.moveTo(size.width * 0.35, 0);
    path.lineTo(size.width * 0.65, 0);
    path.lineTo(size.width * 0.85, size.height);
    path.lineTo(size.width * 0.15, size.height);
    path.close();
    canvas.drawPath(path, beamPaint);

    // Bulu malaikat melayang turun
    for (var i = 0; i < 5; i++) {
      final pFeather = (progress + i * 0.2) % 1.0;
      final x = size.width * (0.2 + i * 0.15) + math.sin(pFeather * 4 * math.pi) * 16;
      final y = pFeather * size.height;
      final fPaint = Paint()..color = Colors.white.withOpacity(0.7);
      canvas.drawOval(Rect.fromCenter(center: Offset(x, y), width: 4, height: 12), fPaint);
    }
  }

  // 9. Kelopak Sakura Berputar
  void _gambarSakura(Canvas canvas, Size size) {
    for (var i = 0; i < 14; i++) {
      final pSakura = (progress + i * 0.08) % 1.0;
      final x = (size.width * (1.1 - pSakura * 1.3)) + math.sin(pSakura * 6 * math.pi + i) * 22;
      final y = (size.height * pSakura) + math.cos(pSakura * 4 * math.pi) * 12;
      final alpha = math.sin(pSakura * math.pi).clamp(0.0, 1.0) * 0.85;

      final sPaint = Paint()
        ..color = (i % 2 == 0 ? const Color(0xFFF472B6) : const Color(0xFFFBCFE8)).withOpacity(alpha);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(pSakura * 8 * math.pi + i);
      canvas.drawOval(const Rect.fromLTWH(-4, -6, 8, 12), sPaint);
      canvas.restore();
    }
  }

  void _gambarPartikelDefault(Canvas canvas, Size size) {
    for (var i = 0; i < 8; i++) {
      final pD = (progress + i * 0.125) % 1.0;
      final x = size.width * (0.1 + i * 0.11);
      final y = size.height - pD * size.height;
      final paint = Paint()
        ..color = Colors.white.withOpacity((1.0 - pD) * 0.6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      canvas.drawCircle(Offset(x, y), 2.5, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _EpicPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.bingkai != bingkai;
}
