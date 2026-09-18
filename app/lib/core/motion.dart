import 'pengaturan.dart';
import 'package:flutter/material.dart';

/// ============================================================
///  Gerak dan transisi halaman XyCloudStore
/// ============================================================
///  Kebijakan gerak 2026-09-18: PERPINDAHAN HALAMAN TIDAK MEMAKAI FADE.
///  Semua route memakai geser (slide) murni supaya arah navigasi terbaca
///  dan halaman tidak "berkedip" lewat transparansi:
///    - xyRoute      : geser horizontal ala material-ios hybrid; halaman
///                     yang tertutup ikut mundur seperempat layar (parallax).
///    - xyRouteBawah : geser vertikal penuh untuk halaman formulir/modal.
///    - xyRouteBesar : geser vertikal + settle untuk alur besar
///                     (splash → onboarding → shell).
///  Konten masuk (stagger) memakai FadeInUp yang juga sudah tanpa opacity:
///  hanya translate, lihat widgets/common.dart.

const Duration _durasi = Duration(milliseconds: 360);
const Duration _durasiBalik = Duration(milliseconds: 300);

Route<T> xyRoute<T>(Widget page, {bool fullscreen = false}) {
  return PageRouteBuilder<T>(
    fullscreenDialog: fullscreen,
    transitionDuration: PengaturanLokal.animasi ? _durasi : Duration.zero,
    reverseTransitionDuration: PengaturanLokal.animasi ? _durasiBalik : Duration.zero,
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, masuk, keluar, child) {
      final a = CurvedAnimation(
        parent: masuk,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      // `keluar` adalah secondaryAnimation: berjalan saat route ini DITUTUPI
      // route lain — dipakai untuk parallax halaman yang ditinggalkan.
      final t = CurvedAnimation(
        parent: keluar,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(a),
        child: SlideTransition(
          position: Tween<Offset>(begin: Offset.zero, end: const Offset(-.24, 0)).animate(t),
          child: child,
        ),
      );
    },
  );
}

/// Transisi dari bawah (halaman formulir / modal). Geser penuh, tanpa fade.
Route<T> xyRouteBawah<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: PengaturanLokal.animasi ? _durasi : Duration.zero,
    reverseTransitionDuration: PengaturanLokal.animasi ? _durasiBalik : Duration.zero,
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, a, keluar, child) {
      final k = CurvedAnimation(parent: a, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
      final t = CurvedAnimation(parent: keluar, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
      return SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(k),
        child: SlideTransition(
          position: Tween<Offset>(begin: Offset.zero, end: const Offset(0, -.06)).animate(t),
          child: child,
        ),
      );
    },
  );
}

/// Transisi alur besar (splash, onboarding, shell): geser naik + settle
/// skala tipis. Tanpa opacity supaya tidak terasa seperti fade-in.
Route<T> xyRouteBesar<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: PengaturanLokal.animasi ? const Duration(milliseconds: 460) : Duration.zero,
    reverseTransitionDuration: PengaturanLokal.animasi ? _durasiBalik : Duration.zero,
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, a, __, child) {
      final k = CurvedAnimation(parent: a, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
      return SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, .10), end: Offset.zero).animate(k),
        child: ScaleTransition(
          scale: Tween<double>(begin: 1.04, end: 1).animate(k),
          child: child,
        ),
      );
    },
  );
}

/// Pergantian isi tab bawah: geser mikro vertikal, tanpa fade, supaya
/// berpindah tab tidak berkedip dan tidak terasa seperti halaman baru.
class TukarHalus extends StatelessWidget {
  const TukarHalus({super.key, required this.child, this.kunci});
  final Widget child;
  final Key? kunci;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
        duration: PengaturanLokal.animasi ? const Duration(milliseconds: 220) : Duration.zero,
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (anak, a) => SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, .015), end: Offset.zero).animate(a),
          child: anak,
        ),
        child: KeyedSubtree(key: kunci, child: child),
      );
}
