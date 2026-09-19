import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../core/theme.dart';
import '../widgets/common.dart';

/// Video Editor Native - Trim/Cut video sebelum post
/// Fitur: preview, trim slider, cut, filter, rotate, aspect ratio
class VideoEditorScreen extends StatefulWidget {
  VideoEditorScreen({super.key, File? file, File? videoFile})
      : assert(file != null || videoFile != null, 'file/videoFile required'),
        file = file ?? videoFile!,
        videoFile = videoFile ?? file;

  final File file;
  final File? videoFile;

  @override
  State<VideoEditorScreen> createState() => _VideoEditorScreenState();
}

class _VideoEditorScreenState extends State<VideoEditorScreen> {
  VideoPlayerController? _ctrl;
  bool _memuat = true;
  double _start = 0;
  double _end = 0;
  double _durasi = 0;
  bool _isPlaying = false;
  String _filter = 'normal';
  double _volume = 1.0;
  bool _muted = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _ctrl = VideoPlayerController.file(widget.file);
    await _ctrl!.initialize();
    setState(() {
      _durasi = _ctrl!.value.duration.inSeconds.toDouble();
      _end = _durasi > 15 ? 15 : _durasi;
      _memuat = false;
    });
    _ctrl!.setLooping(true);
    _ctrl!.play();
    _isPlaying = true;
    _ctrl!.addListener(() {
      if (_ctrl!.value.position.inSeconds.toDouble() >= _end) {
        _ctrl!.seekTo(Duration(milliseconds: (_start * 1000).toInt()));
      }
    });
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  void _togglePlay() {
    if (_ctrl == null) return;
    if (_ctrl!.value.isPlaying) {
      _ctrl!.pause();
      setState(() => _isPlaying = false);
    } else {
      _ctrl!.play();
      setState(() => _isPlaying = true);
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
        title: const Text('Edit Video', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: Icon(_muted ? Icons.volume_off_rounded : Icons.volume_up_rounded, color: Colors.white),
            onPressed: () {
              setState(() => _muted = !_muted);
              _ctrl?.setVolume(_muted ? 0 : _volume);
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
            child: FilledButton(
              onPressed: () {
                Navigator.pop(context, {
                  'trim_start': _start,
                  'trim_end': _end,
                  'filter': _filter,
                  'durasi': _durasi,
                  'muted': _muted,
                });
              },
              style: FilledButton.styleFrom(backgroundColor: XyTheme.primary),
              child: const Text('Selesai', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
      body: _memuat
          ? const Center(child: SkeletonBox(width: 200, height: 200))
          : Column(
              children: [
                // Preview
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Center(
                        child: AspectRatio(
                          aspectRatio: _ctrl!.value.aspectRatio,
                          child: ColorFiltered(
                            colorFilter: _filter == 'bw'
                                ? const ColorFilter.matrix([0.2126, 0.7152, 0.0722, 0, 0, 0.2126, 0.7152, 0.0722, 0, 0, 0.2126, 0.7152, 0.0722, 0, 0, 0, 0, 0, 1, 0])
                                : _filter == 'sepia'
                                    ? const ColorFilter.matrix([0.393, 0.769, 0.189, 0, 0, 0.349, 0.686, 0.168, 0, 0, 0.272, 0.534, 0.131, 0, 0, 0, 0, 0, 1, 0])
                                    : _filter == 'vivid'
                                        ? const ColorFilter.matrix([1.2, 0, 0, 0, 0, 0, 1.2, 0, 0, 0, 0, 0, 1.2, 0, 0, 0, 0, 0, 1, 0])
                                        : const ColorFilter.mode(Colors.transparent, BlendMode.multiply),
                            child: VideoPlayer(_ctrl!),
                          ),
                        ),
                      ),
                      // Play button overlay
                      Center(
                        child: GestureDetector(
                          onTap: _togglePlay,
                          child: AnimatedOpacity(
                            opacity: _isPlaying ? 0 : 1,
                            duration: const Duration(milliseconds: 200),
                            child: Container(
                              width: 64, height: 64,
                              decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle, border: Border.all(color: Colors.white30)),
                              child: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 36),
                            ),
                          ),
                        ),
                      ),
                      // Duration badge
                      Positioned(
                        top: 12, right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                          child: Text('${_durasi.toStringAsFixed(1)}s • ${_end - _start <= 0 ? 0 : (_end - _start).toStringAsFixed(1)}s terpilih', style: const TextStyle(color: Colors.white, fontSize: 11)),
                        ),
                      ),
                    ],
                  ),
                ),

                // Controls
                Container(
                  color: const Color(0xFF121212),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Trim slider
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          const Text('Trim Video', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                          Text('${_start.toStringAsFixed(1)}s - ${_end.toStringAsFixed(1)}s', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                        ]),
                        const SizedBox(height: 4),
                        RangeSlider(
                          min: 0, max: _durasi,
                          values: RangeValues(_start, _end),
                          activeColor: XyTheme.primary,
                          inactiveColor: Colors.white24,
                          onChanged: (v) {
                            if (v.end - v.start <= 15 && v.end - v.start >= 1) {
                              setState(() { _start = v.start; _end = v.end; });
                              _ctrl?.seekTo(Duration(milliseconds: (v.start * 1000).toInt()));
                            }
                          },
                        ),
                        const Text('Maksimal 15 detik untuk story. Geser untuk potong bagian terbaik.', style: TextStyle(color: Colors.white38, fontSize: 10)),
                        const SizedBox(height: 12),

                        // Filter
                        const Text('Filter', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 70,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: 7,
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (_, i) {
                              final filters = ['normal', 'bw', 'sepia', 'vintage', 'vivid', 'warm', 'cool'];
                              final labels = ['Normal', 'B&W', 'Sepia', 'Vintage', 'Vivid', 'Warm', 'Cool'];
                              final aktif = _filter == filters[i];
                              return GestureDetector(
                                onTap: () => setState(() => _filter = filters[i]),
                                child: Container(
                                  width: 60,
                                  decoration: BoxDecoration(color: aktif ? XyTheme.primary : Colors.white10, borderRadius: BorderRadius.circular(10), border: Border.all(color: aktif ? XyTheme.primary : Colors.white24)),
                                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                    Icon(Icons.filter_rounded, size: 20, color: aktif ? Colors.white : Colors.white70),
                                    const SizedBox(height: 4),
                                    Text(labels[i], style: TextStyle(fontSize: 9, color: aktif ? Colors.white : Colors.white70, fontWeight: FontWeight.w600)),
                                  ]),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Volume
                        Row(children: [
                          const Icon(Icons.volume_up_rounded, size: 18, color: Colors.white70),
                          const SizedBox(width: 8),
                          const Text('Volume', style: TextStyle(color: Colors.white70, fontSize: 12)),
                          Expanded(child: Slider(value: _volume, min: 0, max: 1, activeColor: XyTheme.primary, onChanged: (v) { setState(() => _volume = v); if (!_muted) _ctrl?.setVolume(v); })),
                        ]),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
