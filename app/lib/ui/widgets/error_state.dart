import 'package:flutter/material.dart';
import '../../core/theme.dart';
import 'common.dart';

/// ============================================================
///  Tampilan keadaan khusus: gagal muat, tanpa internet, kosong
/// ============================================================

/// Kartu galat besar dengan ilustrasi dan tombol coba lagi.
class GagalMuat extends StatelessWidget {
  const GagalMuat({
    super.key,
    required this.pesan,
    this.judul,
    this.onCoba,
    this.ilustrasi = 'error',
    this.rapat = false,
  });

  final String pesan;
  final String? judul;
  final VoidCallback? onCoba;
  final String ilustrasi;
  final bool rapat;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 30, vertical: rapat ? 16 : 36),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Stack(alignment: Alignment.center, children: [
            Container(
              width: rapat ? 150 : 200,
              height: rapat ? 150 : 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  XyTheme.violet.withOpacity(.14),
                  XyTheme.violet.withOpacity(.03),
                  Colors.transparent,
                ]),
              ),
            ),
            XyIlustrasi(ilustrasi, tinggi: rapat ? 132 : 178),
          ]),
          const SizedBox(height: 12),
          Text(
            judul ?? 'Ada yang tidak beres',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16.5, letterSpacing: -.3),
          ),
          const SizedBox(height: 8),
          Text(
            pesan,
            textAlign: TextAlign.center,
            style:  TextStyle(color: XyTheme.of(context).muted, fontSize: 13, height: 1.6),
          ),
          if (onCoba != null) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: 190,
              child: GradientButton(
                label: 'Coba Lagi',
                icon: Icons.refresh_rounded,
                height: 48,
                onPressed: onCoba,
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

/// Versi khusus ketika perangkat tidak terhubung internet.
class TanpaKoneksi extends StatelessWidget {
  const TanpaKoneksi({super.key, this.onCoba, this.rapat = false});
  final VoidCallback? onCoba;
  final bool rapat;

  @override
  Widget build(BuildContext context) => GagalMuat(
        judul: 'Tidak ada koneksi',
        pesan: 'Periksa data seluler atau Wi-Fi kamu, lalu coba lagi. '
            'Data yang sempat tersimpan tetap bisa dilihat.',
        ilustrasi: 'offline',
        onCoba: onCoba,
        rapat: rapat,
      );
}

/// Bilah tipis di atas layar saat aplikasi sedang memakai data tersimpan.
class BilahOffline extends StatelessWidget {
  const BilahOffline({super.key, required this.tampil, this.onCoba, this.keterangan});

  final bool tampil;
  final VoidCallback? onCoba;
  final String? keterangan;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
      child: tampil
          ? Container(
              width: double.infinity,
              color: XyTheme.warning.withOpacity(.12),
              padding: const EdgeInsets.fromLTRB(16, 9, 10, 9),
              child: Row(children: [
                const Icon(Icons.cloud_off_rounded, size: 16, color: XyTheme.warning),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    keterangan ?? 'Sedang offline, menampilkan data tersimpan',
                    style: const TextStyle(
                        fontSize: 11.8, fontWeight: FontWeight.w700, color: XyTheme.warnInk),
                  ),
                ),
                if (onCoba != null)
                  Pressable(
                    onTap: onCoba,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      child: Text('Muat ulang',
                          style: TextStyle(
                              fontSize: 11.8, fontWeight: FontWeight.w700, color: XyTheme.primary)),
                    ),
                  ),
              ]),
            )
          : const SizedBox(width: double.infinity, height: 0),
    );
  }
}
