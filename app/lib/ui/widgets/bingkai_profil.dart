import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme.dart';

/// ============================================================
///  Bingkai avatar profil (Batch I)
/// ============================================================
///  Id bingkai harus sama dengan whitelist BINGKAI_PROFIL di
///  api/src/index.js. 'aurora' dan 'permata' khusus langganan
///  Pro/VIP (gate ditegakkan di server, di sini hanya ikon kunci).
class BingkaiInfo {
  const BingkaiInfo(this.id, this.label,
      {this.langganan = false, this.vip = false, this.ikon});
  final String id;
  final String label;
  final bool langganan;

  /// Batch L: bingkai kelas tertinggi — hanya untuk member VIP.
  final bool vip;
  final IconData? ikon;
}

const List<BingkaiInfo> daftarBingkai = [
  BingkaiInfo('polos', 'Polos'),
  BingkaiInfo('ungu', 'Ungu Glossy'),
  BingkaiInfo('emas', 'Emas'),
  BingkaiInfo('neon', 'Neon'),
  BingkaiInfo('aurora', 'Aurora', langganan: true),
  BingkaiInfo('permata', 'Permata', langganan: true),
  // Batch J: bingkai aset AI + partikel melayang.
  BingkaiInfo('api', 'Api Ungu', langganan: true),
  BingkaiInfo('galaksi', 'Galaksi', langganan: true),
  // Batch L: enam bingkai aset AI baru (WebP, chroma-key). Dua teratas VIP.
  BingkaiInfo('sakura', 'Sakura', langganan: true),
  BingkaiInfo('sirkuit', 'Sirkuit Neon', langganan: true),
  BingkaiInfo('sayap', 'Sayap Surgawi', langganan: true),
  BingkaiInfo('petir', 'Petir Badai', langganan: true),
  BingkaiInfo('mahkota', 'Mahkota Raja', langganan: true, vip: true),
  BingkaiInfo('naga', 'Naga Emas', langganan: true, vip: true),
  // Batch Q: bingkai tambahan permintaan pengguna (Cyberpunk, Hologram, Es, Pelangi, Ruby, Emerald).
  BingkaiInfo('cyberpunk', 'Cyberpunk', langganan: true),
  BingkaiInfo('hologram', 'Hologram', langganan: true, vip: true),
  BingkaiInfo('es', 'Kristal Es', langganan: true),
  BingkaiInfo('pelangi', 'Pelangi RGB', langganan: true),
  BingkaiInfo('ruby', 'Permata Ruby', langganan: true, vip: true),
  BingkaiInfo('emerald', 'Zamrud Hijau', langganan: true, vip: true),
  // Bingkai Baru Non-Cyber (Floating elements & motion blur)
  BingkaiInfo('celestial', 'Celestial Breeze', langganan: true, vip: true),
  BingkaiInfo('sakura_angin', 'Sakura Melayang', langganan: true, vip: true),
  // Bingkai Baru: Inferno, Matrix, Samurai, Nebula, Phantom
  BingkaiInfo('inferno', 'Inferno Lava', langganan: true, vip: true),
  BingkaiInfo('matrix', 'Matrix Cyber', langganan: true),
  BingkaiInfo('samurai', 'Spirit Samurai', langganan: true),
  BingkaiInfo('nebula', 'Nebula Kosmik', langganan: true),
  BingkaiInfo('phantom', 'Phantom Abyss', langganan: true, vip: true),
];

/// Id bingkai yang memakai artwork AI (assets/bingkai/{id}.webp).
const Set<String> _idAsetAi = {
  'api', 'galaksi', 'sakura', 'sirkuit', 'sayap', 'petir', 'mahkota', 'naga',
  'celestial', 'sakura_angin',
  'inferno', 'matrix', 'samurai', 'nebula', 'phantom',
};

/// Cincin gradasi statis untuk bingkai non-animasi.
Gradient? _gradBingkai(String? id) => switch (id) {
      'ungu' => const LinearGradient(
          colors: [Color(0xFFD6C8FF), XyTheme.violet, Color(0xFF3B1188)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight),
      'emas' => const LinearGradient(
          colors: [Color(0xFFF7E7B3), Color(0xFFD3A625), Color(0xFF7A5A10)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight),
      'neon' => const LinearGradient(
          colors: [Color(0xFF22D3EE), Color(0xFF8B5CF6), Color(0xFFF472B6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight),
      'cyberpunk' => const LinearGradient(
          colors: [Color(0xFF00F0FF), Color(0xFFFF007F), Color(0xFF7000FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight),
      'hologram' => const LinearGradient(
          colors: [Color(0xFFFDE047), Color(0xFF67E8F9), Color(0xFFF472B6), Color(0xFFA78BFA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight),
      'es' => const LinearGradient(
          colors: [Color(0xFFE0F2FE), Color(0xFF38BDF8), Color(0xFF0284C7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight),
      'pelangi' => const SweepGradient(
          colors: [
            Color(0xFFEF4444), Color(0xFFF59E0B), Color(0xFF10B981),
            Color(0xFF06B6D4), Color(0xFF6366F1), Color(0xFFEC4899), Color(0xFFEF4444),
          ]),
      'ruby' => const LinearGradient(
          colors: [Color(0xFFFECDD3), Color(0xFFE11D48), Color(0xFF881337)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight),
      'emerald' => const LinearGradient(
          colors: [Color(0xFFA7F3D0), Color(0xFF059669), Color(0xFF064E3B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight),
      'inferno' => const SweepGradient(
          colors: [
            Color(0xFFFF1E00), Color(0xFFFF8500), Color(0xFFFFD600),
            Color(0xFFFF1E00),
          ]),
      'matrix' => const LinearGradient(
          colors: [Color(0xFF00FF66), Color(0xFF008F11), Color(0xFF042F2E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight),
      'samurai' => const LinearGradient(
          colors: [Color(0xFFF8FAFC), Color(0xFF60A5FA), Color(0xFF1E3A8A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight),
      'nebula' => const SweepGradient(
          colors: [
            Color(0xFFC084FC), Color(0xFFE879F9), Color(0xFF4C1D95),
            Color(0xFF818CF8), Color(0xFFC084FC),
          ]),
      'phantom' => const LinearGradient(
          colors: [Color(0xFF22D3EE), Color(0xFFA855F7), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight),
      _ => null,
    };

/// Avatar dengan bingkai. `child` biasanya Container bulat berisi foto/inisial.
/// Untuk 'aurora' cincin berputar halus (khusus pelanggan, sudah digate server).
/// Untuk 'permata' cincin emas-ungu + empat titik permata di diagonal.
class AvatarBingkai extends StatefulWidget {
  const AvatarBingkai({
    super.key,
    required this.child,
    required this.size,
    this.bingkai,
    this.tebal,
  });

  final Widget child;
  final double size;
  final String? bingkai;

  /// Ketebalan cincin; default proporsional terhadap ukuran.
  final double? tebal;

  @override
  State<AvatarBingkai> createState() => _AvatarBingkaiState();
}

class _AvatarBingkaiState extends State<AvatarBingkai>
    with TickerProviderStateMixin {
  late final AnimationController _putar;

  /// Partikel melayang untuk bingkai aset AI (bara api naik / bintang mengorbit).
  late final AnimationController _apung;

  bool get _animasi =>
      widget.bingkai == 'aurora' ||
      widget.bingkai == 'pelangi' ||
      widget.bingkai == 'hologram' ||
      widget.bingkai == 'es' ||
      widget.bingkai == 'inferno' ||
      widget.bingkai == 'nebula' ||
      _idAsetAi.contains(widget.bingkai ?? '');

  bool get _asetAi => _idAsetAi.contains(widget.bingkai ?? '');

  /// Bingkai yang memakai partikel apung (loop _apung).
  bool get _pakaiApung => const {'api', 'sakura', 'sayap', 'naga', 'es', 'sakura_angin', 'celestial', 'inferno', 'nebula', 'phantom'}
      .contains(widget.bingkai ?? '');

  @override
  void initState() {
    super.initState();
    // Jangan lazy-init dari dispose: TickerProvider membutuhkan context yang
    // masih aktif, termasuk saat bingkai yang dipilih adalah Polos.
    _putar = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );
    _apung = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    if (_animasi) _putar.repeat();
    if (_pakaiApung) _apung.repeat();
  }

  @override
  void didUpdateWidget(covariant AvatarBingkai old) {
    super.didUpdateWidget(old);
    if (_animasi && !_putar.isAnimating) {
      _putar.repeat();
    } else if (!_animasi && _putar.isAnimating) {
      _putar.stop();
    }
    if (_pakaiApung && !_apung.isAnimating) {
      _apung.repeat();
    } else if (!_pakaiApung && _apung.isAnimating) {
      _apung.stop();
    }
  }

  @override
  void dispose() {
    _putar.dispose();
    _apung.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.bingkai ?? 'polos';
    if (id == 'polos' || id.isEmpty) {
      return SizedBox(width: widget.size, height: widget.size, child: widget.child);
    }
    // Bingkai aset AI punya cincin tebal yang menyatu dengan artwork-nya.
    final tebal = widget.tebal ??
        (_asetAi ? math.max(6.0, widget.size * .13) : math.max(2.6, widget.size * .055));
    final grad = _gradBingkai(id);
    // Kebijakan tata letak 2026-09-18: footprint widget PERSIS widget.size
    // supaya bingkai tidak meluber di grid/baris liste. Cincin digambar
    // masuk ke dalam; foto mengecil sebesar ketebalan cincin.
    final inner = math.max(8.0, widget.size - tebal * 2);

    Widget cincin() {
      if (_asetAi) {
        // Ring artwork hasil generate AI (chroma-key hijau → transparan).
        return Image.asset(
          'assets/bingkai/$id.webp',
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, __, ___) => Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: id == 'api'
                    ? [const Color(0xFFF472B6), XyTheme.violet, const Color(0xFF7C2D12)]
                    : [const Color(0xFF22D3EE), XyTheme.violet, const Color(0xFF312E81)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        );
      }
      if (id == 'aurora' || id == 'pelangi' || id == 'hologram' || id == 'inferno' || id == 'nebula') {
        return RotationTransition(
          turns: _putar,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: id == 'pelangi'
                  ? _gradBingkai('pelangi')
                  : id == 'hologram'
                      ? _gradBingkai('hologram')
                      : id == 'inferno'
                          ? _gradBingkai('inferno')
                          : id == 'nebula'
                              ? _gradBingkai('nebula')
                              : const SweepGradient(
                          colors: [
                            Color(0xFF22D3EE),
                            XyTheme.violet,
                            Color(0xFFF472B6),
                            Color(0xFFA78BFA),
                            Color(0xFF22D3EE),
                          ],
                          stops: [0, .28, .52, .78, 1],
                        ),
            ),
          ),
        );
      }
      return Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: id == 'permata'
              ? const LinearGradient(
                  colors: [
                    Color(0xFFF7E7B3),
                    Color(0xFF8B5CF6),
                    Color(0xFFD3A625),
                    Color(0xFF4C1D95),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight)
              : grad,
          color: grad == null && id != 'permata' ? XyTheme.lavender : null,
        ),
      );
    }

    Widget hasil = SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(alignment: Alignment.center, children: [
        // Cincin CSS/gradasi harus menjadi alas karena bentuknya lingkaran
        // penuh. Artwork AI punya lubang transparan, jadi dirender SETELAH
        // foto agar ornamen bingkai benar-benar berada di depan avatar.
        if (!_asetAi) Positioned.fill(child: cincin()),
        if (!_asetAi)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.center,
                    colors: [
                      Colors.white.withOpacity(.30),
                      Colors.white.withOpacity(0),
                    ],
                  ),
                ),
              ),
            ),
          ),
        Container(
          width: inner,
          height: inner,
          decoration: const BoxDecoration(shape: BoxShape.circle),
          clipBehavior: Clip.antiAlias,
          child: widget.child,
        ),
        if (_asetAi)
          Positioned.fill(
            child: IgnorePointer(child: cincin()),
          ),
        // Elemen melayang juga berada di lapisan paling depan.
        if (id == 'galaksi')
          Positioned.fill(
              child: _BintangOrbit(size: inner, tebal: tebal, putar: _putar)),
        if (id == 'api')
          Positioned.fill(
              child: _BaraNaik(size: inner, tebal: tebal, apung: _apung)),
        // Batch L: partikel khas tiap bingkai baru.
        if (id == 'sakura')
          Positioned.fill(
              child: _KelopakJatuh(
                  size: inner, tebal: tebal, apung: _apung)),
        if (id == 'sayap')
          Positioned.fill(
              child: _CahayaNaik(
                  size: inner, tebal: tebal, apung: _apung)),
        if (id == 'naga')
          Positioned.fill(
              child: _BaraNaik(size: inner, tebal: tebal, apung: _apung)),
        if (id == 'petir')
          Positioned.fill(
              child: _BintangOrbit(
                  size: widget.size,
                  tebal: tebal,
                  putar: _putar,
                  warna: const [
                    Color(0xFF93C5FD), Color(0xFFC4B5FD), Colors.white,
                  ])),
        if (id == 'sirkuit')
          Positioned.fill(
              child: _BintangOrbit(
                  size: widget.size,
                  tebal: tebal,
                  putar: _putar,
                  warna: const [
                    Color(0xFF22D3EE), Color(0xFFF472B6), Color(0xFF67E8F9),
                  ])),
        if (id == 'mahkota')
          Positioned.fill(
              child: _BintangOrbit(
                  size: widget.size,
                  tebal: tebal,
                  putar: _putar,
                  warna: const [
                    XyTheme.goldSoft, Colors.white, Color(0xFFFCA5A5),
                  ])),
        if (id == 'celestial')
          Positioned.fill(
              child: _BintangOrbit(
                  size: widget.size,
                  tebal: tebal,
                  putar: _putar,
                  warna: const [
                    Color(0xFFE9D5FF), Color(0xFFFDE68A), Color(0xFFC084FC), Colors.white,
                  ])),
        if (id == 'sakura_angin')
          Positioned.fill(
              child: _KelopakJatuh(
                  size: inner, tebal: tebal, apung: _apung)),
        if (id == 'permata')
          ...List.generate(4, (i) {
            final sudut = math.pi / 4 + i * math.pi / 2;
            final r = inner / 2 + tebal;
            return Positioned(
              left: r + r * math.cos(sudut) - tebal * .55,
              top: r + r * math.sin(sudut) - tebal * .55,
              child: Container(
                width: tebal * 1.1,
                height: tebal * 1.1,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFDF3D7),
                  boxShadow: [
                    BoxShadow(
                        color: XyTheme.goldSoft.withOpacity(.8), blurRadius: 6),
                  ],
                ),
              ),
            );
          }),
      ]),
    );

    return hasil;
  }
}

/// Pemilih bingkai horizontal untuk layar Ubah Profil.
class PilihBingkai extends StatelessWidget {
  const PilihBingkai({
    super.key,
    required this.nilai,
    required this.onPilih,
    required this.foto,
    required this.tier,
  });

  final String? nilai;
  final ValueChanged<String?> onPilih;
  final String? foto;
  final String tier;

  bool get _langganan => tier == 'pro' || tier == 'vip';
  bool get _vip => tier == 'vip';

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 116,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: daftarBingkai.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final b = daftarBingkai[i];
          final terpilih = (nilai ?? 'polos') == b.id;
          final terkunci = (b.langganan && !_langganan) || (b.vip && !_vip);
          return GestureDetector(
            onTap: () {
              if (terkunci) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(b.vip
                        ? 'Bingkai ${b.label} eksklusif member VIP. Naikkan tier dulu ya.'
                        : 'Bingkai premium khusus pelanggan Pro/VIP. Naikkan tier dulu ya.')));
                return;
              }
              onPilih(b.id);
            },
            child: Column(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: EdgeInsets.all(terpilih ? 3 : 0),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: terpilih ? XyTheme.violet : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Stack(alignment: Alignment.center, children: [
                  AvatarBingkai(
                    bingkai: b.id,
                    size: 52,
                    child: _AvatarIsi(foto: foto),
                  ),
                  if (terkunci)
                    Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withOpacity(.45),
                      ),
                      child: const Icon(Icons.lock_rounded,
                          size: 18, color: Colors.white),
                    ),
                ]),
              ),
              const SizedBox(height: 6),
              if (b.langganan)
                Container(
                  margin: const EdgeInsets.only(bottom: 2),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    gradient: b.vip
                        ? const LinearGradient(colors: [
                            Color(0xFFD3A625), Color(0xFF8B5CF6),
                          ])
                        : null,
                    color: b.vip ? null : XyTheme.violet.withOpacity(.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    b.vip ? 'VIP' : 'PRO+',
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .6,
                      color: b.vip ? Colors.white : XyTheme.violet,
                    ),
                  ),
                ),
              SizedBox(
                width: 74,
                child: Text(
                  b.label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: terpilih ? FontWeight.w800 : FontWeight.w600,
                    color: terpilih
                        ? XyTheme.of(context).ink
                        : XyTheme.of(context).muted,
                  ),
                ),
              ),
            ]),
          );
        },
      ),
    );
  }
}

class _AvatarIsi extends StatelessWidget {
  const _AvatarIsi({this.foto});
  final String? foto;

  @override
  Widget build(BuildContext context) {
    if ((foto ?? '').isNotEmpty) {
      return Image.network(
        foto!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const _AvatarJatuh(),
      );
    }
    return const _AvatarJatuh();
  }
}

class _AvatarJatuh extends StatelessWidget {
  const _AvatarJatuh();
  @override
  Widget build(BuildContext context) => Container(
        color: XyTheme.of(context).primarySoft,
        alignment: Alignment.center,
        child: Icon(Icons.person_rounded,
            color: XyTheme.of(context).muted, size: 26),
      );
}

/// Bintang kecil mengorbit mengelilingi bingkai Galaksi (Batch J).
class _BintangOrbit extends StatelessWidget {
  const _BintangOrbit(
      {required this.size,
      required this.tebal,
      required this.putar,
      this.warna = const [Colors.white, XyTheme.goldSoft, Color(0xFFBFD9FF)]});
  final double size;
  final double tebal;
  final Animation<double> putar;
  final List<Color> warna;

  @override
  Widget build(BuildContext context) {
    final r = size / 2 + tebal * .5;
    return AnimatedBuilder(
      animation: putar,
      builder: (_, __) => Stack(children: [
        for (var i = 0; i < 3; i++)
          Builder(builder: (_) {
            final sudut = putar.value * 2 * math.pi + i * 2 * math.pi / 3;
            final denyut = .75 + .25 * math.sin(putar.value * 6 * math.pi + i);
            final s = (i == 0 ? 13.0 : 9.0) * denyut;
            return Positioned(
              left: r + r * math.cos(sudut) - s / 2,
              top: r + r * math.sin(sudut) - s / 2,
              child: Icon(Icons.auto_awesome_rounded,
                  size: s,
                  color: warna[i % warna.length].withOpacity(.95)),
            );
          }),
      ]),
    );
  }
}

/// Bara api ungu-emas melayang naik di sekeliling bingkai Api (Batch J).
class _BaraNaik extends StatelessWidget {
  const _BaraNaik({required this.size, required this.tebal, required this.apung});
  final double size;
  final double tebal;
  final Animation<double> apung;

  static const _bara = [
    Color(0xFFFBBF24),
    Color(0xFFF472B6),
    Color(0xFFA78BFA),
    Color(0xFFFDE68A),
    Color(0xFFF97316),
  ];

  @override
  Widget build(BuildContext context) {
    final tinggi = size + tebal * 2;
    return AnimatedBuilder(
      animation: apung,
      builder: (_, __) => Stack(clipBehavior: Clip.none, children: [
        for (var i = 0; i < 5; i++)
          Builder(builder: (_) {
            final p = (apung.value + i / 5) % 1.0;
            final naik = tinggi * (1 - p) - tebal;
            final goyang = math.sin(p * 4 * math.pi + i * 1.7) * size * .16;
            final alpha = math.sin(p * math.pi).clamp(0.0, 1.0) * .9;
            final s = 3.0 + (i % 3) * 1.6;
            return Positioned(
              left: tinggi / 2 + goyang + (i - 2) * size * .17 - s / 2,
              top: naik,
              child: Opacity(
                opacity: alpha,
                child: Container(
                  width: s,
                  height: s,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _bara[i],
                    boxShadow: [
                      BoxShadow(color: _bara[i].withOpacity(.75), blurRadius: 5),
                    ],
                  ),
                ),
              ),
            );
          }),
      ]),
    );
  }
}

/// Kelopak sakura melayang turun perlahan di sekitar bingkai (Batch L).
class _KelopakJatuh extends StatelessWidget {
  const _KelopakJatuh(
      {required this.size, required this.tebal, required this.apung});
  final double size;
  final double tebal;
  final Animation<double> apung;

  static const _warna = [
    Color(0xFFFBCFE8),
    Color(0xFFF9A8D4),
    Color(0xFFFDF2F8),
    Color(0xFFF472B6),
  ];

  @override
  Widget build(BuildContext context) {
    final tinggi = size + tebal * 2;
    return AnimatedBuilder(
      animation: apung,
      builder: (_, __) => Stack(clipBehavior: Clip.none, children: [
        for (var i = 0; i < 4; i++)
          Builder(builder: (_) {
            final p = (apung.value + i / 4) % 1.0;
            final turun = tinggi * p - tebal;
            final goyang = math.sin(p * 3 * math.pi + i * 2.1) * size * .18;
            final alpha = math.sin(p * math.pi).clamp(0.0, 1.0) * .9;
            final s = 5.0 + (i % 2) * 2.5;
            return Positioned(
              left: tinggi / 2 + goyang + (i - 1.5) * size * .2 - s / 2,
              top: turun,
              child: Opacity(
                opacity: alpha,
                child: Transform.rotate(
                  angle: p * 4 * math.pi + i,
                  child: Icon(Icons.spa_rounded,
                      size: s, color: _warna[i % _warna.length]),
                ),
              ),
            );
          }),
      ]),
    );
  }
}

/// Butir cahaya putih-emas naik lembut — bingkai Sayap Surgawi (Batch L).
class _CahayaNaik extends StatelessWidget {
  const _CahayaNaik(
      {required this.size, required this.tebal, required this.apung});
  final double size;
  final double tebal;
  final Animation<double> apung;

  static const _warna = [
    Colors.white,
    Color(0xFFFDF2C5),
    Color(0xFFE0E7FF),
    XyTheme.goldSoft,
  ];

  @override
  Widget build(BuildContext context) {
    final tinggi = size + tebal * 2;
    return AnimatedBuilder(
      animation: apung,
      builder: (_, __) => Stack(clipBehavior: Clip.none, children: [
        for (var i = 0; i < 4; i++)
          Builder(builder: (_) {
            final p = (apung.value + i / 4) % 1.0;
            final naik = tinggi * (1 - p) - tebal;
            final goyang = math.sin(p * 2 * math.pi + i * 1.3) * size * .12;
            final alpha = math.sin(p * math.pi).clamp(0.0, 1.0) * .8;
            final s = 3.0 + (i % 3) * 1.4;
            return Positioned(
              left: tinggi / 2 + goyang + (i - 1.5) * size * .22 - s / 2,
              top: naik,
              child: Opacity(
                opacity: alpha,
                child: Container(
                  width: s,
                  height: s,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _warna[i % _warna.length],
                    boxShadow: [
                      BoxShadow(
                          color: Colors.white.withOpacity(.7), blurRadius: 6),
                    ],
                  ),
                ),
              ),
            );
          }),
      ]),
    );
  }
}
