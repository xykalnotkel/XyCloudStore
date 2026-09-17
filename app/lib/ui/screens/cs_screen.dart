import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/galeri_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';

import '../../core/format.dart';
import '../../core/kompres.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/app_state.dart';
import '../widgets/lembar.dart';

/// Tampilkan lama suara sebagai m:ss.
String _fmtDur(double? detik) {
  final t = (detik ?? 0).round();
  final m = t ~/ 60, s = t % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

/// Keterangan jenis pesan yang dibalas (untuk strip reply).
String _labelTipe(String? tipe) => switch (tipe) {
      'gambar' => 'Foto',
      'audio' => 'Pesan suara',
      _ => 'Pesan',
    };

/// Live chat CS — pesan masuk lewat WebSocket (atau simulasi di mode mock).
/// V2: balasan (reply) ala WhatsApp, pesan suara (tekan-tahan mic, geser ke
/// atas untuk membatalkan), dan gambar tampil polos tanpa kotak label.
class CsScreen extends StatefulWidget {
  const CsScreen({super.key});
  @override
  State<CsScreen> createState() => _CsScreenState();
}

class _CsScreenState extends State<CsScreen> {
  final ctrl = TextEditingController();
  final scroll = ScrollController();
  final _kunciPesan = <String, GlobalKey>{};
  bool _sending = false;
  Timer? _retensi;
  ChatMessage? _balas;

  // --- rekam suara (gestur ala WhatsApp: atas=batal, kiri=hapus, tahan=kunci) ---
  final _rec = AudioRecorder();
  bool _rekam = false;
  bool _batal = false;
  bool _hapus = false;
  bool _kunci = false;
  double _angkat = 0; // dy: geseran ke atas (negatif = naik)
  double _geser = 0; // dx: geseran ke kiri (negatif = ke kiri)
  int _detik = 0;
  Timer? _stopwatch;
  Timer? _kunciTimer;

  static const cepat = [
    'Halo Kirana, aku mau tanya',
    'Cara isi saldo gimana?',
    'PC-nya lag, tolong dicek',
    'Akun yang aku beli bermasalah',
    'Berapa lama garansinya?',
    'Mau minta refund pesanan',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().muatChat();
      _keBawah();
    });
    _retensi = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) context.read<AppState>().muatChat();
    });
  }

  @override
  void dispose() {
    _retensi?.cancel();
    _stopwatch?.cancel();
    _kunciTimer?.cancel();
    ctrl.dispose();
    scroll.dispose();
    _rec.dispose();
    super.dispose();
  }

  void _keBawah({bool animasi = true}) {
    if (!scroll.hasClients) return;
    final tujuan = scroll.position.maxScrollExtent;
    if (animasi) {
      scroll.animateTo(tujuan,
          duration: const Duration(milliseconds: 260), curve: Curves.easeOut);
    } else {
      scroll.jumpTo(tujuan);
    }
  }

  /// Loncat ke pesan asal ketika strip balasan diketuk.
  void _loncatKe(String? id) {
    if (id == null) return;
    final ctx = _kunciPesan[id]?.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      alignment: .45,
    );
  }

  /// Ambil gambar dari galeri lalu kirim sebagai lampiran chat (tanpa kotak).
  Future<void> _kirimGambar() async {
    if (_rekam) return;
    final f = await GaleriPicker.pilihGambar(context);
    if (f == null) return;
    final bytes = await f.readAsBytes();
    // Kompres ke WebP dulu biar unggahan ringan dan cepat.
    final dataUri = await Kompres.dataUri(bytes, f.path.split('/').last);
    if (!mounted) return;
    await context.read<AppState>().kirimChat(
          '',
          gambar: dataUri,
          pratinjauGambar: dataUri,
          replyTo: _balas?.id,
          replyTeks: _balas == null ? null : _cuplikan(_balas!),
          replyTipe: _balas?.tipe,
        );
    if (mounted) {
      setState(() => _balas = null);
      _keBawah();
    }
  }

  String? _cuplikan(ChatMessage m) {
    if (m.tipe == 'audio') return null; // cukup label "Pesan suara"
    final t = m.tipe == 'gambar' ? (m.teks.isNotEmpty ? m.teks : null) : m.teks;
    return (t ?? '').replaceAll('\n', ' ');
  }

  Future<void> _kirim([String? teks]) async {
    final t = (teks ?? ctrl.text).trim();
    if (t.isEmpty || _sending || _rekam) return;
    setState(() => _sending = true);
    final balas = _balas;
    final e = await context.read<AppState>().kirimChat(
          t,
          replyTo: balas?.id,
          replyTeks: balas == null ? null : _cuplikan(balas),
          replyTipe: balas?.tipe,
        );
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (e == null) {
        ctrl.clear();
        _balas = null;
      }
    });
    if (e != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e)));
    }
    _keBawah();
  }

  // ------------------------------------------------------------------
  //  Pesan suara: tekan-tahan mic; geser ke atas (>= 70px) = batalkan.
  // ------------------------------------------------------------------
  Future<void> _mulaiRekam() async {
    if (_rekam) return;
    try {
      if (!await _rec.hasPermission()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Izinkan akses mikrofon untuk mengirim pesan suara.')));
        return;
      }
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/xy_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _rec.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 32000,
          sampleRate: 44100,
          numChannels: 1,
          autoGain: true,
        ),
        path: path,
      );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() {
        _rekam = true;
        _batal = false;
        _hapus = false;
        _kunci = false;
        _angkat = 0;
        _geser = 0;
        _detik = 0;
      });
      _stopwatch?.cancel();
      _stopwatch = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted && _rekam) setState(() => _detik++);
      });
      // Tahan jari diam-diam ~1,4 detik → rekaman terkunci (hands-free).
      _kunciTimer?.cancel();
      _kunciTimer = Timer(const Duration(milliseconds: 1400), () {
        if (!mounted || !_rekam || _kunci) return;
        if (_batal || _hapus) return;
        HapticFeedback.mediumImpact();
        SystemSound.play(SystemSoundType.click);
        setState(() => _kunci = true);
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Tidak bisa mulai merekam. Coba periksa mikrofon.')));
    }
  }

  Future<void> _hentiRekam({required bool batal}) async {
    _stopwatch?.cancel();
    _kunciTimer?.cancel();
    String? jalur;
    try {
      if (batal) {
        await _rec.cancel();
      } else {
        jalur = await _rec.stop();
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _rekam = false;
      _batal = false;
      _hapus = false;
      _kunci = false;
      _angkat = 0;
      _geser = 0;
    });
    if (batal || jalur == null) return;
    final detik = _detik < 1 ? 1 : _detik;
    if (detik < 1) return;
    try {
      final bytes = await File(jalur).readAsBytes();
      if (bytes.isEmpty) return;
      final dataUri = 'data:audio/mp4;base64,${base64Encode(bytes)}';
      if (!mounted) return;
      final balas = _balas;
      final e = await context.read<AppState>().kirimChat(
            '',
            audio: dataUri,
            durasi: detik.toDouble(),
            pratinjauAudio: dataUri,
            replyTo: balas?.id,
            replyTeks: balas == null ? null : _cuplikan(balas),
            replyTipe: balas?.tipe,
          );
      if (mounted) {
        setState(() => _balas = null);
        if (e != null) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(e)));
        }
        _keBawah();
      }
    } catch (_) {}
  }

  int _jumlahTerakhir = 0;

  // ------------------------------------------------------------------
  //  Menu tekan-lama pada pesan.
  // ------------------------------------------------------------------
  Future<void> _menuPesan(BuildContext context, ChatMessage m) async {
    if (m.tipe == 'system') return;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (d) => Container(
        padding: EdgeInsets.fromLTRB(
            20, 14, 20, MediaQuery.of(d).padding.bottom + 18),
        decoration: BoxDecoration(
          color: XyTheme.of(context).bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 44,
            height: 4.5,
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
                color: XyTheme.of(context).line,
                borderRadius: BorderRadius.circular(10)),
          ),
          ListTile(
            leading: Icon(Icons.reply_rounded, color: XyTheme.primary),
            title: const Text('Balas',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            onTap: () {
              Navigator.pop(d);
              if (!mounted) return;
              setState(() => _balas = m);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (scroll.hasClients) {
                  scroll.animateTo(scroll.position.maxScrollExtent,
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut);
                }
              });
            },
          ),
          if (m.teks.isNotEmpty)
            ListTile(
              leading: Icon(Icons.copy_rounded, color: XyTheme.primary),
              title: const Text('Salin pesan',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              onTap: () {
                Clipboard.setData(ClipboardData(text: m.teks));
                Navigator.pop(d);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Pesan disalin'),
                    duration: Duration(seconds: 1)));
              },
            ),
          if (m.milikSaya)
            ListTile(
              leading:
                  Icon(Icons.delete_outline_rounded, color: XyTheme.danger),
              title: const Text('Hapus pesan',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: XyTheme.danger)),
              onTap: () async {
                Navigator.pop(d);
                final pesan =
                    await context.read<AppState>().hapusPesan(m.id);
                if (pesan != null && context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(pesan)));
                }
              },
            ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();

    if (s.chat.length != _jumlahTerakhir) {
      _jumlahTerakhir = s.chat.length;
      WidgetsBinding.instance.addPostFrameCallback((_) => _keBawah());
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: Row(children: [
          Stack(children: [
            const CircleAvatar(
              radius: 20,
              backgroundColor: XyTheme.primary,
              child: Icon(Icons.support_agent_rounded,
                  color: Colors.white, size: 22),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: XyTheme.of(context).muted,
                  shape: BoxShape.circle,
                  border: Border.all(color: XyTheme.of(context).bg, width: 2),
                ),
              ),
            ),
          ]),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('Bantuan XyCloud',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
                Text(
                    s.csMengetik
                        ? 'sedang mengetik...'
                        : 'Riwayat disimpan 7 hari',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11.5,
                        color: XyTheme.of(context).muted,
                        fontWeight: FontWeight.w600)),
              ])),
        ]),
        actions: [
          IconButton(
            onPressed: () => context.read<AppState>().muatChat(),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Muat ulang percakapan',
          ),
          IconButton(
            tooltip: 'Bersihkan pesanku',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: () async {
              final yakin = await konfirmasi(
                context,
                judul: 'Bersihkan pesanmu?',
                pesan:
                    'Semua pesan yang pernah kamu kirim akan dihapus dari percakapan ini. '
                    'Balasan Kirana tetap tersimpan.',
                tombolYa: 'Bersihkan',
                ikon: Icons.delete_sweep_outlined,
                bahaya: true,
              );
              if (!yakin || !context.mounted) return;
              final pesan = await context.read<AppState>().hapusSemuaPesan();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(pesan ?? 'Pesanmu sudah dibersihkan.')));
              }
            },
          ),
        ],
      ),
      body: Column(children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
            child: Text(
                'Pesan yang lebih tua dari 7 hari dihapus otomatis. Simpan informasi penting sebelum kedaluwarsa.',
                style: TextStyle(
                    color: XyTheme.of(context).muted,
                    fontSize: 11,
                    height: 1.4))),
        if (s.chat.isEmpty)
          const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                  'Belum ada percakapan aktif. Kirim pesan untuk memulai obrolan baru.')),
        Expanded(
          child: Stack(children: [
            ListView.builder(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              itemCount: s.chat.length + (s.csMengetik ? 1 : 0),
              itemBuilder: (_, i) {
                if (i == s.chat.length) return const _Mengetik();
                final m = s.chat[i];
                final kunci = _kunciPesan.putIfAbsent(m.id, () => GlobalKey());
                return KeyedSubtree(
                  key: kunci,
                  child: GestureDetector(
                    onLongPress: () => _menuPesan(context, m),
                    onTap: m.gagal
                        ? () => _ulangKirim(m)
                        : m.replyTo != null
                            ? () => _loncatKe(m.replyTo)
                            : null,
                    child: _Gelembung(
                      msg: m,
                      onBalas: () => setState(() => _balas = m),
                    ),
                  ),
                );
              },
            ),
            if (_rekam)
              _OverlayRekam(
                detik: _detik,
                batal: _batal,
                hapus: _hapus,
                angkat: _angkat,
                geser: _geser,
                kunci: _kunci,
                onKirim: () => _hentiRekam(batal: false),
                onBatal: () => _hentiRekam(batal: true),
              ),
          ]),
        ),
        // strip balasan
        if (_balas != null) _StripBalasan(
          balas: _balas!,
          onTutup: () => setState(() => _balas = null),
          onBuka: () => _loncatKe(_balas!.id),
        ),
        if (s.chat.length < 4)
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: cepat.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => ActionChip(
                label: Text(cepat[i],
                    style:
                        const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                onPressed: () => _kirim(cepat[i]),
                backgroundColor: XyTheme.of(context).surface,
                side: BorderSide(color: XyTheme.of(context).line),
              ),
            ),
          ),
        _BarInput(
          ctrl: ctrl,
          sending: _sending,
          rekam: _rekam,
          kunci: _kunci,
          onKirim: _kirim,
          onGambar: _kirimGambar,
          onMicMulai: _mulaiRekam,
          onMicUpdate: (dx, dy) {
            if (!_rekam || !mounted) return;
            final batalBaru = dy <= -70;
            final hapusBaru = !batalBaru && dx <= -70;
            if (batalBaru != _batal || hapusBaru != _hapus) {
              // feedback terasa + terdengar tiap masuk/keluar zona gestur
              HapticFeedback.selectionClick();
              SystemSound.play(SystemSoundType.click);
            }
            setState(() {
              _angkat = dy;
              _geser = dx;
              _batal = batalBaru;
              _hapus = hapusBaru;
            });
          },
          onMicSelesai: (batal) => _hentiRekam(batal: batal),
          onKetik: (v) => context.read<AppState>().ketikCs(v.isNotEmpty),
        ),
      ]),
    );
  }

  void _ulangKirim(ChatMessage m) {
    if (m.audio != null && m.audio!.startsWith('data:')) {
      // ulang kirim suara lokal yang gagal
      context.read<AppState>().kirimChat(
            m.teks,
            audio: m.audio,
            durasi: m.durasi,
            pratinjauAudio: m.audio,
            replyTo: m.replyTo,
            replyTeks: m.replyTeks,
            replyTipe: m.replyTipe,
            ulangId: m.clientId,
          );
      return;
    }
    context.read<AppState>().kirimChat(
          m.teks,
          gambar: m.gambar,
          pratinjauGambar: m.gambar,
          replyTo: m.replyTo,
          replyTeks: m.replyTeks,
          replyTipe: m.replyTipe,
          ulangId: m.clientId,
        );
  }
}

/// Strip "Membalas ..." di atas kotak ketik.
class _StripBalasan extends StatelessWidget {
  const _StripBalasan({
    required this.balas,
    required this.onTutup,
    required this.onBuka,
  });
  final ChatMessage balas;
  final VoidCallback onTutup;
  final VoidCallback onBuka;

  @override
  Widget build(BuildContext context) {
    final label = balas.milikSaya ? 'Kamu' : 'Kirana';
    String cuplikan;
    if (balas.tipe == 'audio') {
      cuplikan = 'Pesan suara · ${_fmtDur(balas.durasi)}';
    } else if (balas.tipe == 'gambar') {
      cuplikan = balas.teks.isNotEmpty ? balas.teks : 'Foto';
    } else {
      cuplikan = balas.teks;
    }
    return Material(
      color: XyTheme.of(context).surface,
      child: InkWell(
        onTap: onBuka,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
          decoration: BoxDecoration(
            boxShadow: [BoxShadow(color: XyTheme.of(context).ink.withOpacity(.07), blurRadius: 22, offset: const Offset(0, -6))],
            color: XyTheme.primary.withOpacity(.045),
          ),
          child: Row(children: [
            Container(width: 3, height: 34, color: XyTheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label,
                    style: const TextStyle(
                        color: XyTheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  cuplikan,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: XyTheme.of(context).muted, fontSize: 12),
                ),
              ]),
            ),
            InkWell(
              onTap: onTutup,
              customBorder: const CircleBorder(),
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(Icons.close_rounded,
                    size: 18, color: XyTheme.danger),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Baris pengetik + lampiran + mic/send (gaya WhatsApp).
class _BarInput extends StatelessWidget {
  const _BarInput({
    required this.ctrl,
    required this.sending,
    required this.rekam,
    required this.kunci,
    required this.onKirim,
    required this.onGambar,
    required this.onMicMulai,
    required this.onMicUpdate,
    required this.onMicSelesai,
    required this.onKetik,
  });

  final TextEditingController ctrl;
  final bool sending;
  final bool rekam;
  final bool kunci;
  final void Function(String?) onKirim;
  final VoidCallback onGambar;
  final Future<void> Function() onMicMulai;
  final void Function(double dx, double dy) onMicUpdate;
  final void Function(bool batal) onMicSelesai;
  final void Function(String) onKetik;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: ctrl,
      builder: (_, value, __) {
        final adaTeks = value.text.trim().isNotEmpty;
        return Container(
          padding: EdgeInsets.fromLTRB(
              10, 8, 10, MediaQuery.of(context).padding.bottom + 8),
          decoration: BoxDecoration(
              color: XyTheme.of(context).surface, boxShadow: XyTheme.shadowMd),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            IconButton(
              onPressed: rekam ? null : onGambar,
              icon: Icon(Icons.image_outlined, color: XyTheme.primary),
              tooltip: 'Kirim gambar',
            ),
            Expanded(
              child: TextField(
                controller: ctrl,
                minLines: 1,
                maxLines: 4,
                maxLength: 5000,
                buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onKirim(null),
                onChanged: onKetik,
                decoration: InputDecoration(
                  hintText: 'Tulis pesan untuk tim CS…',
                  fillColor: XyTheme.of(context).bg,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide:
                          const BorderSide(color: XyTheme.primary, width: 1.4)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (adaTeks || sending)
              _TombolKirim(onKirim: () => onKirim(null), sending: sending)
            else
              _TombolMic(
                onMulai: onMicMulai,
                onUpdate: onMicUpdate,
                onSelesai: onMicSelesai,
                kunci: kunci,
              ),
          ]),
        );
      },
    );
  }
}

class _TombolKirim extends StatelessWidget {
  const _TombolKirim({required this.onKirim, required this.sending});
  final VoidCallback onKirim;
  final bool sending;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: XyTheme.primary,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: sending ? null : onKirim,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: sending
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.2, color: Colors.white))
              : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

/// Tombol mic: tekan-tahan untuk merekam; geser ke atas (>=70px) = batal,
/// geser ke kiri (>=70px) = hapus, tahan diam ~1,4 dtk = kunci rekaman
/// (lepas jari tidak menghentikan — kirim/buang lewat tombol di overlay).
class _TombolMic extends StatefulWidget {
  const _TombolMic({
    required this.onMulai,
    required this.onUpdate,
    required this.onSelesai,
    required this.kunci,
  });
  final Future<void> Function() onMulai;
  final void Function(double dx, double dy) onUpdate;
  final void Function(bool batal) onSelesai;
  final bool kunci;

  @override
  State<_TombolMic> createState() => _TombolMicState();
}

class _TombolMicState extends State<_TombolMic> {
  bool _aktif = false;
  bool _selesaiDiproses = false;
  double _dy = 0;
  double _dx = 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPressStart: (_) async {
        if (widget.kunci) return; // rekaman terkunci: abaikan gestur baru
        setState(() {
          _aktif = true;
          _selesaiDiproses = false;
          _dy = 0;
          _dx = 0;
        });
        await widget.onMulai();
      },
      onLongPressMoveUpdate: (d) {
        if (!_aktif) return;
        _dx = d.offsetFromOrigin.dx;
        _dy = d.offsetFromOrigin.dy;
        widget.onUpdate(_dx, _dy);
      },
      onLongPressEnd: (_) {
        if (!_aktif || _selesaiDiproses) return;
        setState(() => _aktif = false);
        // Rekaman terkunci: lepas jari TIDAK menghentikan — kirim/buang
        // lewat tombol pada overlay.
        if (widget.kunci) return;
        _selesaiDiproses = true;
        widget.onSelesai(_dy <= -70 || _dx <= -70);
      },
      onLongPressCancel: () {
        if (!_aktif || _selesaiDiproses) return;
        setState(() => _aktif = false);
        if (widget.kunci) return;
        _selesaiDiproses = true;
        widget.onSelesai(true);
      },
      onTapUp: (_) {
        // ketukan singkat = abaikan (biar tidak salah kirim suara kosong);
        // saat terkunci ketukan mic tidak boleh membatalkan rekaman.
        if (_selesaiDiproses || widget.kunci) return;
        _selesaiDiproses = true;
        widget.onSelesai(true);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _aktif ? XyTheme.danger : XyTheme.primary,
          boxShadow: _aktif ? null : XyTheme.shadowXs,
        ),
        child: Icon(
          _aktif ? Icons.mic_rounded : Icons.mic_none_rounded,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }
}

/// Overlay rekaman: zona geser (atas = batal, kiri = hapus) plus mode
/// terkunci dengan tombol Kirim/Buang ala WhatsApp.
class _OverlayRekam extends StatelessWidget {
  const _OverlayRekam({
    required this.detik,
    required this.batal,
    required this.hapus,
    required this.angkat,
    required this.geser,
    required this.kunci,
    required this.onKirim,
    required this.onBatal,
  });
  final int detik;
  final bool batal;
  final bool hapus;
  final bool kunci;
  final double angkat;
  final double geser;
  final VoidCallback onKirim;
  final VoidCallback onBatal;

  String get _waktu => '${detik ~/ 60}:${(detik % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    // ---- rekaman terkunci: jari bebas, kirim/buang lewat tombol ----
    if (kunci) {
      return Positioned.fill(
        child: Container(
          color: Colors.black.withOpacity(.35),
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 92),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 26),
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              decoration: BoxDecoration(
                color: XyTheme.of(context).surface,
                borderRadius: BorderRadius.circular(XyRadius.xxl),
                boxShadow: XyTheme.shadowMd,
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                        color: XyTheme.danger, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Text(_waktu,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 15)),
                  const SizedBox(width: 9),
                  Icon(Icons.lock_rounded,
                      size: 14, color: XyTheme.of(context).muted),
                  const SizedBox(width: 5),
                  Text('Rekaman terkunci',
                      style: TextStyle(
                          color: XyTheme.of(context).muted,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        onBatal();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: XyTheme.danger.withOpacity(.10),
                          borderRadius: BorderRadius.circular(XyRadius.pill),
                          border: Border.all(
                              color: XyTheme.danger.withOpacity(.45)),
                        ),
                        child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.close_rounded,
                                  size: 17, color: XyTheme.danger),
                              SizedBox(width: 6),
                              Text('Buang',
                                  style: TextStyle(
                                      color: XyTheme.danger,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13)),
                            ]),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        onKirim();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          gradient: XyTheme.gradPrimary,
                          borderRadius: BorderRadius.circular(XyRadius.pill),
                        ),
                        child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.send_rounded,
                                  size: 16, color: Colors.white),
                              SizedBox(width: 7),
                              Text('Kirim sekarang',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13)),
                            ]),
                      ),
                    ),
                  ),
                ]),
              ]),
            ),
          ),
        ),
      );
    }

    // ---- masih menahan jari: tampilkan zona atas (batal) & kiri (hapus) ----
    final lintang = (angkat * -1).clamp(0.0, 200.0);
    final geseran = (geser * -1).clamp(0.0, 200.0);
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          color: Colors.black.withOpacity(.18),
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.only(
                bottom: 70 + lintang * .3, right: geseran * .5),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  color: batal || hapus
                      ? XyTheme.danger.withOpacity(.95)
                      : XyTheme.of(context).ink.withOpacity(.92),
                  borderRadius: BorderRadius.circular(XyRadius.pill),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                    batal
                        ? Icons.keyboard_arrow_up_rounded
                        : hapus
                            ? Icons.delete_rounded
                            : Icons.mic_rounded,
                    color: Colors.white,
                    size: 17,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    batal
                        ? 'Lepaskan untuk membatalkan'
                        : hapus
                            ? 'Lepaskan untuk menghapus'
                            : 'Geser \u2191 batal \u00b7 \u2190 hapus \u00b7 tahan diam = kunci',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600),
                  ),
                ]),
              ),
              const SizedBox(height: 14),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: batal || hapus
                      ? XyTheme.danger.withOpacity(.9)
                      : XyTheme.primary.withOpacity(.9),
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(.25),
                        blurRadius: 18,
                        offset: const Offset(0, 8)),
                  ],
                ),
                child: Center(
                  child: Text(
                    _waktu,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Gelembung extends StatelessWidget {
  const _Gelembung({required this.msg, this.onBalas});
  final ChatMessage msg;
  final VoidCallback? onBalas;

  @override
  Widget build(BuildContext context) {
    if (msg.dari == 'system') {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
              color: XyTheme.of(context).line.withOpacity(.6),
              borderRadius: BorderRadius.circular(20)),
          child: Text(msg.teks,
              textAlign: TextAlign.center,
              style:
                  TextStyle(fontSize: 11.5, color: XyTheme.of(context).muted)),
        ),
      );
    }
    final saya = msg.milikSaya;

    // ---------- pesan media (gambar / suara) tampil polos, tanpa label ----------
    if (msg.tipe == 'gambar' || msg.tipe == 'audio') {
      return Align(
        alignment: saya ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * (saya ? .78 : .74)),
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (msg.replyTo != null)
                _Kutipan(context, saya, onTap: onBalas),
              const SizedBox(height: 4),
              if (msg.tipe == 'audio')
                _Suara(msg: msg, saya: saya)
              else ...[
                _MediaGambar(context, msg),
                if (msg.teks.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Align(
                    alignment:
                        saya ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: EdgeInsets.only(left: saya ? 0 : 2, right: saya ? 2 : 0),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 11, vertical: 6),
                      decoration: BoxDecoration(
                        color: saya
                            ? XyTheme.primary.withOpacity(.13)
                            : XyTheme.of(context).surface,
                        borderRadius: BorderRadius.circular(14),
                        border: saya
                            ? null
                            : Border.all(color: XyTheme.of(context).line),
                      ),
                      child: Text(msg.teks,
                          style: TextStyle(
                              fontSize: 12.5,
                              height: 1.3,
                              color: saya
                                  ? XyTheme.primaryDeep
                                  : XyTheme.of(context).ink)),
                    ),
                  ),
                ],
              ],
              _MetaMedia(context, saya),
            ],
          ),
        ),
      );
    }

    // ---------- pesan teks (gelembung biasa) ----------
    return Align(
      alignment: saya ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .76),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
        decoration: BoxDecoration(
          color: saya ? XyTheme.primary : XyTheme.of(context).surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(saya ? 18 : 4),
            bottomRight: Radius.circular(saya ? 4 : 18),
          ),
          border: saya ? null : Border.all(color: XyTheme.of(context).line),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          if (msg.replyTo != null) ...[
            _Kutipan(context, saya, onTap: onBalas),
            const SizedBox(height: 8),
          ],
          Text(msg.teks,
              style: TextStyle(
                  color: saya ? Colors.white : XyTheme.of(context).ink,
                  fontSize: 13.8,
                  height: 1.42)),
          const SizedBox(height: 3),
          _Meta(context, saya),
        ]),
      ),
    );
  }

  /// Meta untuk pesan media yang tampil polos (kontras di atas latar terang).
  Widget _MetaMedia(BuildContext context, bool saya) {
    return Padding(
      padding: EdgeInsets.only(
          top: 3, left: saya ? 30 : 2, right: saya ? 2 : 0),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(jam(msg.waktu),
            style: TextStyle(
                fontSize: 10, color: XyTheme.of(context).muted)),
        if (saya) ...[
          const SizedBox(width: 4),
          Icon(
            msg.gagal
                ? Icons.error_outline_rounded
                : msg.terkirim
                    ? Icons.done_all_rounded
                    : Icons.schedule_rounded,
            size: 13,
            color: msg.gagal
                ? XyTheme.danger
                : msg.dibaca
                    ? XyTheme.csRead
                    : XyTheme.of(context).muted,
          ),
        ],
      ]),
    );
  }

  Widget _Meta(BuildContext context, bool saya) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text(jam(msg.waktu),
          style: TextStyle(
              fontSize: 10,
              color: saya ? Colors.white70 : XyTheme.of(context).muted)),
      if (saya) ...[
        const SizedBox(width: 4),
        Icon(
          msg.gagal
              ? Icons.error_outline_rounded
              : msg.terkirim
                  ? Icons.done_all_rounded
                  : Icons.schedule_rounded,
          size: 13,
          color: msg.gagal
              ? XyTheme.csFail
              : msg.dibaca
                  ? XyTheme.csRead
                  : Colors.white70,
        ),
      ],
    ]);
  }

  Widget _Kutipan(BuildContext context, bool saya, {VoidCallback? onTap}) {
    final warna = saya ? Colors.white.withOpacity(.9) : XyTheme.primary;
    final isi = msg.replyTeks?.isNotEmpty == true ? msg.replyTeks! : '';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(8, 5, 8, 5),
        decoration: BoxDecoration(
          color: saya ? Colors.white.withOpacity(.13) : XyTheme.of(context).primarySoft,
          borderRadius: BorderRadius.circular(10),
          border: Border(left: BorderSide(color: warna, width: 3)),
        ),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_labelTipe(msg.replyTipe),
                  style: TextStyle(
                      color: warna,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 1),
              Text(
                msg.replyTipe == 'audio'
                    ? 'Audio · · ·'
                    : isi,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 11.5,
                    color: saya
                        ? Colors.white.withOpacity(.85)
                        : XyTheme.of(context).inkSoft),
              ),
            ]),
          ),
          if (msg.replyTipe == 'audio')
            Icon(Icons.graphic_eq_rounded,
                size: 16, color: saya ? Colors.white70 : XyTheme.muted),
        ]),
      ),
    );
  }
}

/// Gambar polos: tanpa bubble/background, tepi membulat + bayangan halus.
Widget _MediaGambar(BuildContext context, ChatMessage msg) {
  final Widget gambar;
  final fitur = msg.gambar?.startsWith('data:') ?? false;
  if (fitur) {
    gambar = Image.memory(
      base64Decode(msg.gambar!.split(',').last),
      width: 210,
      fit: BoxFit.cover,
    );
  } else {
    gambar = Image.network(
      msg.gambar!,
      width: 210,
      fit: BoxFit.cover,
      cacheWidth: 640,
      loadingBuilder: (_, anak, p) => p == null
          ? anak
          : Container(
              width: 210,
              height: 150,
              color: XyTheme.of(context).lineSoft,
              child: const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                ),
              ),
            ),
    );
  }
  return Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      boxShadow: [
        BoxShadow(
            color: Colors.black.withOpacity(.08),
            blurRadius: 12,
            offset: const Offset(0, 4)),
      ],
    ),
    child: ClipRRect(borderRadius: BorderRadius.circular(18), child: gambar),
  );
}

/// Bubbble pesan suara dengan tombol putar, bilah gelombang, dan durasi.
class _Suara extends StatefulWidget {
  const _Suara({required this.msg, required this.saya});
  final ChatMessage msg;
  final bool saya;

  @override
  State<_Suara> createState() => _SuaraState();
}

class _SuaraState extends State<_Suara> with SingleTickerProviderStateMixin {
  AudioPlayer? _player;
  bool _main = false;
  Duration _pos = Duration.zero;
  Duration? _dur;
  bool _dispose = false;

  List<int> get _bar => _batang(widget.msg.id, widget.msg.durasi ?? 8);

  @override
  void dispose() {
    _dispose = true;
    _player?.dispose();
    super.dispose();
  }

  Future<void> _putar() async {
    final url = widget.msg.audio;
    if (url == null || !url.startsWith('http')) return;
    if (_player == null) {
      final p = AudioPlayer();
      p.onPlayerStateChanged.listen((s) {
        if (_dispose) return;
        if (!mounted) return;
        setState(() => _main = s == PlayerState.playing);
      });
      p.onPositionChanged.listen((d) {
        if (_dispose || !mounted) return;
        setState(() => _pos = d);
      });
      p.onDurationChanged.listen((d) {
        if (_dispose || !mounted) return;
        setState(() => _dur = d);
      });
      p.onPlayerComplete.listen((_) {
        if (_dispose || !mounted) return;
        setState(() {
          _main = false;
          _pos = Duration.zero;
        });
      });
      _player = p;
    }
    final p = _player!;
    if (_main) {
      await p.pause();
    } else {
      try {
        final habis = _dur != null && _pos >= _dur!;
        if (_pos == Duration.zero || habis) {
          await p.stop();
          await p.setSourceUrl(url);
          await p.resume();
        } else {
          await p.resume();
        }
      } catch (_) {}
    }
  }

  static List<int> _batang(String id, double durasi) {
    final seed = id.codeUnits.fold<int>(0, (a, b) => a + b);
    final r = math.Random(seed);
    final n = durasi < 5 ? 18 : 30;
    return List.generate(n, (_) => 4 + r.nextInt(7));
  }

  @override
  Widget build(BuildContext context) {
    final warnaDasar = widget.saya ? Colors.white38 : XyTheme.muted;
    final tampilDur = _dur ?? Duration(seconds: (widget.msg.durasi ?? 0).round());
    final posisi = _pos.inMilliseconds >= tampilDur.inMilliseconds
        ? Duration.zero
        : _pos;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 12, 6),
      decoration: BoxDecoration(
        color: widget.saya
            ? XyTheme.primary
            : XyTheme.of(context).surface,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(widget.saya ? 18 : 4),
          bottomRight: Radius.circular(widget.saya ? 4 : 18),
        ),
        border: widget.saya
            ? null
            : Border.all(color: XyTheme.of(context).line),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Material(
          color: widget.saya
              ? Colors.white.withOpacity(.22)
              : XyTheme.of(context).primarySoft,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _putar,
            child: Padding(
              padding: const EdgeInsets.all(9),
              child: Icon(
                _main
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                size: 21,
                color: widget.saya ? Colors.white : XyTheme.primary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // bilah gelombang (statis: penuh saat diputar)
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 120,
          height: 26,
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(_bar.length, (i) {
              final h = _bar[i].toDouble();
              final prop = (i + 1) / _bar.length;
              final aktif = _main && prop <= posisi.inMilliseconds / (tampilDur.inMilliseconds > 0 ? tampilDur.inMilliseconds : 1) + .08;
              return Container(
                width: 2.6,
                height: (h + (aktif ? 3 : 0)).clamp(3.0, 26.0),
                decoration: BoxDecoration(
                  color: aktif
                      ? (widget.saya ? Colors.white : XyTheme.primary)
                      : warnaDasar,
                  borderRadius: BorderRadius.circular(10),
                ),
              );
            }),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          _main ? _fmtDur(posisi.inMilliseconds / 1000) : _fmtDur(widget.msg.durasi),
          style: TextStyle(
              fontSize: 11,
              color: widget.saya ? Colors.white70 : XyTheme.of(context).muted),
        ),
      ]),
    );
  }
}

/// Indikator "CS sedang mengetik…" berupa tiga titik melompat.
class _Mengetik extends StatefulWidget {
  const _Mengetik();
  @override
  State<_Mengetik> createState() => _MengetikState();
}

class _MengetikState extends State<_Mengetik>
    with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat();

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: XyTheme.of(context).surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
          ),
          border: Border.all(color: XyTheme.of(context).line),
        ),
        child: AnimatedBuilder(
          animation: c,
          builder: (_, __) => Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              final t = ((c.value + i * .22) % 1);
              final naik = (t < .5 ? t : 1 - t) * 2;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                width: 7,
                height: 7,
                transform: Matrix4.translationValues(0, -naik * 4, 0),
                decoration: BoxDecoration(
                  color: XyTheme.of(context).muted.withOpacity(.4 + naik * .5),
                  shape: BoxShape.circle,
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
