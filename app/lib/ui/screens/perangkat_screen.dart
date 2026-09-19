import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../providers/app_state.dart';
import '../widgets/common.dart';
import '../widgets/lembar.dart';

/// ============================================================
///  Manajemen Perangkat Login (Active Sessions & Devices)
/// ============================================================
class PerangkatScreen extends StatefulWidget {
  const PerangkatScreen({super.key});

  @override
  State<PerangkatScreen> createState() => _PerangkatScreenState();
}

class _PerangkatScreenState extends State<PerangkatScreen> {
  List<Map<String, dynamic>> _devices = [];
  bool _memuat = true;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    setState(() => _memuat = true);
    final res = await context.read<AppState>().muatDaftarPerangkat();
    if (mounted) {
      setState(() {
        _devices = res;
        _memuat = false;
      });
    }
  }

  Future<void> _cabut(String? deviceId, String nama) async {
    final semua = deviceId == null;
    final yakin = await konfirmasi(
      context,
      judul: semua ? 'Keluarkan semua perangkat lain?' : 'Keluarkan perangkat ini?',
      pesan: semua
          ? 'Semua HP atau browser lain yang terhubung ke akun ini akan logout otomatis.'
          : 'Sesi di $nama akan langsung dicabut dan harus login ulang.',
      tombolYa: 'Keluarkan',
      bahaya: true,
    );

    if (!yakin || !mounted) return;

    final s = context.read<AppState>();
    final ok = await s.cabutAksesPerangkat(deviceId: deviceId);
    if (!mounted) return;

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(semua
              ? 'Berhasil logout dari semua perangkat lain.'
              : '$nama berhasil dikeluarkan.'),
        ),
      );
      _muat();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal mencabut sesi perangkat.')),
      );
    }
  }

  IconData _iconKind(String kind) {
    switch (kind.toLowerCase()) {
      case 'android':
        return Icons.phone_android_rounded;
      case 'ios':
        return Icons.phone_iphone_rounded;
      case 'windows':
        return Icons.laptop_windows_rounded;
      case 'browser':
        return Icons.language_rounded;
      default:
        return Icons.devices_rounded;
    }
  }

  String _formatWaktu(String? iso) {
    if (iso == null || iso.isEmpty) return 'Baru saja';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 2) return 'Baru saja';
      if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
      if (diff.inHours < 24) return '${diff.inHours} jam lalu';
      if (diff.inDays < 7) return '${diff.inDays} hari lalu';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return 'Baru saja';
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = XyTheme.of(context);
    final perangkatSaatIni = _devices.where((d) => d['is_current'] == true).toList();
    final perangkatLain = _devices.where((d) => d['is_current'] != true).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Perangkat Login')),
      body: _memuat
          ? const SkeletonList(count: 3)
          : RefreshIndicator(
              onRefresh: _muat,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 36),
                children: [
                  // Banner Header
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: XyTheme.gradPrimary,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: XyTheme.glow(XyTheme.primary, .2),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(.18),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.shield_rounded,
                              color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Keamanan Sesi Akun',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15.5,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Pantau perangkat yang aktif masuk ke akunmu dan cabut akses yang tidak kamu kenali.',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(.82),
                                  fontSize: 11.5,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SectionHeader('Perangkat Ini (Aktif)'),
                  if (perangkatSaatIni.isNotEmpty)
                    ...perangkatSaatIni.map((d) {
                      final model = d['model'] ?? 'Perangkat Ini';
                      final kind = d['kind'] ?? 'android';
                      final lastSeen = _formatWaktu(d['last_seen']);

                      return XyCard(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: XyTheme.success.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                _iconKind(kind),
                                color: XyTheme.success,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          model,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14.5,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: XyTheme.success.withOpacity(.15),
                                          borderRadius:
                                              BorderRadius.circular(XyRadius.pill),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            CircleAvatar(
                                              radius: 3,
                                              backgroundColor: XyTheme.success,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              'Aktif',
                                              style: TextStyle(
                                                color: XyTheme.success,
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Terakhir aktif: $lastSeen',
                                    style: TextStyle(
                                      color: pal.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    })
                  else
                    XyCard(
                      child: Row(
                        children: [
                          Icon(Icons.smartphone_rounded, color: pal.muted),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Aplikasi sedang berjalan pada perangkat ini.',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 10),
                  SectionHeader(
                    'Perangkat Lain yang Pernah Login',
                    sub: '${perangkatLain.length} perangkat',
                  ),

                  if (perangkatLain.isEmpty)
                    XyCard(
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: pal.lineSoft,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.check_circle_outline_rounded,
                                color: pal.muted, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Tidak ada perangkat lain yang terhubung ke akunmu. Akun ini hanya aktif di HP ini.',
                              style: TextStyle(
                                color: pal.muted,
                                fontSize: 12.5,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    ...perangkatLain.map((d) {
                      final model = d['model'] ?? 'Perangkat Lain';
                      final kind = d['kind'] ?? 'unknown';
                      final lastSeen = _formatWaktu(d['last_seen']);
                      final devId = d['device_id'] as String?;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: XyCard(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: pal.lineSoft,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  _iconKind(kind),
                                  color: pal.inkSoft,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      model,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Terakhir login: $lastSeen',
                                      style: TextStyle(
                                        color: pal.muted,
                                        fontSize: 11.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(60, 34),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10),
                                  foregroundColor: XyTheme.danger,
                                  side: BorderSide(
                                    color: XyTheme.danger.withOpacity(0.3),
                                  ),
                                ),
                                onPressed: () => _cabut(devId, model),
                                child: const Text(
                                  'Keluarkan',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: XyTheme.danger,
                        side: BorderSide(color: XyTheme.danger.withOpacity(0.4)),
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: () => _cabut(null, 'semua perangkat lain'),
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      label: const Text(
                        'Keluarkan dari Semua Perangkat Lain',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),
                  XyCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.lock_clock_rounded,
                                size: 17, color: XyTheme.primary),
                            SizedBox(width: 8),
                            Text(
                              'Kebijakan Sesi & Keamanan',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '• Setiap perangkat memiliki pengenal unik terlindung.\n'
                          '• Batas pendaftaran akun baru pada perangkat yang sama dibatasi maksimal 2 akun.\n'
                          '• Jika mencurigai aktivitas tidak wajar, segera keluarkan perangkat lain dan ganti kata sandi akunmu.',
                          style: TextStyle(
                            color: pal.muted,
                            fontSize: 12,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
