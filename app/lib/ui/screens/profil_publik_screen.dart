import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/app_state.dart';
import '../widgets/banner_profil.dart';
import '../widgets/bingkai_profil.dart';
import '../widgets/gaya_nama.dart';
import '../widgets/common.dart';
import 'dm_chat_screen.dart';
import 'forum_screen.dart' show LencanaTier, LencanaKhusus;
import 'pengaturan_screen.dart' as pengaturan;
import 'profile_layout_editor_screen.dart';

/// Profil Publik — TikTok Style, No Border, Drag & Drop Custom Grid
class ProfilPublikScreen extends StatefulWidget {
  const ProfilPublikScreen({super.key, required this.userId});
  final String userId;

  @override
  State<ProfilPublikScreen> createState() => _ProfilPublikScreenState();
}

class _ProfilPublikScreenState extends State<ProfilPublikScreen> {
  ProfilPublik? _profil;
  String? _galat;
  bool _memuat = true;
  bool _sibuk = false;
  List<String> _layoutOrder = ['avatar', 'nama', 'username', 'badges', 'slogan', 'bio', 'bio_link', 'stats', 'action'];

  @override
  void initState() {
    super.initState();
    _muat();
    _muatLayout();
  }

  Future<void> _muatLayout() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('profile_layout_order');
    if (saved != null && saved.isNotEmpty) {
      setState(() => _layoutOrder = saved.split(','));
    }
  }

  Future<void> _muat() async {
    setState(() {
      _memuat = true;
      _galat = null;
    });
    try {
      final p = await context.read<AppState>().repo.profilPublik(widget.userId);
      if (!mounted) return;
      setState(() {
        _profil = p;
        _memuat = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _galat = 'Profil tidak dapat dimuat.';
        _memuat = false;
      });
    }
  }

  Future<void> _toggleIkuti() async {
    final p = _profil;
    if (p == null || _sibuk) return;
    setState(() => _sibuk = true);
    final baru = !p.sayaIkuti;
    setState(() {
      _profil = p.copyWith(sayaIkuti: baru, pengikut: p.pengikut + (baru ? 1 : -1));
    });
    try {
      await context.read<AppState>().repo.ikuti(p.id, baru);
    } catch (_) {
      if (mounted) setState(() => _profil = p);
    }
    if (mounted) setState(() => _sibuk = false);
  }

  Future<void> _laporkan(ProfilPublik p) async {
    const opsi = ['Menghina / pelecehan', 'SARA / ujaran kebencian', 'Konten pornografi', 'Spam / penipuan', 'Lainnya'];
    String jenis = opsi.first;
    final rincian = TextEditingController();
    final dikirim = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: StatefulBuilder(
          builder: (ctx, setSheet) => Container(
            margin: const EdgeInsets.all(14),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(24)),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Laporkan pengguna', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5, color: Colors.white)),
              const SizedBox(height: 4),
              Text('Laporan terhadap ${p.nama} akan ditinjau tim moderasi.', style: const TextStyle(fontSize: 12, height: 1.5, color: Color(0xFF8A8B8F))),
              const SizedBox(height: 14),
              Wrap(spacing: 8, runSpacing: 8, children: [for (final o in opsi) ChoiceChip(label: Text(o, style: const TextStyle(fontSize: 11.5)), selected: jenis == o, onSelected: (_) => setSheet(() => jenis = o))]),
              const SizedBox(height: 14),
              TextField(controller: rincian, maxLines: 3, maxLength: 300, decoration: const InputDecoration(hintText: 'Jelaskan singkat (opsional)')),
              const SizedBox(height: 8),
              GradientButton(label: 'Kirim Laporan', icon: Icons.flag_rounded, onPressed: () => Navigator.pop(ctx, true)),
            ]),
          ),
        ),
      ),
    );
    if (dikirim != true) {
      rincian.dispose();
      return;
    }
    final gabungan = rincian.text.trim().isEmpty ? jenis : '$jenis — ${rincian.text.trim()}';
    rincian.dispose();
    try {
      await context.read<AppState>().repo.laporPengguna(p.id, gabungan);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Laporan terkirim.')));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal mengirim laporan.')));
    }
  }

  String _inisial(String nama) {
    final bagian = nama.trim().split(RegExp(r'\s+'));
    if (bagian.isEmpty || bagian.first.isEmpty) return '?';
    if (bagian.length == 1) return bagian.first[0].toUpperCase();
    return (bagian[0][0] + bagian[1][0]).toUpperCase();
  }

  static const _namaBulan = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];
  String _bulanTahun(String iso) {
    final d = DateTime.tryParse(iso.contains('T') ? iso : '${iso.replaceFirst(' ', 'T')}Z');
    if (d == null) return '';
    return '${_namaBulan[d.month - 1]} ${d.year}';
  }

  // TikTok style builders dengan custom order
  Widget _buildElement(String id, ProfilPublik p) {
    final t = XyTheme.of(context);
    switch (id) {
      case 'avatar':
        return Center(
          child: AvatarBingkai(
            bingkai: p.bingkai,
            size: 100,
            child: Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(shape: BoxShape.circle),
              child: ClipOval(
                child: (p.foto ?? '').isNotEmpty
                    ? AppImage(p.foto!)
                    : Container(
                        color: const Color(0xFF262626),
                        alignment: Alignment.center,
                        child: Text(_inisial(p.nama), style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white)),
                      ),
              ),
            ),
          ),
        );
      case 'nama':
        return Center(
          child: Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.center,
            children: [
              GayaNama(p.nama, gaya: p.gayaNama, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
              LencanaTier(p.tier ?? 'basic'),
              if (p.badge != null) LencanaKhusus(p.badge!),
            ],
          ),
        );
      case 'username':
        if ((p.username ?? '').isEmpty) return const SizedBox.shrink();
        return Center(child: Text('@${p.username}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: XyTheme.primary)));
      case 'badges':
        return Center(
          child: Wrap(spacing: 6, alignment: WrapAlignment.center, children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: const Color(0xFF262626), borderRadius: BorderRadius.circular(20)), child: Text(p.tier?.toUpperCase() ?? 'BASIC', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white))),
            if (p.badge != null) Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: XyTheme.primary, borderRadius: BorderRadius.circular(20)), child: Text(p.badge!.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white))),
          ]),
        );
      case 'slogan':
        if ((p.slogan ?? '').isEmpty) return const SizedBox.shrink();
        return Center(child: Text('“${p.slogan}”', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, fontWeight: FontWeight.w600, color: t.muted)));
      case 'bio':
        if ((p.bio ?? '').isEmpty) return const SizedBox.shrink();
        return Text(p.bio!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13.5, height: 1.5, fontWeight: FontWeight.w600, color: Color(0xFFE4E4E7)));
      case 'bio_link':
        if ((p.bioLink ?? '').isEmpty) return const SizedBox.shrink();
        return Center(
          child: Pressable(
            onTap: () => launchUrl(Uri.parse(p.bioLink!), mode: LaunchMode.externalApplication),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: const Color(0xFF262626), borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.link_rounded, size: 14, color: Colors.white),
                const SizedBox(width: 6),
                ConstrainedBox(constraints: const BoxConstraints(maxWidth: 220), child: Text(p.bioLink!.replaceFirst(RegExp(r'^https?://'), '').replaceFirst(RegExp(r'/$'), ''), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white))),
              ]),
            ),
          ),
        );
      case 'stats':
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            _stat('Posting', '${p.posting}'),
            _divider(),
            _stat('Pengikut', _formatNumber(p.pengikut)),
            _divider(),
            _stat('Mengikuti', _formatNumber(p.mengikuti)),
          ]),
        );
      case 'action':
        if (p.saya) {
          return GradientButton(label: 'Ubah Profil Saya', icon: Icons.edit_rounded, onPressed: () => Navigator.push(context, xyRoute(const pengaturan.UbahProfilScreen())));
        } else {
          return Row(children: [
            Expanded(flex: 3, child: GradientButton(label: p.sayaIkuti ? 'Mengikuti' : 'Ikuti', icon: p.sayaIkuti ? Icons.person_remove_alt_1_rounded : Icons.person_add_alt_1_rounded, loading: _sibuk, onPressed: _toggleIkuti)),
            const SizedBox(width: 10),
            Expanded(flex: 3, child: Pressable(onTap: () => Navigator.push(context, xyRoute(DmChatScreen(userId: p.id, nama: p.nama, foto: p.foto))), child: Container(height: 48, decoration: BoxDecoration(color: const Color(0xFF262626), borderRadius: BorderRadius.circular(99)), child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.chat_bubble_rounded, size: 18, color: Colors.white), SizedBox(width: 6), Text('Pesan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700))])))),
          ]);
        }
      default:
        return const SizedBox.shrink();
    }
  }

  String _formatNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    final t = XyTheme.of(context);
    final p = _profil;
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: _memuat
          ? const Padding(padding: EdgeInsets.only(top: 80), child: SkeletonList(count: 4))
          : _galat != null
              ? Kosong(icon: Icons.person_off_rounded, judul: 'Waduh', sub: _galat, aksi: GradientButton(label: 'Coba Lagi', onPressed: _muat))
              : CustomScrollView(
                  slivers: [
                    SliverAppBar(
                      expandedHeight: 200,
                      pinned: true,
                      backgroundColor: const Color(0xFF0A0A0A),
                      flexibleSpace: FlexibleSpaceBar(
                        background: BannerProfil(tema: p!.banner, media: p.bannerMedia, bingkai: p.bingkai, child: const SizedBox.expand()),
                      ),
                      leading: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Pressable(
                          onTap: () => Navigator.pop(context),
                          child: Container(width: 36, height: 36, decoration: BoxDecoration(color: Colors.black.withOpacity(.35), shape: BoxShape.circle), child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20)),
                        ),
                      ),
                      actions: [
                        if (p.saya)
                          Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: Pressable(
                              onTap: () => Navigator.push(context, xyRoute(const ProfileLayoutEditorScreen())),
                              child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: Colors.black.withOpacity(.35), borderRadius: BorderRadius.circular(20)), child: const Row(children: [Icon(Icons.dashboard_customize_rounded, size: 16, color: Colors.white), SizedBox(width: 6), Text('Atur Layout', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))])),
                            ),
                          ),
                      ],
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // TikTok style: avatar di tengah, stats di bawah, tanpa border
                            ..._layoutOrder.map((id) => Padding(padding: const EdgeInsets.only(bottom: 12), child: _buildElement(id, p))),
                            if ((p.createdAt ?? '').isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Center(
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  const Icon(Icons.calendar_today_rounded, size: 12, color: Color(0xFF8A8B8F)),
                                  const SizedBox(width: 5),
                                  Text('Bergabung ${_bulanTahun(p.createdAt!)}', style: const TextStyle(fontSize: 11.5, color: Color(0xFF8A8B8F))),
                                ]),
                              ),
                            ],
                            const SizedBox(height: 20),
                            if (!p.saya) ...[
                              Center(
                                child: Pressable(
                                  onTap: () => _laporkan(p),
                                  child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(20)), child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.flag_outlined, size: 14, color: Color(0xFF8A8B8F)), SizedBox(width: 6), Text('Laporkan pengguna', style: TextStyle(fontSize: 12, color: Color(0xFF8A8B8F), fontWeight: FontWeight.w600))])),
                                ),
                              ),
                            ],
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _stat(String label, String nilai) => Expanded(
        child: Column(children: [
          Text(nilai, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF8A8B8F))),
        ]),
      );

  Widget _divider() => Container(width: 1, height: 28, color: const Color(0xFF2A2A2A));
}
