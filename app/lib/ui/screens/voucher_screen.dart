import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/app_state.dart';
import '../widgets/common.dart';

/// Voucher Saya — cek kode voucher dan cara pakai.
/// Backend tidak menyediakan daftar voucher milik pengguna, hanya validasi
/// kode saat checkout (`/voucher/cek`), jadi layar ini dipakai untuk
/// memverifikasi kode promo yang didapat user sebelum checkout.
class VoucherScreen extends StatefulWidget {
  const VoucherScreen({super.key});
  @override
  State<VoucherScreen> createState() => _VoucherScreenState();
}

class _VoucherScreenState extends State<VoucherScreen> {
  final TextEditingController _kode = TextEditingController();
  bool loading = false;
  Map<String, dynamic>? hasil;
  String? err;

  @override
  void dispose() {
    _kode.dispose();
    super.dispose();
  }

  Future<void> _cek() async {
    final kode = _kode.text.trim();
    if (kode.isEmpty) {
      setState(() { err = 'Masukkan kode voucher dulu.'; hasil = null; });
      return;
    }
    setState(() { loading = true; err = null; hasil = null; });
    final s = context.read<AppState>();
    final d = await s.cekVoucher(kode: kode, jenis: 'sewa', total: 0);
    if (!mounted) return;
    setState(() {
      loading = false;
      if (d != null && d['error'] == null) {
        hasil = d;
      } else {
        err = s.error ?? 'Kode voucher tidak berlaku.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = XyTheme.of(context);
    final potongan = hasil?['potongan'] is num ? (hasil?['potongan'] as num).toInt() : 0;
    return Scaffold(
      appBar: AppBar(title: const Text('Voucher Saya')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [XyTheme.bgGelap, XyTheme.primary], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(20),
              boxShadow: XyTheme.glow(XyTheme.primary, .22),
            ),
            child: Row(children: [
              const XyIlustrasi('voucher', tinggi: 72),
              const SizedBox(width: 14),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Punya kode voucher?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                SizedBox(height: 4),
                Text('Cek dulu di sini, lalu masukkan saat checkout sewa PC atau beli akun.', style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4)),
              ])),
            ]),
          ),
          const SizedBox(height: 16),
          XyCard(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Cek Kode Voucher', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
              const SizedBox(height: 10),
              TextField(
                controller: _kode,
                textCapitalization: TextCapitalization.characters,
                onSubmitted: (_) => _cek(),
                decoration: InputDecoration(
                  hintText: 'contoh: HEMAT10',
                  hintStyle: TextStyle(color: t.muted.withOpacity(.7), fontSize: 14),
                  filled: true,
                  fillColor: t.surface,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: t.line)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: t.line)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: XyTheme.primary, width: 1.6)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: loading ? null : _cek,
                  icon: loading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.verified_rounded, size: 18),
                  label: Text(loading ? 'Memeriksa...' : 'Cek Kode'),
                ),
              ),
              if (err != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: XyTheme.danger.withOpacity(.1), borderRadius: BorderRadius.circular(14)),
                    child: Text(err!, style: const TextStyle(color: XyTheme.danger, fontWeight: FontWeight.w700, fontSize: 12.5)),
                  ),
                ),
              if (hasil != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: XyTheme.success.withOpacity(.1), borderRadius: BorderRadius.circular(14)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Voucher berlaku!', style: TextStyle(color: XyTheme.success, fontWeight: FontWeight.w700, fontSize: 13)),
                      const SizedBox(height: 6),
                      Text(
                        potongan > 0
                            ? 'Potongan: $potongan (persen)${hasil?['keterangan'] != null ? ' — ${hasil!['keterangan']}' : ''}'
                            : '${hasil?['keterangan'] ?? 'Voucher valid.'}',
                        style: const TextStyle(fontSize: 12.5, height: 1.5),
                      ),
                      const SizedBox(height: 6),
                      const Text('Masukkan kode ini di halaman checkout untuk memakainya.', style: TextStyle(fontSize: 12)),
                    ]),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 16),
          XyCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Cara pakai', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('1. Pilih paket PC atau produk akun\n2. Di halaman checkout, tap "Pakai Voucher"\n3. Masukkan kode — potongan langsung terhitung\n4. Voucher tidak bisa digabung & ada minimal belanja',
                  style: TextStyle(color: t.muted, fontSize: 12.5, height: 1.7)),
            ]),
          ),
        ],
      ),
    );
  }
}
