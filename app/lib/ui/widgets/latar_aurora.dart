import 'package:flutter/material.dart';
import '../../core/theme.dart';

/// ============================================================
///  XyLatar — latar "Midnight Aurora" global (Batch I)
/// ============================================================
///  Permintaan pemilik: mode gelap harus terlihat premium, tidak
///  pasaran. Alih-alih satu warna datar, seluruh app duduk di atas
///  gradasi vertikal dalam + blob aurora violet/plum yang lembut.
///  Dipasang sekali di MaterialApp.builder; semua Scaffold memakai
///  latar transparan sehingga aurora tembus di setiap layar.
///
///  Statis (tanpa AnimationController) supaya hemat baterai dan
///  tidak memicu repaint saat daftar digulir.
class XyLatar extends StatelessWidget {
  const XyLatar({super.key, required this.child, this.padat = false, this.paksaGelap});

  final Widget child;

  /// Blob lebih pekat untuk layar autentikasi (login/welcome/onboarding).
  final bool padat;

  /// Paksa varian gelap/terang tanpa melihat tema (layar hero welcome).
  final bool? paksaGelap;

  static Widget blob(Color warna, double diameter, {double opasitas = 1}) =>
      Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [warna.withOpacity(.30 * opasitas), warna.withOpacity(0)],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final gelap =
        paksaGelap ?? (Theme.of(context).brightness == Brightness.dark);
    final o = padat ? 1.5 : 1.0;

    return RepaintBoundary(
      child: Stack(fit: StackFit.expand, children: [
        // Dasar: GitHub Dark Canvas (gelap) / lavender halus (terang).
        DecoratedBox(
          decoration: BoxDecoration(
            color: gelap ? const Color(0xFF0D1117) : null,
            gradient: gelap
                ? null
                : const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFFFDFBFF),
                      Color(0xFFF4EFFF),
                      Color(0xFFEEE6FF),
                    ],
                    stops: [0, .55, 1],
                  ),
          ),
        ),
        // Blob aurora hanya di mode terang agar mode gelap tetap solid GitHub style
        if (!gelap) ...[
          Positioned(
            left: -150,
            top: -130,
            child: blob(XyTheme.lavender, 400, opasitas: .9 * o),
          ),
          Positioned(
            right: -170,
            top: 180,
            child: blob(const Color(0xFFDDD6FE), 360, opasitas: .8 * o),
          ),
          Positioned(
            left: -120,
            bottom: -80,
            child: blob(const Color(0xFFE9D5FF), 420, opasitas: .75 * o),
          ),
        ],
        // Kilau tipis di tepi atas supaya tidak datar.
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: 220,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    (gelap ? XyTheme.lilac : XyTheme.lavender)
                        .withOpacity(gelap ? .07 : .18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(child: child),
      ]),
    );
  }
}
