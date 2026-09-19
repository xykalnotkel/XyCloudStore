import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/app_state.dart';
import '../widgets/common.dart';

/// Dokumen legal dari server: 'syarat' | 'privasi' | 'refund'.
/// Versi publik (bisa dibuka dari menu mana pun — Pengaturan, Tentang)
/// dengan isi yang sama persis seperti halaman /legal/... di browser.
class LegalScreen extends StatefulWidget {
  const LegalScreen({super.key, required this.jenis});
  final String jenis;

  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen> {
  Map<String, dynamic>? data;
  String? galat;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    try {
      final d = await context.read<AppState>().dokumenLegal(widget.jenis);
      if (mounted) setState(() {
        data = d;
        galat = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() =>
            galat = 'Tidak bisa memuat dokumen. Periksa koneksi internetmu.');
      }
    }
  }

  String get _judul {
    switch (widget.jenis) {
      case 'privasi':
        return 'Kebijakan Privasi';
      case 'refund':
        return 'Kebijakan Pengembalian Dana';
      case 'komunitas':
        return 'Panduan Komunitas';
      case 'live':
        return 'Ketentuan Kreator & Siaran';
      default:
        return 'Syarat dan Ketentuan';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_judul)),
      body: galat != null
          ? Kosong(
              icon: Icons.wifi_off_rounded,
              judul: 'Gagal memuat',
              sub: galat,
              ilustrasi: 'kosong')
          : data == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _muat,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 34),
                    children: [
                      Text('Pembaruan terakhir: ${data!['pembaruan']}',
                          style: TextStyle(
                              color: XyTheme.of(context).muted, fontSize: 12)),
                      const SizedBox(height: 18),
                      ...List.generate((data!['bagian'] as List).length, (i) {
                        final b = (data!['bagian'] as List)[i] as Map;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: XyCard(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Container(
                                      width: 26,
                                      height: 26,
                                      decoration: BoxDecoration(
                                        color: XyTheme.of(context).primarySoft,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Center(
                                        child: Text('${i + 1}',
                                            style: const TextStyle(
                                                color: XyTheme.primary,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 12)),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text('${b['judul']}',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14)),
                                    ),
                                  ]),
                                  const SizedBox(height: 8),
                                  Text('${b['teks']}',
                                      style: TextStyle(
                                          color: XyTheme.of(context).inkSoft,
                                          fontSize: 13,
                                          height: 1.65)),
                                ]),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
    );
  }
}
