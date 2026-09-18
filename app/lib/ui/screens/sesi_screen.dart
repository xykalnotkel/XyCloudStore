import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/format.dart';
import '../../core/motion.dart';
import '../../core/pengaturan.dart';
import '../../core/theme.dart';
import '../../data/native_stream.dart';
import '../../models/models.dart';
import '../../providers/app_state.dart';
import '../widgets/common.dart';
import '../widgets/lembar.dart';
import 'checkout_sewa_screen.dart';
import 'cs_screen.dart';
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
  Timer? _timer, _elapsedTimer, _reconnectTimer, _stableTimer;
  bool _loading = true,
      _connecting = false,
      _native = false,
      _video = false,
      _polling = false,
      _reconnectPending = false,
      _diagnosing = false;
  String? _error;
  Map<String, dynamic>? _networkDiagnostic;
  String _stage = 'Menyiapkan sesi melalui agen…';
  String _route = 'Belum dipilih';
  String _quality = 'Menunggu pengukuran';
  String? _lastDisconnect;
  int _progress = 4;
  int _elapsedSeconds = 0;
  int _reconnectAttempt = 0;
  int _reconnectIn = 0;
  int _disconnects = 0;
  int? _latencyMs;
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

  void _mulaiJamProgres() {
    _elapsedTimer?.cancel();
    _elapsedSeconds = 0;
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _elapsedSeconds++;
        if (!_connecting && sesi?.status == 'menyiapkan') {
          _progress = (_progress + 2).clamp(4, 88).toInt();
          _stage = _elapsedSeconds < 15
              ? 'Agen memeriksa Sunshine dan menyiapkan desktop…'
              : 'Masih menunggu agen — aplikasi boleh ditutup, sewa belum dianggap siap.';
        }
      });
    });
  }

  void _hentikanJamProgres() {
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
  }

  String get _waktuProgres {
    final m = _elapsedSeconds ~/ 60;
    final d = _elapsedSeconds % 60;
    return m == 0 ? '$d dtk' : '$m:${d.toString().padLeft(2, '0')}';
  }

  Future<void> _laporKlien(String status, {String? alasan}) async {
    final id = sesi?.id;
    if (id == null || !mounted) return;
    final state = context.read<AppState>();
    unawaited(state.telemetriSesi(id, {
      'status': status,
      'route': _route == 'Belum dipilih' ? null : _route,
      'latency_ms': _latencyMs,
      'quality': _quality == 'Menunggu pengukuran' ? null : _quality,
      'disconnects': _disconnects,
      'reconnect_attempt': _reconnectAttempt,
      if (alasan != null) 'reason': alasan,
    }));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _elapsedTimer?.cancel();
    _reconnectTimer?.cancel();
    _stableTimer?.cancel();
    NativeStream.onEvent = null;
    unawaited(NativeStream.batal());
    super.dispose();
  }

  Future<void> _mulai() async {
    _mulaiJamProgres();
    setState(() {
      _loading = true;
      _error = null;
      _progress = 5;
      _stage = 'Memeriksa engine streaming di perangkat…';
    });
    _native = await NativeStream.tersedia();
    if (!mounted) return;
    setState(() {
      _progress = 14;
      _stage = 'Meminta unit PC dan agen menyiapkan Sunshine…';
    });
    final state = context.read<AppState>();
    final s = await state.mulaiSesi(widget.order.id);
    if (!mounted) return;
    setState(() {
      sesi = s;
      _loading = false;
      _progress = s == null ? 0 : (s.status == 'menyiapkan' ? 24 : 100);
      _stage = s == null
          ? 'Persiapan tidak dapat dilanjutkan.'
          : s.status == 'menyiapkan'
              ? 'Agen memeriksa Sunshine dan menyiapkan desktop…'
              : 'Unit siap menerima koneksi dari HP.';
      _error = s == null ? state.error : null;
      if (s != null) {
        _disconnects = s.clientDisconnects;
        _reconnectAttempt = s.clientReconnectAttempt;
        _latencyMs = s.clientLatencyMs;
        if ((s.clientRoute ?? '').isNotEmpty) _route = s.clientRoute!;
        if ((s.clientQuality ?? '').isNotEmpty) _quality = s.clientQuality!;
        _lastDisconnect = s.clientReason;
      }
    });
    if (s == null || s.status != 'menyiapkan') _hentikanJamProgres();
    _timer?.cancel();
    if (s != null) {
      _timer = Timer.periodic(const Duration(seconds: 4), (_) => _refresh());
    }
  }

  Future<void> _refresh() async {
    if (_polling || sesi == null || !mounted) return;
    _polling = true;
    final s = await context.read<AppState>().statusSesi(sesi!.id);
    _polling = false;
    if (!mounted || s == null) return;
    setState(() {
      sesi = s;
      if (s.clientDisconnects > _disconnects) _disconnects = s.clientDisconnects;
      _latencyMs ??= s.clientLatencyMs;
      if (_route == 'Belum dipilih' && (s.clientRoute ?? '').isNotEmpty) {
        _route = s.clientRoute!;
      }
      if (_quality == 'Menunggu pengukuran' &&
          (s.clientQuality ?? '').isNotEmpty) _quality = s.clientQuality!;
      _lastDisconnect ??= s.clientReason;
      if (s.status == 'menyiapkan') {
        _progress = _progress.clamp(24, 88).toInt();
      } else if (['siap', 'pairing', 'berjalan'].contains(s.status) &&
          !_connecting) {
        _progress = 100;
        _stage = 'Unit siap menerima koneksi dari HP.';
      }
    });
    if (s.status != 'menyiapkan') _hentikanJamProgres();
    if (['selesai', 'gagal'].contains(s.status)) {
      _timer?.cancel();
      _batalReconnect();
    }
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
        setState(() {
          _stage = '${event['message']}';
          _progress = ((event['progress'] as num?)?.toInt() ?? _progress)
              .clamp(0, 100)
              .toInt();
        });
        break;
      case 'diagnostic':
        final host = '${event['host'] ?? ''}';
        setState(() {
          _latencyMs = (event['latencyMs'] as num?)?.toInt();
          if (host.isNotEmpty && !_route.endsWith(host)) _route = 'Host · $host';
        });
        break;
      case 'quality':
        final resolusi = '${event['resolution'] ?? ''}';
        final fps = (event['fps'] as num?)?.toInt();
        final bitrate = (event['bitrate'] as num?)?.toInt();
        setState(() {
          _quality = resolusi.isEmpty
              ? '${event['message']}'
              : '$resolusi · ${fps ?? '-'} FPS · ${((bitrate ?? 0) / 1000).toStringAsFixed(0)} Mbps';
          _stage = '${event['message']}';
        });
        break;
      case 'connected':
        _reconnectTimer?.cancel();
        setState(() {
          _video = true;
          _reconnectPending = false;
          _reconnectIn = 0;
          _error = null;
          _stage = 'Video terhubung — input, audio, dan kontrol aktif.';
        });
        _stableTimer?.cancel();
        _stableTimer = Timer(const Duration(seconds: 30), () {
          if (mounted && _video) setState(() => _reconnectAttempt = 0);
        });
        if (sesi != null) await context.read<AppState>().tandaiVideo(sesi!.id);
        await _laporKlien('connected');
        break;
      case 'error':
        setState(() {
          _error = '${event['message']}';
          _lastDisconnect = 'Kode ${event['code'] ?? '-'} · ${event['stage'] ?? 'stream'}';
        });
        break;
      case 'log':
        final baris = '${event['message']}';
        if (baris.isNotEmpty) {
          _log.add(baris);
          if (_log.length > 30) _log.removeRange(0, _log.length - 30);
          if (mounted) setState(() {});
        }
        break;
      case 'disconnected':
        _stableTimer?.cancel();
        _disconnects++;
        final alasan = '${event['message']}';
        setState(() {
          _video = false;
          _lastDisconnect = alasan;
        });
        await _laporKlien('disconnected', alasan: alasan);
        _jadwalkanReconnect(alasan);
        await _refresh();
        break;
      case 'closed':
        setState(() => _video = false);
        if (event['manual'] == true) {
          _batalReconnect();
          await _laporKlien('closed');
        }
        await _refresh();
        break;
    }
  }

  void _batalReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    if (!mounted) return;
    setState(() {
      _reconnectPending = false;
      _reconnectIn = 0;
    });
  }

  void _jadwalkanReconnect(String alasan) {
    if (!mounted ||
        _reconnectPending ||
        PengaturanLokal.nilai['autoReconnect'] == false ||
        _appId == null ||
        sesi == null ||
        !['siap', 'pairing', 'berjalan'].contains(sesi!.status)) return;
    if (_reconnectAttempt >= 3) {
      setState(() {
        _error = 'Sambung ulang otomatis berhenti setelah 3 kali. '
            'Periksa jaringan/host lalu tekan Buka Layar PC.';
        _reconnectPending = false;
      });
      unawaited(_laporKlien('reconnect_exhausted', alasan: alasan));
      return;
    }
    _reconnectAttempt++;
    _reconnectIn = [2, 4, 8][_reconnectAttempt - 1];
    setState(() {
      _reconnectPending = true;
      _stage = 'Koneksi putus — sambung ulang $_reconnectAttempt/3 dalam $_reconnectIn detik…';
    });
    unawaited(_laporKlien('reconnecting', alasan: alasan));
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_reconnectIn > 1) {
        setState(() {
          _reconnectIn--;
          _stage = 'Koneksi putus — sambung ulang $_reconnectAttempt/3 dalam $_reconnectIn detik…';
        });
        return;
      }
      timer.cancel();
      setState(() {
        _reconnectIn = 0;
        _reconnectPending = false;
        _stage = 'Mencoba menyambungkan video kembali ($_reconnectAttempt/3)…';
      });
      unawaited(_tonton(otomatis: true));
    });
  }

  bool _masalahJalur(Object e) {
    // Watchdog sudah membatalkan task native; jangan langsung mulai task kedua
    // sebelum thread lama benar-benar keluar (bisa menghasilkan BUSY palsu).
    if (e is TimeoutException) return false;
    final m = e.toString().toLowerCase();
    return m.contains('failed to connect') ||
        m.contains('timeout') ||
        m.contains('timed out') ||
        m.contains('econnrefused') ||
        m.contains('unable to resolve') ||
        m.contains('no address associated') ||
        m.contains('network is unreachable');
  }

  Future<void> _hubungkan({bool bukaSesudahSiap = false}) async {
    if (_connecting || sesi == null) return;
    _mulaiJamProgres();
    setState(() {
      _connecting = true;
      _error = null;
      _progress = 6;
      _stage = 'Memilih jalur terbaik ke host…';
    });
    final hostPublik = (sesi!.host ?? '').trim();
    final hostLan = (sesi!.hostLan ?? '').trim();
    final dahulukanLan = PengaturanLokal.nilai['preferLan'] == true &&
        hostLan.isNotEmpty;
    final hostPertama = dahulukanLan ? hostLan : hostPublik;
    final labelPertama = dahulukanLan ? 'LAN' : 'Publik';
    final hostKedua = dahulukanLan ? hostPublik : hostLan;
    final labelKedua = dahulukanLan ? 'Publik' : 'LAN';

    Future<dynamic> jajak(String host, String label) async {
      if (host.isEmpty) {
        throw StateError('Alamat host $label belum tersedia.');
      }
      if (mounted) {
        setState(() {
          _route = '$label · $host';
          _stage = 'Menguji jalur $label ke $host…';
          _progress = 10;
        });
      }
      try {
        return await NativeStream.hubungkan(
          host: host,
          session: sesi!.id,
          hostKey: sesi!.agenId ?? sesi!.host ?? '',
        ).timeout(const Duration(seconds: 35));
      } on TimeoutException {
        await NativeStream.batal();
        throw TimeoutException(
            'Host tidak memberi jawaban dalam 35 detik; proses dihentikan agar aplikasi tidak diam.');
      }
    }

    Future<dynamic> jajakDenganCadangan() async {
      try {
        return await jajak(hostPertama, labelPertama);
      } catch (e) {
        if (!_masalahJalur(e) ||
            hostKedua.isEmpty ||
            hostKedua == hostPertama) rethrow;
        if (!mounted) rethrow;
        setState(() {
          _stage = 'Jalur $labelPertama gagal — mencoba $labelKedua…';
          _progress = 8;
        });
        return jajak(hostKedua, labelKedua);
      }
    }

    void pakaiApps(dynamic raw) {
      final apps = List<Map<String, dynamic>>.from(
          (raw as List).map((x) => Map<String, dynamic>.from(x as Map)));
      setState(() {
        _apps = apps;
        _appId = (apps
                    .where((x) => '${x['name']}'.toLowerCase() == 'desktop')
                    .firstOrNull ??
                apps.first)['id']
            as int;
        _stage = 'Host terhubung. Pilih aplikasi untuk ditampilkan.';
        _progress = 100;
        _error = null;
      });
    }

    try {
      dynamic apps;
      try {
        apps = await jajakDenganCadangan();
      } catch (e) {
        final msg = e.toString();
        // Identitas/sediaan crypto lokal rusak: reset hanya data pairing HP,
        // lalu ulang satu kali. Kredensial Sunshine host tidak disentuh.
        if (!(msg.contains('NoSuchAlgorithm') ||
            msg.contains('provider BC') ||
            msg.contains('RSA for provider'))) rethrow;
        await NativeStream.resetPairing();
        if (!mounted) return;
        setState(() {
          _stage = 'Memperbarui kunci pairing lokal lalu mencoba kembali…';
          _progress = 18;
        });
        apps = await jajakDenganCadangan();
      }
      if (!mounted) return;
      pakaiApps(apps);
      _hentikanJamProgres();
      await _laporKlien('ready');
      if (bukaSesudahSiap) await _tonton(otomatis: true);
    } catch (e) {
      var clean = e.toString().replaceFirst('PlatformException(', '');
      final lower = clean.toLowerCase();
      if (e is TimeoutException) {
        clean = 'Host tidak menjawab dalam 35 detik. Proses native sudah dihentikan '
            'agar layar tidak diam; tunggu sebentar lalu coba lagi atau jalankan Diagnostik jaringan.';
      } else if (lower.contains('unable to resolve host') ||
          lower.contains('eai_nodata') ||
          lower.contains('no address associated')) {
        clean = 'Alamat host PC tidak bisa dijangkau dari HP. '
            'Minta admin memastikan IP publik/domain unit dan IP LAN agen benar. Detail: $clean';
      } else if (_masalahJalur(e)) {
        clean = 'Host PC tidak merespons${hostLan.isNotEmpty && hostLan != hostPublik ? ' melalui jalur publik maupun LAN' : ''}. '
            'Buka/forward 47984–47990 TCP+UDP dan 48010 pada router/firewall; '
            'untuk VM cloud periksa NSG/Security Group, lalu jalankan Cek port dari internet pada Agen. '
            'Detail: $clean';
      }
      if (mounted) {
        setState(() {
          _error = clean;
          _progress = 0;
          _stage = 'Koneksi ke host gagal.';
        });
      }
      await _laporKlien('prepare_failed', alasan: clean);
    } finally {
      _hentikanJamProgres();
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _tonton({bool otomatis = false}) async {
    if (_appId == null) return;
    if (!otomatis) {
      _batalReconnect();
      _reconnectAttempt = 0;
    }
    setState(() {
      _error = null;
      _stage = otomatis
          ? 'Membuka kembali renderer native…'
          : 'Membuka renderer native, audio, dan kontrol…';
    });
    await _laporKlien(otomatis ? 'reconnect_start' : 'connecting');
    try {
      final options = <String, dynamic>{...PengaturanLokal.nilai};
      if (otomatis && options['adaptiveStreaming'] != false) {
        options['adaptiveRecovery'] = _reconnectAttempt;
      }
      await NativeStream.mulai(_appId!, options);
    } catch (e) {
      if (!mounted) return;
      final pesan = '$e';
      setState(() => _error = pesan);
      await _laporKlien('start_failed', alasan: pesan);
      if (otomatis) _jadwalkanReconnect(pesan);
    }
  }

  Future<void> _diagnostik() async {
    if (_diagnosing || sesi == null) return;
    setState(() {
      _diagnosing = true;
      _networkDiagnostic = null;
    });
    final hasil = await context.read<AppState>().diagnostikSesi(sesi!.id);
    if (!mounted) return;
    setState(() {
      _diagnosing = false;
      _networkDiagnostic = hasil;
      if (hasil == null) {
        _error = 'Diagnostik jaringan belum dapat dijalankan. Coba lagi sesaat lagi.';
      }
    });
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
    _batalReconnect();
    await NativeStream.batal();
    await _laporKlien('ending');
    final err = await context.read<AppState>().akhiriSesi(sesi!.id);
    if (mounted) {
      if (err != null)
        setState(() => _error = err);
      else
        await _refresh();
    }
  }

  Widget _barisDiagnosis(String label, String nilai, XyPalette p) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 104,
              child: Text(label,
                  style: TextStyle(color: p.muted, fontSize: 11.5))),
          Expanded(
              child: Text(nilai,
                  style: const TextStyle(
                      fontSize: 11.5, fontWeight: FontWeight.w700))),
        ]),
      );

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
          const SizedBox(height: 16),
          // ---------- PANEL BILLING CYBERINDO (VM Integration) ----------
          _PanelBillingCyberindo(
            sesi: s,
            order: widget.order,
            selesai: selesai,
            onPerpanjang: () {
              final plans = context.read<AppState>().plans;
              final targetPlan = plans.firstWhere(
                (pl) => pl.id == widget.order.planId,
                orElse: () => PcPlan(
                  id: widget.order.planId,
                  nama: widget.order.planNama,
                  cpu: 'Intel Xeon / Core i7',
                  gpu: 'NVIDIA RTX',
                  ramGb: 16,
                  storageGb: 256,
                  hargaPerJam: widget.order.durasiJam > 0
                      ? (widget.order.total ~/ widget.order.durasiJam)
                      : 10000,
                  hargaPerHari: widget.order.total * 8,
                  region: 'Jakarta',
                  unitTersedia: 1,
                  totalUnit: 1,
                  tag: 'Cyberindo',
                  gambar: '',
                ),
              );
              Navigator.push(
                context,
                xyRoute(CheckoutSewaScreen(plan: targetPlan)),
              );
            },
            onPanggilOperator: () => Navigator.push(context, xyRoute(const CsScreen())),
            onRestartVm: () async {
              final yakin = await konfirmasi(
                context,
                judul: 'Restart PC VM Cyberindo?',
                pesan:
                    'Sistem operasi VM akan dimuat ulang oleh agen Cyberindo. Streaming akan menyambung kembali otomatis dalam 1–2 menit.',
                tombolYa: 'Restart Sekarang',
                ikon: Icons.restart_alt_rounded,
              );
              if (yakin && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Perintah restart telah dikirim ke agen PC VM Cyberindo.'),
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 18),
          if (_loading || s?.status == 'menyiapkan')
            XyCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
              Row(children: [
                const Icon(Icons.settings_input_antenna_rounded,
                    size: 18, color: XyTheme.primary),
                const SizedBox(width: 8),
                const Expanded(
                    child: Text('Persiapan unit',
                        style: TextStyle(fontWeight: FontWeight.w700))),
                Text('$_progress% · $_waktuProgres',
                    style: const TextStyle(
                        color: XyTheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(XyRadius.pill),
                child: LinearProgressIndicator(
                  value: (_progress / 100).clamp(0.0, 1.0).toDouble(),
                  minHeight: 8,
                  backgroundColor: p.lineSoft,
                ),
              ),
              const SizedBox(height: 10),
              Text(_stage, style: TextStyle(color: p.inkSoft, height: 1.5)),
              const SizedBox(height: 5),
              Text(
                  'Aplikasi boleh ditutup saat agen menyiapkan Sunshine. Progres di atas tetap menunjukkan tahap terakhir, bukan terminal yang diam.',
                  style: TextStyle(color: p.muted, fontSize: 11.5, height: 1.45))
            ])),
          if (_reconnectPending)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: XyCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(Icons.sync_rounded,
                        size: 19, color: XyTheme.warning),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text('Pemulihan koneksi $_reconnectAttempt/3',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    Text('$_reconnectIn dtk',
                        style: const TextStyle(
                            color: XyTheme.warning,
                            fontWeight: FontWeight.w800)),
                  ]),
                  const SizedBox(height: 8),
                  Text(_stage,
                      style: TextStyle(color: p.inkSoft, height: 1.45)),
                  TextButton.icon(
                    onPressed: _batalReconnect,
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: const Text('Batalkan sambung ulang'),
                  ),
                ]),
              ),
            ),
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
                                  ? (_apps.isNotEmpty
                                      ? () => _tonton()
                                      : () => _hubungkan())
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
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _diagnosing ? null : _diagnostik,
                    icon: const Icon(Icons.network_check_rounded, size: 18),
                    label: Text(_diagnosing
                        ? 'Menguji port dari internet…'
                        : 'Diagnostik jaringan'),
                  ),
                  if (_networkDiagnostic != null) ...[
                    const SizedBox(height: 10),
                    Builder(builder: (context) {
                      final d = _networkDiagnostic!;
                      final kondisi = '${d['keadaan'] ?? 'belum diketahui'}';
                      final ports = (d['hasil'] as List? ?? const [])
                          .map((x) => Map<String, dynamic>.from(x as Map))
                          .toList();
                      final sehat = kondisi == 'sehat';
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: (sehat ? XyTheme.success : XyTheme.warning)
                              .withOpacity(.08),
                          borderRadius: BorderRadius.circular(XyRadius.md),
                          border: Border.all(
                            color: (sehat ? XyTheme.success : XyTheme.warning)
                                .withOpacity(.25),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Jalur internet: ${kondisi.toUpperCase()}',
                                style: TextStyle(
                                    color: sehat
                                        ? XyTheme.success
                                        : XyTheme.warning,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800)),
                            const SizedBox(height: 5),
                            Text(
                              ports.map((x) =>
                                '${x['port']}/${x['protokol'] ?? 'TCP'}: ${x['terbuka'] == true ? 'terbuka' : 'tertutup'}').join(' · '),
                              style: const TextStyle(
                                  fontSize: 11.5, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 5),
                            Text('${d['saran'] ?? ''}',
                                style: TextStyle(
                                    color: p.inkSoft,
                                    fontSize: 11.5,
                                    height: 1.4)),
                          ],
                        ),
                      );
                    }),
                  ],
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
                        padding: const EdgeInsets.only(top: 14),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(XyRadius.pill),
                            child: LinearProgressIndicator(
                              value: (_progress / 100).clamp(0.0, 1.0).toDouble(),
                              minHeight: 8,
                              backgroundColor: p.lineSoft,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(children: [
                            Expanded(child: Text(_stage,
                                style: TextStyle(color: p.muted, height: 1.4))),
                            Text('$_progress% · $_waktuProgres',
                                style: const TextStyle(
                                    color: XyTheme.primary,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700)),
                          ]),
                        ]),
                      ),
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
                        onPressed: () => _tonton()),
                  ],
                ])),
          ],
          if (ready && (_apps.isNotEmpty || _latencyMs != null || _lastDisconnect != null)) ...[
            const SizedBox(height: 14),
            XyCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.monitor_heart_outlined,
                      size: 18, color: XyTheme.primary),
                  const SizedBox(width: 8),
                  const Text('Diagnostik koneksi',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: (_video ? XyTheme.success : XyTheme.warning).withOpacity(.10),
                      borderRadius: BorderRadius.circular(XyRadius.pill),
                    ),
                    child: Text(_video ? 'TERHUBUNG' : 'SIAGA',
                        style: TextStyle(
                            color: _video ? XyTheme.success : XyTheme.warning,
                            fontWeight: FontWeight.w800,
                            fontSize: 9.5)),
                  ),
                ]),
                const SizedBox(height: 12),
                _barisDiagnosis('Jalur aktif', _route, p),
                _barisDiagnosis('Respons host',
                    _latencyMs == null ? 'belum diukur' : '$_latencyMs ms', p),
                _barisDiagnosis('Kualitas aktual', _quality, p),
                _barisDiagnosis('Anti-putus',
                    PengaturanLokal.nilai['autoReconnect'] == false
                        ? 'nonaktif'
                        : 'aktif · $_disconnects kali putus', p),
                if (_lastDisconnect != null)
                  _barisDiagnosis('Kejadian terakhir', _lastDisconnect!, p),
                const SizedBox(height: 5),
                Text(
                  'Adaptive anti-lag hanya menurunkan batas kualitas saat respons awal berat; pilihan pengguna tetap dipakai bila jaringan sehat.',
                  style: TextStyle(color: p.muted, fontSize: 11, height: 1.4),
                ),
              ]),
            ),
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

/// Panel Status & Kontrol Billing Cyber Indo VM
class _PanelBillingCyberindo extends StatelessWidget {
  const _PanelBillingCyberindo({
    required this.sesi,
    required this.order,
    required this.selesai,
    required this.onPerpanjang,
    required this.onPanggilOperator,
    required this.onRestartVm,
  });

  final SesiMain? sesi;
  final RentOrder order;
  final bool selesai;
  final VoidCallback onPerpanjang;
  final VoidCallback onPanggilOperator;
  final VoidCallback onRestartVm;

  @override
  Widget build(BuildContext context) {
    final t = XyTheme.of(context);
    final idSuffix = (order.id.hashCode.abs() % 30 + 1).toString().padLeft(2, '0');
    final sisaWaktuTeks = sesi?.berakhir != null && !selesai
        ? durasiSisa(sesi!.berakhir!)
        : (selesai ? 'Waktu Habis' : '${order.durasiJam} Jam');

    final sisaMenit = sesi?.berakhir != null
        ? sesi!.berakhir!.difference(DateTime.now()).inMinutes
        : 999;
    final hampirHabis = !selesai && sisaMenit >= 0 && sisaMenit <= 10;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hampirHabis
              ? const Color(0xFFEF4444).withOpacity(0.6)
              : const Color(0xFF38BDF8).withOpacity(0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: (hampirHabis ? const Color(0xFFEF4444) : const Color(0xFF0284C7)).withOpacity(0.18),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hampirHabis) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined, color: Color(0xFFEF4444), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'PERINGATAN SISA WAKTU BILLING',
                          style: TextStyle(
                            color: Color(0xFFEF4444),
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Waktu bermain tersisa $sisaMenit menit! Perpanjang billing sekarang agar PC tidak tertutup otomatis.',
                          style: const TextStyle(color: Colors.white, fontSize: 11, height: 1.35),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Header Cyber Indo
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0284C7), Color(0xFF2563EB)],
                  ),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.computer_rounded, size: 13, color: Colors.white),
                    SizedBox(width: 5),
                    Text(
                      'CYBER INDO BILLING v2.9',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: selesai ? const Color(0xFFEF4444) : const Color(0xFF22C55E),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (selesai ? const Color(0xFFEF4444) : const Color(0xFF22C55E))
                          .withOpacity(0.6),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                selesai ? 'Billing Berakhir' : 'Online / Gac Server',
                style: TextStyle(
                  color: selesai ? const Color(0xFFEF4444) : const Color(0xFF22C55E),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Baris PC ID & Status Sisa Waktu Billing
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Terminal / PC ID',
                        style: TextStyle(color: Colors.white60, fontSize: 11.5, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 3),
                    Text(
                      'PC-CYBERINDO #$idSuffix',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      order.planNama,
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Sisa Waktu Billing',
                      style: TextStyle(color: Colors.white60, fontSize: 11.5, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0369A1).withOpacity(0.35),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.4)),
                    ),
                    child: Text(
                      sisaWaktuTeks,
                      style: const TextStyle(
                        color: Color(0xFF38BDF8),
                        fontSize: 16.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .5,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 12),

          // Detail Spek Billing
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _itemStat('Tarif Billing', rupiah(order.total)),
              _itemStat('Paket Akun', 'Personal Member'),
              _itemStat('Billing Server', 'Cyberindo Gac v2.9'),
            ],
          ),

          const SizedBox(height: 16),

          // Tombol Kontrol Billing Cyber Indo
          Row(
            children: [
              Expanded(
                child: Pressable(
                  onTap: onPerpanjang,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0284C7), Color(0xFF2563EB)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.more_time_rounded, size: 15, color: Colors.white),
                        SizedBox(width: 5),
                        Text(
                          'Perpanjang',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Pressable(
                  onTap: onPanggilOperator,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.headset_mic_rounded, size: 15, color: Colors.white),
                        SizedBox(width: 5),
                        Text(
                          'Panggil Operator',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Pressable(
                onTap: onRestartVm,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Icon(Icons.restart_alt_rounded, size: 16, color: Colors.white70),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _itemStat(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
}
