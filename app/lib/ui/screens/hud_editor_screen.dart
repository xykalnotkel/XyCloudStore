import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/hud_store.dart';
import '../../core/pengaturan.dart';
import '../../core/theme.dart';
import '../../data/native_stream.dart';
import '../../models/models.dart';

/// Editor HUD selalu dibuka landscape agar koordinat pratinjau sama dengan
/// layar streaming native. Seluruh posisi relatif, sehingga preset tetap rapi
/// saat dipakai pada resolusi HP yang berbeda.
class HudEditorScreen extends StatefulWidget {
  const HudEditorScreen({super.key, required this.awal});
  final HudLayout awal;

  @override
  State<HudEditorScreen> createState() => _HudEditorScreenState();
}

class _HudEditorScreenState extends State<HudEditorScreen> {
  late HudLayout _draft;
  String? _terpilihId;
  bool _berubah = false;
  bool _menyimpan = false;
  double _progres = 0;
  String _tahap = '';
  Timer? _jamProses;
  int _detikProses = 0;

  @override
  void initState() {
    super.initState();
    _draft = widget.awal.copyWith(tombol: [...widget.awal.tombol]);
    unawaited(SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]));
  }

  @override
  void dispose() {
    _jamProses?.cancel();
    unawaited(SystemChrome.setPreferredOrientations(
        const [DeviceOrientation.portraitUp]));
    super.dispose();
  }

  HudTombol? get _terpilih {
    for (final b in _draft.tombol) {
      if (b.id == _terpilihId) return b;
    }
    return null;
  }

  void _ubahTombol(HudTombol baru) {
    final daftar = [..._draft.tombol];
    final i = daftar.indexWhere((e) => e.id == baru.id);
    if (i < 0) return;
    daftar[i] = baru;
    setState(() {
      _draft = _draft.copyWith(tombol: daftar);
      _berubah = true;
    });
  }

  Future<HudAksi?> _pilihAksi() async {
    var cari = '';
    return showDialog<HudAksi>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialog) {
          final daftar = hudAksiTersedia
              .where((e) => '${e.label} ${e.grup}'
                  .toLowerCase()
                  .contains(cari.toLowerCase()))
              .toList();
          final ukuran = MediaQuery.sizeOf(context);
          return AlertDialog(
            title: const Text('Pilih mapping tombol'),
            content: SizedBox(
              width: math.min(570.0, ukuran.width * .78),
              height: math.min(330.0, ukuran.height * .62),
              child: Column(children: [
                TextField(
                  autofocus: true,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded),
                    hintText: 'Cari W, Space, F1…',
                    isDense: true,
                  ),
                  onChanged: (v) => setDialog(() => cari = v),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: GridView.builder(
                    itemCount: daftar.length,
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 112,
                      childAspectRatio: 1.8,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemBuilder: (_, i) {
                      final a = daftar[i];
                      return OutlinedButton(
                        onPressed: () => Navigator.pop(dialogContext, a),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(a.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w800)),
                            Text(a.grup,
                                style: const TextStyle(fontSize: 9.5),
                                maxLines: 1),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ]),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Batal')),
            ],
          );
        },
      ),
    );
  }

  Future<void> _tambah() async {
    if (_draft.tombol.length >= 48) {
      _pesan('Maksimal 48 tombol per preset.', galat: true);
      return;
    }
    final aksi = await _pilihAksi();
    if (aksi == null || !mounted) return;
    final n = _draft.tombol.length;
    final baru = HudTombol(
      id: 't_${DateTime.now().microsecondsSinceEpoch}',
      label: aksi.label,
      kode: aksi.kode,
      x: (.42 + (n % 5) * .035).clamp(0, .88).toDouble(),
      y: (.40 + (n % 4) * .045).clamp(0, .84).toDouble(),
      lebar: aksi.label.length > 4 ? 82 : 56,
      tinggi: aksi.label.length > 4 ? 48 : 56,
      cara: aksi.cara,
    );
    setState(() {
      _draft = _draft.copyWith(tombol: [..._draft.tombol, baru]);
      _terpilihId = baru.id;
      _berubah = true;
    });
  }

  Future<void> _gantiMapping() async {
    final lama = _terpilih;
    if (lama == null) return;
    final aksi = await _pilihAksi();
    if (aksi == null || !mounted) return;
    _ubahTombol(lama.copyWith(
      label: aksi.label,
      kode: aksi.kode,
      cara: aksi.cara,
    ));
  }

  Future<void> _gantiLabel() async {
    final lama = _terpilih;
    if (lama == null) return;
    final c = TextEditingController(text: lama.label);
    final hasil = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Label tombol'),
        content: TextField(
          controller: c,
          autofocus: true,
          maxLength: 8,
          decoration: const InputDecoration(
              hintText: 'Maksimal 8 karakter', counterText: ''),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Batal')),
          FilledButton(
              onPressed: () {
                final teks = c.text.trim();
                if (teks.isNotEmpty) Navigator.pop(d, teks);
              },
              child: const Text('Simpan')),
        ],
      ),
    );
    c.dispose();
    if (hasil != null && mounted) _ubahTombol(lama.copyWith(label: hasil));
  }

  void _duplikat() {
    final lama = _terpilih;
    if (lama == null || _draft.tombol.length >= 48) return;
    final baru = lama.copyWith(
      id: 't_${DateTime.now().microsecondsSinceEpoch}',
      x: (lama.x + .045).clamp(0, 1).toDouble(),
      y: (lama.y + .045).clamp(0, 1).toDouble(),
    );
    setState(() {
      _draft = _draft.copyWith(tombol: [..._draft.tombol, baru]);
      _terpilihId = baru.id;
      _berubah = true;
    });
  }

  void _hapusTerpilih() {
    final id = _terpilihId;
    if (id == null) return;
    setState(() {
      _draft = _draft.copyWith(
          tombol: _draft.tombol.where((e) => e.id != id).toList());
      _terpilihId = null;
      _berubah = true;
    });
  }

  Future<void> _kosongkan() async {
    if (_draft.tombol.isEmpty) return;
    final ya = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Hapus semua tombol?'),
        content: const Text('Kanvas menjadi kosong. Tindakan ini belum permanen sampai disimpan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(d, true),
              child: const Text('Kosongkan')),
        ],
      ),
    );
    if (ya == true && mounted) {
      setState(() {
        _draft = _draft.copyWith(tombol: const []);
        _terpilihId = null;
        _berubah = true;
      });
    }
  }

  Future<Map<String, String>?> _metadata() async {
    final nama = TextEditingController(text: _draft.nama);
    final game = TextEditingController(text: _draft.game);
    final deskripsi = TextEditingController(text: _draft.deskripsi);
    final form = GlobalKey<FormState>();
    final hasil = await showDialog<Map<String, String>>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Simpan preset lokal'),
        content: Form(
          key: form,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(
                controller: nama,
                maxLength: 40,
                decoration: const InputDecoration(labelText: 'Nama preset'),
                validator: (v) => (v ?? '').trim().length < 3
                    ? 'Minimal 3 karakter'
                    : null,
              ),
              TextFormField(
                controller: game,
                maxLength: 50,
                decoration: const InputDecoration(
                    labelText: 'Game / kategori', hintText: 'Contoh: FPS'),
              ),
              TextFormField(
                controller: deskripsi,
                maxLength: 160,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Deskripsi'),
              ),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Batal')),
          FilledButton.icon(
            onPressed: () {
              if (!(form.currentState?.validate() ?? false)) return;
              Navigator.pop(d, {
                'nama': nama.text.trim(),
                'game': game.text.trim(),
                'deskripsi': deskripsi.text.trim(),
              });
            },
            icon: const Icon(Icons.save_outlined),
            label: const Text('Simpan & gunakan'),
          ),
        ],
      ),
    );
    nama.dispose();
    game.dispose();
    deskripsi.dispose();
    return hasil;
  }

  Future<void> _simpan() async {
    if (_menyimpan) return;
    if (_draft.tombol.isEmpty) {
      _pesan('Tambahkan minimal satu tombol sebelum menyimpan.', galat: true);
      return;
    }
    final meta = await _metadata();
    if (meta == null || !mounted) return;
    _jamProses?.cancel();
    _detikProses = 0;
    _jamProses = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _menyimpan) setState(() => _detikProses++);
    });
    setState(() {
      _menyimpan = true;
      _progres = .12;
      _tahap = 'Memeriksa posisi dan mapping…';
    });
    try {
      var layout = _draft.copyWith(
        nama: meta['nama'],
        game: meta['game'],
        deskripsi: meta['deskripsi'],
      );
      setState(() {
        _progres = .38;
        _tahap = 'Menyimpan preset ke perangkat…';
      });
      layout = await HudStore.simpan(layout);
      await HudStore.aktifkan(layout.id);
      await PengaturanLokal.set('kontrolBawaan', false);
      setState(() {
        _progres = .72;
        _tahap = 'Mengirim layout ke overlay streaming…';
      });
      await NativeStream.setKontrolBawaan(false);
      final nativeSiap = await NativeStream.terapkanHud(layout.toData());
      if (!mounted) return;
      setState(() {
        _draft = layout;
        _berubah = false;
        _progres = 1;
        _tahap = nativeSiap
            ? 'Selesai — HUD aktif untuk sesi berikutnya.'
            : 'Tersimpan lokal — overlay memerlukan APK Android terbaru.';
      });
      _pesan(nativeSiap
          ? 'Preset “${layout.nama}” tersimpan dan sudah aktif.'
          : 'Preset tersimpan. Pasang APK terbaru agar muncul saat streaming.',
          galat: !nativeSiap);
    } catch (e) {
      if (mounted) _pesan('Preset gagal disimpan: $e', galat: true);
    } finally {
      _jamProses?.cancel();
      if (mounted) setState(() => _menyimpan = false);
    }
  }

  void _pesan(String teks, {bool galat = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(galat ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
            color: Colors.white),
        const SizedBox(width: 10),
        Expanded(child: Text(teks)),
      ]),
      backgroundColor: galat ? XyTheme.danger : const Color(0xFF166534),
    ));
  }

  Future<void> _keluar() async {
    if (_menyimpan) return;
    if (_berubah) {
      final ya = await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
          title: const Text('Keluar tanpa menyimpan?'),
          content: const Text('Perubahan posisi, ukuran, atau tombol akan hilang.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Tetap edit')),
            FilledButton(
                onPressed: () => Navigator.pop(d, true),
                child: const Text('Keluar')),
          ],
        ),
      );
      if (ya != true || !mounted) return;
    }
    Navigator.pop(context, _draft);
  }

  @override
  Widget build(BuildContext context) {
    final tema = XyTheme.of(context);
    return WillPopScope(
      onWillPop: () async {
        await _keluar();
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF07101D),
        appBar: AppBar(
          leading: IconButton(
              tooltip: 'Kembali', onPressed: _keluar, icon: const Icon(Icons.arrow_back_rounded)),
          title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Editor HUD Landscape', style: TextStyle(fontSize: 16)),
            Text('${_draft.tombol.length}/48 tombol · ${_draft.nama}',
                style: TextStyle(fontSize: 10.5, color: tema.muted)),
          ]),
          actions: [
            TextButton.icon(
              onPressed: _menyimpan ? null : _simpan,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Simpan'),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Stack(children: [
          Row(children: [
            Expanded(child: _kanvas()),
            Container(
              width: math.min(250.0, MediaQuery.sizeOf(context).width * .36),
              decoration: BoxDecoration(
                color: tema.surface,
                border: Border(left: BorderSide(color: tema.line)),
              ),
              child: _panel(),
            ),
          ]),
          if (_menyimpan)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withOpacity(.62),
                child: Center(
                  child: Container(
                    width: math.min(420.0, MediaQuery.sizeOf(context).width * .65),
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: tema.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: tema.line),
                    ),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Row(children: [
                        const Icon(Icons.gamepad_outlined),
                        const SizedBox(width: 10),
                        Expanded(child: Text(_tahap,
                            style: const TextStyle(fontWeight: FontWeight.w700))),
                        Text('${(_progres * 100).round()}%'),
                      ]),
                      const SizedBox(height: 5),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Waktu berjalan: $_detikProses detik',
                            style: TextStyle(color: tema.muted, fontSize: 11)),
                      ),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(value: _progres),
                    ]),
                  ),
                ),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _kanvas() => Padding(
        padding: const EdgeInsets.all(12),
        child: Center(
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: LayoutBuilder(builder: (context, batas) {
              final w = batas.maxWidth, h = batas.maxHeight;
              return ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(children: [
                  const Positioned.fill(child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF13243B), Color(0xFF07101D)],
                      ),
                    ),
                  )),
                  Positioned.fill(child: CustomPaint(painter: _HudGridPainter())),
                  const Center(
                    child: IgnorePointer(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.desktop_windows_outlined,
                            size: 52, color: Color(0x337C3AED)),
                        SizedBox(height: 8),
                        Text('AREA VIDEO 16:9',
                            style: TextStyle(
                                color: Color(0x557C3AED),
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2)),
                      ]),
                    ),
                  ),
                  for (final b in _draft.tombol)
                    Positioned(
                      left: b.x * math.max(0.0, w - b.lebar),
                      top: b.y * math.max(0.0, h - b.tinggi),
                      width: math.min(b.lebar, w),
                      height: math.min(b.tinggi, h),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(() => _terpilihId = b.id),
                        onPanStart: (_) => setState(() => _terpilihId = b.id),
                        onPanUpdate: (d) {
                          final saatIni = _draft.tombol.firstWhere(
                              (e) => e.id == b.id, orElse: () => b);
                          final nx = (saatIni.x +
                                  d.delta.dx / math.max(1.0, w - saatIni.lebar))
                              .clamp(0.0, 1.0)
                              .toDouble();
                          final ny = (saatIni.y +
                                  d.delta.dy / math.max(1.0, h - saatIni.tinggi))
                              .clamp(0.0, 1.0)
                              .toDouble();
                          _ubahTombol(saatIni.copyWith(x: nx, y: ny));
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 100),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFF263541).withOpacity(b.opacity),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _terpilihId == b.id
                                  ? const Color(0xFFA78BFA)
                                  : Colors.white.withOpacity(.35),
                              width: _terpilihId == b.id ? 3 : 1,
                            ),
                            boxShadow: _terpilihId == b.id
                                ? [BoxShadow(
                                    color: const Color(0xFF7C3AED).withOpacity(.45),
                                    blurRadius: 12)]
                                : null,
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Padding(
                              padding: const EdgeInsets.all(5),
                              child: Text(b.label,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    left: 10,
                    bottom: 8,
                    child: IgnorePointer(
                      child: Text('Geser tombol · ketuk untuk edit',
                          style: TextStyle(
                              color: Colors.white.withOpacity(.55), fontSize: 10.5)),
                    ),
                  ),
                ]),
              );
            }),
          ),
        ),
      );

  Widget _panel() {
    final p = _terpilih;
    final tema = XyTheme.of(context);
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        FilledButton.icon(
          onPressed: _tambah,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Tambah tombol'),
        ),
        const SizedBox(height: 6),
        TextButton.icon(
          onPressed: _draft.tombol.isEmpty ? null : _kosongkan,
          icon: const Icon(Icons.layers_clear_outlined),
          label: const Text('Kosongkan kanvas'),
        ),
        Divider(color: tema.line, height: 22),
        if (p == null) ...[
          const Icon(Icons.touch_app_outlined, size: 32),
          const SizedBox(height: 10),
          const Text('Pilih sebuah tombol',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          Text('Setelah dipilih, mapping, label, ukuran, dan cara tekan dapat diubah.',
              textAlign: TextAlign.center,
              style: TextStyle(color: tema.muted, fontSize: 11.5, height: 1.4)),
        ] else ...[
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                Text('Keycode ${p.kode}',
                    style: TextStyle(color: tema.muted, fontSize: 10.5)),
              ]),
            ),
            IconButton(
                tooltip: 'Hapus tombol',
                onPressed: _hapusTerpilih,
                color: XyTheme.danger,
                icon: const Icon(Icons.delete_outline_rounded)),
          ]),
          Wrap(spacing: 4, runSpacing: 2, children: [
            TextButton(onPressed: _gantiMapping, child: const Text('Ganti mapping')),
            TextButton(onPressed: _gantiLabel, child: const Text('Ubah label')),
            TextButton(onPressed: _duplikat, child: const Text('Duplikat')),
          ]),
          const SizedBox(height: 4),
          Text('Lebar ${p.lebar.round()} dp',
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
          Slider(
            value: p.lebar.clamp(36.0, 160.0).toDouble(),
            min: 36,
            max: 160,
            divisions: 31,
            onChanged: (v) => _ubahTombol(p.copyWith(lebar: v)),
          ),
          Text('Tinggi ${p.tinggi.round()} dp',
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
          Slider(
            value: p.tinggi.clamp(36.0, 100.0).toDouble(),
            min: 36,
            max: 100,
            divisions: 16,
            onChanged: (v) => _ubahTombol(p.copyWith(tinggi: v)),
          ),
          Text('Transparansi ${(p.opacity * 100).round()}%',
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
          Slider(
            value: p.opacity.clamp(.25, 1.0).toDouble(),
            min: .25,
            max: 1,
            divisions: 15,
            onChanged: (v) => _ubahTombol(p.copyWith(opacity: v)),
          ),
          DropdownButtonFormField<String>(
            value: p.cara,
            isDense: true,
            decoration: const InputDecoration(labelText: 'Cara tekan'),
            items: const [
              DropdownMenuItem(value: 'tahan', child: Text('Tahan (turun–lepas)')),
              DropdownMenuItem(value: 'ketuk', child: Text('Ketuk sekali')),
              DropdownMenuItem(value: 'toggle', child: Text('Toggle aktif/mati')),
            ],
            onChanged: (v) {
              if (v != null) _ubahTombol(p.copyWith(cara: v));
            },
          ),
          const SizedBox(height: 8),
          Text(
            p.cara == 'tahan'
                ? 'Cocok untuk WASD, sprint, lompat, dan tombol yang perlu ditahan.'
                : p.cara == 'toggle'
                    ? 'Sekali ketuk menahan key; ketuk lagi untuk melepas.'
                    : 'Mengirim satu ketukan pendek ke PC.',
            style: TextStyle(color: tema.muted, fontSize: 10.5, height: 1.35),
          ),
        ],
      ],
    );
  }
}

class _HudGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final kecil = Paint()
      ..color = Colors.white.withOpacity(.055)
      ..strokeWidth = 1;
    final besar = Paint()
      ..color = const Color(0xFF7C3AED).withOpacity(.14)
      ..strokeWidth = 1;
    const jarak = 24.0;
    for (double x = 0; x <= size.width; x += jarak) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height),
          ((x / jarak).round() % 4 == 0) ? besar : kecil);
    }
    for (double y = 0; y <= size.height; y += jarak) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y),
          ((y / jarak).round() % 4 == 0) ? besar : kecil);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
