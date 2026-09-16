import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../core/motion.dart';
import '../../core/theme.dart';
import 'common.dart';

/// Jenis media yang boleh dipilih. Foto, video, dan GIF sengaja dipisah agar
/// berkas animasi tidak ikut terbaca sebagai foto biasa oleh Android MediaStore.
enum JenisGaleri { foto, video, gif }

enum _FilterGaleri { foto, video, gif, semua }

/// ============================================================
///  GaleriPicker — pemilih galeri kustom
/// ============================================================
///  Grid galeri milik aplikasi dengan album, thumbnail cepat, izin yang jelas,
///  filter Foto/Video/GIF terpisah, dan urutan terbaru selalu di paling atas.
class GaleriPicker {
  GaleriPicker._();

  /// Sentinel: pengguna memilih jatuh ke picker sistem.
  static const String pakaiSistem = '__sistem__';

  static Future<Object?> buka(
    BuildContext context, {
    Set<JenisGaleri> jenis = const {JenisGaleri.foto},
    JenisGaleri? awal,
    String judul = 'Pilih dari Galeri',
  }) {
    final jenisAman = jenis.isEmpty ? const {JenisGaleri.foto} : jenis;
    return Navigator.push<Object?>(
      context,
      xyRoute(_GaleriScreen(
        jenis: jenisAman,
        awal: awal,
        judul: judul,
      )),
    );
  }

  /// Galeri kustom dulu; bila izin ditolak dan pengguna memilih picker sistem,
  /// otomatis jatuh ke image_picker dengan jenis media yang sama.
  static Future<File?> pilihGambar(
    BuildContext context, {
    Set<JenisGaleri> jenis = const {JenisGaleri.foto},
    JenisGaleri? awal,
    String judul = 'Pilih dari Galeri',
  }) async {
    final jenisAman = jenis.isEmpty ? const {JenisGaleri.foto} : jenis;
    final hasil = await buka(
      context,
      jenis: jenisAman,
      awal: awal,
      judul: judul,
    );
    if (hasil is File) return hasil;
    if (hasil != pakaiSistem) return null;

    XFile? x;
    if (jenisAman.length == 1 && jenisAman.contains(JenisGaleri.video)) {
      x = await ImagePicker().pickVideo(source: ImageSource.gallery);
    } else if (jenisAman.contains(JenisGaleri.video)) {
      x = await ImagePicker().pickMedia();
    } else {
      x = await ImagePicker().pickImage(source: ImageSource.gallery);
    }
    if (x == null) return null;

    final file = File(x.path);
    final terdeteksi = _jenisDariNama(x.name.isNotEmpty ? x.name : x.path);
    if (!jenisAman.contains(terdeteksi)) {
      if (context.mounted) {
        final diminta = jenisAman.map(_labelJenis).join(' / ');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Berkas itu terdeteksi sebagai ${_labelJenis(terdeteksi)}, bukan $diminta.'),
        ));
      }
      return null;
    }
    return file;
  }
}

class _GaleriScreen extends StatefulWidget {
  const _GaleriScreen({
    required this.jenis,
    required this.judul,
    this.awal,
  });

  final Set<JenisGaleri> jenis;
  final JenisGaleri? awal;
  final String judul;

  @override
  State<_GaleriScreen> createState() => _GaleriScreenState();
}

class _GaleriScreenState extends State<_GaleriScreen> {
  static const _perHalaman = 60;

  final _scroll = ScrollController();
  List<AssetPathEntity> _album = [];
  AssetPathEntity? _aktif;
  List<AssetEntity> _aset = [];
  int _halaman = 0;
  int _generasiMuat = 0;
  int _generasiAlbum = 0;
  bool _habis = false;
  bool _memuat = true;
  bool _memuatHalaman = false;
  bool _izinDitolak = false;
  bool _mengambil = false;
  late _FilterGaleri _filter;

  @override
  void initState() {
    super.initState();
    final awal = widget.awal != null && widget.jenis.contains(widget.awal)
        ? widget.awal!
        : widget.jenis.first;
    _filter = _filterDariJenis(awal);
    _siapkan();
    _scroll.addListener(() {
      if (_scroll.hasClients && _scroll.position.extentAfter < 600) {
        _muatLagi();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  List<_FilterGaleri> get _filterTersedia {
    final hasil = <_FilterGaleri>[];
    if (widget.jenis.contains(JenisGaleri.foto)) hasil.add(_FilterGaleri.foto);
    if (widget.jenis.contains(JenisGaleri.video))
      hasil.add(_FilterGaleri.video);
    if (widget.jenis.contains(JenisGaleri.gif)) hasil.add(_FilterGaleri.gif);
    if (hasil.length == 3) hasil.add(_FilterGaleri.semua);
    return hasil;
  }

  RequestType get _tipe => switch (_filter) {
        _FilterGaleri.foto || _FilterGaleri.gif => RequestType.image,
        _FilterGaleri.video => RequestType.video,
        _FilterGaleri.semua => RequestType.common,
      };

  /// Filter database sekaligus ORDER BY tanggal pembuatan menurun. Filter SQL
  /// membuat album GIF tetap cepat meski galeri perangkat berisi ribuan foto.
  PMFilter get _opsiFilter {
    final urut = <OrderOption>[
      const OrderOption(type: OrderOptionType.createDate, asc: false),
    ];
    if (_filter == _FilterGaleri.gif || _filter == _FilterGaleri.foto) {
      String? where;
      if (Platform.isAndroid) {
        final mime = CustomColumns.android.mimeType;
        where = _filter == _FilterGaleri.gif
            ? "$mime == 'image/gif'"
            : "($mime IS NULL OR $mime != 'image/gif')";
      } else if (Platform.isIOS || Platform.isMacOS) {
        final gaya = CustomColumns.darwin.playbackStyle;
        where = _filter == _FilterGaleri.gif
            ? '$gaya == 2'
            : '($gaya == nil OR $gaya != 2)';
      }
      if (where != null) {
        final opsi = CustomFilter.sql(
          where: where,
          orderBy: [OrderByItem.desc(CustomColumns.base.createDate)],
        );
        opsi.needTitle = true;
        return opsi;
      }
    }
    return FilterOptionGroup(
      imageOption: const FilterOption(needTitle: true),
      videoOption: const FilterOption(needTitle: true),
      orders: urut,
    );
  }

  Future<void> _siapkan() async {
    final izin = await PhotoManager.requestPermissionExtend();
    if (!mounted) return;
    if (!izin.isAuth && !izin.hasAccess) {
      setState(() {
        _memuat = false;
        _izinDitolak = true;
      });
      return;
    }
    await _muatDaftarAlbum();
  }

  Future<void> _muatDaftarAlbum() async {
    final generasi = ++_generasiAlbum;
    _generasiMuat++; // batalkan hasil pagination dari filter sebelumnya
    setState(() {
      _memuat = true;
      _aset = [];
      _habis = false;
    });
    try {
      final album = await PhotoManager.getAssetPathList(
        type: _tipe,
        hasAll: true,
        onlyAll: false,
        filterOption: _opsiFilter,
      );
      if (!mounted || generasi != _generasiAlbum) return;
      setState(() {
        _album = album;
        _aktif = album.isNotEmpty ? album.first : null;
        _memuat = album.isNotEmpty;
      });
      if (album.isEmpty) return;
      await _muatLagi(reset: true);
    } catch (_) {
      if (!mounted || generasi != _generasiAlbum) return;
      setState(() {
        _album = [];
        _aktif = null;
        _memuat = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Daftar album gagal dimuat. Pakai picker sistem atau coba lagi.'),
      ));
    }
  }

  Future<void> _gantiFilter(_FilterGaleri f) async {
    if (f == _filter || _memuat) return;
    HapticFeedback.selectionClick();
    setState(() => _filter = f);
    await _muatDaftarAlbum();
  }

  Future<void> _gantiAlbum(AssetPathEntity a) async {
    if (_aktif?.id == a.id) return;
    setState(() {
      _aktif = a;
      _memuat = true;
      _aset = [];
    });
    await _muatLagi(reset: true);
  }

  Future<void> _muatLagi({bool reset = false}) async {
    final album = _aktif;
    if (album == null) {
      if (mounted) setState(() => _memuat = false);
      return;
    }
    if (!reset && (_habis || _memuatHalaman)) return;

    final generasi = reset ? ++_generasiMuat : _generasiMuat;
    final halamanAwal = reset ? 0 : _halaman;
    _memuatHalaman = true;
    if (reset && mounted) {
      setState(() {
        _halaman = 0;
        _habis = false;
        _aset = [];
        _memuat = true;
      });
    }

    try {
      var halaman = halamanAwal;
      var sumberHabis = false;
      final tambahan = <AssetEntity>[];

      // Pada Android/iOS filter dijalankan native. Saringan lokal ini menjadi
      // pertahanan tambahan dan fallback untuk platform lain.
      do {
        final mentah = await album.getAssetListPaged(
          page: halaman,
          size: _perHalaman,
        );
        halaman++;
        sumberHabis = mentah.length < _perHalaman;
        tambahan.addAll(mentah.where(_sesuaiFilter));
      } while (tambahan.isEmpty &&
          !sumberHabis &&
          (_filter == _FilterGaleri.foto || _filter == _FilterGaleri.gif));

      if (!mounted || generasi != _generasiMuat) return;
      tambahan.sort((a, b) {
        final tanggal = b.createDateTime.compareTo(a.createDateTime);
        return tanggal != 0 ? tanggal : b.id.compareTo(a.id);
      });
      setState(() {
        _aset = reset ? tambahan : [..._aset, ...tambahan];
        _halaman = halaman;
        _habis = sumberHabis;
        _memuat = false;
      });
    } catch (_) {
      if (!mounted || generasi != _generasiMuat) return;
      setState(() => _memuat = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:
            Text('Galeri gagal dimuat. Coba lagi atau pakai picker sistem.'),
      ));
    } finally {
      if (generasi == _generasiMuat) _memuatHalaman = false;
    }
  }

  bool _sesuaiFilter(AssetEntity e) {
    final jenis = _jenisAset(e);
    return switch (_filter) {
      _FilterGaleri.foto => jenis == JenisGaleri.foto,
      _FilterGaleri.video => jenis == JenisGaleri.video,
      _FilterGaleri.gif => jenis == JenisGaleri.gif,
      _FilterGaleri.semua => widget.jenis.contains(jenis),
    };
  }

  Future<void> _pilih(AssetEntity e) async {
    if (_mengambil) return;
    final jenis = _jenisAset(e);
    if (!widget.jenis.contains(jenis)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Menu ini tidak menerima ${_labelJenis(jenis)}.'),
      ));
      return;
    }

    setState(() => _mengambil = true);
    HapticFeedback.selectionClick();
    try {
      final f = await e.file;
      if (!mounted) return;
      if (f == null) {
        setState(() => _mengambil = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Berkas tidak bisa dibaca.')),
        );
        return;
      }

      final ukuran = await f.length();
      if (!mounted) return;
      final maks = switch (jenis) {
        JenisGaleri.video => 15 * 1024 * 1024,
        JenisGaleri.gif => 8 * 1024 * 1024,
        JenisGaleri.foto => 10 * 1024 * 1024,
      };
      if (ukuran > maks) {
        if (!mounted) return;
        setState(() => _mengambil = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            '${_labelJenis(jenis)} ini ${(ukuran / 1048576).toStringAsFixed(1)} MB — batasnya ${maks ~/ 1048576} MB.',
          ),
        ));
        return;
      }
      Navigator.pop(context, f);
    } catch (_) {
      if (!mounted) return;
      setState(() => _mengambil = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Gagal membuka berkas. Coba pilih yang lain.')),
      );
    }
  }

  Widget _barFilter(XyPalette t) {
    final tersedia = _filterTersedia;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(9, 8, 9, 4),
        child: Row(children: [
          for (final f in tersedia)
            Expanded(
              child: GestureDetector(
                onTap: () => _gantiFilter(f),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: BoxDecoration(
                    color: _filter == f ? XyTheme.violet : t.lineSoft,
                    borderRadius: BorderRadius.circular(XyRadius.pill),
                    border: Border.all(
                      color: _filter == f ? XyTheme.violet : t.line,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _ikonFilter(f),
                        size: 14,
                        color: _filter == f ? Colors.white : t.muted,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          _labelFilter(f),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: _filter == f ? Colors.white : t.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(13, 2, 13, 7),
        child: Row(children: [
          Icon(Icons.update_rounded, size: 13, color: t.muted),
          const SizedBox(width: 5),
          Text('Terbaru dulu',
              style: TextStyle(
                  color: t.muted, fontSize: 10.5, fontWeight: FontWeight.w600)),
          const Spacer(),
          if (_memuat && _aset.isNotEmpty)
            SizedBox(
              width: 13,
              height: 13,
              child:
                  CircularProgressIndicator(strokeWidth: 1.8, color: t.accent),
            ),
        ]),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final t = XyTheme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: _album.length < 2
              ? null
              : () async {
                  final pilihan = await showModalBottomSheet<AssetPathEntity>(
                    context: context,
                    backgroundColor: Colors.transparent,
                    builder: (ctx) => Container(
                      margin: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: t.surfaceHigh,
                        borderRadius: BorderRadius.circular(XyRadius.xxl),
                      ),
                      child: SafeArea(
                        child: ListView(
                          shrinkWrap: true,
                          children: [
                            for (final a in _album)
                              ListTile(
                                leading: Icon(
                                  a.isAll
                                      ? Icons.photo_library_rounded
                                      : Icons.folder_rounded,
                                  color: t.accent,
                                ),
                                title: Text(a.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14)),
                                trailing: _aktif?.id == a.id
                                    ? Icon(Icons.check_rounded, color: t.accent)
                                    : null,
                                onTap: () => Navigator.pop(ctx, a),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                  if (pilihan != null) _gantiAlbum(pilihan);
                },
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Flexible(
              child: Text(
                _aktif?.name ?? widget.judul,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            if (_album.length > 1)
              const Icon(Icons.arrow_drop_down_rounded, size: 22),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(children: [
        _barFilter(t),
        Expanded(
          child: Stack(children: [
            if (_izinDitolak)
              Kosong(
                icon: Icons.no_photography_outlined,
                judul: 'Akses galeri ditolak',
                sub:
                    'Beri izin akses foto dan video, atau gunakan picker sistem.',
                ilustrasi: '',
                aksi: Column(children: [
                  GradientButton(
                    label: 'Buka Pengaturan',
                    icon: Icons.settings_rounded,
                    onPressed: PhotoManager.openSetting,
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () =>
                        Navigator.pop(context, GaleriPicker.pakaiSistem),
                    icon: const Icon(Icons.folder_open_rounded, size: 18),
                    label: const Text('Pakai picker sistem'),
                  ),
                ]),
              )
            else if (_memuat && _aset.isEmpty)
              const Center(child: CircularProgressIndicator())
            else if (_aset.isEmpty)
              Kosong(
                icon: _ikonFilter(_filter),
                judul: '${_labelFilter(_filter)} belum ada',
                sub:
                    'Tidak ditemukan di album ini. Pilih album lain atau gunakan picker sistem.',
                ilustrasi: '',
                aksi: OutlinedButton.icon(
                  onPressed: () =>
                      Navigator.pop(context, GaleriPicker.pakaiSistem),
                  icon: const Icon(Icons.folder_open_rounded, size: 18),
                  label: const Text('Pakai picker sistem'),
                ),
              )
            else
              GridView.builder(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(3, 3, 3, 90),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 3,
                  mainAxisSpacing: 3,
                ),
                itemCount: _aset.length + (_habis ? 0 : 1),
                itemBuilder: (context, i) {
                  if (i >= _aset.length) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      ),
                    );
                  }
                  final e = _aset[i];
                  return _KotakAset(
                    entity: e,
                    onTap: () => _pilih(e),
                  );
                },
              ),
            if (_mengambil)
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.black.withOpacity(.45),
                  child: const Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 12),
                      Text('Membuka berkas…',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
              ),
          ]),
        ),
      ]),
    );
  }
}

class _KotakAset extends StatefulWidget {
  const _KotakAset({required this.entity, required this.onTap});
  final AssetEntity entity;
  final VoidCallback onTap;

  @override
  State<_KotakAset> createState() => _KotakAsetState();
}

class _KotakAsetState extends State<_KotakAset> {
  Uint8List? _data;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  @override
  void didUpdateWidget(covariant _KotakAset oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entity.id != widget.entity.id) {
      _data = null;
      _muat();
    }
  }

  Future<void> _muat() async {
    try {
      final id = widget.entity.id;
      final d = await widget.entity.thumbnailDataWithSize(
        const ThumbnailSize(240, 240),
        quality: 72,
      );
      if (mounted && d != null && widget.entity.id == id) {
        setState(() => _data = d);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.entity;
    final jenis = _jenisAset(e);
    final d = _data;
    return GestureDetector(
      onTap: widget.onTap,
      child: Stack(fit: StackFit.expand, children: [
        if (d != null)
          Image.memory(d, fit: BoxFit.cover, gaplessPlayback: true)
        else
          ColoredBox(color: XyTheme.of(context).lineSoft),
        if (jenis == JenisGaleri.video)
          Positioned(
            left: 5,
            bottom: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(.68),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Row(children: [
                const Icon(Icons.play_arrow_rounded,
                    size: 12, color: Colors.white),
                const SizedBox(width: 2),
                Text(
                  _durasi(e.duration),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ]),
            ),
          ),
        if (jenis == JenisGaleri.gif)
          Positioned(
            right: 5,
            top: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(.68),
                borderRadius: BorderRadius.circular(7),
              ),
              child: const Text('GIF',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800)),
            ),
          ),
      ]),
    );
  }

  static String _durasi(int detik) {
    final m = detik ~/ 60;
    final s = detik % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

_FilterGaleri _filterDariJenis(JenisGaleri jenis) => switch (jenis) {
      JenisGaleri.foto => _FilterGaleri.foto,
      JenisGaleri.video => _FilterGaleri.video,
      JenisGaleri.gif => _FilterGaleri.gif,
    };

JenisGaleri _jenisAset(AssetEntity e) {
  if (e.type == AssetType.video) return JenisGaleri.video;
  final mime = (e.mimeType ?? '').toLowerCase();
  final nama = (e.title ?? '').toLowerCase();
  if (mime == 'image/gif' || nama.endsWith('.gif')) return JenisGaleri.gif;
  return JenisGaleri.foto;
}

JenisGaleri _jenisDariNama(String nama) {
  final n = nama.toLowerCase().split('?').first;
  if (n.endsWith('.gif')) return JenisGaleri.gif;
  if (n.endsWith('.mp4') ||
      n.endsWith('.mov') ||
      n.endsWith('.webm') ||
      n.endsWith('.mkv') ||
      n.endsWith('.avi') ||
      n.endsWith('.3gp')) {
    return JenisGaleri.video;
  }
  return JenisGaleri.foto;
}

String _labelJenis(JenisGaleri jenis) => switch (jenis) {
      JenisGaleri.foto => 'Foto',
      JenisGaleri.video => 'Video',
      JenisGaleri.gif => 'GIF',
    };

String _labelFilter(_FilterGaleri filter) => switch (filter) {
      _FilterGaleri.foto => 'Foto',
      _FilterGaleri.video => 'Video',
      _FilterGaleri.gif => 'GIF',
      _FilterGaleri.semua => 'Semua',
    };

IconData _ikonFilter(_FilterGaleri filter) => switch (filter) {
      _FilterGaleri.foto => Icons.image_rounded,
      _FilterGaleri.video => Icons.videocam_rounded,
      _FilterGaleri.gif => Icons.gif_box_rounded,
      _FilterGaleri.semua => Icons.layers_rounded,
    };
