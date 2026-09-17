import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme.dart';
import '../../providers/app_state.dart';
import '../../data/pembaruan_channel.dart';
import '../widgets/common.dart';
import '../widgets/morph_bg.dart';

/// ============================================================
///  PembaruanScreen — lihat rilis baru & perbarui aplikasi
/// ============================================================
///  Dibuka dari popup rilis (X) atau Pengaturan. Menampilkan gambar
///  rilis (custom per versi via `/rilis.gambar`, fallback aset generik),
///  catatan, dan tombol "Perbarui Sekarang".
class PembaruanScreen extends StatefulWidget {
  const PembaruanScreen({super.key});
  @override
  State<PembaruanScreen> createState() => _PembaruanScreenState();
}

class _PembaruanScreenState extends State<PembaruanScreen> {
  bool _mulai = false;
  String _status = '';

  Map<String, dynamic>? get _r =>
      context.read<AppState>().rilisTerbaru;
  String get _versi => '${_r?['versi'] ?? ''}';

  /// Pilih berkas APK utama (arm64 dulu), kalau ada.
  String? _urlApk() {
    final berkas = ((_r?['berkas']) ?? const []) as List;
    if (berkas.isEmpty) return null;
    berkas.sort((a, b) => ((b is Map && b['utama'] == true) ? 1 : 0) -
        ((a is Map && a['utama'] == true) ? 1 : 0));
    for (final b in berkas) {
      if (b is Map) {
        final u = b['url'];
        if (u is String && u.isNotEmpty) return u;
      }
    }
    return null;
  }

  Future<void> _perbarui() async {
    setState(() => _status = 'Memeriksa unduhan…');
    final url = _urlApk();
    if (url == null) {
      setState(() => _status = 'Berkas belum tersedia. Coba lagi nanti.');
      return;
    }
    // Unduhan disajikan lewat domain sendiri (xycloud.my.id/unduh/…).
    final penuh = url.startsWith('http')
        ? url
        : 'https://xycloud.my.id$url';

    if (await PembaruanChannel.tersedia()) {
      setState(() => _status = 'Mengunduh via notifikasi…');
      final id = await PembaruanChannel.unduh(
          url: penuh,
          judul: 'XyCloudStore',
          versi: _versi);
      if (id == null) {
        setState(() => _status = 'Unduhan gagal dimulai. Coba buka tautan manual.');
        return;
      }
      setState(() => _status = 'Unduhan berjalan — progress ada di notifikasi.');
    } else {
      // Fallback aman: buka halaman unduh web (mode dev / native belum dipasang).
      setState(() => _status = 'Membuka halaman unduh…');
      final u = Uri.parse('https://xycloud.my.id/unduh');
      if (await canLaunchUrl(u)) await launchUrl(u);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final r = s.rilisTerbaru;
    final catatan = '${r?['catatan'] ?? ''}';
    final gambar = '${r?['gambar'] ?? ''}';
    final skema = Theme.of(context).brightness == Brightness.dark;

    // gambar rilis (AI per update), atau fallback ilustrasi update bawaan.
    final hero = gambar.isEmpty
        ? Image.asset('assets/ilustrasi/update.webp',
            height: 210,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const XyIlustrasi('update', tinggi: 210))
        : Image.network(gambar,
            height: 210,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.low,
            loadingBuilder: (_, anak, p) => p == null
                ? anak
                : const Shimmer(height: 210),
            errorBuilder: (_, __, ___) =>
                Image.asset('assets/ilustrasi/update.webp',
                    height: 210, fit: BoxFit.contain));

    return Scaffold(
      backgroundColor: XyTheme.of(context).bg,
      appBar: AppBar(
        title: const Text('Pembaruan', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_forward_rounded),
            tooltip: 'Buka halaman unduh web',
            onPressed: () async {
              await launchUrl(Uri.parse('https://xycloud.my.id/unduh'));
            },
          ),
        ],
      ),
      body: Stack(children: [
        // latar morphing elemen melayang (ringan; auto-stop saat tab tak aktif)
        const Positioned.fill(child: IgnorePointer(child: XyMorphBg())),
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 40),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            RepaintBoundary(
              child: Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.symmetric(vertical: 26),
                decoration: BoxDecoration(
                  gradient: XyTheme.gradPrimary,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: XyTheme.glow(XyTheme.primary, .22),
                ),
                child: Column(children: [
                  if (_versi.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: skema ? Colors.white.withOpacity(.18) : Colors.white.withOpacity(.7),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text('Versi baru $_versi',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: skema ? Colors.white : XyTheme.primaryDeep)),
                    ),
                  const SizedBox(height: 8),
                  Text('Ada Pembaruan Baru',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 22,
                          letterSpacing: -.6,
                          color: skema ? Colors.white : XyTheme.primaryDark)),
                  Text('Fitur makin mulus & cepat.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: skema ? Colors.white.withOpacity(.85) : Colors.white,
                          fontSize: 13)),
                ]),
              ),
            ),

            // gambar murni / ilustrasi rilis
            Center(child: hero),
            const SizedBox(height: 14),

            Text('Apa yang baru',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 8),
            XyCard(
              padding: const EdgeInsets.all(16),
              child: catatan.trim().isEmpty
                  ? Text('Buka halaman unduh untuk melihat catatan rilis lengkap.',
                      style: TextStyle(color: XyTheme.of(context).muted, fontSize: 13))
                  : SelectableText(catatan,
                      style: const TextStyle(fontSize: 13.5, height: 1.7)),
            ),

            const SizedBox(height: 22),
            if (_status.isNotEmpty) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: XyTheme.of(context).primarySoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_status, style: const TextStyle(fontSize: 12.5))),
                ]),
              ),
            ],
            GradientButton(
              label: 'Perbarui Sekarang',
              icon: Icons.system_update_alt_rounded,
              loading: _mulai,
              onPressed: _mulai ? null : _perbarui,
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: () async {
                await launchUrl(Uri.parse('https://xycloud.my.id/unduh'));
              },
              icon: const Icon(Icons.open_in_new_rounded, size: 17),
              label: const Text('Lewati, buka halaman unduh'),
            ),
          ]),
        ),
      ]),
    );
  }
}
