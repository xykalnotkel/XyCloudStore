import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme.dart';

/// ============================================================
///  Gaya nama kustom (Batch L)
/// ============================================================
///  Id gaya harus sama dengan whitelist GAYA_NAMA di
///  api/src/index.js. Gaya beranimasi/gradasi khusus Pro/VIP
///  (gate ditegakkan server; di sini hanya ikon kunci di pemilih).
class GayaNamaInfo {
  const GayaNamaInfo(this.id, this.label, {this.langganan = false});
  final String id;
  final String label;
  final bool langganan;
}

const List<GayaNamaInfo> daftarGayaNama = [
  GayaNamaInfo('normal', 'Normal'),
  GayaNamaInfo('tebal', 'Tebal'),
  GayaNamaInfo('miring', 'Miring'),
  GayaNamaInfo('serif', 'Serif Klasik'),
  GayaNamaInfo('mono', 'Monospace'),
  GayaNamaInfo('gradasi', 'Gradasi Ungu', langganan: true),
  GayaNamaInfo('emas', 'Emas Berkilau', langganan: true),
  GayaNamaInfo('neon', 'Neon Glow', langganan: true),
  GayaNamaInfo('pelangi', 'Pelangi Hidup', langganan: true),
  GayaNamaInfo('ombak', 'Ombak Huruf', langganan: true),
  GayaNamaInfo('ketik', 'Mesin Ketik', langganan: true),
];

/// Teks nama dengan gaya kustom. Dipakai di profil sendiri, profil publik,
/// komunitas, leaderboard — semua orang bisa melihat gaya pemiliknya.
class GayaNama extends StatefulWidget {
  const GayaNama(
    this.nama, {
    super.key,
    this.gaya,
    this.style,
    this.maxLines = 1,
  });

  final String nama;
  final String? gaya;

  /// Style dasar (ukuran/berat) — warna & efek ditimpa oleh gaya.
  final TextStyle? style;
  final int maxLines;

  @override
  State<GayaNama> createState() => _GayaNamaState();
}

class _GayaNamaState extends State<GayaNama>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;

  bool get _hidup => const ['pelangi', 'ombak', 'ketik', 'emas']
      .contains(widget.gaya ?? 'normal');

  @override
  void initState() {
    super.initState();
    // Selalu buat controller saat elemen masih aktif. Inisialisasi lazy di
    // dispose bisa mencoba membaca TickerMode dari context yang sudah mati.
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );
    if (_hidup) _anim.repeat();
  }

  @override
  void didUpdateWidget(covariant GayaNama old) {
    super.didUpdateWidget(old);
    if (_hidup && !_anim.isAnimating) {
      _anim.repeat();
    } else if (!_hidup && _anim.isAnimating) {
      _anim.stop();
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  TextStyle get _dasar =>
      (widget.style ?? const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))
          .copyWith(overflow: TextOverflow.ellipsis);

  @override
  Widget build(BuildContext context) {
    final id = widget.gaya ?? 'normal';
    final nama = widget.nama;

    switch (id) {
      case 'tebal':
        return Text(nama,
            maxLines: widget.maxLines,
            style: _dasar.copyWith(
                fontWeight: FontWeight.w900, letterSpacing: .2));
      case 'miring':
        return Text(nama,
            maxLines: widget.maxLines,
            style: _dasar.copyWith(fontStyle: FontStyle.italic));
      case 'serif':
        return Text(nama,
            maxLines: widget.maxLines,
            style: _dasar.copyWith(
                fontFamily: 'serif', letterSpacing: .3,
                fontWeight: FontWeight.w700));
      case 'mono':
        return Text(nama,
            maxLines: widget.maxLines,
            style: _dasar.copyWith(fontFamily: 'monospace', letterSpacing: 0));
      case 'gradasi':
        return _shader(
            nama,
            const LinearGradient(colors: [
              Color(0xFFA78BFA), XyTheme.violet, Color(0xFF7C3AED),
            ]));
      case 'emas':
        // Kilau emas bergerak pelan (shimmer) — premium tapi kalem.
        return AnimatedBuilder(
            animation: _anim,
            builder: (_, __) {
              final t = _anim.value;
              return _shader(
                  nama,
                  LinearGradient(
                    begin: Alignment(-1.5 + t * 3, 0),
                    end: Alignment(-.5 + t * 3, 0),
                    colors: const [
                      Color(0xFFB98A18), Color(0xFFFDF2C5),
                      Color(0xFFD3A625), Color(0xFF9A7113),
                    ],
                    stops: const [0, .45, .6, 1],
                    tileMode: TileMode.clamp,
                  ));
            });
      case 'neon':
        final gelap = Theme.of(context).brightness == Brightness.dark;
        return Text(nama,
            maxLines: widget.maxLines,
            style: _dasar.copyWith(
              color: gelap ? const Color(0xFF6BF3FF) : const Color(0xFF0284C7),
              shadows: gelap
                  ? const [
                      Shadow(color: Color(0xAA22D3EE), blurRadius: 12),
                      Shadow(color: Color(0x668B5CF6), blurRadius: 22),
                    ]
                  : const [
                      Shadow(color: Color(0x440284C7), blurRadius: 8),
                      Shadow(color: Color(0x337C3AED), blurRadius: 16),
                    ],
            ));
      case 'pelangi':
        return AnimatedBuilder(
            animation: _anim,
            builder: (_, __) {
              final t = _anim.value * 2 * math.pi;
              Color c(double fase) => HSVColor.fromAHSV(
                      1, ((t + fase) * 180 / math.pi) % 360, .68, .96)
                  .toColor();
              return _shader(
                  nama, LinearGradient(colors: [c(0), c(1.6), c(3.2)]));
            });
      case 'ombak':
        // Tiap huruf naik-turun bergelombang halus.
        return AnimatedBuilder(
            animation: _anim,
            builder: (_, __) {
              final t = _anim.value * 2 * math.pi;
              final huruf = nama.characters.take(24).toList();
              return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < huruf.length; i++)
                      Transform.translate(
                        offset: Offset(0, math.sin(t + i * .7) * 2.2),
                        child: Text(huruf[i], style: _dasar),
                      ),
                  ]);
            });
      case 'ketik':
        // Efek mesin ketik: huruf muncul satu-satu lalu kursor berkedip.
        return AnimatedBuilder(
            animation: _anim,
            builder: (_, __) {
              final t = _anim.value;
              final n = nama.characters.length;
              // 70% durasi untuk mengetik, sisanya jeda penuh.
              final tampil = (t < .7)
                  ? (n * (t / .7)).ceil().clamp(0, n)
                  : n;
              final kursor = (t * 6).floor() % 2 == 0 ? '▌' : ' ';
              return Text(
                  '${nama.characters.take(tampil)}$kursor',
                  maxLines: widget.maxLines,
                  style: _dasar.copyWith(fontFamily: 'monospace'));
            });
      default:
        return Text(nama, maxLines: widget.maxLines, style: _dasar);
    }
  }

  Widget _shader(String nama, Gradient g) => ShaderMask(
        shaderCallback: (r) => g.createShader(r),
        blendMode: BlendMode.srcIn,
        child: Text(nama,
            maxLines: widget.maxLines,
            style: _dasar.copyWith(color: Colors.white)),
      );
}
