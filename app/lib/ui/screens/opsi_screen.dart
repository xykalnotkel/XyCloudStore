import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/pengaturan.dart';
import '../../core/theme.dart';
import '../../data/native_stream.dart';
import '../../data/push_service.dart';
import '../../providers/app_state.dart';
import '../widgets/common.dart';
import '../widgets/lembar.dart';

class OpsiStreamingScreen extends StatefulWidget {
  const OpsiStreamingScreen({super.key});
  @override
  State<OpsiStreamingScreen> createState() => _OpsiStreamingScreenState();
}

class _OpsiStreamingScreenState extends State<OpsiStreamingScreen> {
  Future<void> _set(String key, dynamic value) async {
    await PengaturanLokal.set(key, value);
    if (mounted) setState(() {});
  }

  Future<void> _preset(Map<String, dynamic> nilai) async {
    for (final e in nilai.entries) {
      await PengaturanLokal.set(e.key, e.value);
    }
    if (mounted) setState(() {});
  }

  Widget _tombolPreset(String label, Map<String, dynamic> nilai) => Pressable(
        onTap: () => _preset(nilai),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: XyTheme.primary.withOpacity(.10),
            borderRadius: BorderRadius.circular(XyRadius.pill),
            border: Border.all(color: XyTheme.primary.withOpacity(.35)),
          ),
          child: Text(label,
              style: TextStyle(
                  color: XyTheme.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final p = PengaturanLokal.nilai;
    return Scaffold(
        appBar: AppBar(title: const Text('Streaming & Kontrol')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          const Text(
              'Pengaturan berlaku pada koneksi berikutnya. Tidak memerlukan aplikasi streaming lain.',
              style: TextStyle(height: 1.5)),
          const SizedBox(height: 14),
          const Text('Preset cepat',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _tombolPreset('\u26a1 Latensi Ultra Rendah', {
              'resolution': '1920x1080',
              'fps': 120,
              'codec': 'forceh265',
              'bitrate': 24000
            }),
            _tombolPreset('Seimbang', {
              'resolution': '1280x720',
              'fps': 60,
              'codec': 'auto',
              'bitrate': 10000
            }),
            _tombolPreset('Hemat Data', {
              'resolution': '854x480',
              'fps': 30,
              'codec': 'neverh265',
              'bitrate': 4000
            }),
          ]),
          const SizedBox(height: 6),
          Text(
              'Latensi Ultra Rendah = HEVC + 120 FPS + bitrate tinggi; butuh HP yang mampu dan Wi-Fi/jaringan stabil. Suara game & Discord di PC ikut terdengar di HP; untuk onmic pakai Discord di HP atau mic PC.',
              style: TextStyle(fontSize: 11.5, color: XyTheme.of(context).muted, height: 1.4)),
          const SizedBox(height: 18),
          SwitchListTile(
              value: p['kontrolBawaan'] == true,
              title: const Text('Kontrol bawaan (Moonlight)'),
              subtitle: const Text(
                  'Matikan untuk memakai HUD XyCloudStore: QWERTY, F1–F12, Windows, numpad. Bisa juga diganti langsung saat streaming lewat tombol ☰.'),
              onChanged: (v) async {
                await _set('kontrolBawaan', v);
                await NativeStream.setKontrolBawaan(v);
              }),
          _pilih('Resolusi', 'resolution', {
            '854x480': '480p · ringan',
            '1280x720': '720p',
            '1920x1080': '1080p',
            '2560x1440': '1440p',
            '3840x2160': '4K'
          }),
          _pilih('Frame per detik', 'fps',
              {30: '30 FPS', 60: '60 FPS', 90: '90 FPS', 120: '120 FPS'}),
          _pilih('Codec video', 'codec', {
            'auto': 'Otomatis',
            'neverh265': 'H.264 (kompatibel)',
            'forceh265': 'HEVC / H.265'
          }),
          XyCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Bitrate ${((p['bitrate'] as num) / 1000).round()} Mbps',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                Slider(
                    value: (p['bitrate'] as num).toDouble().clamp(2000, 80000),
                    min: 2000,
                    max: 80000,
                    divisions: 39,
                    label: '${((p['bitrate'] as num) / 1000).round()} Mbps',
                    onChanged: (v) => _set('bitrate', v.round()))
              ])),
          for (final item in [
            (
              'gamepad',
              'Gamepad di layar',
              'Tombol sentuh native untuk bermain'
            ),
            (
              'trackpad',
              'Sentuh sebagai trackpad',
              'Matikan untuk sentuhan langsung'
            ),
            ('vibration', 'Getar kontrol', 'Umpan balik tombol gamepad'),
            (
              'hostAudio',
              'Suara juga di PC',
              'Audio tetap diputar di perangkat host'
            ),
            (
              'stats',
              'Statistik streaming',
              'FPS, decoder dan informasi koneksi'
            )
          ])
            SwitchListTile(
                value: p[item.$1] == true,
                title: Text(item.$2),
                subtitle: Text(item.$3),
                onChanged: (v) => _set(item.$1, v)),
          const SizedBox(height: 12),
          OutlinedButton(
              onPressed: () async {
                if (await konfirmasi(context,
                    judul: 'Hapus pasangan tersimpan?',
                    pesan:
                        'Koneksi berikutnya akan memasangkan HP kembali dengan host.',
                    tombolYa: 'Hapus')) {
                  await NativeStream.resetPairing();
                  if (context.mounted)
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Pasangan lokal dibersihkan.')));
                }
              },
              child: const Text('Reset pasangan streaming')),
        ]));
  }

  Widget _pilih(String title, String key, Map<dynamic, String> options) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: DropdownButtonFormField<dynamic>(
              value: PengaturanLokal.nilai[key],
              isExpanded: true,
              decoration: InputDecoration(labelText: title),
              items:
                  options.entries
                      .map((e) =>
                          DropdownMenuItem(value: e.key, child: Text(e.value)))
                      .toList(),
              onChanged: (v) => _set(key, v)));
}

class OpsiTampilanScreen extends StatefulWidget {
  const OpsiTampilanScreen({super.key});
  @override
  State<OpsiTampilanScreen> createState() => _OpsiTampilanScreenState();
}

class _OpsiTampilanScreenState extends State<OpsiTampilanScreen> {
  Future<void> set(String k, dynamic v) async {
    await context.read<AppState>().setPengaturan(k, v);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Teks & Gerakan')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Text('Ukuran teks ${((PengaturanLokal.skala) * 100).round()}%',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        Slider(
            value: PengaturanLokal.skala,
            min: .85,
            max: 1.3,
            divisions: 9,
            onChanged: (v) => set('textScale', v)),
        const Text(
            'Pratinjau teks XyCloudStore. Ukuran juga mengikuti pengaturan aksesibilitas HP.'),
        const SizedBox(height: 20),
        SwitchListTile(
            title: const Text('Animasi perpindahan layar'),
            subtitle: const Text('Matikan untuk perpindahan lebih langsung'),
            value: PengaturanLokal.animasi,
            onChanged: (v) => set('animasi', v)),
        const SizedBox(height: 24),
        const Text('Tombol tengah navigasi bawah',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 4),
        const Text(
            'Pilih halaman mana yang jadi tombol besar di tengah. Kamu juga bisa swipe kiri/kanan di layar untuk pindah halaman.',
            style: TextStyle(fontSize: 12.5, height: 1.45)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (var i = 0; i < _labelNav.length; i++)
            ChoiceChip(
              label: Text(_labelNav[i]),
              selected:
                  ((PengaturanLokal.nilai['navTengah'] as num?)?.toInt() ?? 2) ==
                      i,
              onSelected: (_) => set('navTengah', i),
            ),
        ]),
      ]));
}

const _labelNav = ['Beranda', 'Sewa PC', 'Akun', 'Komunitas', 'Profil'];

class OpsiNotifikasiScreen extends StatefulWidget {
  const OpsiNotifikasiScreen({super.key});
  @override
  State<OpsiNotifikasiScreen> createState() => _OpsiNotifikasiScreenState();
}

class _OpsiNotifikasiScreenState extends State<OpsiNotifikasiScreen>
    with WidgetsBindingObserver {
  Map<String, dynamic>? data;
  String? error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    muat();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) muat();
  }

  Future<void> muat() async {
    try {
      final d = await NativeSettings.statusNotifikasi();
      if (mounted)
        setState(() {
          data = d;
          error = null;
        });
    } catch (_) {
      if (mounted)
        setState(() =>
            error = 'Pengaturan channel membutuhkan Android dan APK terbaru.');
    }
  }

  Future<void> buka([String? channel]) async {
    try {
      await NativeSettings.bukaNotifikasi(channel);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Pengaturan Android belum bisa dibuka.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Scaffold(
        appBar: AppBar(title: const Text('Notifikasi & Nada')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          XyCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(
                    data?['enabled'] == true
                        ? 'Izin notifikasi aktif'
                        : 'Izin notifikasi belum aktif',
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                const Text(
                    'Nada, getar, prioritas, dan tampilan layar kunci mengikuti pengaturan channel Android. Pilih kategori di bawah untuk mengaturnya.'),
                const SizedBox(height: 10),
                TextButton(
                    onPressed: () async {
                      await PushService.mintaIzin();
                      await buka();
                    },
                    child: const Text('Izin & pengaturan Android'))
              ])),
          const SizedBox(height: 16),
          if (error != null)
            Text(error!, style: const TextStyle(color: XyTheme.danger)),
          for (final raw in data?['channels'] as List? ?? [])
            Builder(builder: (context) {
              final c = Map<String, dynamic>.from(raw);
              return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: XyCard(
                      padding: EdgeInsets.zero,
                      child: ListTile(
                          title: Text('${c['name']}'),
                          subtitle: Text(
                              '${c['enabled'] == true ? 'Aktif' : 'Nonaktif'} · ${c['sound']}'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => buka('${c['id']}'))));
            }),
          OutlinedButton.icon(
              onPressed: () async {
                final e = await s.tesNotifikasi();
                if (context.mounted)
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(e ??
                          'Permintaan dikirim. Periksa notifikasi di HP.')));
              },
              icon: const Icon(Icons.notifications_active_outlined),
              label: const Text('Tes notifikasi sistem')),
          SwitchListTile(
              value: s.user?.notifForum ?? true,
              title: const Text('Pemberitahuan komunitas'),
              subtitle: const Text('Simpan preferensi akun ke server'),
              onChanged: (v) async {
                final e = await s.perbaruiProfil(notifForum: v);
                if (e != null && context.mounted)
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(e)));
              }),
          Text(
              'Memilih nada tidak mengaktifkan layanan push yang belum dikonfigurasi. Android dan izin perangkat tetap menentukan apakah pemberitahuan ditampilkan.',
              style: TextStyle(
                  color: XyTheme.of(context).muted,
                  fontSize: 11.5,
                  height: 1.5)),
        ]));
  }
}
