import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format.dart';
import '../../core/prefs.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/app_state.dart';
import '../widgets/common.dart';
import 'order_list_screen.dart';

Future<void> _bukaKetentuanLive() => launchUrl(
      Uri.parse('https://api.xycloud.my.id/legal/live'),
      mode: LaunchMode.externalApplication,
    );

void _snackMutasiLive(
  ScaffoldMessengerState messenger,
  String? hasil, {
  required String pesanSukses,
}) {
  // `teks` dipakai agar flow analysis Dart bisa memastikan `substring` hanya
  // dipanggil pada nilai non-null. Sebelumnya `hasil.substring(5)` dipanggil
  // langsung di cabang `informasi` — analyzer menolak karena nullability
  // `hasil` tidak terpromosikan lewat variabel bool terpisah
  // (unchecked_use_of_nullable_value). Perilakunya identik: bila `hasil` null,
  // `teks` kosong sehingga `informasi` tetap false dan cabang itu tak terpakai.
  final teks = hasil ?? '';
  final informasi = teks.startsWith('INFO:');
  final gagal = hasil != null && !informasi;
  messenger.showSnackBar(SnackBar(
    behavior: SnackBarBehavior.floating,
    backgroundColor: gagal
        ? XyTheme.danger
        : informasi
            ? XyTheme.warning
            : XyTheme.success,
    content: Text(
      informasi ? teks.substring(5) : (hasil ?? pesanSukses),
      style: TextStyle(color: informasi ? const Color(0xFF241500) : Colors.white),
    ),
  ));
}

String _pesanDiagnostikLive(LiveDiagnostics? d) {
  final code = d?.failureCode ?? d?.healthCode ?? 'UNKNOWN';
  if (code.contains('OBS_NOT_INSTALLED')) return 'OBS Studio belum siap di unit ini. Pilih unit lain atau hubungi admin rental.';
  if (code.contains('OBS_VERSION')) return 'OBS Studio unit harus versi 30.1 atau lebih baru agar audio game dapat ditangkap secara terisolasi.';
  if (code.contains('GAME_AUDIO_MUTED')) return 'Source audio game sedang mute. Agen membatalkan siaran agar tidak tayang tanpa suara.';
  if (code.contains('GAME_AUDIO_TRACK') || code.contains('STREAM_AUDIO_TRACK')) return 'Audio game belum masuk ke track stream 1. Minta operator memperbaiki track OBS; Desktop Audio tidak boleh dijadikan fallback.';
  if (code.contains('GAME_AUDIO_VOLUME') || code.contains('INPUT_VOLUME')) return 'Volume source audio game nol. Agen membatalkan siaran sampai jalur audio aman kembali terdengar.';
  if (code.contains('GAME_AUDIO')) return 'Audio Game Capture terisolasi tidak tersedia. Siaran dibatalkan agar tidak tayang tanpa suara atau membocorkan audio desktop.';
  if (code.contains('MIC_NOT_CONFIGURED')) return 'Mic dipilih, tetapi source mic aman belum disiapkan operator. Coba lagi dengan mic mati.';
  if (code.contains('UNMANAGED_RUNNING')) return 'OBS dibuka manual dan tidak boleh diambil alih. Tutup OBS lalu mulai siaran kembali melalui agen rental.';
  if (code.contains('UNSAFE_SCENE') || code.contains('SCENE_CHANGED') || code.contains('SCENE_DUPLICATE') || code.contains('PROGRAM_SCENE')) return 'Scene OBS berubah atau memiliki source selain Game Capture. Privasi memutus siaran otomatis.';
  if (code.contains('VIDEO_SETTINGS') || code.contains('PROFILE_SETTING')) return 'Profil OBS tidak dapat menerapkan 1080p30 dan bitrate aman. Operator perlu memperbaiki profil sebelum siaran.';
  if (code.contains('GAME_CAPTURE')) return 'Game Capture aman belum mendeteksi game fullscreen. Buka game lalu coba lagi.';
  if (code.contains('CREDENTIAL') || code.contains('CLEANUP')) return 'Credential ingest sedang diamankan. Jangan mulai ulang berulang kali; tunggu agen membersihkan OBS.';
  if (code.contains('OBS_OS_RNG')) return 'Sumber acak aman sistem operasi tidak tersedia. Live diblokir agar koneksi OBS tidak memakai nonce lemah.';
  if (code.contains('MONITOR') || code.contains('STATUS_UNAVAILABLE')) return 'Audit keselamatan OBS tidak dapat diverifikasi selama 30 detik. Ingress diputus otomatis; operator perlu memeriksa obs-websocket.';
  if (code.contains('STREAM_SERVICE')) return 'Route ingest OBS berubah atau tidak terverifikasi. Siaran dihentikan agar gameplay tidak terkirim ke tujuan lain.';
  if (code.contains('NETWORK') || code.contains('TIMEOUT') || code.contains('RECONNECT')) return 'Koneksi unit ke server livestream terputus atau lambat. Periksa internet lalu coba lagi.';
  if (code.contains('GLOBAL_AUDIO')) return 'Perlindungan audio tidak dapat menjamin mic/desktop tetap privat, jadi siaran dibatalkan.';
  return 'Kode $code. Segarkan diagnostik; bila berulang, kirim kode ini ke Chat Admin.';
}

/// Discovery livestream + studio kreator dalam satu pintu. Player sengaja
/// dibuka di browser aman bertiket; token login tidak pernah masuk URL.
class XyLiveScreen extends StatefulWidget {
  const XyLiveScreen({super.key, this.fokusId, this.creator = false});
  final String? fokusId;
  final bool creator;

  @override
  State<XyLiveScreen> createState() => _XyLiveScreenState();
}

class _XyLiveScreenState extends State<XyLiveScreen> {
  Timer? _timer;
  bool _fokusDibuka = false;
  bool _fokusDicari = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final state = context.read<AppState>();
      await state.muatLive();
      _bukaFokus(state.liveCatalog.streams);
    });
    _timer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) context.read<AppState>().muatLive(senyap: true);
    });
  }

  void _bukaFokus(List<LivestreamItem> streams) {
    final fokusId = widget.fokusId;
    if (_fokusDibuka || fokusId == null || !mounted) return;
    final found = streams.where((x) => x.id == fokusId);
    if (found.isNotEmpty) {
      _fokusDibuka = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _detail(found.first);
      });
      return;
    }
    if (_fokusDicari) return;
    _fokusDicari = true;
    unawaited(_cariFokus(fokusId));
  }

  Future<void> _cariFokus(String fokusId) async {
    try {
      final live = await context.read<AppState>().detailLivestream(fokusId);
      if (!mounted || widget.fokusId != fokusId || _fokusDibuka) return;
      _fokusDibuka = true;
      _detail(live);
    } catch (_) {
      if (!mounted || widget.fokusId != fokusId) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Siaran dari tautan ini sudah tidak tersedia.'),
      ));
    }
  }

  @override
  void didUpdateWidget(covariant XyLiveScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fokusId != widget.fokusId) {
      _fokusDibuka = false;
      _fokusDicari = false;
      _bukaFokus(context.read<AppState>().liveCatalog.streams);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    _bukaFokus(state.liveCatalog.streams);
    return DefaultTabController(
      length: 2,
      initialIndex: widget.creator ? 1 : 0,
      child: Scaffold(
        backgroundColor: XyTheme.of(context).bg,
        appBar: AppBar(
          title: const Text('XyCloud Live'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.live_tv_rounded), text: 'Live Sekarang'),
              Tab(icon: Icon(Icons.stars_rounded), text: 'Studio Kreator'),
            ],
          ),
        ),
        body: TabBarView(children: [
          _Discovery(
            catalog: state.liveCatalog,
            loading: state.liveMemuat,
            error: state.liveGalat,
            onRefresh: () => state.muatLive(),
            onOpen: _detail,
          ),
          _Studio(
            data: state.creatorLive,
            loading: state.liveMemuat,
            error: state.creatorLiveGalat ?? state.liveGalat,
            onRetry: () => state.muatLive(),
          ),
        ]),
      ),
    );
  }

  Future<void> _detail(LivestreamItem live) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LiveDetail(live: live),
    );
  }
}

class _Discovery extends StatelessWidget {
  const _Discovery({
    required this.catalog,
    required this.loading,
    required this.error,
    required this.onRefresh,
    required this.onOpen,
  });
  final LiveCatalog catalog;
  final bool loading;
  final String? error;
  final Future<void> Function() onRefresh;
  final ValueChanged<LivestreamItem> onOpen;

  @override
  Widget build(BuildContext context) {
    final streams = catalog.streams;
    return RefreshIndicator(
      color: XyTheme.primary,
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 110),
        children: [
          _HeroLive(enabled: catalog.enabled, count: streams.length),
          const SizedBox(height: 22),
          Row(children: [
            const Expanded(
              child: Text('Sedang berlangsung',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: -.4)),
            ),
            if (loading) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          ]),
          const SizedBox(height: 4),
          Text(
            'Tonton gamer bermain dari PC rental tanpa melihat desktop pribadi.',
            style: TextStyle(color: XyTheme.of(context).muted, fontSize: 12.5, height: 1.45),
          ),
          const SizedBox(height: 14),
          if (error != null && streams.isNotEmpty) ...[
            _Notice(
              icon: Icons.sync_problem_rounded,
              title: 'Menampilkan daftar terakhir',
              text: '$error Tarik layar untuk mencoba lagi.',
              tone: XyTheme.warning,
            ),
            const SizedBox(height: 12),
          ],
          if (error != null && streams.isEmpty)
            _Notice(
              icon: Icons.cloud_off_rounded,
              title: 'Live belum dapat dimuat',
              text: error!,
              tone: XyTheme.danger,
            )
          else if (!catalog.enabled)
            const _Notice(
              icon: Icons.lock_clock_rounded,
              title: 'Peluncuran bertahap',
              text: 'Fitur berbiaya ini masih dimatikan pemilik sampai Cloudflare Stream, OBS unit, dan payout selesai diverifikasi.',
              tone: XyTheme.warning,
            )
          else if (streams.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Kosong(
                icon: Icons.live_tv_rounded,
                judul: 'Belum ada siaran aktif',
                sub: 'Jadilah gamer pertama yang menyiarkan live stream! Mulai siaran dari kamera HP atau layar di tab Studio Kreator.',
                ilustrasi: 'livestream',
              ),
            )
          else
            ...streams.map((live) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _LiveCard(live: live, onTap: () => onOpen(live)),
                )),
          const SizedBox(height: 18),
          _SafetyCard(feeBps: catalog.platformFeeBps),
        ],
      ),
    );
  }
}

class _HeroLive extends StatelessWidget {
  const _HeroLive({required this.enabled, required this.count});
  final bool enabled;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 210,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF16002F), Color(0xFF4C1D95), Color(0xFF8B5CF6)],
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
        ),
        boxShadow: [BoxShadow(color: XyTheme.primary.withOpacity(.24), blurRadius: 30, offset: const Offset(0, 14))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(children: [
          Positioned(right: -34, top: -30, child: Icon(Icons.sports_esports_rounded, size: 190, color: Colors.white.withOpacity(.09))),
          Positioned(right: 22, bottom: 18, child: Container(
            width: 82, height: 82,
            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(.12)),
            child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 50),
          )),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: enabled ? const Color(0xFFEF4444) : Colors.white.withOpacity(.14), borderRadius: BorderRadius.circular(99)),
                child: Text(enabled ? '●  $count LIVE' : 'SEGERA HADIR',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: .7)),
              ),
              const Spacer(),
              const Text('Main. Siarkan.\nBangun komunitasmu.',
                  style: TextStyle(color: Colors.white, fontSize: 25, height: 1.08, fontWeight: FontWeight.w900, letterSpacing: -.8)),
              const SizedBox(height: 8),
              Text('Dukungan penonton menjadi penghasilan kreator setelah masa aman.',
                  style: TextStyle(color: Colors.white.withOpacity(.76), fontSize: 12.2, height: 1.35)),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _LiveCard extends StatelessWidget {
  const _LiveCard({required this.live, required this.onTap});
  final LivestreamItem live;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return XyCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              gradient: LinearGradient(
                colors: [const Color(0xFF090014), _warnaGame(live.game), const Color(0xFF2E1065)],
                begin: Alignment.bottomLeft,
                end: Alignment.topRight,
              ),
            ),
            child: Stack(children: [
              Center(child: Icon(Icons.sports_esports_rounded, size: 78, color: Colors.white.withOpacity(.16))),
              Positioned(left: 12, top: 12, child: _Badge(text: live.status == 'live' ? '● LIVE' : 'MENYIAPKAN', color: live.status == 'live' ? const Color(0xFFEF4444) : const Color(0xFFF59E0B))),
              Positioned(right: 12, top: 12, child: _Badge(text: '${live.viewers} menonton', color: Colors.black.withOpacity(.55))),
              Positioned(left: 15, right: 15, bottom: 13, child: Text(live.game.toUpperCase(), maxLines: 1,
                  style: TextStyle(color: Colors.white.withOpacity(.84), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.1))),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(15),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CircleAvatar(
              radius: 21,
              backgroundColor: XyTheme.primary.withOpacity(.14),
              backgroundImage: live.creatorPhoto == null ? null : NetworkImage(live.creatorPhoto!),
              child: live.creatorPhoto == null ? Text(live.creatorName.isEmpty ? 'X' : live.creatorName.characters.first.toUpperCase(),
                  style: const TextStyle(color: XyTheme.primary, fontWeight: FontWeight.w800)) : null,
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(live.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14.5, height: 1.25, fontWeight: FontWeight.w800)),
              const SizedBox(height: 5),
              Text('${live.creatorName}  ·  ${rupiah(live.grossTip)} dukungan',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: XyTheme.of(context).muted, fontSize: 11.5)),
            ])),
            const Icon(Icons.chevron_right_rounded, color: XyTheme.primary),
          ]),
        ),
      ]),
    );
  }

  Color _warnaGame(String seed) {
    const colors = [Color(0xFF7C3AED), Color(0xFF1D4ED8), Color(0xFFBE185D), Color(0xFF0F766E)];
    return colors[seed.codeUnits.fold<int>(0, (a, b) => a + b) % colors.length];
  }
}

class _LiveDetail extends StatelessWidget {
  const _LiveDetail({required this.live});
  final LivestreamItem live;

  Future<void> _watch(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final url = await context.read<AppState>().tiketTontonLive(live.id);
      final uri = Uri.tryParse(url);
      if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('Player tidak dapat dibuka.');
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final mine = live.creatorId == context.read<AppState>().user?.id;
    final aktif = live.status == 'live';
    final statusText = aktif
        ? '● LIVE'
        : live.status == 'starting'
            ? 'MENUNGGU SINYAL'
            : live.status == 'ending'
                ? 'MENGAKHIRI'
                : 'SELESAI';
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 22),
      decoration: BoxDecoration(
        color: XyTheme.of(context).surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 42, height: 4, decoration: BoxDecoration(color: XyTheme.of(context).line, borderRadius: BorderRadius.circular(99)))),
          const SizedBox(height: 18),
          Row(children: [
            _Badge(
              text: statusText,
              color: aktif ? const Color(0xFFEF4444) : XyTheme.warning,
            ),
            const SizedBox(width: 8),
            Text(
              aktif ? '${live.viewers} penonton aktif' : 'Siaran tidak lagi berlangsung',
              style: TextStyle(color: XyTheme.of(context).muted, fontSize: 12),
            ),
          ]),
          const SizedBox(height: 13),
          Text(live.title, style: const TextStyle(fontSize: 22, height: 1.15, fontWeight: FontWeight.w900, letterSpacing: -.6)),
          const SizedBox(height: 8),
          Text('${live.creatorName} bermain ${live.game}', style: TextStyle(color: XyTheme.of(context).muted, fontSize: 13)),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: XyTheme.primary.withOpacity(.07), borderRadius: BorderRadius.circular(16)),
            child: Row(children: [
              const Icon(Icons.shield_outlined, color: XyTheme.primary),
              const SizedBox(width: 10),
              Expanded(child: Text('Player memakai tiket singkat. Jangan kirim saldo atau data pribadi di luar aplikasi.',
                  style: TextStyle(color: XyTheme.of(context).muted, fontSize: 11.5, height: 1.4))),
            ]),
          ),
          const SizedBox(height: 18),
          GradientButton(label: 'Tonton di Player Aman', icon: Icons.play_circle_fill_rounded,
              onPressed: live.canWatch ? () => _watch(context) : null),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: live.shareUrl.isEmpty ? null : () async {
                await Clipboard.setData(ClipboardData(text: live.shareUrl));
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tautan live disalin.')));
              },
              icon: const Icon(Icons.ios_share_rounded), label: const Text('Salin tautan'),
            )),
            if (!mine) ...[
              const SizedBox(width: 10),
              Expanded(child: FilledButton.tonalIcon(
                onPressed: live.status == 'live' ? () => _tipDialog(context, live) : null,
                icon: const Icon(Icons.favorite_rounded), label: const Text('Dukung'),
              )),
            ],
          ]),
        ])),
      ),
    );
  }
}

Future<void> _tipDialog(BuildContext context, LivestreamItem live) async {
  final state = context.read<AppState>();
  final messenger = ScaffoldMessenger.of(context);
  LiveTipTertunda? pending;
  try {
    pending = await state.dukunganLivestreamTertunda();
  } catch (_) {
    if (context.mounted) {
      _snackMutasiLive(
        messenger,
        'Penyimpanan aman tidak dapat dibaca. Dukungan tidak dikirim agar saldo tidak terpotong dua kali.',
        pesanSukses: '',
      );
    }
    return;
  }
  if (!context.mounted) return;

  final tertunda = pending;
  if (tertunda != null && tertunda.liveId != live.id) {
    final pulihkan = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Selesaikan dukungan tertunda?'),
        content: Text(
          'Ada percobaan dukungan Rp${tertunda.amount} dari siaran sebelumnya yang belum mendapat respons pasti. Pulihkan dengan payload dan ID yang sama sebelum membuat transaksi baru.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Nanti'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Pulihkan aman'),
          ),
        ],
      ),
    );
    if (pulihkan == true && context.mounted) {
      final hasil = await state.dukungLivestream(
        tertunda.liveId,
        amount: tertunda.amount,
        message: tertunda.message,
      );
      if (context.mounted) {
        _snackMutasiLive(
          messenger,
          hasil,
          pesanSukses: 'Dukungan tertunda berhasil dikonfirmasi tanpa tagihan ganda. Ketuk Dukung lagi untuk transaksi baru.',
        );
      }
    }
    return;
  }

  final catalog = state.liveCatalog;
  var amount = pending?.amount ?? catalog.minTip;
  var busy = false;
  final message = TextEditingController(text: pending?.message ?? '');
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(builder: (context, setLocal) {
      final creatorNet = amount - (amount * catalog.platformFeeBps ~/ 10000);
      return AlertDialog(
        title: const Text('Dukung kreator'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Saldo kamu ${rupiah(state.user?.saldo ?? 0)}', style: TextStyle(color: XyTheme.of(context).muted)),
          if (pending != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: XyTheme.warning.withOpacity(.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Melanjutkan percobaan ${rupiah(amount)} sebelumnya dengan ID yang sama. Nominal dan pesan dikunci agar server tidak memotong saldo dua kali.',
                style: const TextStyle(fontSize: 11.5, height: 1.4),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: [5000, 10000, 25000, 50000, 100000]
              .where((x) => x >= catalog.minTip && x <= catalog.maxTip)
              .map((x) => ChoiceChip(
                    label: Text(rupiah(x)),
                    selected: amount == x,
                    onSelected: pending != null ? null : (_) => setLocal(() => amount = x),
                  )).toList()),
          const SizedBox(height: 14),
          TextField(
            controller: message,
            readOnly: pending != null,
            maxLength: 120,
            decoration: const InputDecoration(labelText: 'Pesan (opsional)', hintText: 'GG! Lanjutkan!'),
          ),
          const SizedBox(height: 8),
          Text('Kreator menerima ${rupiah(creatorNet)} setelah hold 7 hari. Fee platform ${(catalog.platformFeeBps / 100).toStringAsFixed(0)}%.',
              style: TextStyle(color: XyTheme.of(context).muted, fontSize: 11.5, height: 1.4)),
        ])),
        actions: [
          TextButton(onPressed: busy ? null : () => Navigator.pop(dialogContext), child: const Text('Batal')),
          FilledButton(
            onPressed: busy || (pending == null && amount > (state.user?.saldo ?? 0)) ? null : () async {
              setLocal(() => busy = true);
              final cleanMessage = message.text.trim();
              final error = await state.dukungLivestream(
                live.id,
                amount: amount,
                message: cleanMessage,
              );
              if (!dialogContext.mounted) return;
              if (error == null || error.startsWith('INFO:')) {
                Navigator.pop(dialogContext);
                _snackMutasiLive(
                  messenger,
                  error,
                  pesanSukses: 'Dukungan ${rupiah(amount)} berhasil.',
                );
              } else {
                setLocal(() => busy = false);
                _snackMutasiLive(messenger, error, pesanSukses: '');
              }
            },
            child: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Konfirmasi'),
          ),
        ],
      );
    }),
  );
  message.dispose();
}

class _Studio extends StatelessWidget {
  const _Studio({
    required this.data,
    required this.loading,
    required this.error,
    required this.onRetry,
  });
  final CreatorLiveData? data;
  final bool loading;
  final String? error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    if (data == null) {
      if (loading) return const Padding(padding: EdgeInsets.only(top: 24), child: SkeletonList(count: 3));
      if (error != null) {
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 28, 18, 110),
          children: [
            _Notice(
              icon: Icons.cloud_off_rounded,
              title: 'Studio belum dapat dimuat',
              text: '$error Data pengajuan tidak diubah.',
              tone: XyTheme.danger,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Coba lagi'),
            ),
          ],
        );
      }
      return const _CreatorApply();
    }
    final content = data!.profile == null
        ? const _CreatorApply()
        : !data!.approved
            ? _CreatorStatus(data: data!)
            : _CreatorDashboard(data: data!);
    if (error == null) return content;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
        child: _Notice(
          icon: Icons.sync_problem_rounded,
          title: 'Menampilkan snapshot Studio terakhir',
          text: '$error Tarik untuk mencoba lagi; jangan ulangi mutasi payout hanya karena angka belum berubah.',
          tone: XyTheme.warning,
        ),
      ),
      Expanded(child: content),
    ]);
  }
}

class _CreatorApply extends StatefulWidget {
  const _CreatorApply({this.embedded = false});
  final bool embedded;
  @override
  State<_CreatorApply> createState() => _CreatorApplyState();
}

class _CreatorApplyState extends State<_CreatorApply> {
  late final TextEditingController name;
  final bio = TextEditingController();
  bool age = false;
  bool terms = false;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: context.read<AppState>().user?.nama ?? '');
  }

  @override
  void dispose() {
    name.dispose();
    bio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final namaBersih = name.text.trim();
    final siap = !busy && age && terms && namaBersih.length >= 3 && namaBersih.length <= 40;
    final children = <Widget>[
      const Center(child: XyIlustrasi('livestream', tinggi: 130)),
      const SizedBox(height: 12),
      const Text('Jadi kreator XyCloud', textAlign: TextAlign.center,
          style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900, letterSpacing: -.6)),
      const SizedBox(height: 8),
      Text('Siarkan gameplay dari PC rental, bangun pengikut, dan terima dukungan saldo dengan ledger transparan.',
          textAlign: TextAlign.center, style: TextStyle(color: XyTheme.of(context).muted, height: 1.5)),
      const SizedBox(height: 24),
      TextField(controller: name, maxLength: 40, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Nama kreator')),
      const SizedBox(height: 10),
      TextField(controller: bio, maxLength: 240, minLines: 3, maxLines: 5, decoration: const InputDecoration(labelText: 'Bio & game favorit')),
      CheckboxListTile(
        value: age, onChanged: (v) => setState(() => age = v == true),
        contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading,
        title: const Text('Saya berusia 18 tahun atau lebih.'),
      ),
      CheckboxListTile(
        value: terms, onChanged: (v) => setState(() => terms = v == true),
        contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading,
        title: const Text('Saya menyetujui syarat kreator, hold 7 hari, review anti-fraud, dan kebijakan konten.'),
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: _bukaKetentuanLive,
          icon: const Icon(Icons.open_in_new_rounded, size: 17),
          label: const Text('Baca ketentuan lengkap XyCloud Live'),
        ),
      ),
      const SizedBox(height: 10),
      GradientButton(
        label: 'Ajukan untuk ditinjau', icon: Icons.send_rounded,
        onPressed: siap ? () async {
          setState(() => busy = true);
          final e = await context.read<AppState>().ajukanKreatorLive(name.text.trim(), bio.text.trim());
          if (!mounted) return;
          setState(() => busy = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e ?? 'Pengajuan terkirim.')));
        } : null,
      ),
    ];
    return widget.embedded
        ? Column(mainAxisSize: MainAxisSize.min, children: children)
        : ListView(padding: const EdgeInsets.fromLTRB(18, 22, 18, 110), children: children);
  }
}

class _CreatorStatus extends StatelessWidget {
  const _CreatorStatus({required this.data});
  final CreatorLiveData data;

  @override
  Widget build(BuildContext context) {
    final status = data.status;
    final pending = status == 'pending';
    final color = pending ? XyTheme.warning : XyTheme.danger;
    return ListView(padding: const EdgeInsets.fromLTRB(18, 20, 18, 110), children: [
      if (pending)
        const Center(child: XyIlustrasi('kreator_review', tinggi: 160))
      else
        Icon(Icons.info_outline_rounded, size: 62, color: color),
      const SizedBox(height: 14),
      Text(pending ? 'Pengajuan Sedang Ditinjau' : status == 'suspended' ? 'Program ditangguhkan' : 'Pengajuan belum disetujui',
          textAlign: TextAlign.center, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
      const SizedBox(height: 8),
      Text('${data.profile?['review_note'] ?? (pending ? 'Tim verifikasi sedang memeriksa identitas & kelayakan kreator. Notifikasi akan masuk saat disetujui.' : 'Perbaiki profil lalu ajukan ulang atau hubungi Chat Admin.')}',
          textAlign: TextAlign.center, style: TextStyle(color: XyTheme.of(context).muted, height: 1.5)),
      if (!pending && status != 'suspended') ...[
        const SizedBox(height: 20),
        const _CreatorApply(embedded: true),
      ],
    ]);
  }
}

class _CreatorDashboard extends StatelessWidget {
  const _CreatorDashboard({required this.data});
  final CreatorLiveData data;

  @override
  Widget build(BuildContext context) {
    final active = data.active;
    return RefreshIndicator(
      onRefresh: () => context.read<AppState>().muatLive(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 110),
        children: [
          Row(children: [
            const Expanded(child: Text('Studio kreator', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900))),
            const _Badge(text: 'SIAP LIVE', color: XyTheme.success),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _MoneyStat(label: 'Ditahan', value: data.earningValue('held'), color: XyTheme.warning)),
            const SizedBox(width: 10),
            Expanded(child: _MoneyStat(label: 'Tersedia', value: data.earningValue('available'), color: XyTheme.success)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _MoneyStat(label: 'Diproses', value: data.earningValue('reserved'), color: XyTheme.primary)),
            const SizedBox(width: 10),
            Expanded(child: _MoneyStat(label: 'Terbayar', value: data.earningValue('paid'), color: const Color(0xFF0EA5E9))),
          ]),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: data.payoutVerified && data.earningValue('available') >= data.minPayout
                ? () => _payout(context, data)
                : null,
            icon: const Icon(Icons.account_balance_rounded),
            label: Text(data.payoutVerified
                ? 'Minta payout (min. ${rupiah(data.minPayout)})'
                : 'Payout menunggu verifikasi admin'),
          ),
          const SizedBox(height: 24),
          if (active != null)
            _ActiveCreatorLive(live: active, diagnostics: data.activeDiagnostics)
          else ...[
            if (data.lastBroadcast?.status == 'failed' || data.lastDiagnostics?.failureCode != null) ...[
              _Notice(
                icon: Icons.error_outline_rounded,
                title: 'Siaran terakhir gagal',
                text: _pesanDiagnostikLive(data.lastDiagnostics),
                tone: XyTheme.danger,
              ),
              const SizedBox(height: 12),
            ],
            _StartLiveForm(enabled: true),
          ],
          const SizedBox(height: 22),
          const _Notice(
            icon: Icons.privacy_tip_outlined,
            title: 'Privasi lebih penting dari tayang',
            text: 'Agen hanya menerima Game Capture. Pergantian scene, Display Capture, atau source asing menghentikan output otomatis. Mic mati secara default.',
          ),
          if (data.payouts.isNotEmpty) ...[
            const SizedBox(height: 22),
            const Text('Riwayat payout', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            ...data.payouts.take(5).map((p) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(child: Icon(Icons.payments_outlined)),
              title: Text(rupiah((p['amount'] as num?)?.toInt() ?? 0)),
              subtitle: Text('${p['payout_label'] ?? 'Metode terverifikasi'}'),
              trailing: Text('${p['status'] ?? '-'}', style: const TextStyle(fontWeight: FontWeight.w700)),
            )),
          ],
        ],
      ),
    );
  }

  Future<void> _payout(BuildContext context, CreatorLiveData data) async {
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('Minta payout?'),
      content: Text('${rupiah(data.earningValue('available'))} akan direservasi dan diperiksa pemilik sebelum transfer eksternal.'),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Minta payout'))],
    ));
    if (ok != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final e = await context.read<AppState>().mintaPayoutLive();
    if (context.mounted) {
      _snackMutasiLive(
        messenger,
        e,
        pesanSukses: 'Payout masuk antrean review.',
      );
    }
  }
}

class _ActiveCreatorLive extends StatelessWidget {
  const _ActiveCreatorLive({required this.live, this.diagnostics});
  final LivestreamItem live;
  final LiveDiagnostics? diagnostics;

  @override
  Widget build(BuildContext context) {
    final d = diagnostics;
    final quality = d?.quality ?? (live.status == 'starting' ? 'starting' : 'offline');
    final qualityText = switch (quality) {
      'good' => 'Koneksi sehat',
      'reconnecting' => 'Menyambung ulang otomatis',
      'degraded' => 'Jaringan tidak stabil',
      'cleanup_pending' => 'Sedang membersihkan credential',
      'starting' => 'Menunggu sinyal OBS',
      _ => 'Agen belum mengirim diagnostik',
    };
    final qualityColor = quality == 'good'
        ? XyTheme.success
        : (quality == 'degraded' || quality == 'reconnecting' || quality == 'starting')
            ? XyTheme.warning
            : XyTheme.danger;
    return XyCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        _Badge(text: live.status.toUpperCase(), color: live.status == 'live' ? const Color(0xFFEF4444) : XyTheme.warning),
        const Spacer(),
        Text('${live.viewers} menonton', style: TextStyle(color: XyTheme.of(context).muted)),
      ]),
      const SizedBox(height: 12),
      Text(live.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
      const SizedBox(height: 5),
      Text('${live.game} · ${rupiah(live.grossTip)} dukungan', style: TextStyle(color: XyTheme.of(context).muted)),
      const SizedBox(height: 13),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: qualityColor.withOpacity(.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: qualityColor.withOpacity(.24)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(quality == 'good' ? Icons.network_check_rounded : Icons.wifi_tethering_error_rounded,
              color: qualityColor, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(qualityText, style: TextStyle(color: qualityColor, fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text(
              d == null
                  ? 'Diagnostik akan muncul setelah heartbeat agen berikutnya.'
                  : 'Kode ${d.healthCode} · congestion ${((d.congestion ?? 0) * 100).toStringAsFixed(0)}% · frame lewat ${(d.skippedRatio * 100).toStringAsFixed(1)}%',
              style: TextStyle(color: XyTheme.of(context).muted, fontSize: 11.5, height: 1.4),
            ),
          ])),
        ]),
      ),
      const SizedBox(height: 16),
      FilledButton.icon(
        style: FilledButton.styleFrom(backgroundColor: XyTheme.danger, minimumSize: const Size.fromHeight(46)),
        onPressed: () async {
          final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
            title: const Text('Akhiri siaran?'),
            content: const Text('Player ditutup, ingest dinonaktifkan, dan OBS dibersihkan oleh agen.'),
            actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
              FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Akhiri'))],
          ));
          if (ok != true || !context.mounted) return;
          final e = await context.read<AppState>().akhiriLivestream(live.id);
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e ?? 'Siaran sedang diakhiri.')));
        },
        icon: const Icon(Icons.stop_circle_rounded), label: const Text('Akhiri siaran'),
      ),
    ]));
  }
}

class _StartLiveForm extends StatefulWidget {
  const _StartLiveForm({required this.enabled});
  final bool enabled;
  @override
  State<_StartLiveForm> createState() => _StartLiveFormState();
}

class _StartLiveFormState extends State<_StartLiveForm> {
  final title = TextEditingController();
  final game = TextEditingController();
  String sumber = 'kamera'; // 'kamera' | 'layar' | 'obs'
  bool recording = false;
  bool safe = false;
  bool terms = false;
  bool mic = true;
  bool busy = false;

  @override
  void dispose() {
    title.dispose();
    game.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = XyTheme.of(context);
    final titleLength = title.text.trim().length;
    final gameLength = game.text.trim().length;
    final ready = recording && safe && terms && !busy
        && titleLength >= 5 && titleLength <= 100
        && gameLength >= 2 && gameLength <= 60;
    final isMobile = sumber == 'kamera' || sumber == 'layar';

    return XyCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Mulai siaran baru', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
      const SizedBox(height: 5),
      Text(
        isMobile
            ? 'Live langsung dari smartphone kamu (kamera depan/belakang atau rekam layar).'
            : 'Siaran otomatis dari PC Cloud rental yang sedang aktif.',
        style: TextStyle(color: t.muted, fontSize: 12),
      ),
      const SizedBox(height: 14),

      // Pilihan sumber siaran: Kamera HP, Layar HP, atau PC Rental (OBS)
      const Text('Pilih Sumber Siaran', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(
          child: _PilihanSumber(
            icon: Icons.videocam_rounded,
            label: 'Kamera HP',
            terpilih: sumber == 'kamera',
            onTap: () => setState(() => sumber = 'kamera'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _PilihanSumber(
            icon: Icons.screen_share_rounded,
            label: 'Layar HP',
            terpilih: sumber == 'layar',
            onTap: () => setState(() => sumber = 'layar'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _PilihanSumber(
            icon: Icons.desktop_windows_rounded,
            label: 'PC Rental',
            terpilih: sumber == 'obs',
            onTap: () => setState(() => sumber = 'obs'),
          ),
        ),
      ]),
      const SizedBox(height: 15),

      TextField(
        controller: title,
        maxLength: 100,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: 'Judul live',
          hintText: sumber == 'kamera'
              ? 'Ngobrol santai & mabar bareng'
              : sumber == 'layar'
                  ? 'Push rank Mobile Legends / Free Fire'
                  : 'Push rank menuju Immortal',
        ),
      ),
      const SizedBox(height: 8),
      TextField(
        controller: game,
        maxLength: 60,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: sumber == 'kamera' ? 'Kategori / Topik' : 'Game',
          hintText: sumber == 'kamera' ? 'Just Chatting / Mabar' : 'Mobile Legends / GTA V',
        ),
      ),
      SwitchListTile(
        value: mic,
        onChanged: (v) => setState(() => mic = v),
        contentPadding: EdgeInsets.zero,
        title: const Text('Izinkan mic'),
        subtitle: Text(
          isMobile
              ? 'Gunakan mikrofon smartphone untuk berbicara selama siaran.'
              : 'Default mati. Hanya source XyCloudMic yang disiapkan operator.',
          style: TextStyle(color: t.muted, fontSize: 11.5),
        ),
      ),
      CheckboxListTile(
        value: recording,
        onChanged: (v) => setState(() => recording = v == true),
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        title: const Text('Saya setuju siaran direkam maksimal 30 hari untuk moderasi.'),
      ),
      CheckboxListTile(
        value: safe,
        onChanged: (v) => setState(() => safe = v == true),
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        title: Text(
          isMobile
              ? 'Tidak menampilkan password, chat pribadi, atau data sensitif di kamera/layar.'
              : 'Game fullscreen sudah terbuka; tidak ada data pribadi di layar PC.',
        ),
      ),
      CheckboxListTile(
        value: terms,
        onChanged: (v) => setState(() => terms = v == true),
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        title: const Text('Saya menyetujui aturan siaran dan larangan konten.'),
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: _bukaKetentuanLive,
          icon: const Icon(Icons.gavel_rounded, size: 17),
          label: const Text('Ketentuan kreator & monetisasi'),
        ),
      ),
      const SizedBox(height: 8),
      if (!isMobile)
        const _Notice(
          icon: Icons.info_outline_rounded,
          title: 'Siaran PC Rental (OBS)',
          text: 'Pastikan sesi PC Cloud rental kamu sedang aktif, atau ganti pilihan sumber ke Kamera HP / Layar HP.',
          tone: XyTheme.primary,
        ),
      const SizedBox(height: 8),
      GradientButton(
        label: busy
            ? (isMobile ? 'Menyiapkan live HP…' : 'Menyiapkan OBS…')
            : (isMobile ? 'Mulai Live HP' : 'Mulai Live OBS'),
        icon: isMobile ? Icons.sensors_rounded : Icons.live_tv_rounded,
        onPressed: ready ? () async {
          if (!isMobile && context.read<AppState>().orderAktif == null) {
            final go = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
              title: const Text('Belum ada sesi PC'),
              content: const Text('Sewa dan mulai sesi PC terlebih dahulu untuk siaran OBS. Atau pilih mode Kamera HP / Layar HP.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Nanti')),
                FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Lihat pesanan')),
              ],
            ));
            if (go == true && context.mounted) {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const OrderListScreen()));
            }
            return;
          }
          setState(() => busy = true);
          final judul = title.text.trim();
          final namaGame = game.text.trim();
          final state = context.read<AppState>();
          final e = await state.mulaiLivestream(
            title: judul,
            game: namaGame,
            mic: mic,
            sumber: sumber,
          );
          if (!mounted) return;
          setState(() => busy = false);
          if (e == null) {
            if (isMobile) {
              final activeItem = state.liveAktifSaya ?? state.creatorLive.active;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MobileBroadcastLiveScreen(
                    title: judul,
                    game: namaGame,
                    sumber: sumber,
                    mic: mic,
                    liveId: activeItem?.id,
                  ),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('OBS sedang menyiapkan siaran di PC rental.')),
              );
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e)));
          }
        } : null,
      ),
    ]));
  }
}

class _PilihanSumber extends StatelessWidget {
  const _PilihanSumber({
    required this.icon,
    required this.label,
    required this.terpilih,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool terpilih;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: terpilih ? XyTheme.primary.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: terpilih ? XyTheme.primary : Colors.white.withOpacity(0.2),
            width: terpilih ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 22,
              color: terpilih ? XyTheme.primary : XyTheme.of(context).muted,
            ),
            const SizedBox(height: 5),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: terpilih ? FontWeight.w800 : FontWeight.w600,
                  color: terpilih ? XyTheme.primary : XyTheme.of(context).ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoneyStat extends StatelessWidget {
  const _MoneyStat({required this.label, required this.value, required this.color});
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: color.withOpacity(.09), borderRadius: BorderRadius.circular(17), border: Border.all(color: color.withOpacity(.18))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color: XyTheme.of(context).muted, fontSize: 11)),
      const SizedBox(height: 5),
      FittedBox(child: Text(rupiah(value), style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w900))),
    ]),
  );
}

class _SafetyCard extends StatelessWidget {
  const _SafetyCard({required this.feeBps});
  final int feeBps;
  @override
  Widget build(BuildContext context) => _Notice(
    icon: Icons.verified_user_outlined,
    title: 'Monetisasi yang dapat diaudit',
    text: 'Dukungan didebit atomik, fee ${(feeBps / 100).toStringAsFixed(0)}%, bagian kreator ditahan 7 hari, lalu payout hanya ke metode yang diverifikasi admin.',
  );
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.title,
    required this.text,
    this.tone = XyTheme.primary,
  });
  final IconData icon;
  final String title;
  final String text;
  final Color tone;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: tone.withOpacity(.06),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: tone.withOpacity(.18)),
    ),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: tone),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(text, style: TextStyle(color: XyTheme.of(context).muted, fontSize: 12, height: 1.45)),
      ])),
    ]),
  );
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(99)),
    child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: .3)),
  );
}

/// ============================================================
/// Layar Broadcast Live Mobile (Kamera HP & Rekam Layar)
/// Kontrol HUD berbentuk BULAT (Circle) dengan outline BORDER SAJA
/// ============================================================

class MobileBroadcastLiveScreen extends StatefulWidget {
  const MobileBroadcastLiveScreen({
    super.key,
    required this.title,
    required this.game,
    required this.sumber,
    required this.mic,
    this.liveId,
  });

  final String title;
  final String game;
  final String sumber; // 'kamera' | 'layar'
  final bool mic;
  final String? liveId;

  @override
  State<MobileBroadcastLiveScreen> createState() => _MobileBroadcastLiveScreenState();
}

class _MobileBroadcastLiveScreenState extends State<MobileBroadcastLiveScreen> {
  late bool _micAktif;
  bool _kameraDepan = true;
  bool _flashAktif = false;
  bool _tampilChat = true;
  int _detik = 0;
  int _penonton = 0;
  Timer? _timer;
  final List<Map<String, String>> _pesanChat = [];

  @override
  void initState() {
    super.initState();
    _micAktif = widget.mic;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        _detik++;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDurasi(int dtk) {
    final m = (dtk ~/ 60).toString().padLeft(2, '0');
    final s = (dtk % 60).toString().padLeft(2, '0');
    final j = (dtk ~/ 3600);
    return j > 0 ? '$j:$m:$s' : '$m:$s';
  }

  Future<void> _akhiriSiaran() async {
    final konfirmasi = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Akhiri Siaran?'),
        content: const Text('Siaran live akan dihentikan untuk semua penonton.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Lanjut Live')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Akhiri Sekarang'),
          ),
        ],
      ),
    );
    if (konfirmasi == true && mounted) {
      if (widget.liveId != null && widget.liveId!.isNotEmpty) {
        unawaited(context.read<AppState>().akhiriLivestream(widget.liveId!));
      }
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Siaran langsung telah diakhiri.')),
      );
    }
  }

  void _bukaInfoIngest() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161B22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Parameter Ingest Siaran HP',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Koneksi Cloudflare Stream Ingest resmi untuk siaran ${widget.sumber == 'kamera' ? 'Kamera' : 'Layar'}.',
                style: const TextStyle(color: Color(0xFF8B949E), fontSize: 12),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D1117),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF30363D)),
                ),
                child: Column(
                  children: [
                    _barisInfo('Endpoint RTMP', 'rtmps://live.cloudflare.com:443/live/'),
                    const Divider(color: Color(0xFF21262D), height: 16),
                    _barisInfo('Mode Sumber', widget.sumber == 'kamera' ? 'Kamera Smartphone' : 'Layar Smartphone (Game)'),
                    const Divider(color: Color(0xFF21262D), height: 16),
                    _barisInfo('ID Siaran', widget.liveId ?? 'Membuat sesi...'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  minimumSize: const Size.fromHeight(44),
                ),
                onPressed: () {
                  Clipboard.setData(const ClipboardData(text: 'rtmps://live.cloudflare.com:443/live/'));
                  Navigator.pop(c);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Endpoint RTMP disalin ke clipboard.')),
                  );
                },
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('Salin Endpoint RTMP'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _barisInfo(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(color: Color(0xFF8B949E), fontSize: 11.5),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _akhiriSiaran();
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Latar Belakang Viewfinder Kamera atau Layar
            Positioned.fill(
              child: widget.sumber == 'kamera'
                  ? Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment.center,
                          radius: 1.2,
                          colors: [
                            const Color(0xFF1E1B2E),
                            Colors.black,
                          ],
                        ),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _kameraDepan
                                  ? Icons.face_rounded
                                  : Icons.camera_rear_rounded,
                              size: 72,
                              color: Colors.white.withOpacity(0.35),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _kameraDepan
                                  ? 'Kamera Depan Aktif'
                                  : 'Kamera Belakang Aktif',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.65),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Video broadcast sedang ditransmisikan realtime',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.35),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Container(
                      color: const Color(0xFF0F0B1E),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFF7C3AED).withOpacity(0.6),
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.screen_share_rounded,
                                size: 36,
                                color: Color(0xFFA78BFA),
                              ),
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'Menyiarkan Layar Smartphone',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Buka game atau aplikasi apa pun di HP kamu sekarang.',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),

            // Bilah Atas: Live Status, Durasi, Penonton
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      // Badge Live
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFDC2626).withOpacity(0.5),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.fiber_manual_record_rounded, size: 10, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              'LIVE',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Durasi
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.2)),
                        ),
                        child: Text(
                          _formatDurasi(_detik),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Penonton
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.remove_red_eye_rounded, size: 12, color: Colors.white),
                            const SizedBox(width: 5),
                            Text(
                              '$_penonton',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        icon: const Icon(Icons.info_outline_rounded, size: 18, color: Colors.white70),
                        tooltip: 'Info Ingest',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        onPressed: _bukaInfoIngest,
                      ),
                      const Spacer(),

                      // Judul & Kategori
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              widget.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              widget.game,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.65),
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Live Chat Overlay (Kiri Bawah)
            if (_tampilChat)
              Positioned(
                left: 16,
                bottom: 96,
                width: MediaQuery.of(context).size.width * 0.76,
                child: _pesanChat.isEmpty
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.12)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.chat_bubble_outline_rounded, size: 14, color: Colors.white.withOpacity(0.7)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Belum ada obrolan. Pesan penonton akan muncul di sini secara realtime.',
                                style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: _pesanChat.map((msg) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.45),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white.withOpacity(0.12)),
                            ),
                            child: RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: '${msg['nama']}: ',
                                    style: const TextStyle(
                                      color: Color(0xFFA78BFA),
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  TextSpan(
                                    text: msg['teks'] ?? '',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
              ),

            // Bilah Kontrol HUD Bawah: SEMUA TOMBOL BULAT & OUTLINE BORDER SAJA
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // 1. Mic Toggle (Bulat, Outline Border)
                      _hudBulat(
                        icon: _micAktif ? Icons.mic_rounded : Icons.mic_off_rounded,
                        tooltip: _micAktif ? 'Mute Mic' : 'Nyalakan Mic',
                        aktif: _micAktif,
                        onTap: () => setState(() => _micAktif = !_micAktif),
                      ),

                      // 2. Kamera Switch (Bulat, Outline Border)
                      if (widget.sumber == 'kamera')
                        _hudBulat(
                          icon: Icons.flip_camera_ios_rounded,
                          tooltip: 'Putar Kamera',
                          onTap: () => setState(() => _kameraDepan = !_kameraDepan),
                        ),

                      // 3. Flashlight (Bulat, Outline Border)
                      if (widget.sumber == 'kamera' && !_kameraDepan)
                        _hudBulat(
                          icon: _flashAktif ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                          tooltip: 'Flash',
                          aktif: _flashAktif,
                          onTap: () => setState(() => _flashAktif = !_flashAktif),
                        ),

                      // 4. Chat Toggle (Bulat, Outline Border)
                      _hudBulat(
                        icon: _tampilChat ? Icons.chat_bubble_rounded : Icons.chat_bubble_outline_rounded,
                        tooltip: 'Toggle Chat',
                        aktif: _tampilChat,
                        onTap: () => setState(() => _tampilChat = !_tampilChat),
                      ),

                      // 5. Akhiri Live (Bulat, Outline Border Merah)
                      _hudBulat(
                        icon: Icons.stop_rounded,
                        tooltip: 'Akhiri Siaran',
                        warnaKhusus: const Color(0xFFEF4444),
                        onTap: _akhiriSiaran,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Tombol HUD Streaming: Bulat (Circle), Border Only (Outline), Tanpa Kotak Solid
  Widget _hudBulat({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    bool aktif = false,
    Color? warnaKhusus,
  }) {
    final borderColor = warnaKhusus ?? (aktif ? const Color(0xFFA78BFA) : Colors.white.withOpacity(0.80));
    final iconColor = warnaKhusus ?? (aktif ? const Color(0xFFA78BFA) : Colors.white);

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 50,
          height: 50,
          // BULAT (BoxShape.circle) & CUKUP BORDER AJA (outline border minimalis)
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: warnaKhusus != null
                ? warnaKhusus.withOpacity(0.12)
                : (aktif ? const Color(0x33A78BFA) : Colors.white.withOpacity(0.06)),
            border: Border.all(
              color: borderColor,
              width: 1.8,
            ),
            boxShadow: aktif
                ? [
                    BoxShadow(
                      color: (warnaKhusus ?? const Color(0xFF7C3AED)).withOpacity(0.4),
                      blurRadius: 10,
                    )
                  ]
                : null,
          ),
          child: Icon(
            icon,
            size: 22,
            color: iconColor,
          ),
        ),
      ),
    );
  }
}
