import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/hud_store.dart';
import '../../core/pengaturan.dart';
import '../../core/theme.dart';
import '../../data/api_client.dart';
import '../../data/native_stream.dart';
import '../../models/models.dart';
import '../../providers/app_state.dart';
import '../widgets/common.dart';
import 'hud_editor_screen.dart';

class HudPresetScreen extends StatefulWidget {
  const HudPresetScreen({super.key});

  @override
  State<HudPresetScreen> createState() => _HudPresetScreenState();
}

class _HudPresetScreenState extends State<HudPresetScreen> {
  List<HudLayout> _lokal = const [];
  List<HudPresetPublik> _publik = const [];
  List<HudPresetPublik> _milik = const [];
  String? _aktifId;
  String _urut = 'populer';
  int _tab = 0;
  bool _memuat = true;
  String? _galat;
  String? _aksiId;
  String _tahap = 'Membaca preset lokal…';
  double _progres = .08;
  int _detikProses = 0;
  late final Timer _jamProses;

  @override
  void initState() {
    super.initState();
    _jamProses = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && (_memuat || _aksiId != null)) {
        setState(() => _detikProses++);
      }
    });
    unawaited(_muat());
  }

  @override
  void dispose() {
    _jamProses.cancel();
    super.dispose();
  }

  Future<void> _muat({bool tenang = false}) async {
    if (!tenang && mounted) {
      setState(() {
        _memuat = true;
        _galat = null;
        _progres = .08;
        _detikProses = 0;
        _tahap = 'Membaca preset lokal…';
      });
    }
    try {
      final lokal = await HudStore.semua();
      final aktif = await HudStore.aktifId();
      if (!mounted) return;
      setState(() {
        _lokal = lokal;
        _aktifId = aktif;
        _progres = .42;
        _tahap = 'Menghubungkan galeri komunitas…';
      });
      final repo = context.read<AppState>().repo;
      final hasil = await Future.wait([
        repo.hudPresetPublik(urut: _urut),
        repo.hudPresetSaya(),
      ]);
      if (!mounted) return;
      setState(() {
        _publik = hasil[0];
        _milik = hasil[1];
        _progres = 1;
        _tahap = 'Preset siap digunakan.';
        _memuat = false;
        _galat = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _memuat = false;
        _progres = 1;
        _galat = _pesanGalat(e);
      });
    }
  }

  String _pesanGalat(Object e) => e is ApiException
      ? e.pesan
      : 'Tidak dapat memuat galeri komunitas. Periksa koneksi lalu coba lagi.';

  void _snack(String teks, {bool galat = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: galat ? XyTheme.danger : const Color(0xFF166534),
      content: Row(children: [
        Icon(galat ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
            color: Colors.white),
        const SizedBox(width: 10),
        Expanded(child: Text(teks)),
      ]),
    ));
  }

  void _aksiMulai(String id, String tahap, double progres) {
    if (!mounted) return;
    setState(() {
      _aksiId = id;
      _detikProses = 0;
      _tahap = tahap;
      _progres = progres;
    });
  }

  void _aksiTahap(String tahap, double progres) {
    if (!mounted) return;
    setState(() {
      _tahap = tahap;
      _progres = progres;
    });
  }

  void _aksiSelesai() {
    if (!mounted) return;
    setState(() {
      _aksiId = null;
      _progres = 1;
    });
  }

  Future<bool> _terapkan(HudLayout layout) async {
    await HudStore.aktifkan(layout.id);
    await PengaturanLokal.set('kontrolBawaan', false);
    _aksiTahap('Mengirim ${layout.tombol.length} tombol ke overlay Android…', .72);
    await NativeStream.setKontrolBawaan(false);
    final native = await NativeStream.terapkanHud(layout.toData());
    if (mounted) setState(() => _aktifId = layout.id);
    return native;
  }

  Future<void> _gunakanLokal(HudLayout layout) async {
    if (_aksiId != null) return;
    _aksiMulai(layout.id, 'Membuka preset lokal…', .18);
    try {
      final native = await _terapkan(layout);
      _aksiTahap(native
          ? 'Selesai — preset aktif untuk sesi berikutnya.'
          : 'Tersimpan — overlay perlu APK Android terbaru.', 1);
      _snack(native
          ? 'HUD “${layout.nama}” sekarang aktif.'
          : 'Preset dipilih, tetapi overlay memerlukan APK terbaru.',
          galat: !native);
    } catch (e) {
      _snack('Tidak dapat memakai preset: ${_pesanGalat(e)}', galat: true);
    } finally {
      _aksiSelesai();
    }
  }

  Future<void> _gunakanPublik(HudPresetPublik preset) async {
    if (_aksiId != null) return;
    _aksiMulai(preset.id, 'Mengunduh preset dari komunitas…', .12);
    try {
      final terbaru = await context.read<AppState>().repo.pakaiHudPublik(preset.id);
      _aksiTahap('Menyimpan salinan ke perangkat…', .45);
      var layout = terbaru.layout.copyWith(
        id: 'komunitas_${preset.id}',
        bawaan: false,
        sumberId: preset.id,
      );
      layout = await HudStore.simpan(layout);
      final native = await _terapkan(layout);
      if (mounted) {
        final i = _publik.indexWhere((e) => e.id == preset.id);
        if (i >= 0) {
          final daftar = [..._publik];
          daftar[i] = daftar[i].copyWith(dipakai: terbaru.dipakai);
          setState(() => _publik = daftar);
        }
      }
      _aksiTahap('Selesai — preset tersimpan lokal dan aktif.', 1);
      _snack(native
          ? 'Preset “${preset.nama}” diunduh dan diaktifkan.'
          : 'Preset tersimpan lokal. Pasang APK terbaru untuk overlay.',
          galat: !native);
      await _muat(tenang: true);
    } catch (e) {
      _snack('Gagal mengunduh preset: ${_pesanGalat(e)}', galat: true);
    } finally {
      _aksiSelesai();
    }
  }

  Future<void> _nonaktifkan() async {
    if (_aksiId != null) return;
    _aksiMulai('nonaktif', 'Menonaktifkan tombol HUD kustom…', .35);
    try {
      await HudStore.aktifkan(null);
      final native = await NativeStream.terapkanHud(null);
      if (mounted) setState(() => _aktifId = null);
      _aksiTahap('Selesai — keyboard lengkap tetap tersedia lewat bilah HUD.', 1);
      _snack(native
          ? 'HUD kustom dinonaktifkan. Keyboard lengkap tetap tersedia.'
          : 'Pilihan lokal dihapus. APK lama mungkin belum menerima perubahan.',
          galat: !native);
    } catch (e) {
      _snack('HUD gagal dinonaktifkan: ${_pesanGalat(e)}', galat: true);
    } finally {
      _aksiSelesai();
    }
  }

  Future<void> _bukaEditor(HudLayout layout) async {
    final hasil = await Navigator.push<HudLayout>(
      context,
      MaterialPageRoute(builder: (_) => HudEditorScreen(awal: layout)),
    );
    if (hasil != null && mounted) await _muat(tenang: true);
  }

  Future<void> _hapusLokal(HudLayout layout) async {
    if (layout.bawaan) return;
    final ya = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Hapus preset lokal?'),
        content: Text('“${layout.nama}” akan dihapus dari perangkat. Salinan yang pernah dipublikasikan tidak ikut terhapus.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(d, true),
              child: const Text('Hapus')),
        ],
      ),
    );
    if (ya != true || !mounted) return;
    await HudStore.hapus(layout.id);
    if (_aktifId == layout.id) await NativeStream.terapkanHud(null);
    _snack('Preset lokal dihapus.');
    await _muat(tenang: true);
  }

  Future<_DataTerbit?> _formTerbit(HudLayout layout) async {
    final nama = TextEditingController(text: layout.nama);
    final game = TextEditingController(text: layout.game);
    final deskripsi = TextEditingController(text: layout.deskripsi);
    final form = GlobalKey<FormState>();
    var publik = true;
    final hasil = await showDialog<_DataTerbit>(
      context: context,
      builder: (d) => StatefulBuilder(builder: (context, setDialog) => AlertDialog(
        title: const Text('Simpan ke akun'),
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
                    labelText: 'Game / kategori', hintText: 'Contoh: Valorant'),
              ),
              TextFormField(
                controller: deskripsi,
                maxLength: 160,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Deskripsi'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: publik,
                onChanged: (v) => setDialog(() => publik = v),
                title: const Text('Publikasikan ke komunitas'),
                subtitle: Text(publik
                    ? 'Anggota lain dapat melihat, menyukai, dan mengimpor.'
                    : 'Cadangan privat — hanya terlihat olehmu.'),
              ),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Batal')),
          FilledButton.icon(
            onPressed: () {
              if (!(form.currentState?.validate() ?? false)) return;
              Navigator.pop(d, _DataTerbit(
                nama.text.trim(), game.text.trim(), deskripsi.text.trim(), publik));
            },
            icon: Icon(publik ? Icons.public_rounded : Icons.cloud_outlined),
            label: Text(publik ? 'Publikasikan' : 'Simpan privat'),
          ),
        ],
      )),
    );
    nama.dispose();
    game.dispose();
    deskripsi.dispose();
    return hasil;
  }

  Future<void> _terbitkan(HudLayout layout) async {
    if (layout.tombol.isEmpty || _aksiId != null) return;
    final form = await _formTerbit(layout);
    if (form == null || !mounted) return;
    _aksiMulai(layout.id, 'Memeriksa nama dan struktur preset…', .12);
    try {
      final siap = layout.copyWith(
        nama: form.nama,
        game: form.game,
        deskripsi: form.deskripsi,
      );
      _aksiTahap(form.publik
          ? 'Menerbitkan ke galeri komunitas…'
          : 'Menyimpan cadangan privat ke akun…', .52);
      HudPresetPublik remote;
      HudPresetPublik? sebelumnya;
      for (final item in _milik) {
        if (item.id == layout.sumberId) {
          sebelumnya = item;
          break;
        }
      }
      if (sebelumnya != null) {
        remote = await context.read<AppState>().repo
            .perbaruiHudPublik(sebelumnya.id, siap, publik: form.publik);
      } else {
        remote = await context.read<AppState>().repo
            .terbitkanHud(siap, publik: form.publik);
      }
      _aksiTahap('Menautkan salinan lokal dengan akun…', .84);
      final tertaut = siap.copyWith(sumberId: remote.id);
      await HudStore.simpan(tertaut);
      _aksiTahap('Selesai — preset aman di akunmu.', 1);
      _snack(form.publik
          ? 'Preset “${remote.nama}” berhasil dipublikasikan.'
          : 'Preset “${remote.nama}” tersimpan privat di akun.');
      await _muat(tenang: true);
    } catch (e) {
      _snack('Preset gagal diterbitkan: ${_pesanGalat(e)}', galat: true);
    } finally {
      _aksiSelesai();
    }
  }

  Future<void> _sukai(HudPresetPublik preset) async {
    if (_aksiId != null) return;
    _aksiMulai('suka_${preset.id}', 'Menyimpan pilihan suka…', .45);
    try {
      final r = await context.read<AppState>().repo.sukaiHud(preset.id);
      final disukai = r['disukai'] == true || r['disukai'] == 1;
      final jumlah = (r['suka'] as num?)?.toInt() ?? preset.suka;
      void ubah(List<HudPresetPublik> sumber, void Function(List<HudPresetPublik>) pasang) {
        final i = sumber.indexWhere((e) => e.id == preset.id);
        if (i < 0) return;
        final d = [...sumber];
        d[i] = d[i].copyWith(sayaSuka: disukai, suka: jumlah);
        pasang(d);
      }
      if (mounted) {
        setState(() {
          ubah(_publik, (d) => _publik = d);
          ubah(_milik, (d) => _milik = d);
        });
      }
      _aksiTahap(disukai ? 'Preset disukai.' : 'Suka dibatalkan.', 1);
    } catch (e) {
      _snack(_pesanGalat(e), galat: true);
    } finally {
      _aksiSelesai();
    }
  }

  Future<void> _hapusTerbitan(HudPresetPublik preset) async {
    final ya = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Hapus dari akun?'),
        content: Text('“${preset.nama}” hilang dari galeri/akun, tetapi salinan lokal di perangkat tetap ada.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(d, true),
              child: const Text('Hapus terbitan')),
        ],
      ),
    );
    if (ya != true || !mounted) return;
    _aksiMulai(preset.id, 'Menghapus preset dari akun…', .4);
    try {
      await context.read<AppState>().repo.hapusHudPublik(preset.id);
      _snack('Preset di akun berhasil dihapus.');
      await _muat(tenang: true);
    } catch (e) {
      _snack(_pesanGalat(e), galat: true);
    } finally {
      _aksiSelesai();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = XyTheme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('HUD & Preset Kontrol'),
        actions: [
          IconButton(
              tooltip: 'Preset baru',
              onPressed: () => _bukaEditor(HudLayout.baru()),
              icon: const Icon(Icons.add_box_outlined)),
        ],
      ),
      body: Column(children: [
        if (_memuat || _aksiId != null)
          Material(
            color: t.surface,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
              child: Column(children: [
                Row(children: [
                  Expanded(child: Text(_tahap,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                  Text('${(_progres * 100).round()}% · $_detikProses dtk',
                      style: TextStyle(color: t.muted, fontSize: 11)),
                ]),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: _progres),
              ]),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, icon: Icon(Icons.phone_android_rounded), label: Text('Lokal')),
              ButtonSegment(value: 1, icon: Icon(Icons.public_rounded), label: Text('Komunitas')),
              ButtonSegment(value: 2, icon: Icon(Icons.cloud_outlined), label: Text('Milikku')),
            ],
            selected: {_tab},
            onSelectionChanged: (v) => setState(() => _tab = v.first),
          ),
        ),
        if (_tab == 1)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Text('Urutkan:', style: TextStyle(color: t.muted, fontSize: 12)),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Populer'),
                selected: _urut == 'populer',
                onSelected: (_) {
                  setState(() => _urut = 'populer');
                  unawaited(_muat());
                },
              ),
              const SizedBox(width: 7),
              ChoiceChip(
                label: const Text('Terbaru'),
                selected: _urut == 'baru',
                onSelected: (_) {
                  setState(() => _urut = 'baru');
                  unawaited(_muat());
                },
              ),
            ]),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _muat,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
              children: [
                if (_galat != null) _errorCard(_galat!),
                if (_tab == 0) ..._lokalWidgets(),
                if (_tab == 1) ..._publikWidgets(_publik),
                if (_tab == 2) ..._publikWidgets(_milik, milik: true),
              ],
            ),
          ),
        ),
      ]),
      floatingActionButton: _tab == 0
          ? FloatingActionButton.extended(
              onPressed: () => _bukaEditor(HudLayout.baru()),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Buat HUD'))
          : null,
    );
  }

  Widget _errorCard(String pesan) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: XyCard(
          color: XyTheme.danger.withOpacity(.07),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.cloud_off_outlined, color: XyTheme.danger),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Galeri komunitas belum termuat',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 5),
              Text(pesan, style: const TextStyle(fontSize: 12.5, height: 1.4)),
              TextButton(onPressed: _muat, child: const Text('Coba lagi')),
            ])),
          ]),
        ),
      );

  List<Widget> _lokalWidgets() {
    final t = XyTheme.of(context);
    final widgets = <Widget>[
      Row(children: [
        Expanded(child: Text(
          _aktifId == null
              ? 'Belum ada HUD kustom aktif. Keyboard lengkap tetap tersedia.'
              : 'Preset aktif akan dimuat otomatis ketika layar PC dibuka.',
          style: TextStyle(color: t.muted, fontSize: 12.5, height: 1.4),
        )),
        if (_aktifId != null)
          TextButton(onPressed: _nonaktifkan, child: const Text('Nonaktifkan')),
      ]),
      const SizedBox(height: 10),
    ];
    if (_lokal.isEmpty && !_memuat) {
      widgets.add(_kosong('Belum ada preset lokal', 'Buat HUD pertama lalu atur tombol sesukamu.'));
    }
    for (final layout in _lokal) {
      widgets.add(_kartuLokal(layout));
      widgets.add(const SizedBox(height: 10));
    }
    return widgets;
  }

  Widget _kartuLokal(HudLayout layout) {
    final aktif = _aktifId == layout.id;
    final t = XyTheme.of(context);
    return XyCard(
      border: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: aktif ? XyTheme.primary.withOpacity(.16) : t.primarySoft,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(aktif ? Icons.gamepad_rounded : Icons.sports_esports_outlined,
                color: aktif ? XyTheme.primary : t.inkSoft),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text(layout.nama,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
              if (layout.bawaan) ...[
                const SizedBox(width: 6),
                const Chip(label: Text('TEMPLAT', style: TextStyle(fontSize: 8))),
              ],
            ]),
            Text('${layout.game.isEmpty ? 'Kustom' : layout.game} · ${layout.tombol.length} tombol${aktif ? ' · AKTIF' : ''}',
                style: TextStyle(color: aktif ? XyTheme.primary : t.muted, fontSize: 11.5,
                    fontWeight: aktif ? FontWeight.w700 : FontWeight.w400)),
          ])),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'edit') _bukaEditor(layout);
              if (v == 'publish') _terbitkan(layout);
              if (v == 'delete') _hapusLokal(layout);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit / buat salinan')),
              const PopupMenuItem(value: 'publish', child: Text('Simpan ke akun / publikasikan')),
              if (!layout.bawaan)
                const PopupMenuItem(value: 'delete', child: Text('Hapus lokal')),
            ],
          ),
        ]),
        if (layout.deskripsi.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(layout.deskripsi,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: t.inkSoft, fontSize: 12.5, height: 1.4)),
        ],
        const SizedBox(height: 12),
        Row(children: [
          OutlinedButton.icon(
            onPressed: _aksiId == null ? () => _bukaEditor(layout) : null,
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Edit'),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton.icon(
              onPressed: _aksiId == null ? () => _gunakanLokal(layout) : null,
              icon: Icon(aktif ? Icons.check_rounded : Icons.play_arrow_rounded, size: 18),
              label: Text(aktif ? 'Sedang aktif' : 'Gunakan'),
            ),
          ),
        ]),
      ]),
    );
  }

  List<Widget> _publikWidgets(List<HudPresetPublik> daftar, {bool milik = false}) {
    if (daftar.isEmpty && !_memuat) {
      return [
        _kosong(
          milik ? 'Belum ada preset di akun' : 'Belum ada preset komunitas',
          milik
              ? 'Dari tab Lokal, buka menu preset lalu pilih publikasikan.'
              : 'Jadilah orang pertama yang membagikan layout HUD.',
        ),
      ];
    }
    return [
      for (final p in daftar) ...[
        _kartuPublik(p, milik: milik),
        const SizedBox(height: 10),
      ],
    ];
  }

  Widget _kartuPublik(HudPresetPublik p, {bool milik = false}) {
    final t = XyTheme.of(context);
    return XyCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: t.primarySoft,
            backgroundImage: p.pembuatFoto?.isNotEmpty == true
                ? NetworkImage(p.pembuatFoto!)
                : null,
            child: p.pembuatFoto?.isNotEmpty == true
                ? null
                : const Icon(Icons.person_outline_rounded, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.nama,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            Text(
              p.pembuatUsername?.isNotEmpty == true
                  ? '@${p.pembuatUsername} · ${p.game.isEmpty ? 'Kustom' : p.game}'
                  : '${p.pembuatNama} · ${p.game.isEmpty ? 'Kustom' : p.game}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: t.muted, fontSize: 11.5),
            ),
          ])),
          if (milik || p.saya)
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'delete') _hapusTerbitan(p);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'delete', child: Text('Hapus dari akun')),
              ],
            ),
        ]),
        if (p.deskripsi.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(p.deskripsi,
              style: TextStyle(color: t.inkSoft, fontSize: 12.5, height: 1.4)),
        ],
        const SizedBox(height: 10),
        Wrap(spacing: 12, runSpacing: 5, children: [
          _stat(Icons.grid_view_rounded, '${p.layout.tombol.length} tombol'),
          _stat(Icons.favorite_border_rounded, '${p.suka} suka'),
          _stat(Icons.download_outlined, '${p.dipakai} dipakai'),
          if (!p.publik) _stat(Icons.lock_outline_rounded, 'Privat'),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          IconButton.filledTonal(
            tooltip: p.sayaSuka ? 'Batalkan suka' : 'Sukai preset',
            onPressed: p.publik && _aksiId == null ? () => _sukai(p) : null,
            icon: Icon(p.sayaSuka ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: p.sayaSuka ? XyTheme.danger : null),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton.icon(
              onPressed: _aksiId == null ? () => _gunakanPublik(p) : null,
              icon: const Icon(Icons.download_done_rounded, size: 18),
              label: const Text('Impor & gunakan'),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _stat(IconData ikon, String teks) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(ikon, size: 14, color: XyTheme.muted),
        const SizedBox(width: 4),
        Text(teks, style: const TextStyle(fontSize: 10.5, color: XyTheme.muted)),
      ]);

  Widget _kosong(String judul, String isi) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(children: [
          const XyIlustrasi('gamepad', tinggi: 140),
          const SizedBox(height: 12),
          Text(judul, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 5),
          Text(isi,
              textAlign: TextAlign.center,
              style: const TextStyle(color: XyTheme.muted, fontSize: 12.5)),
        ]),
      );
}

class _DataTerbit {
  const _DataTerbit(this.nama, this.game, this.deskripsi, this.publik);
  final String nama;
  final String game;
  final String deskripsi;
  final bool publik;
}
