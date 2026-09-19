import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../data/device_identity.dart';
import '../../providers/app_state.dart';
import '../widgets/common.dart';
import 'perangkat_screen.dart';

/// Aktivitas & Keamanan — audit login pribadi + device terdaftar
class AktivitasScreen extends StatefulWidget {
  const AktivitasScreen({super.key});
  @override
  State<AktivitasScreen> createState() => _AktivitasScreenState();
}

class _AktivitasScreenState extends State<AktivitasScreen> {
  List<dynamic> audit = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      await DeviceIdentity.prepare();
      final did = DeviceIdentity.id;
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      setState(() {
        audit = [
          {'aksi': 'LOGIN', 'waktu': DateTime.now().subtract(const Duration(minutes: 5)), 'detail': 'Login via Android • device ${did.isEmpty ? '-' : did.substring(0, 8)}...', 'ip': '114.10.x.x'},
          {'aksi': 'SEWA', 'waktu': DateTime.now().subtract(const Duration(hours: 2)), 'detail': 'Sewa PC RTX 4070 3 jam', 'ip': '-'},
          {'aksi': 'BELI_AKUN', 'waktu': DateTime.now().subtract(const Duration(days: 1)), 'detail': 'Beli Akun Steam Premium', 'ip': '-'},
          {'aksi': 'OTP', 'waktu': DateTime.now().subtract(const Duration(days: 2)), 'detail': 'Verifikasi OTP email berhasil', 'ip': '114.10.x.x'},
        ];
        loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AppState>();
    final deviceId = DeviceIdentity.id.isEmpty ? 'menyiapkan...' : DeviceIdentity.id;

    return Scaffold(
      appBar: AppBar(title: const Text('Aktivitas & Keamanan')),
      body: loading
          ? const SkeletonList(count: 5)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [XyTheme.bgGelap, XyTheme.primary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(color: Colors.white.withOpacity(.15), borderRadius: BorderRadius.circular(14)),
                      child: const Icon(Icons.security_rounded, color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Perangkat Terpercaya',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                        const SizedBox(height: 4),
                        Text('Device ID: ${deviceId.substring(0, 12)}... • Max 2 akun per device',
                            style: const TextStyle(color: Colors.white70, fontSize: 11)),
                      ]),
                    ),
                  ]),
                ),
                const SectionHeader('Device Saat Ini'),
                XyCard(
                  child: Column(children: [
                    Row(children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(color: XyTheme.okBright.withOpacity(.12), borderRadius: BorderRadius.circular(10)),
                        child: Icon(Icons.smartphone_rounded, color: XyTheme.okBright),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('HP Ini', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                          const SizedBox(height: 2),
                          Text(deviceId, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: XyTheme.of(context).muted, fontSize: 10.5, fontFamily: 'monospace')),
                        ]),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: XyTheme.okBright.withOpacity(.15), borderRadius: BorderRadius.circular(20)),
                        child: Text('Aktif', style: TextStyle(color: XyTheme.okBright, fontWeight: FontWeight.w700, fontSize: 10)),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: XyTheme.of(context).primarySoft, borderRadius: BorderRadius.circular(10)),
                      child: Row(children: [
                        Icon(Icons.info_outline_rounded, size: 14, color: XyTheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Keamanan: 1 device max 2 akun. Jika ganti HP, akun lama tetap aman. Hubungi admin jika device terblokir.',
                            style: TextStyle(color: XyTheme.of(context).muted, fontSize: 11, height: 1.4),
                          ),
                        ),
                      ]),
                    ),
                  ]),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(context, xyRoute(const PerangkatScreen())),
                  icon: const Icon(Icons.devices_rounded, size: 18),
                  label: const Text('Kelola Semua Perangkat Login'),
                ),
                const SectionHeader('Riwayat Aktivitas'),
                ...audit.map((a) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: XyCard(
                        padding: const EdgeInsets.all(14),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: _colorAksi(a['aksi'] as String).withOpacity(.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(_iconAksi(a['aksi'] as String), size: 18, color: _colorAksi(a['aksi'] as String)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [
                                Text(a['aksi'] as String, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                                const SizedBox(width: 8),
                                Text(_fmtWaktu(a['waktu'] as DateTime), style: TextStyle(color: XyTheme.of(context).muted, fontSize: 10.5)),
                              ]),
                              const SizedBox(height: 3),
                              Text(a['detail'] as String, style: TextStyle(color: XyTheme.of(context).inkSoft.withOpacity(.85), fontSize: 12.5)),
                              if ((a['ip'] as String) != '-')
                                Padding(
                                  padding: const EdgeInsets.only(top: 3),
                                  child: Text('IP: ${a['ip']}', style: TextStyle(color: XyTheme.of(context).muted, fontSize: 10)),
                                ),
                            ]),
                          ),
                        ]),
                      ),
                    )),
                const SizedBox(height: 12),
                XyCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Tips Keamanan', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text(
                      '• Jangan bagikan OTP ke siapapun\n• Gunakan email pribadi, bukan email bersama\n• Jika ada login mencurigakan, segera ganti password di menu Keamanan\n• Device dibatasi 2 akun untuk mencegah abuse voucher',
                      style: TextStyle(color: XyTheme.of(context).muted, fontSize: 12.5, height: 1.6),
                    ),
                  ]),
                ),
              ],
            ),
            ),
    );
  }

  Color _colorAksi(String aksi) {
    switch (aksi) {
      case 'LOGIN':
        return XyTheme.primary;
      case 'SEWA':
        return XyTheme.okBright;
      case 'BELI_AKUN':
        return XyTheme.plum;
      case 'OTP':
        return XyTheme.goldSoft;
      default:
        return XyTheme.muted;
    }
  }

  IconData _iconAksi(String aksi) {
    switch (aksi) {
      case 'LOGIN':
        return Icons.login_rounded;
      case 'SEWA':
        return Icons.desktop_windows_rounded;
      case 'BELI_AKUN':
        return Icons.shopping_bag_rounded;
      case 'OTP':
        return Icons.verified_user_rounded;
      default:
        return Icons.history_rounded;
    }
  }

  String _fmtWaktu(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m lalu';
    if (diff.inHours < 24) return '${diff.inHours}j lalu';
    if (diff.inDays < 7) return '${diff.inDays}h lalu';
    return '${d.day}/${d.month}/${d.year}';
  }
}
