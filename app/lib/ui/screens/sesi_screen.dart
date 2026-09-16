import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/format.dart';
import '../../core/pengaturan.dart';
import '../../core/theme.dart';
import '../../data/native_stream.dart';
import '../../models/models.dart';
import '../../providers/app_state.dart';
import '../widgets/common.dart';
import '../widgets/lembar.dart';
import 'opsi_screen.dart';

/// Real GameStream protocol runs inside this APK's native renderer, not a browser/other app.
class SesiScreen extends StatefulWidget {
  const SesiScreen({super.key, required this.order});
  final RentOrder order;
  @override
  State<SesiScreen> createState() => _SesiScreenState();
}

class _SesiScreenState extends State<SesiScreen> {
  SesiMain? sesi;
  Timer? _timer;
  bool _loading = true,
      _connecting = false,
      _native = false,
      _video = false,
      _polling = false;
  String? _error;
  String _stage = 'Menyiapkan sesi melalui agen…';
  List<Map<String, dynamic>> _apps = [];
  int? _appId;
  final List<String> _log = [];
  @override
  void initState() {
    super.initState();
    NativeStream.init();
    NativeStream.onEvent = _event;
    _mulai();
  }

  @override
  void dispose() {
    _timer?.cancel();
    NativeStream.onEvent = null;
    unawaited(NativeStream.batal());
    super.dispose();
  }

  Future<void> _mulai() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    _native = await NativeStream.tersedia();
    if (!mounted) return;
    final state = context.read<AppState>();
    final s = await state.mulaiSesi(widget.order.id);
    if (!mounted) return;
    setState(() {
      sesi = s;
      _loading = false;
      _error = s == null ? state.error : null;
    });
    _timer?.cancel();
    if (s != null)
      _timer = Timer.periodic(const Duration(seconds: 4), (_) => _refresh());
  }

  Future<void> _refresh() async {
    if (_polling || sesi == null || !mounted) return;
    _polling = true;
    final s = await context.read<AppState>().statusSesi(sesi!.id);
    _polling = false;
    if (!mounted || s == null) return;
    setState(() => sesi = s);
    if (['selesai', 'gagal'].contains(s.status)) _timer?.cancel();
  }

  Future<void> _event(Map<String, dynamic> event) async {
    if (!mounted) return;
    switch (event['type']) {
      case 'pin':
        if (event['session'] != sesi?.id) return;
        final error = await context.read<AppState>().kirimPinSesi(
            sesi!.id, '${event['pin']}',
            clientId: event['clientId'] as String?);
        if (error != null && mounted) {
          setState(() => _error = error);
          await NativeStream.batal();
        }
        break;
      case 'stage':
        setState(() => _stage = '${event['message']}');
        break;
      case 'connected':
        setState(() => _video = true);
        if (sesi != null) await context.read<AppState>().tandaiVideo(sesi!.id);
        break;
      case 'error':
        setState(() => _error = '${event['message']}');
        break;
      case 'log':
        final baris = '${event['message']}';
        if (baris.isNotEmpty) {
          _log.add(baris);
          if (_log.length > 30) _log.removeRange(0, _log.length - 30);
          if (mounted) setState(() {});
        }
        break;
      case 'closed':
      case 'disconnected':
        setState(() => _video = false);
        await _refresh();
        break;
    }
  }

  Future<void> _hubungkan() async {
    if (_connecting || sesi == null) return;
    setState(() {
      _connecting = true;
      _error = null;
      _stage = 'Memeriksa host…';
    });
    final hostPublik = sesi!.host ?? '';
    final hostLan = (sesi!.hostLan ?? '').trim();

    Future<dynamic> jajak(String host) => NativeStream.hubungkan(
        host: host, session: sesi!.id, hostKey: sesi!.agenId ?? sesi!.host ?? '');

    void pakaiApps(dynamic apps) {
      setState(() {
        _apps = apps;
        _appId = (apps
                .where((x) => '${x['name']}'.toLowerCase() == 'desktop')
                .firstOrNull ??
            apps.first)['id'] as int;
        _stage = 'Host terhubung. Pilih aplikasi untuk ditampilkan.';
        _error = null;
      });
    }

    try {
      dynamic apps;
      try {
        apps = await jajak(hostPublik);
      } catch (e) {
        final msg = e.toString();
        final tertutup = msg.contains('failed to connect') ||
            msg.contains('ETIMEDOUT') ||
            msg.contains('ECONNREFUSED') ||
            msg.contains('connect timed out');
        // Host publik tak terjangkau & unit melaporkan IP LAN → coba jalur lokal
        // (berguna saat penyewa satu Wi-Fi/jaringan dengan PC unit).
        if (tertutup && hostLan.isNotEmpty && hostLan != hostPublik) {
          if (!mounted) return;
          setState(() => _stage =
              'Host publik $hostPublik tertutup — mencoba IP jaringan lokal $hostLan…');
          apps = await jajak(hostLan);
        } else {
          rethrow;
        }
      }
      if (!mounted) return;
      pakaiApps(apps);
    } catch (e) {
      final msg = e.toString();
      // Cert klien / BC rusak — bersihkan pairing lokal lalu coba sekali lagi
      if (msg.contains('NoSuchAlgorithm') ||
          msg.contains('provider BC') ||
          msg.contains('RSA for provider')) {
        try {
          await NativeStream.resetPairing();
          setState(() => _stage = 'Memperbarui kunci pairing… coba lagi');
          dynamic apps;
          try {
            apps = await jajak(hostPublik);
          } catch (_) {
            if (hostLan.isNotEmpty && hostLan != hostPublik) {
              apps = await jajak(hostLan);
            } else {
              rethrow;
            }
          }
          if (!mounted) return;
          pakaiApps(apps);
          return;
        } catch (e2) {
          if (mounted)
            setState(() => _error =
                e2.toString().replaceFirst('PlatformException(', ''));
          return;
        }
      }
      var clean = msg.replaceFirst('PlatformException(', '');
      if (clean.contains('Unable to resolve host') ||
          clean.contains('EAI_NODATA') ||
          clean.contains('No address associated')) {
        clean =
            'Alamat host PC tidak bisa dijangkau dari HP (bukan IP/DNS publik). '
            'Minta admin isi IP publik unit di Dashboard → Unit PC, atau perbarui agen ke 1.3.3+. '
            'Detail: $clean';
      }
      if (clean.contains('failed to connect') ||
          clean.contains('connect timed out') ||
          clean.contains('ECONNREFUSED')) {
        clean = 'Host PC tidak merespons${hostLan.isNotEmpty && hostLan != hostPublik ? ' (IP publik $hostPublik & IP lokal $hostLan sama-sama gagal)' : ''}. '
            'Port streaming di sisi PC kemungkinan belum terbuka dari internet. '
            'Admin PC: buka/forward port 47984–47990 (TCP+UDP) dan 48010 di router/firewall — '
            'untuk VM cloud (Azure/AWS/GCP) tambahkan inbound rule di NSG/Security Group — '
            'lalu tekan "Cek port dari internet" di aplikasi agen untuk memastikan. '
            'Detail: $clean';
      }
      if (mounted) setState(() => _error = clean);
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _tonton() async {
    if (_appId == null) return;
    try {
      await NativeStream.mulai(_appId!, PengaturanLokal.nilai);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _akhiri() async {
    if (sesi == null) return;
    if (!await konfirmasi(context,
            judul: 'Akhiri sesi?',
            pesan:
                'Streaming dihentikan dan aplikasi penyewa dibersihkan oleh agen. Sisa waktu tidak dikembalikan setelah unit siap.',
            tombolYa: 'Akhiri',
            bahaya: true) ||
        !mounted) return;
    final err = await context.read<AppState>().akhiriSesi(sesi!.id);
    if (mounted) {
      if (err != null)
        setState(() => _error = err);
      else
        await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = XyTheme.of(context), s = sesi;
    final ready =
        s != null && ['siap', 'pairing', 'berjalan'].contains(s.status);
    final selesai = s != null && ['selesai', 'gagal'].contains(s.status);
    final title = switch (s?.status) {
      'siap' => 'Unit siap',
      'pairing' => 'Memasangkan HP',
      'berjalan' => 'Sesi berjalan',
      'mengakhiri' => 'Membersihkan host',
      'selesai' => 'Sesi selesai',
      'gagal' => 'Persiapan gagal',
      _ => 'Menyiapkan unit'
    };
    return Scaffold(
        appBar: AppBar(title: const Text('Sesi PC'), actions: [
          IconButton(
              tooltip: 'Pengaturan streaming',
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const OpsiStreamingScreen())),
              icon: const Icon(Icons.tune_rounded))
        ]),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                  gradient: XyTheme.gradMidnight,
                  borderRadius: BorderRadius.circular(24)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.desktop_windows_rounded,
                        color: Colors.white, size: 34),
                    const SizedBox(height: 16),
                    Text(title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 23,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(widget.order.planNama,
                        style: const TextStyle(color: Colors.white70)),
                    if (s?.berakhir != null && !selesai) ...[
                      const SizedBox(height: 18),
                      Text('Sisa ${durasiSisa(s!.berakhir!)}',
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w700))
                    ],
                  ])),
          const SizedBox(height: 18),
          if (_loading || s?.status == 'menyiapkan')
            XyCard(
                child: Column(children: [
              const LinearProgressIndicator(),
              const SizedBox(height: 14),
              Text(
                  'Menunggu agen memeriksa Sunshine dan menyiapkan sesi. Simpan pekerjaan di VM: aplikasi penyewa dapat ditutup saat persiapan.',
                  style: TextStyle(color: p.inkSoft, height: 1.5))
            ])),
          if (_error != null)
            Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: XyCard(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      const Text('Belum tersambung',
                          style: TextStyle(
                              color: XyTheme.danger,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Text(_error!,
                          style: TextStyle(color: p.inkSoft, height: 1.5)),
                      TextButton(
                          onPressed: _connecting
                              ? null
                              : ready
                                  ? _hubungkan
                                  : _mulai,
                          child: const Text('Coba lagi'))
                    ]))),
          if (ready) ...[
            XyCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Text('Streaming di XyCloudStore',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(
                      'Tidak perlu memasang aplikasi lain. Pairing dikirim otomatis melalui agen PC.',
                      style: TextStyle(color: p.muted, height: 1.5)),
                  const SizedBox(height: 12),
                  SelectableText(s.host ?? 'Host belum tersedia',
                      style: TextStyle(color: p.inkSoft)),
                  const SizedBox(height: 18),
                  if (!_native)
                    const Text(
                        'Engine native tidak tersedia pada build/perangkat ini. Pasang APK rilis Android terbaru.',
                        style: TextStyle(color: XyTheme.danger))
                  else if (_apps.isEmpty) ...[
                    GradientButton(
                        label: _connecting ? 'Menghubungkan…' : 'Hubungkan PC',
                        loading: _connecting,
                        onPressed: _connecting ? null : _hubungkan,
                        icon: Icons.link_rounded),
                    if (_connecting)
                      Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child:
                              Text(_stage, style: TextStyle(color: p.muted))),
                  ] else ...[
                    DropdownButtonFormField<int>(
                        value: _appId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                            labelText: 'Aplikasi pada PC'),
                        items: _apps
                            .map((a) => DropdownMenuItem(
                                value: a['id'] as int,
                                child: Text('${a['name']}',
                                    overflow: TextOverflow.ellipsis)))
                            .toList(),
                        onChanged: (v) => setState(() => _appId = v)),
                    const SizedBox(height: 14),
                    GradientButton(
                        label:
                            _video ? 'Kembali ke tampilan PC' : 'Buka Layar PC',
                        icon: Icons.fullscreen_rounded,
                        onPressed: _tonton),
                  ],
                ])),
          ],
          if (_log.isNotEmpty) ...[
            const SizedBox(height: 14),
            XyCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(children: [
                    const Icon(Icons.terminal_rounded, size: 16),
                    const SizedBox(width: 8),
                    const Text('Log Streaming',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    const Spacer(),
                    Text('terakhir ${_log.length} baris',
                        style: TextStyle(color: p.muted, fontSize: 11)),
                  ]),
                  const SizedBox(height: 10),
                  for (final baris in _log.reversed.take(8).toList())
                    Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(baris,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 11.5,
                                color: p.inkSoft,
                                fontFamily: 'monospace'))),
                  const SizedBox(height: 6),
                  Text(
                      'Log lengkap: tombol ☰ di layar streaming → bagian Log Streaming (bisa disalin).',
                      style: TextStyle(color: p.muted, fontSize: 11, height: 1.4))
                ])),
          ],
          if (s?.catatan != null)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(s!.catatan!,
                    style: TextStyle(color: p.muted, height: 1.5))),
          if (s != null && !selesai)
            OutlinedButton.icon(
                onPressed: s.status == 'mengakhiri' ? null : _akhiri,
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text('Akhiri Sesi')),
          if (selesai)
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Kembali ke pesanan')),
          const SizedBox(height: 22),
          Text(
              'Kontrol XyCloudStore: preset HUD kustom yang kamu pilih muncul langsung di atas video dan mendukung tahan, ketuk, serta toggle. Bilah atas tetap menyediakan QWERTY, F1–F12, Windows/Ctrl/Alt, dan numpad — geser pegangan \u201C\u2800\u2800\u201D untuk memindahkan keyboard, A\u2212/A+ untuk ukuran. Buat/edit/publikasikan preset dari ikon pengaturan → Editor HUD & Preset. Tombol ☰ membuka panel kontrol dan log streaming. API Sunshine yang siap belum menjamin GPU, layar virtual, atau port internet sudah benar.',
              style: TextStyle(fontSize: 12, color: p.muted, height: 1.6)),
        ]));
  }
}
