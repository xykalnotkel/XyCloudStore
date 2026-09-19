import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import '../../core/theme.dart';
import '../../core/kompres.dart';
import '../../models/models.dart';
import '../../providers/app_state.dart';
import '../widgets/common.dart';
import '../widgets/galeri_picker.dart';
import '../widgets/lembar.dart';
import 'video_editor_screen.dart';

/// Story Editor Lengkap ala Instagram
/// Fitur: gaya teks, background, label/no label, filter, trim video native
class StoryEditorScreen extends StatefulWidget {
  const StoryEditorScreen({super.key, this.onStoryDibuat});
  final ValueChanged<StoryItem>? onStoryDibuat;

  @override
  State<StoryEditorScreen> createState() => _StoryEditorScreenState();
}

class _StoryEditorScreenState extends State<StoryEditorScreen> {
  final _teksCtrl = TextEditingController();
  String _bgGradient = 'ungu';
  String _privasi = 'teman';
  String? _mediaDataUri;
  String? _bgImageDataUri;
  String _tipeMedia = 'teks';
  bool _memuat = false;

  // Editor teks
  String _gayaTeks = 'normal';
  String _warnaTeks = '#FFFFFF';
  int _ukuranTeks = 21;
  String _alignTeks = 'center';
  String _bgType = 'gradient';
  String _bgWarna = '#6B21A8';
  bool _teksBg = true;
  String _teksBgWarna = '#00000073';
  String _filter = 'normal';
  List<Map<String, dynamic>> _labels = [];
  double _trimStart = 0;
  double _trimEnd = 0;
  double _durasiVideo = 0;

  VideoPlayerController? _videoCtrl;
  bool _showTextEditor = true;
  bool _showBgEditor = false;
  bool _showLabelEditor = false;

  final _opsiBg = const [
    ('ungu', Color(0xFF6B21A8), 'Ungu'),
    ('emas', Color(0xFFD97706), 'Emas'),
    ('neon', Color(0xFF0284C7), 'Neon'),
    ('senja', Color(0xFFBE185D), 'Senja'),
    ('cyber', Color(0xFF1E1B4B), 'Cyber'),
  ];

  final _opsiGaya = const [
    ('normal', 'Normal', Icons.text_fields_rounded),
    ('bold', 'Bold', Icons.format_bold_rounded),
    ('italic', 'Italic', Icons.format_italic_rounded),
    ('bold_italic', 'Bold Italic', Icons.format_bold_rounded),
    ('neon', 'Neon', Icons.lightbulb_rounded),
    ('pelangi', 'Pelangi', Icons.color_lens_rounded),
    ('ketik', 'Ketik', Icons.keyboard_rounded),
    ('ombak', 'Ombak', Icons.waves_rounded),
    ('retro', 'Retro', Icons.style_rounded),
    ('minimal', 'Minimal', Icons.minimize_rounded),
  ];

  final _opsiWarna = const [
    '#FFFFFF', '#000000', '#FF0000', '#00FF00', '#0000FF',
    '#FFFF00', '#FF00FF', '#00FFFF', '#FFA500', '#800080',
    '#FFC0CB', '#A52A2A', '#808080', '#FFD700', '#4B0082',
  ];

  final _opsiFilter = const [
    ('normal', 'Normal'),
    ('bw', 'B&W'),
    ('sepia', 'Sepia'),
    ('vintage', 'Vintage'),
    ('vivid', 'Vivid'),
    ('warm', 'Warm'),
    ('cool', 'Cool'),
  ];

  @override
  void dispose() {
    _teksCtrl.dispose();
    _videoCtrl?.dispose();
    super.dispose();
  }

  Color _hexToColor(String hex) {
    try {
      var h = hex.replaceAll('#', '');
      if (h.length == 6) h = 'FF$h';
      return Color(int.parse(h, radix: 16));
    } catch (_) {
      return Colors.white;
    }
  }

  LinearGradient _getGradient(String jenis) {
    switch (jenis) {
      case 'emas': return const LinearGradient(colors: [Color(0xFF78350F), Color(0xFFD97706), Color(0xFFF59E0B)]);
      case 'neon': return const LinearGradient(colors: [Color(0xFF0284C7), Color(0xFF06B6D4), Color(0xFF10B981)]);
      case 'senja': return const LinearGradient(colors: [Color(0xFF831843), Color(0xFFBE185D), Color(0xFFFB7185)]);
      case 'cyber': return const LinearGradient(colors: [Color(0xFF1E1B4B), Color(0xFF4C1D95), Color(0xFF06B6D4)]);
      default: return const LinearGradient(colors: [Color(0xFF3B0764), Color(0xFF6B21A8), Color(0xFFA855F7)]);
    }
  }

  TextStyle _currentTextStyle() {
    return TextStyle(
      color: _hexToColor(_warnaTeks),
      fontSize: _ukuranTeks.toDouble(),
      fontWeight: _gayaTeks.contains('bold') ? FontWeight.w800 : FontWeight.w700,
      fontStyle: _gayaTeks.contains('italic') ? FontStyle.italic : FontStyle.normal,
      letterSpacing: _gayaTeks == 'ketik' ? 1.2 : -0.2,
      shadows: _gayaTeks == 'neon'
          ? [Shadow(color: _hexToColor(_warnaTeks).withOpacity(0.8), blurRadius: 12)]
          : _gayaTeks == 'retro'
              ? [const Shadow(color: Colors.black, offset: Offset(3, 3), blurRadius: 0)]
              : null,
    );
  }

  Future<void> _pickImage() async {
    final f = await GaleriPicker.pilihGambar(context);
    if (f != null && mounted) {
      final bytes = await f.readAsBytes();
      final uri = await Kompres.dataUri(bytes, f.path.split('/').last, maxSisi: 1080, kualitas: 75);
      setState(() {
        _mediaDataUri = uri;
        _tipeMedia = 'gambar';
        _bgType = 'image';
      });
    }
  }

  Future<void> _pickVideo() async {
    final f = await GaleriPicker.buka(context, jenis: const {JenisGaleri.video, JenisGaleri.gif}, judul: 'Pilih Video Story');
    if (f != null && mounted && f is File) {
      // Open native trim editor first
      final hasil = await Navigator.push<Map<String, dynamic>?>(
        context,
        MaterialPageRoute(builder: (_) => VideoEditorScreen(videoFile: f)),
      );
      if (hasil != null && mounted) {
        final start = (hasil['trim_start'] ?? 0.0) as double;
        final end = (hasil['trim_end'] ?? 15.0) as double;
        final filter = hasil['filter'] ?? 'normal';
        // For now we keep original file but store trim values; real trim would need ffmpeg, we store metadata
        final bytes = await f.readAsBytes();
        final nama = f.path.split('/').last.toLowerCase();
        final mime = nama.endsWith('.gif') ? 'image/gif' : 'video/mp4';
        _videoCtrl?.dispose();
        _videoCtrl = VideoPlayerController.file(f)
          ..initialize().then((_) {
            if (mounted) {
              setState(() {
                _durasiVideo = _videoCtrl!.value.duration.inSeconds.toDouble();
                _trimStart = start;
                _trimEnd = end > _durasiVideo ? _durasiVideo : end;
                _filter = filter;
              });
              _videoCtrl!.seekTo(Duration(milliseconds: (start * 1000).toInt()));
              _videoCtrl!.play();
              _videoCtrl!.setLooping(true);
            }
          });
        setState(() {
          _mediaDataUri = 'data:$mime;base64,${base64Encode(bytes)}';
          _tipeMedia = 'video';
          _bgType = 'video';
          _trimStart = start;
          _trimEnd = end;
          _filter = filter;
        });
      } else if (mounted) {
        // Fallback if user cancels editor, still use file without trim
        final bytes = await f.readAsBytes();
        final nama = f.path.split('/').last.toLowerCase();
        final mime = nama.endsWith('.gif') ? 'image/gif' : 'video/mp4';
        _videoCtrl?.dispose();
        _videoCtrl = VideoPlayerController.file(f)
          ..initialize().then((_) {
            if (mounted) {
              setState(() {
                _durasiVideo = _videoCtrl!.value.duration.inSeconds.toDouble();
                _trimEnd = _durasiVideo > 15 ? 15 : _durasiVideo;
              });
              _videoCtrl!.play();
              _videoCtrl!.setLooping(true);
            }
          });
        setState(() {
          _mediaDataUri = 'data:$mime;base64,${base64Encode(bytes)}';
          _tipeMedia = 'video';
          _bgType = 'video';
        });
      }
    }
  }

  Future<void> _pickBgImage() async {
    final f = await GaleriPicker.pilihGambar(context);
    if (f != null && mounted) {
      final bytes = await f.readAsBytes();
      final uri = await Kompres.dataUri(bytes, f.path.split('/').last, maxSisi: 1080, kualitas: 75);
      setState(() {
        _bgImageDataUri = uri;
        _bgType = 'image';
      });
    }
  }

  void _addLabel(String type) async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Tambah ${type[0].toUpperCase()}${type.substring(1)}'),
        content: TextField(controller: ctrl, decoration: InputDecoration(hintText: 'Masukkan $type', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), autofocus: true),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')), FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Tambah'))],
      ),
    );
    if (result != null && result.isNotEmpty) {
      setState(() => _labels.add({'type': type, 'text': result}));
    }
  }

  Future<void> _kirim() async {
    final t = _teksCtrl.text.trim();
    if (t.isEmpty && _mediaDataUri == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tulis sesuatu atau pilih media untuk story.')));
      return;
    }
    setState(() => _memuat = true);
    final galat = await context.read<AppState>().buatStory(
      teks: t,
      mediaUrl: _mediaDataUri,
      tipe: _mediaDataUri != null ? _tipeMedia : 'teks',
      bgGradient: _bgGradient,
      privasi: _privasi,
      gayaTeks: _gayaTeks,
      warnaTeks: _warnaTeks,
      ukuranTeks: _ukuranTeks,
      alignTeks: _alignTeks,
      bgType: _bgType,
      bgWarna: _bgWarna,
      bgImageUrl: _bgImageDataUri,
      teksBg: _teksBg,
      teksBgWarna: _teksBgWarna,
      label: _labels.isEmpty ? '' : jsonEncode(_labels),
      trimStart: _trimStart,
      trimEnd: _trimEnd,
      filter: _filter,
      durasiVideo: _durasiVideo,
    );
    if (!mounted) return;
    setState(() => _memuat = false);
    if (galat == null) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Story berhasil dibagikan (aktif 24 jam)!')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(galat)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = XyTheme.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Editor Story', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        actions: [
          XyPillSelector<String>(
            value: _privasi,
            title: 'Privasi',
            options: const [
              XyDropdownOption(value: 'teman', label: 'Teman', icon: Icons.people_alt_rounded),
              XyDropdownOption(value: 'publik', label: 'Publik', icon: Icons.public_rounded),
            ],
            onChanged: (v) => setState(() => _privasi = v),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
            child: FilledButton(
              onPressed: _memuat ? null : _kirim,
              style: FilledButton.styleFrom(backgroundColor: XyTheme.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 16)),
              child: _memuat ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Bagikan', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Preview area
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: _bgType == 'solid' ? LinearGradient(colors: [_hexToColor(_bgWarna), _hexToColor(_bgWarna)]) : _getGradient(_bgGradient),
                color: _bgType == 'solid' ? _hexToColor(_bgWarna) : null,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_bgImageDataUri != null && _bgType == 'image')
                    Positioned.fill(child: Image.memory(base64Decode(_bgImageDataUri!.split(',').last), fit: BoxFit.cover)),
                  if (_mediaDataUri != null)
                    Positioned.fill(
                      child: _tipeMedia == 'video' && _videoCtrl != null && _videoCtrl!.value.isInitialized
                          ? Center(child: AspectRatio(aspectRatio: _videoCtrl!.value.aspectRatio, child: VideoPlayer(_videoCtrl!)))
                          : _tipeMedia == 'gambar'
                              ? Image.memory(base64Decode(_mediaDataUri!.split(',').last), fit: BoxFit.contain)
                              : const SizedBox.shrink(),
                    ),
                  if (_teksCtrl.text.isNotEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Container(
                          padding: _teksBg ? const EdgeInsets.symmetric(horizontal: 20, vertical: 16) : EdgeInsets.zero,
                          decoration: _teksBg ? BoxDecoration(color: _hexToColor(_teksBgWarna), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white12)) : null,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_teksCtrl.text, style: _currentTextStyle(), textAlign: _alignTeks == 'left' ? TextAlign.left : _alignTeks == 'right' ? TextAlign.right : TextAlign.center),
                              if (_labels.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Wrap(spacing: 6, runSpacing: 6, children: _labels.map((e) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white24)),
                                  child: Text(e['text'], style: const TextStyle(color: Colors.white, fontSize: 11)),
                                )).toList()),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Trim video slider if video
          if (_tipeMedia == 'video' && _durasiVideo > 0)
            Container(
              color: Colors.black,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Trim Video (max 15 detik)', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                    Text('${_trimStart.toStringAsFixed(1)}s - ${_trimEnd.toStringAsFixed(1)}s', style: const TextStyle(color: Colors.white, fontSize: 11)),
                  ]),
                  RangeSlider(
                    min: 0, max: _durasiVideo,
                    values: RangeValues(_trimStart, _trimEnd),
                    activeColor: XyTheme.primary,
                    inactiveColor: Colors.white24,
                    labels: RangeLabels('${_trimStart.toStringAsFixed(1)}s', '${_trimEnd.toStringAsFixed(1)}s'),
                    onChanged: (v) {
                      if (v.end - v.start <= 15) {
                        setState(() { _trimStart = v.start; _trimEnd = v.end; });
                        _videoCtrl?.seekTo(Duration(milliseconds: (v.start * 1000).toInt()));
                      }
                    },
                  ),
                ],
              ),
            ),

          // Editor controls
          Container(
            color: pal.surfaceHigh,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Tab selector
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: pal.line))),
                    child: Row(
                      children: [
                        _TabBtn(icon: Icons.text_fields_rounded, label: 'Teks', aktif: _showTextEditor, onTap: () => setState(() { _showTextEditor = true; _showBgEditor = false; _showLabelEditor = false; })),
                        _TabBtn(icon: Icons.palette_rounded, label: 'Background', aktif: _showBgEditor, onTap: () => setState(() { _showTextEditor = false; _showBgEditor = true; _showLabelEditor = false; })),
                        _TabBtn(icon: Icons.label_rounded, label: 'Label', aktif: _showLabelEditor, onTap: () => setState(() { _showTextEditor = false; _showBgEditor = false; _showLabelEditor = true; })),
                        const Spacer(),
                        IconButton(onPressed: _pickImage, icon: const Icon(Icons.image_rounded), tooltip: 'Gambar'),
                        IconButton(onPressed: _pickVideo, icon: const Icon(Icons.videocam_rounded), tooltip: 'Video'),
                        if (_mediaDataUri != null) IconButton(onPressed: () => setState(() { _mediaDataUri = null; _tipeMedia = 'teks'; _videoCtrl?.dispose(); _videoCtrl = null; }), icon: const Icon(Icons.close_rounded, color: Colors.redAccent)),
                      ],
                    ),
                  ),

                  // Content
                  if (_showTextEditor)
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _teksCtrl,
                            maxLines: 4,
                            maxLength: 1000,
                            style: _currentTextStyle().copyWith(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Tulis story kamu...',
                              hintStyle: const TextStyle(color: Colors.white54),
                              filled: true,
                              fillColor: Colors.white10,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                              counterStyle: const TextStyle(color: Colors.white54, fontSize: 11),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 12),
                          const Text('Gaya Teks', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 72,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: _opsiGaya.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 8),
                              itemBuilder: (_, i) {
                                final g = _opsiGaya[i];
                                final aktif = _gayaTeks == g.$1;
                                return Pressable(
                                  onTap: () => setState(() => _gayaTeks = g.$1),
                                  child: Container(
                                    width: 64,
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(color: aktif ? XyTheme.primary : Colors.white10, borderRadius: BorderRadius.circular(12), border: Border.all(color: aktif ? XyTheme.primary : Colors.white12)),
                                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                      Icon(g.$3, size: 20, color: aktif ? Colors.white : Colors.white70),
                                      const SizedBox(height: 4),
                                      Text(g.$2, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: aktif ? Colors.white : Colors.white70), textAlign: TextAlign.center),
                                    ]),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text('Warna Teks', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                          const SizedBox(height: 8),
                          Wrap(spacing: 8, runSpacing: 8, children: _opsiWarna.map((c) => GestureDetector(
                            onTap: () => setState(() => _warnaTeks = c),
                            child: Container(width: 32, height: 32, decoration: BoxDecoration(color: _hexToColor(c), shape: BoxShape.circle, border: Border.all(color: _warnaTeks == c ? Colors.white : Colors.transparent, width: 2))),
                          )).toList()),
                          const SizedBox(height: 12),
                          Row(children: [
                            const Text('Ukuran', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                            Expanded(child: Slider(value: _ukuranTeks.toDouble(), min: 14, max: 40, activeColor: XyTheme.primary, onChanged: (v) => setState(() => _ukuranTeks = v.toInt()))),
                            Text('${_ukuranTeks}px', style: const TextStyle(fontSize: 11)),
                          ]),
                          const SizedBox(height: 8),
                          Row(children: [
                            const Text('Align', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                            const SizedBox(width: 12),
                            ...[
                              ('left', Icons.format_align_left_rounded),
                              ('center', Icons.format_align_center_rounded),
                              ('right', Icons.format_align_right_rounded),
                            ].map((e) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Pressable(
                                onTap: () => setState(() => _alignTeks = e.$1),
                                child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: _alignTeks == e.$1 ? XyTheme.primary : Colors.white10, borderRadius: BorderRadius.circular(8)), child: Icon(e.$2, size: 18, color: Colors.white)),
                              ),
                            )),
                            const Spacer(),
                            const Text('BG Teks', style: TextStyle(fontSize: 11)),
                            Switch(value: _teksBg, activeColor: XyTheme.primary, onChanged: (v) => setState(() => _teksBg = v)),
                          ]),
                        ],
                      ),
                    ),

                  if (_showBgEditor)
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Tipe Background', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                          const SizedBox(height: 8),
                          Row(children: [
                            _BgTypeBtn(label: 'Gradient', aktif: _bgType == 'gradient', onTap: () => setState(() => _bgType = 'gradient')),
                            _BgTypeBtn(label: 'Solid', aktif: _bgType == 'solid', onTap: () => setState(() => _bgType = 'solid')),
                            _BgTypeBtn(label: 'Image', aktif: _bgType == 'image', onTap: () => setState(() => _bgType = 'image')),
                          ]),
                          const SizedBox(height: 12),
                          if (_bgType == 'gradient') ...[
                            const Text('Pilih Gradient', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                            const SizedBox(height: 8),
                            Wrap(spacing: 8, runSpacing: 8, children: _opsiBg.map((op) => GestureDetector(
                              onTap: () => setState(() { _bgGradient = op.$1; _bgType = 'gradient'; }),
                              child: Container(width: 60, height: 40, decoration: BoxDecoration(gradient: _getGradient(op.$1), borderRadius: BorderRadius.circular(10), border: Border.all(color: _bgGradient == op.$1 ? Colors.white : Colors.transparent, width: 2)), child: Center(child: Text(op.$3, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)))),
                            )).toList()),
                          ],
                          if (_bgType == 'solid') ...[
                            const Text('Warna Solid', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                            const SizedBox(height: 8),
                            Wrap(spacing: 8, runSpacing: 8, children: _opsiWarna.map((c) => GestureDetector(
                              onTap: () => setState(() { _bgWarna = c; _bgType = 'solid'; _bgGradient = 'solid'; }),
                              child: Container(width: 36, height: 36, decoration: BoxDecoration(color: _hexToColor(c), shape: BoxShape.circle, border: Border.all(color: _bgWarna == c ? Colors.white : Colors.white24, width: 2))),
                            )).toList()),
                          ],
                          if (_bgType == 'image') ...[
                            Row(children: [
                              const Text('Background Image', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                              const Spacer(),
                              FilledButton.icon(onPressed: _pickBgImage, icon: const Icon(Icons.add_photo_alternate_rounded, size: 16), label: const Text('Pilih')),
                              if (_bgImageDataUri != null) IconButton(onPressed: () => setState(() => _bgImageDataUri = null), icon: const Icon(Icons.close_rounded, color: Colors.redAccent)),
                            ]),
                          ],
                          const SizedBox(height: 12),
                          const Text('Filter', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                          const SizedBox(height: 8),
                          Wrap(spacing: 8, children: _opsiFilter.map((f) => ChoiceChip(label: Text(f.$2, style: const TextStyle(fontSize: 11)), selected: _filter == f.$1, onSelected: (_) => setState(() => _filter = f.$1))).toList()),
                        ],
                      ),
                    ),

                  if (_showLabelEditor)
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const Text('Label / Stiker (No Label jika kosong)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                            const Spacer(),
                            if (_labels.isNotEmpty) TextButton(onPressed: () => setState(() => _labels.clear()), child: const Text('Hapus Semua', style: TextStyle(fontSize: 11))),
                          ]),
                          const SizedBox(height: 8),
                          Wrap(spacing: 8, runSpacing: 8, children: [
                            _LabelAddBtn(icon: Icons.location_on_rounded, label: 'Lokasi', onTap: () => _addLabel('location')),
                            _LabelAddBtn(icon: Icons.alternate_email_rounded, label: 'Mention', onTap: () => _addLabel('mention')),
                            _LabelAddBtn(icon: Icons.tag_rounded, label: 'Hashtag', onTap: () => _addLabel('hashtag')),
                            _LabelAddBtn(icon: Icons.timer_rounded, label: 'Countdown', onTap: () => _addLabel('countdown')),
                            _LabelAddBtn(icon: Icons.mood_rounded, label: 'Mood', onTap: () => _addLabel('mood')),
                          ]),
                          const SizedBox(height: 12),
                          if (_labels.isEmpty)
                            Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)), child: const Center(child: Text('No Label - story tanpa label tambahan', style: TextStyle(color: Colors.white54, fontSize: 12)))),
                          if (_labels.isNotEmpty)
                            Wrap(spacing: 8, runSpacing: 8, children: _labels.asMap().entries.map((e) => Chip(
                              label: Text(e.value['text'], style: const TextStyle(fontSize: 11)),
                              deleteIcon: const Icon(Icons.close_rounded, size: 14),
                              onDeleted: () => setState(() => _labels.removeAt(e.key)),
                            )).toList()),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabBtn extends StatelessWidget {
  const _TabBtn({required this.icon, required this.label, required this.aktif, required this.onTap});
  final IconData icon;
  final String label;
  final bool aktif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Pressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(color: aktif ? XyTheme.primary : Colors.white10, borderRadius: BorderRadius.circular(20)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}

class _BgTypeBtn extends StatelessWidget {
  const _BgTypeBtn({required this.label, required this.aktif, required this.onTap});
  final String label;
  final bool aktif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Pressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(color: aktif ? XyTheme.primary : Colors.white10, borderRadius: BorderRadius.circular(10), border: Border.all(color: aktif ? XyTheme.primary : Colors.white24)),
          child: Text(label, style: TextStyle(color: aktif ? Colors.white : Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}

class _LabelAddBtn extends StatelessWidget {
  const _LabelAddBtn({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white24)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: Colors.white70),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
          const Icon(Icons.add_rounded, size: 14, color: Colors.white54),
        ]),
      ),
    );
  }
}
