import 'package:flutter/material.dart';
import '../../core/theme.dart';
import 'common.dart';

/// ============================================================
///  Halaman saat server sedang mode pemeliharaan (HTTP 503)
/// ============================================================
///  Muncul menggantikan layar aplikasi ketika `AppState.perawatan` aktif,
///  supaya pengguna tidak bingung melihat galat. Desain sendiri khas
///  XyCloudStore, tanpa emoji.
class PerawatanScreen extends StatelessWidget {
  const PerawatanScreen({
    super.key,
    required this.pesan,
    this.onCoba,
    this.onKeluar,
    this.onMasuk,
  });

  final String pesan;
  final VoidCallback? onCoba;
  final VoidCallback? onKeluar;

  /// Bila diisi, menampilkan jalan masuk kecil untuk staf internal yang
  /// dikecualikan dari pemeliharaan (lihat setelan `pemeliharaan_bebas`),
  /// supaya mereka bisa login dan menguji aplikasi meski mode menyala.
  final VoidCallback? onMasuk;

  @override
  Widget build(BuildContext context) {
    final gelap = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: XyTheme.of(context).bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Ilustrasi baru (transparan, tanpa latar & tanpa bingkai lingkaran).
                Stack(alignment: Alignment.center, children: [
                  Container(
                    width: 240,
                    height: 190,
                    decoration: BoxDecoration(
                      shape: BoxShape.rectangle,
                      gradient: RadialGradient(
                        colors: [
                          XyTheme.primary.withOpacity(.16),
                          XyTheme.violet.withOpacity(.05),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  Image.asset(
                    'assets/ilustrasi/maintenance.webp',
                    width: 176,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.engineering_rounded,
                      size: 60,
                      color: XyTheme.primary,
                    ),
                  ),
                ]),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                  decoration: BoxDecoration(
                    color: XyTheme.of(context).surface,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: XyTheme.of(context).line),
                    boxShadow: XyTheme.shadowXs,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _TitikPulsa(),
                      const SizedBox(width: 8),
                      Text(
                        'Sedang Perawatan',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                          color: XyTheme.of(context).accent,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Kami Sebentar Lagi',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 21,
                    letterSpacing: -.6,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Kami sedang menyempurnakan layanan sebentar. '
                  'Data dan saldo kamu aman — tinggal tunggu sampai selesai.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: XyTheme.of(context).muted,
                    fontSize: 13.5,
                    height: 1.6,
                  ),
                ),
                if (pesan.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: gelap ? XyTheme.lineGelap.withOpacity(.5) : XyTheme.of(context).primarySoft,
                      borderRadius: BorderRadius.circular(XyRadius.lg),
                      border: Border.all(
                          color: gelap ? XyTheme.lineGelap : XyTheme.of(context).line),
                    ),
                    child: Text(
                      pesan,
                      textAlign: TextAlign.center,
                      style:  TextStyle(fontSize: 12, height: 1.5, color: XyTheme.of(context).muted),
                    ),
                  ),
                ],
                const SizedBox(height: 26),
                if (onCoba != null) ...[
                  SizedBox(
                    width: 210,
                    child: GradientButton(
                      label: 'Coba Lagi',
                      icon: Icons.refresh_rounded,
                      height: 50,
                      onPressed: onCoba,
                    ),
                  ),
                ],
                if (onMasuk != null) ...[
                  const SizedBox(height: 16),
                  InkWell(
                    borderRadius: BorderRadius.circular(99),
                    onTap: onMasuk,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock_outline_rounded,
                              size: 13, color: XyTheme.of(context).muted.withOpacity(.75)),
                          const SizedBox(width: 6),
                          Text(
                            'Staf internal? Masuk untuk uji',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: XyTheme.of(context).muted.withOpacity(.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (onKeluar != null) ...[
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: onKeluar,
                    child: Text(
                      'Keluar dari akun ini',
                      style: TextStyle(
                        color: XyTheme.of(context).muted,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                        decorationColor: XyTheme.of(context).muted.withOpacity(.5),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Titik kecil pada lencana "Sedang Perawatan".
class _TitikPulsa extends StatelessWidget {
  const _TitikPulsa();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: XyTheme.of(context).accent.withOpacity(.8),
      ),
    );
  }
}
