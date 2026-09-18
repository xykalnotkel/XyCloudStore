import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/app_state.dart';
import '../widgets/common.dart';
import 'dm_chat_screen.dart';
import 'profil_publik_screen.dart';

/// ============================================================
///  Daftar Mengikuti / Pengikut (Batch D) + pintu masuk DM.
/// ============================================================
class FollowsScreen extends StatefulWidget {
  const FollowsScreen({super.key});

  @override
  State<FollowsScreen> createState() => _FollowsScreenState();
}

class _FollowsScreenState extends State<FollowsScreen> {
  List<IkutanItem> _mengikuti = [];
  List<IkutanItem> _pengikut = [];
  bool _memuat = true;
  String? _galat;
  String _cari = '';
  final _cariCtrl = TextEditingController();

  @override
  void dispose() {
    _cariCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    setState(() {
      _memuat = true;
      _galat = null;
    });
    try {
      final repo = context.read<AppState>().repo;
      final hasil = await Future.wait([
        repo.followsSaya(arah: 'mengikuti'),
        repo.followsSaya(arah: 'pengikut'),
      ]);
      if (!mounted) return;
      setState(() {
        _mengikuti = hasil[0];
        _pengikut = hasil[1];
        _memuat = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _galat = 'Daftar belum bisa dimuat.';
        _memuat = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = XyTheme.of(context);
    final q = _cari.trim().toLowerCase();
    final listIkut = q.isEmpty
        ? _mengikuti
        : _mengikuti.where((x) => x.nama.toLowerCase().contains(q)).toList();
    final listPengikut = q.isEmpty
        ? _pengikut
        : _pengikut.where((x) => x.nama.toLowerCase().contains(q)).toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Pesan & Pertemanan'),
          bottom: TabBar(
            labelColor: XyTheme.primary,
            unselectedLabelColor: t.muted,
            indicatorColor: XyTheme.primary,
            indicatorSize: TabBarIndicatorSize.tab,
            tabs: [
              Tab(text: 'Mengikuti (${_mengikuti.length})'),
              Tab(text: 'Pengikut (${_pengikut.length})'),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                controller: _cariCtrl,
                onChanged: (v) => setState(() => _cari = v),
                decoration: InputDecoration(
                  hintText: 'Cari nama teman untuk kirim pesan…',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _cari.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () {
                            _cariCtrl.clear();
                            setState(() => _cari = '');
                          },
                        ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
            Expanded(
              child: _memuat
                  ? const Center(
                      child: CircularProgressIndicator(color: XyTheme.primary))
                  : _galat != null
                      ? Kosong(
                          icon: Icons.wifi_off_rounded,
                          judul: 'Waduh',
                          sub: _galat,
                          aksi: GradientButton(
                              label: 'Coba Lagi', onPressed: _muat),
                        )
                      : TabBarView(children: [
                          _daftar(
                              listIkut,
                              'Belum mengikuti siapa pun',
                              'Cari teman di Komunitas, buka profilnya, lalu tekan Ikuti.'),
                          _daftar(
                              listPengikut,
                              'Belum ada pengikut',
                              'Rajin berbagi di Feed Komunitas supaya teman-teman mengikuti profilmu.'),
                        ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _daftar(List<IkutanItem> items, String judulKosong, String subKosong) {
    if (items.isEmpty) {
      return Kosong(
        icon: Icons.people_alt_outlined,
        judul: judulKosong,
        sub: subKosong,
        ilustrasi: 'pesan',
      );
    }
    return RefreshIndicator(
      color: XyTheme.primary,
      onRefresh: _muat,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final u = items[i];
          return XyCard(
            onTap: () => Navigator.push(
                context, xyRoute(ProfilPublikScreen(userId: u.id))),
            child: Row(children: [
              _avatar(u),
              const SizedBox(width: 12),
              Expanded(
                child: Text(u.nama,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13.5)),
              ),
              const SizedBox(width: 8),
              Pressable(
                onTap: () => Navigator.push(
                    context,
                    xyRoute(DmChatScreen(
                        userId: u.id, nama: u.nama, foto: u.foto))),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                  decoration: BoxDecoration(
                    color: XyTheme.primarySoft,
                    borderRadius: BorderRadius.circular(XyRadius.tombol),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.chat_bubble_outline_rounded,
                        size: 14, color: XyTheme.primary),
                    SizedBox(width: 5),
                    Text('Pesan',
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: XyTheme.primary)),
                  ]),
                ),
              ),
            ]),
          );
        },
      ),
    );
  }

  Widget _avatar(IkutanItem u) {
    return Container(
      width: 42,
      height: 42,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(shape: BoxShape.circle),
      child: (u.foto ?? '').isNotEmpty
          ? AppImage(u.foto!)
          : Container(
              color: XyTheme.primarySoft,
              alignment: Alignment.center,
              child: Text(
                  u.nama.isNotEmpty ? u.nama.trim()[0].toUpperCase() : '?',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: XyTheme.primary)),
            ),
    );
  }
}
