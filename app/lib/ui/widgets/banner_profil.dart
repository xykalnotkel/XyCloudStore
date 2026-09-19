import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/models.dart';
import 'animasi_profil_epic.dart';

/// ============================================================
///  Banner header profil (Batch I)
/// ============================================================
///  Sumber tampilan, prioritas:
///  1. `media` — GIF/MP4→GIF kustom (khusus pelanggan Pro/VIP),
///  2. `tema`  — gradasi warna bawaan (XyBannerTema),
///  3. gradasi 'ungu' bila keduanya kosong.
///  Selalu diberi scrim gelap lembut di bagian bawah supaya teks
///  nama/email di atasnya tetap terbaca.
class BannerProfil extends StatelessWidget {
  const BannerProfil({
    super.key,
    this.tema,
    this.media,
    this.bingkai,
    this.borderRadius,
    required this.child,
  });

  final String? tema;
  final BannerMedia? media;
  final String? bingkai;
  final BorderRadius? borderRadius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final grad = LinearGradient(
      colors: XyBannerTema.warna(tema),
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    final radius = borderRadius ?? BorderRadius.zero;

    return ClipRRect(
      borderRadius: radius,
      child: Stack(fit: StackFit.passthrough, children: [
        // Dasar: media kustom bila ada, kalau gagal unduh → gradasi tema.
        // Batch O (Discord-style): prefer Animated WebP (webp) — 24-bit + 8-bit alpha,
        // 64% lebih kecil dari GIF, seamless loop tanpa delay. Fallback ke GIF.
        Positioned.fill(
          child: media != null
              ? CachedNetworkImage(
                  imageUrl: media!.displayUrl,
                  fit: BoxFit.cover,
                  fadeInDuration: Duration.zero,
                  fadeOutDuration: Duration.zero,
                  // Flutter Image natively supports Animated WebP (gaplessPlayback)
                  imageBuilder: (context, imageProvider) => Image(
                    image: imageProvider,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    // Penting: filterQuality medium agar WebP animasi tetap tajam tapi hemat GPU
                    filterQuality: FilterQuality.medium,
                  ),
                  placeholder: (_, __) => DecoratedBox(decoration: BoxDecoration(gradient: grad)),
                  errorWidget: (_, __, ___) {
                    // Jika WebP gagal (perangkat lama), coba fallback GIF
                    if (media!.webp != media!.gif && media!.gif.isNotEmpty) {
                      return CachedNetworkImage(
                        imageUrl: media!.gif,
                        fit: BoxFit.cover,
                        fadeInDuration: Duration.zero,
                        fadeOutDuration: Duration.zero,
                        imageBuilder: (context, ip) => Image(image: ip, fit: BoxFit.cover, gaplessPlayback: true),
                        placeholder: (_, __) => DecoratedBox(decoration: BoxDecoration(gradient: grad)),
                        errorWidget: (_, __, ___) => DecoratedBox(decoration: BoxDecoration(gradient: grad)),
                      );
                    }
                    return DecoratedBox(decoration: BoxDecoration(gradient: grad));
                  },
                )
              : DecoratedBox(decoration: BoxDecoration(gradient: grad)),
        ),
        // Efek animasi epik sinematik (naga emas, kobaran inferno, hujan matrix, tebasan samurai, nebula, dll)
        if (bingkai != null && bingkai!.isNotEmpty)
          Positioned.fill(
            child: AnimasiProfilEpic(bingkai: bingkai),
          ),
        // Scrim keterbacaan.
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(media != null ? .30 : .10),
                    Colors.black.withOpacity(.02),
                    Colors.black.withOpacity(media != null ? .48 : .22),
                  ],
                  stops: const [0, .45, 1],
                ),
              ),
            ),
          ),
        ),
        child,
      ]),
    );
  }
}
