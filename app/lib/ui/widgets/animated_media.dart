import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/models.dart';

/// ============================================================
///  AnimatedMedia — Discord-style Animated WebP renderer
/// ============================================================
///  Kenapa WebP animasi ala Discord?
///  - GIF: 256 warna, tanpa alpha (transparan binary), 1-2 MB untuk 5 detik
///  - Animated WebP: 24-bit + 8-bit alpha, 64% lebih kecil dari GIF,
///    loop seamless, didukung Flutter native via gaplessPlayback.
///  - Discord pakai WebP animasi untuk avatar `a_*.webp`, banner, dan
///    dekorasi. Stiker pakai APNG/Lottie karena butuh alpha halus.
///
///  Widget ini:
///  1. Prefer `webp` jika ada (Animated WebP)
///  2. Fallback ke `gif`
///  3. Fallback ke `url` (masih ada di data lama)
///  4. Jika semua gagal, tampilkan placeholder gradasi.
///
///  Dipakai untuk: banner profil, avatar, badge animasi, dekorasi.
class AnimatedMedia extends StatelessWidget {
  const AnimatedMedia({
    super.key,
    required this.media,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholderGradient,
    this.width,
    this.height,
    this.showBadge = true,
  });

  final BannerMedia media;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Gradient? placeholderGradient;
  final double? width;
  final double? height;
  final bool showBadge;

  String get _primaryUrl => media.displayUrl;
  String get _fallbackUrl => media.gif;

  @override
  Widget build(BuildContext context) {
    final grad = placeholderGradient ??
        LinearGradient(
          colors: XyBannerTema.warna(null),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );

    Widget buildImage(String url, {bool isFallback = false}) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: fit,
        width: width,
        height: height,
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
        memCacheWidth: width != null ? (width! * 2).toInt() : null,
        imageBuilder: (context, provider) => Image(
          image: provider,
          fit: fit,
          width: width,
          height: height,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
        ),
        placeholder: (_, __) => DecoratedBox(
          decoration: BoxDecoration(gradient: grad),
          child: width != null && height != null
              ? SizedBox(width: width, height: height)
              : null,
        ),
        errorWidget: (_, __, ___) {
          // Jika primary WebP gagal dan ini bukan fallback, coba GIF
          if (!isFallback && _primaryUrl != _fallbackUrl && _fallbackUrl.isNotEmpty) {
            return buildImage(_fallbackUrl, isFallback: true);
          }
          return DecoratedBox(
            decoration: BoxDecoration(gradient: grad),
            child: width != null && height != null
                ? SizedBox(width: width, height: height)
                : null,
          );
        },
      );
    }

    final img = buildImage(_primaryUrl);

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: Stack(
          fit: StackFit.loose,
          children: [
            img,
            if (showBadge && media.isAnimatedWebP)
              Positioned(
                right: 6,
                top: 6,
                child: _FormatPill(
                  label: media.isVideoOrigin ? 'VIDEO→WebP' : 'WebP',
                  icon: Icons.animation_rounded,
                ),
              ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        img,
        if (showBadge && media.isAnimatedWebP)
          Positioned(
            right: 6,
            top: 6,
            child: _FormatPill(
              label: media.isVideoOrigin ? 'VIDEO→WebP' : 'WebP',
              icon: Icons.animation_rounded,
            ),
          ),
      ],
    );
  }
}

/// Avatar dengan support Animated WebP (mirip Discord `a_` avatar)
class AnimatedAvatar extends StatelessWidget {
  const AnimatedAvatar({
    super.key,
    required this.imageUrl,
    this.size = 48,
    this.borderRadius,
  });

  final String imageUrl;
  final double size;
  final BorderRadius? borderRadius;

  bool get _isAnimatedWebP => imageUrl.toLowerCase().contains('.webp') || imageUrl.contains('fl_awebp');

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(size / 2);

    return ClipRRect(
      borderRadius: radius,
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
        imageBuilder: (context, provider) => Image(
          image: provider,
          width: size,
          height: size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
        ),
        placeholder: (_, __) => Container(
          width: size,
          height: size,
          color: XyTheme.of(context).lineSoft,
          child: Icon(Icons.person_rounded, size: size * 0.5, color: XyTheme.of(context).muted),
        ),
        errorWidget: (_, __, ___) => Container(
          width: size,
          height: size,
          color: XyTheme.of(context).lineSoft,
          child: Icon(Icons.person_rounded, size: size * 0.5, color: XyTheme.of(context).muted),
        ),
      ),
    );
  }
}

class _FormatPill extends StatelessWidget {
  const _FormatPill({required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(.55),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 10, color: Colors.white),
          const SizedBox(width: 3),
          Text(label,
              style: const TextStyle(
                  color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w800, letterSpacing: .4)),
        ]),
      );
}

/// Penjelasan format untuk docs / tooltip
class FormatInfo {
  static const String animatedWebP = '''
Animated WebP ala Discord:
• 24-bit warna + 8-bit alpha (transparan halus, bukan binary seperti GIF)
• 64% lebih kecil dari GIF untuk durasi sama
• Mendukung lossy + lossless, loop infinite (e_loop)
• Flutter render native via Image(gaplessPlayback: true)
• Cloudinary transform: f_webp,fl_awebp,fl_animated,w_480,fps_20,du_5,q_auto:good,e_loop

Discord pakai:
• Avatar animasi: cdn.discordapp.com/avatars/{id}/a_{hash}.webp
• Banner animasi: cdn.discordapp.com/banners/{id}/a_{hash}.webp?size=600
• Dekorasi avatar: APNG / WebP / Lottie (bukan GIF, karena butuh alpha)
• Stiker: PNG 320x320 / APNG / Lottie max 512KB (GIF tidak support)

Kenapa bukan GIF?
• GIF = 1987, max 256 warna, transparansi 1-bit, file bengkak
• WebP = 2010 + animasi 2011, modern, transparan penuh, kompresi superior
• AVIF animasi bahkan lebih kecil lagi, tapi dukungan Flutter masih terbatas
''';
}
