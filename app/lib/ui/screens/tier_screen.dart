import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../providers/app_state.dart';
import '../widgets/common.dart';

/// ============================================================
///  Tier & Benefit — progres NYATA (Batch I)
/// ============================================================
///  Definisi tier disamakan dengan server (api/src/loyal.js):
///  basic 0 / pro 300.000 / vip 1.500.000 dari total belanja lunas.
class _Tingkat {
  const _Tingkat(this.id, this.nama, this.min, this.warna, this.badge,
      this.manfaat);
  final String id;
  final String nama;
  final int min;
  final Color warna;
  final String badge;
  final List<String> manfaat;
}

const _tingkat = [
  _Tingkat('basic', 'Basic', 0, Color(0xFF7C7391), 'badge_basic', [
    'Akses semua paket rental PC dan produk digital',
    'Chat admin & customer support 24/7',
    'Transfer saldo antar pengguna dengan PIN aman',
    '5 tema banner profil standar',
    'Akses penuh komunitas dan feed publik',
  ]),
  _Tingkat('pro', 'Pro', 300000, XyTheme.violet, 'badge_pro', [
    'Diskon 3% otomatis tiap transaksi',
    'Prioritas antrean unit PC sewa',
    'Lencana 3D Pro eksklusif di profil & feed',
    'Banner profil animasi GIF & video (auto-GIF tanpa jeda)',
    'Bingkai avatar premium Aurora & Permata',
    'Kapasitas preset HUD kustom tambahan',
  ]),
  _Tingkat('vip', 'VIP', 1500000, XyTheme.goldSoft, 'badge_vip', [
    'Diskon 7% otomatis tiap transaksi sewa & produk',
    'Prioritas antrean tertinggi saat server penuh',
    'Lencana 3D VIP Gold berkilau di samping nama',
    '8 Bingkai avatar eksklusif VIP (Celestial, Sakura, Cyber, Nebula, dll)',
    'Gaya tampilan nama khusus (warna, glow, animasi)',
    'Banner profil animasi GIF tanpa batas durasi',
    'Customer service jalur cepat (VIP Fast-Lane)',
    'Semua benefit Basic & Pro otomatis aktif',
  ]),
];

class TierScreen extends StatelessWidget {
  const TierScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = XyTheme.of(context);
    final u = context.watch<AppState>().user;
    final belanja = u?.totalBelanja ?? 0;
    final tierKu = u?.tier ?? 'basic';
    final idxKu = _tingkat.indexWhere((x) => x.id == tierKu).clamp(0, 2);
    final sekarang = _tingkat[idxKu];
    final berikutnya = idxKu < _tingkat.length - 1 ? _tingkat[idxKu + 1] : null;

    // Progres menuju tier berikutnya (dari dasar tier sekarang).
    final rentang = berikutnya == null
        ? 1
        : (berikutnya.min - sekarang.min).clamp(1, 1 << 31);
    final maju = berikutnya == null
        ? 1.0
        : ((belanja - sekarang.min) / rentang).clamp(0.0, 1.0);
    final kurang = berikutnya == null ? 0 : (berikutnya.min - belanja).clamp(0, 1 << 31);
    final persenMaju = (maju * 100).toInt();

    return Scaffold(
      appBar: AppBar(title: const Text('Tier & Benefit')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
        children: [
          // ---------- kartu progres ----------
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF1E1730), XyTheme.primaryDark, sekarang.warna.withOpacity(.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(XyRadius.lg),
              boxShadow: XyTheme.glow(sekarang.warna, .25),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(.25)),
                  ),
                  child: Center(
                    child: Image.asset(
                      'assets/brand/${sekarang.badge}.webp',
                      width: 46,
                      height: 46,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(Icons.stars_rounded, color: Colors.white, size: 30),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('Tier ${sekarang.nama}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                  letterSpacing: -.4)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(.2),
                              borderRadius: BorderRadius.circular(XyRadius.pill),
                            ),
                            child: Text('$persenMaju%',
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        berikutnya == null
                            ? 'Tier tertinggi — semua benefit eksklusif aktif!'
                            : 'Belanja ${rupiah(kurang)} lagi menuju ${berikutnya.nama}',
                        style: TextStyle(
                            color: Colors.white.withOpacity(.82),
                            fontSize: 11.8,
                            height: 1.4),
                      ),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 18),
              // Bar progres benefit.
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: Stack(children: [
                  Container(
                    height: 12,
                    color: Colors.white.withOpacity(.16),
                  ),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: maju),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, __) => FractionallySizedBox(
                      widthFactor: v,
                      child: Container(
                        height: 12,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFD8C9FF), Colors.white],
                          ),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Text(rupiah(belanja),
                    style: TextStyle(
                        color: Colors.white.withOpacity(.85),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700)),
                const Spacer(),
                if (berikutnya != null)
                  Text(rupiah(berikutnya.min),
                      style: TextStyle(
                          color: Colors.white.withOpacity(.85),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.10),
                    borderRadius: BorderRadius.circular(13)),
                child: Row(children: [
                  const Icon(Icons.info_outline_rounded,
                      color: Colors.white70, size: 15),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Total belanja kamu dihitung dari pesanan sewa & produk digital yang lunas — akumulasi otomatis tanpa hangus.',
                      style: TextStyle(
                          color: Colors.white.withOpacity(.82),
                          fontSize: 10.8,
                          height: 1.4),
                    ),
                  ),
                ]),
              ),
            ]),
          ),

          const SectionHeader('Level & Benefit'),
          ..._tingkat.map((x) {
            final tercapai = belanja >= x.min || tierKu == x.id ||
                _tingkat.indexWhere((e) => e.id == tierKu) >=
                    _tingkat.indexOf(x);
            final aktif = tierKu == x.id;
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: XyCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: x.warna.withOpacity(.12),
                            borderRadius: BorderRadius.circular(14),
                            border:
                                Border.all(color: x.warna.withOpacity(.25)),
                          ),
                          child: Center(
                            child: Image.asset(
                              'assets/brand/${x.badge}.webp',
                              width: 38,
                              height: 38,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => Icon(Icons.stars_rounded, color: x.warna, size: 24),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Text(x.nama,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16)),
                                  if (aktif) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        gradient: XyTheme.gradPrimary,
                                        borderRadius: BorderRadius.circular(
                                            XyRadius.pill),
                                      ),
                                      child: const Text('TIER KAMU',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 8,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: .6)),
                                    ),
                                  ],
                                ]),
                                const SizedBox(height: 2),
                                Text(
                                    x.min == 0
                                        ? 'Langsung aktif saat mendaftar'
                                        : 'Minimal total belanja ${rupiah(x.min)}',
                                    style: TextStyle(
                                        color: t.muted, fontSize: 11.5)),
                              ]),
                        ),
                        if (x.id != 'basic')
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: x.warna.withOpacity(.14),
                              borderRadius:
                                  BorderRadius.circular(XyRadius.pill),
                            ),
                            child: Text(
                              'HEMAT ${x.id == 'pro' ? 3 : 7}%',
                              style: TextStyle(
                                  color: x.warna,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 10),
                            ),
                          ),
                      ]),
                      const SizedBox(height: 14),
                      ...x.manfaat.map((m) {
                        final baru = m.contains('Banner profil') ||
                            m.contains('Bingkai avatar') ||
                            m.contains('Lencana 3D') ||
                            m.contains('Gaya tampilan nama');
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 7),
                          child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  tercapai
                                      ? Icons.check_circle_rounded
                                      : Icons.radio_button_unchecked,
                                  size: 15,
                                  color: tercapai ? x.warna : t.line,
                                ),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: Text.rich(
                                    TextSpan(children: [
                                      TextSpan(
                                        text: m,
                                        style: TextStyle(
                                            color: t.inkSoft.withOpacity(.9),
                                            fontSize: 12.4,
                                            height: 1.4),
                                      ),
                                      if (baru)
                                        WidgetSpan(
                                          alignment:
                                              PlaceholderAlignment.middle,
                                          child: Container(
                                            margin: const EdgeInsets.only(
                                                left: 6),
                                            padding: const EdgeInsets
                                                .symmetric(
                                                horizontal: 6, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: XyTheme.plum
                                                  .withOpacity(.14),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      XyRadius.pill),
                                            ),
                                            child: const Text('BARU',
                                                style: TextStyle(
                                                    color: XyTheme.plum,
                                                    fontSize: 7.5,
                                                    fontWeight:
                                                        FontWeight.w800,
                                                    letterSpacing: .5)),
                                          ),
                                        ),
                                    ]),
                                  ),
                                ),
                              ]),
                        );
                      }),
                    ]),
              ),
            );
          }),
          XyCard(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Cara Naik Tier Cepat',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text(
                    '• Sewa paket mingguan atau bulanan untuk percepatan level\n'
                    '• Beli akun game & streaming premium di katalog produk\n'
                    '• Diskon tier otomatis terpotong saat proses checkout\n'
                    '• Akumulasi total belanja permanen (tier tidak pernah turun otomatis)',
                    style: TextStyle(color: t.muted, fontSize: 12.3, height: 1.65),
                  ),
                ]),
          ),
        ],
      ),
    );
  }
}
