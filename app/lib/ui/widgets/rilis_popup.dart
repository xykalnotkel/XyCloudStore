import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../providers/app_state.dart';
import '../screens/pembaruan_screen.dart';

/// ============================================================
///  RilisPopup — popup saat ada versi baru (Violet-Indigo Glossy v3.2)
/// ============================================================
///  Sistem theming popup:
///  - Gambar default: assets/ilustrasi/rilis_popup.webp (violet-indigo glossy)
///  - Varian tema: rilis_popup_{tema}.webp (misal ramadan, idulfitri, natal, tahunbaru)
///  - Prioritas: 1) gambar dari server (rilis.gambar), 2) aset tema lokal, 3) default
///  - Tombol X putih glossy di pojok kanan atas → buka PembaruanScreen
///
///  Warna referensi popup (lihat docs/PopupUpdate.md):
///  - BG indigo tua: #100030 / #200050
///  - Aksen violet glossy: #7C3AED / #8B5CF6 / #A855F7
///  - Gradien hero: #A78BFA → #7C3AED (top→bottom glossy)
Future<void> tampilkanRilisPopup(BuildContext context, AppState s) async {
  final hasil = await showGeneralDialog<String>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Rilis',
    barrierColor: XyTheme.bgGelap.withOpacity(.68), // indigo tua barrier
    transitionDuration: const Duration(milliseconds: 260),
    transitionBuilder: (_, anim, __, child) => FadeTransition(
      opacity: anim,
      child: ScaleTransition(
        scale: Tween<double>(begin: .92, end: 1).animate(
          CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
        ),
        child: child,
      ),
    ),
    pageBuilder: (_, __, ___) => RilisPopup(rilis: s.rilisTerbaru),
  );
  if (hasil == 'buka' && context.mounted) {
    Navigator.of(context, rootNavigator: true)
        .push(MaterialPageRoute(builder: (_) => const PembaruanScreen()));
  }
}

class RilisPopup extends StatelessWidget {
  const RilisPopup({super.key, this.rilis});
  final Map<String, dynamic>? rilis;

  String _assetUntukTema(String? tema) {
    if (tema == null || tema.isEmpty) return 'assets/ilustrasi/rilis_popup.webp';
    final t = tema.toLowerCase().trim();
    // Daftar tema yang didukung (file harus ada di assets/ilustrasi/)
    const supported = [
      'ramadan',
      'idulfitri',
      'lebaran',
      'natal',
      'tahunbaru',
      'imlek',
      'kemerdekaan',
      'halloween',
      'default'
    ];
    if (supported.contains(t)) {
      if (t == 'default') return 'assets/ilustrasi/rilis_popup.webp';
      return 'assets/ilustrasi/rilis_popup_$t.webp';
    }
    // fallback: coba pakai nama tema langsung
    return 'assets/ilustrasi/rilis_popup_$t.webp';
  }

  @override
  Widget build(BuildContext context) {
    final gambarServer = (rilis?['gambar'] as String?)?.trim() ?? '';
    final tema = (rilis?['tema'] as String?)?.trim() ?? // optional field tema
        (rilis?['kategori'] as String?)?.trim() ??
        '';
    final assetLokal = _assetUntukTema(tema.isEmpty ? null : tema);

    Widget gambarWidget;
    if (gambarServer.isNotEmpty) {
      // Gambar dari server (AI per rilis, bisa themed)
      gambarWidget = Image.network(
        gambarServer,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        loadingBuilder: (_, child, prog) => prog == null
            ? child
            : Container(
                decoration: BoxDecoration(gradient: XyTheme.gradMidnight),
                child: const Center(
                  child: CircularProgressIndicator(
                    color: XyTheme.lavender,
                    strokeWidth: 2.5,
                  ),
                ),
              ),
        errorBuilder: (_, __, ___) => Image.asset(
          assetLokal,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Image.asset(
            'assets/ilustrasi/rilis_popup.webp',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              decoration: BoxDecoration(gradient: XyTheme.gradPrimary),
            ),
          ),
        ),
      );
    } else {
      gambarWidget = Image.asset(
        assetLokal,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Image.asset(
          'assets/ilustrasi/rilis_popup.webp',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            decoration: BoxDecoration(gradient: XyTheme.gradPrimary),
          ),
        ),
      );
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 40),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: AspectRatio(
          aspectRatio: 928 / 1152,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Gambar popup penuh (morphing glossy violet-indigo, teks baked-in)
              gambarWidget,

              // Glow tipis di atas biar kesan glossy (sesuai tema)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(.18),
                          Colors.transparent,
                          Colors.transparent,
                          XyTheme.bgGelap.withOpacity(.12),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0, .32, .72, 1],
                      ),
                    ),
                  ),
                ),
              ),

              // Tombol X — putih glossy, tutup popup lalu buka layar pembaruan
              Positioned(
                top: 14,
                right: 14,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context, 'buka'),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.92),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: XyTheme.lavender.withOpacity(.6),
                          width: 1),
                      boxShadow: [
                        BoxShadow(
                            color: XyTheme.bgGelap.withOpacity(.22),
                            blurRadius: 14,
                            offset: const Offset(0, 4)),
                        BoxShadow(
                            color: XyTheme.violet.withOpacity(.18),
                            blurRadius: 18,
                            offset: const Offset(0, 8)),
                      ],
                    ),
                    child: const Icon(Icons.close_rounded,
                        size: 22, color: XyTheme.primaryDark),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
