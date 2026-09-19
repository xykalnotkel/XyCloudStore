import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/motion.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme.dart';
import '../../data/realtime_service.dart';
import 'latar_aurora.dart';
export 'custom_dropdown.dart';

// ============================================================
//  Gambar jaringan dengan cache disk di perangkat
// ============================================================
class AppImage extends StatelessWidget {
  const AppImage(this.url,
      {super.key,
      this.tinggi,
      this.lebar,
      this.fit = BoxFit.cover,
      this.radius,
      this.placeholderKet = false});
  final String url;
  final double? tinggi, lebar;
  final BoxFit fit;
  final double? radius;
  final bool placeholderKet;

  @override
  Widget build(BuildContext context) {
    Widget isi() => CachedNetworkImage(
          imageUrl: url,
          height: tinggi,
          width: lebar,
          fit: fit,
          memCacheWidth: (tinggi ?? 200).toInt() * 3,
          fadeInDuration: const Duration(milliseconds: 120),
          fadeOutDuration: const Duration(milliseconds: 120),
          placeholder: (_, __) => placeholderKet
              ? const Shimmer()
              : const SizedBox.shrink(),
          errorWidget: (_, __, ___) => Container(
            color: XyTheme.of(context).primarySoft,
            child: const Icon(Icons.broken_image_outlined,
                color: XyTheme.muted),
          ),
        );
    if (radius == null) return isi();
    return ClipRRect(
        borderRadius: BorderRadius.circular(radius!), child: isi());
  }
}

// ============================================================
//  Kartu & permukaan — FLAT OPTIMIZED Batch P
// ============================================================

/// Kartu flat — optimasi 2026-09-19:
/// Sebelumnya: shadow berlapis + gradasi + AnimatedScale + AnimatedContainer
/// → overdraw & jank di low-end. Sekarang FLAT: border 1px + surface solid,
/// tanpa shadow, tanpa gradasi, tanpa animasi. InkWell ringan untuk tap.
class XyCard extends StatelessWidget {
  const XyCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    this.radius = XyRadius.lg,
    this.color,
    this.border = true,
    this.elevated = false,
    this.gradient,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final double radius;
  final Color? color;
  final bool border;
  final bool elevated; // compat, diabaikan (flat)
  final Gradient? gradient; // compat, diabaikan

  @override
  Widget build(BuildContext context) {
    final t = XyTheme.of(context);
    final body = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? t.surface,
        borderRadius: BorderRadius.circular(radius),
        border: border ? Border.all(color: t.line) : null,
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: t.ink),
        child: child,
      ),
    );

    if (onTap == null) return body;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap!();
        },
        child: body,
      ),
    );
  }
}

/// Wrapper tekan — flat ringan (tanpa AnimatedScale)
class Pressable extends StatelessWidget {
  const Pressable({super.key, required this.child, this.onTap, this.scale = .96});
  final Widget child;
  final VoidCallback? onTap;
  final double scale; // compat, diabaikan

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(XyRadius.sm),
      onTap: onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onTap!();
            },
      child: child,
    );
  }
}

// ============================================================
//  Tombol — FLAT OPTIMIZED Batch P
// ============================================================

/// Tombol flat — optimasi performa:
/// Sebelumnya: Gradient + border berkilau 3 warna + 2 BoxShadow glow +
/// AnimatedScale + AnimatedContainer + foregroundDecoration kaca = 6 layer.
/// Sekarang: solid color, tanpa gradient/shadow/glow/scale. Material+InkWell.
/// API sama supaya tidak breaking, gradient & glowColor diabaikan.
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.gradient = XyTheme.gradPrimary,
    this.loading = false,
    this.height = 48,
    this.glowColor = XyTheme.primary,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Gradient gradient;
  final bool loading;
  final double height;
  final Color glowColor;

  @override
  Widget build(BuildContext context) {
    final mati = onPressed == null || loading;
    final t = XyTheme.of(context);
    final bg = mati ? t.primarySoft : XyTheme.primary;
    final fg = mati ? t.muted : Colors.white;

    return SizedBox(
      height: height,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(XyRadius.tombol),
        child: InkWell(
          borderRadius: BorderRadius.circular(XyRadius.tombol),
          onTap: mati
              ? null
              : () {
                  HapticFeedback.lightImpact();
                  onPressed!();
                },
          child: Center(
            child: loading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.2, color: fg),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 18, color: fg),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        label,
                        style: TextStyle(
                          color: fg,
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                          letterSpacing: -.1,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
//  Label & indikator — FLAT
// ============================================================

class Pill extends StatelessWidget {
  Pill(this.teks, {super.key, this.warna = XyTheme.primary, this.icon, this.solid = false});
  final String teks;
  final Color warna;
  final IconData? icon;
  final bool solid;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final double lum = warna.computeLuminance();
    final Color teksWarna = solid
        ? (lum > 0.65 ? (isDark ? XyTheme.inkGelap : XyTheme.ink) : Colors.white)
        : (lum > 0.65 ? (isDark ? XyTheme.inkGelap : XyTheme.primaryDeep) : warna);
    final Color bgWarna = solid
        ? warna
        : (lum > 0.75
            ? (isDark ? Colors.white.withOpacity(0.12) : const Color(0xFFEEE8FA))
            : warna.withOpacity(.12));
    final Color borderWarna = solid
        ? Colors.transparent
        : (lum > 0.75 ? XyTheme.of(context).line : warna.withOpacity(.25));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5.5),
      decoration: BoxDecoration(
        color: bgWarna,
        borderRadius: BorderRadius.circular(XyRadius.pill),
        border: solid ? null : Border.all(color: borderWarna),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: 12.5, color: teksWarna),
          const SizedBox(width: 4),
        ],
        Text(teks,
            style: TextStyle(
              color: teksWarna,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: .1,
            )),
      ]),
    );
  }
}

class LiveDot extends StatelessWidget {
  const LiveDot({super.key,required this.state,this.compact=true});
  final RealtimeState state;
  final bool compact;
  @override Widget build(BuildContext context) {
    final online=state==RealtimeState.online;
    final color=online?XyTheme.success:state==RealtimeState.connecting?XyTheme.warning:XyTheme.of(context).muted;
    return Tooltip(message:online?'Terhubung ke server':state==RealtimeState.connecting?'Menghubungkan server':'Koneksi terputus',
      child:Padding(padding:const EdgeInsets.all(4),child:Container(width:8,height:8,decoration:BoxDecoration(color:color,shape:BoxShape.circle))));
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.judul, {super.key, this.sub, this.aksi, this.onAksi, this.top = 26});
  final String judul;
  final String? sub;
  final String? aksi;
  final VoidCallback? onAksi;
  final double top;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(0, top, 0, 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(judul, style: const TextStyle(fontSize: 17.5, fontWeight: FontWeight.w700, letterSpacing: -.45)),
            if (sub != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(sub!, style:  TextStyle(fontSize: 12.5, color: XyTheme.of(context).muted)),
              ),
          ]),
        ),
        if (aksi != null)
          Pressable(
            onTap: onAksi,
            child: Padding(
              padding: const EdgeInsets.only(left: 8, top: 2),
              child: Row(children: [
                Text(aksi!,
                    style: const TextStyle(color: XyTheme.primary, fontWeight: FontWeight.w700, fontSize: 13)),
                Icon(Icons.chevron_right_rounded, size: 18, color: XyTheme.primary),
              ]),
            ),
          ),
      ]),
    );
  }
}

class SpecChip extends StatelessWidget {
  const SpecChip(this.icon, this.teks, {super.key});
  final IconData icon;
  final String teks;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(color: XyTheme.of(context).lineSoft, borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: XyTheme.of(context).muted),
        const SizedBox(width: 5),
        Text(teks, style:  TextStyle(fontSize: 11.5, color: XyTheme.of(context).inkSoft, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class GradientThumb extends StatelessWidget {
  const GradientThumb({
    super.key,
    required this.seed,
    this.icon,
    this.size = 56,
    this.height,
    this.radius = XyRadius.md,
  });

  final String seed;
  final IconData? icon;
  final double size;
  final double? height;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    width:size,height:height??size,
    decoration:BoxDecoration(color:XyTheme.of(context).primarySoft,borderRadius:BorderRadius.circular(radius)),
    alignment:Alignment.center,
    child:Icon(icon??Icons.memory_rounded,color:XyTheme.of(context).accent,size:(height??size)*.40),
  );
}

// ============================================================
//  Skeleton / shimmer — tetap ringan
// ============================================================

class Shimmer extends StatefulWidget {
  const Shimmer({super.key, this.width = double.infinity, this.height = 16, this.radius = 8});
  final double width, height, radius;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: c,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          gradient: LinearGradient(
            begin: Alignment(-1 + c.value * 3, 0),
            end: Alignment(c.value * 3, 0),
            colors: [XyTheme.shimmerA, XyTheme.shimmerB, XyTheme.shimmerA],
          ),
        ),
      ),
    );
  }
}

class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.radius = 8,
  });
  final double width, height, radius;

  @override
  Widget build(BuildContext context) => Shimmer(width: width, height: height, radius: radius);
}

class SkeletonCard extends StatelessWidget {
  const SkeletonCard({
    super.key,
    this.width = double.infinity,
    this.height = 100,
    this.radius = 16,
    this.padding = const EdgeInsets.all(16),
  });
  final double width, height, radius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: XyTheme.of(context).surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: XyTheme.of(context).line),
      ),
      child: Shimmer(width: double.infinity, height: double.infinity, radius: radius > 4 ? radius - 4 : 4),
    );
  }
}

class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 5, this.itemHeight = 72});
  final int count;
  final double itemHeight;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: count,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, __) => Container(
        height: itemHeight,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: XyTheme.of(context).surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: XyTheme.of(context).line),
        ),
        child: Row(
          children: [
            const Shimmer(width: 44, height: 44, radius: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Shimmer(width: 140, height: 14, radius: 6),
                  SizedBox(height: 8),
                  Shimmer(width: 200, height: 11, radius: 4),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SkeletonForumList extends StatelessWidget {
  const SkeletonForumList({super.key, this.count = 4});
  final int count;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: count,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: XyTheme.of(context).surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: XyTheme.of(context).line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Shimmer(width: 38, height: 38, radius: 19),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Shimmer(width: 110, height: 13, radius: 5),
                    SizedBox(height: 5),
                    Shimmer(width: 70, height: 10, radius: 4),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Shimmer(width: double.infinity, height: 15, radius: 5),
            const SizedBox(height: 8),
            const Shimmer(width: 220, height: 15, radius: 5),
            const SizedBox(height: 14),
            Row(
              children: const [
                Shimmer(width: 50, height: 18, radius: 9),
                SizedBox(width: 16),
                Shimmer(width: 50, height: 18, radius: 9),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SkeletonLiveGrid extends StatelessWidget {
  const SkeletonLiveGrid({super.key, this.count = 4});
  final int count;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.82,
      ),
      itemCount: count,
      itemBuilder: (_, __) => Container(
        decoration: BoxDecoration(
          color: XyTheme.of(context).surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: XyTheme.of(context).line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
                child: const Shimmer(width: double.infinity, height: double.infinity, radius: 0),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Shimmer(width: 100, height: 13, radius: 5),
                  SizedBox(height: 6),
                  Shimmer(width: 60, height: 10, radius: 4),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
//  Empty state — flat
// ============================================================

class Kosong extends StatelessWidget {
  const Kosong({super.key, required this.icon, required this.judul, this.sub, this.aksi, this.ilustrasi = 'kosong'});
  final String ilustrasi;
  final IconData icon;
  final String judul;
  final String? sub;
  final Widget? aksi;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
          if (ilustrasi.isEmpty)
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: XyTheme.of(context).primarySoft,
              ),
              child: Icon(icon, size: 30, color: XyTheme.primary),
            )
          else
            XyIlustrasi(ilustrasi, tinggi: 150),
          const SizedBox(height: 14),
          Text(judul, textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5, letterSpacing: -.2)),
          if (sub != null) ...[
            const SizedBox(height: 7),
            Text(sub!, textAlign: TextAlign.center,
                style:  TextStyle(color: XyTheme.of(context).muted, fontSize: 13, height: 1.55)),
          ],
          if (aksi != null) ...[const SizedBox(height: 20), aksi!],
        ]),
      ),
    );
  }
}

// ============================================================
//  Logo — flat
// ============================================================

class XyLogo extends StatelessWidget {
  const XyLogo({super.key, this.size = 64, this.radius = 22, this.putih = false, this.kotak = true, this.glow = false});
  final double size;
  final double radius;
  final bool putih;
  final bool kotak;
  final bool glow; // compat, diabaikan flat

  @override
  Widget build(BuildContext context) {
    final gambar = Image.asset(
      putih ? 'assets/brand/logo_icon_putih.png' : 'assets/brand/logo_icon.png',
      width: size * (kotak ? .74 : 1),
      height: size * (kotak ? .74 : 1),
      filterQuality: FilterQuality.medium,
    );
    if (!kotak) return SizedBox(width: size, height: size, child: Center(child: gambar));

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: putih ? Colors.white.withOpacity(.12) : Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: putih ? Colors.white.withOpacity(.18) : XyTheme.of(context).line),
      ),
      child: Center(child: gambar),
    );
  }
}

class XyWordmark extends StatelessWidget {
  const XyWordmark({super.key, this.tinggi = 30, this.putih = false});
  final double tinggi;
  final bool putih;

  @override
  Widget build(BuildContext context) => Image.asset(
        putih ? 'assets/brand/wordmark_putih.png' : 'assets/brand/wordmark.png',
        height: tinggi,
        filterQuality: FilterQuality.medium,
      );
}

class XyIlustrasi extends StatelessWidget {
  const XyIlustrasi(this.nama, {super.key, this.tinggi = 200});
  final String nama;
  final double tinggi;
  static const String cadangan = 'kosong';

  @override
  Widget build(BuildContext context) => Image.asset(
        'assets/ilustrasi/$nama.webp',
        height: tinggi,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        errorBuilder: (context, error, stackTrace) => nama == cadangan
            ? Icon(Icons.image_not_supported_outlined,
                size: tinggi * .55, color: XyTheme.of(context).muted.withOpacity(.45))
            : XyIlustrasi(cadangan, tinggi: tinggi),
      );
}

// ============================================================
//  Latar dekoratif — flat, tanpa blur berat
// ============================================================

class AuroraBackground extends StatelessWidget {
  const AuroraBackground({super.key,this.child,this.dark=false});
  final Widget? child;final bool dark;
  @override Widget build(BuildContext context)=>XyLatar(padat:true,paksaGelap:dark?true:null,child:child??const SizedBox.shrink());
}
class DotGrid extends StatelessWidget {
  const DotGrid({super.key,this.color=const Color(0x14FFFFFF),this.gap=22});
  final Color color;final double gap;
  @override Widget build(BuildContext context)=>const SizedBox.shrink();
}

class FadeInUp extends StatefulWidget {
  const FadeInUp({super.key, required this.child, this.delay = Duration.zero, this.offset = 18});
  final Widget child;
  final Duration delay;
  final double offset;

  @override
  State<FadeInUp> createState() => _FadeInUpState();
}

class _FadeInUpState extends State<FadeInUp> with SingleTickerProviderStateMixin {
  late final AnimationController c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 360))..repeat();

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) c.forward();
    });
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(parent: c, curve: Curves.easeOutCubic);
    return AnimatedBuilder(
      animation: curve,
      builder: (_, child) => Transform.translate(
        offset: Offset(0, (1 - curve.value) * widget.offset),
        child: child,
      ),
      child: widget.child,
    );
  }
}

class AnimatedRupiah extends StatelessWidget {
  const AnimatedRupiah(this.nilai, {super.key, required this.style, required this.format});
  final int nilai;
  final TextStyle style;
  final String Function(num) format;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: nilai.toDouble()),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => Text(format(v.round()), style: style),
    );
  }
}

class ProgressRing extends StatelessWidget {
  ProgressRing({super.key, required this.value, this.size = 74, this.color = XyTheme.primary, this.label});
  final double value;
  final double size;
  final Color color;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(alignment: Alignment.center, children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: value.clamp(0, 1)),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
          builder: (_, v, __) => CustomPaint(
            size: Size.square(size),
            painter: _RingPainter(v, color),
          ),
        ),
        Text(label ?? '${(value * 100).round()}%',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: size * .21, letterSpacing: -.4)),
      ]),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.v, this.color);
  final double v;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final stroke = size.width * .10;
    canvas.drawArc(rect.deflate(stroke / 2), 0, math.pi * 2, false,
        Paint()..color = XyTheme.line..strokeWidth = stroke..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);
    canvas.drawArc(
      rect.deflate(stroke / 2),
      -math.pi / 2,
      math.pi * 2 * v,
      false,
      Paint()
        ..color = color
        ..strokeWidth = stroke
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.v != v;
}

class XyBarisMenu extends StatelessWidget {
  const XyBarisMenu({
    super.key,
    required this.ikon,
    required this.judul,
    required this.sub,
    this.onTap,
    this.tujuan,
    this.ikonWarna,
  }) : assert(onTap != null || tujuan != null, 'Isi onTap atau tujuan.');

  final IconData ikon;
  final String judul;
  final String sub;
  final VoidCallback? onTap;
  final Widget? tujuan;
  final Color? ikonWarna;

  @override
  Widget build(BuildContext context) {
    final t = XyTheme.of(context);
    final warna = ikonWarna ?? XyTheme.primary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(XyRadius.sm),
        onTap: onTap ?? () => Navigator.push(context, xyRoute(tujuan!)),
        child: Container(
          padding: const EdgeInsets.fromLTRB(4, 12, 2, 12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: t.lineSoft)),
          ),
          child: Row(children: [
            SizedBox(
              width: 38,
              height: 38,
              child: Icon(ikon, size: 21, color: warna),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(judul,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 3),
                Text(sub,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: t.muted, fontSize: 11.5)),
              ]),
            ),
            Icon(Icons.chevron_right_rounded, color: t.muted, size: 21),
          ]),
        ),
      ),
    );
  }
}

class XyLabel extends StatelessWidget {
  const XyLabel(this.teks, {super.key});
  final String teks;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 9, left: 2),
        child: Text(teks,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, letterSpacing: -.1)),
      );
}
