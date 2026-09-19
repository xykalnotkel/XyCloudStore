import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/prefs.dart';
import '../../providers/app_state.dart';
import '../widgets/common.dart';
import '../widgets/banner_profil.dart';
import '../widgets/bingkai_profil.dart';
import '../widgets/gaya_nama.dart';
import 'forum_screen.dart' show LencanaTier, LencanaKhusus;

/// Editor Layout Profil — Drag & Drop Grid ala TikTok
/// User bisa sesuaikan posisi nama, bio, badge, label, dll sesuka hati
class ProfileLayoutEditorScreen extends StatefulWidget {
  const ProfileLayoutEditorScreen({super.key});

  @override
  State<ProfileLayoutEditorScreen> createState() => _ProfileLayoutEditorScreenState();
}

class _ProfileLayoutEditorScreenState extends State<ProfileLayoutEditorScreen> {
  // Daftar elemen profil yang bisa di-drag
  List<ProfileElement> _elements = [];
  bool _memuat = true;

  @override
  void initState() {
    super.initState();
    _muatLayout();
  }

  Future<void> _muatLayout() async {
    final saved = await Prefs.getString('profile_layout_order');
    List<String> order;
    if (saved != null && saved.isNotEmpty) {
      order = saved.split(',');
    } else {
      order = ['avatar', 'nama', 'username', 'badges', 'slogan', 'bio', 'bio_link', 'stats', 'action'];
    }

    final all = {
      'avatar': ProfileElement(id: 'avatar', label: 'Avatar', icon: Icons.account_circle_rounded, builder: _buildAvatar),
      'nama': ProfileElement(id: 'nama', label: 'Nama', icon: Icons.badge_rounded, builder: _buildNama),
      'username': ProfileElement(id: 'username', label: '@Username', icon: Icons.alternate_email_rounded, builder: _buildUsername),
      'badges': ProfileElement(id: 'badges', label: 'Badge & Lencana', icon: Icons.workspace_premium_rounded, builder: _buildBadges),
      'slogan': ProfileElement(id: 'slogan', label: 'Slogan', icon: Icons.format_quote_rounded, builder: _buildSlogan),
      'bio': ProfileElement(id: 'bio', label: 'Bio', icon: Icons.notes_rounded, builder: _buildBio),
      'bio_link': ProfileElement(id: 'bio_link', label: 'Link Bio', icon: Icons.link_rounded, builder: _buildBioLink),
      'stats': ProfileElement(id: 'stats', label: 'Statistik', icon: Icons.bar_chart_rounded, builder: _buildStats),
      'action': ProfileElement(id: 'action', label: 'Tombol Aksi', icon: Icons.touch_app_rounded, builder: _buildAction),
    };

    setState(() {
      _elements = order.where((id) => all.containsKey(id)).map((id) => all[id]!).toList();
      // Tambah yang belum ada
      for (final e in all.values) {
        if (!_elements.any((x) => x.id == e.id)) _elements.add(e);
      }
      _memuat = false;
    });
  }

  Future<void> _simpanLayout() async {
    final order = _elements.map((e) => e.id).join(',');
    await Prefs.setString('profile_layout_order', order);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Layout profil disimpan!')));
    }
  }

  // Builders untuk preview — pakai data user asli
  Widget _buildAvatar(BuildContext context) {
    final u = context.watch<AppState>().user;
    if (u == null) return const SizedBox.shrink();
    return Center(
      child: AvatarBingkai(
        bingkai: u.bingkai,
        size: 96,
        child: (u.foto ?? '').isNotEmpty
            ? ClipOval(child: Image.network(u.foto!, width: 96, height: 96, fit: BoxFit.cover))
            : Container(
                width: 96,
                height: 96,
                color: XyTheme.primary,
                child: Center(child: Text(u.nama.isEmpty ? 'X' : u.nama[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800))),
              ),
      ),
    );
  }

  Widget _buildNama(BuildContext context) {
    final u = context.watch<AppState>().user;
    if (u == null) return const SizedBox.shrink();
    return GayaNama(u.nama, gaya: u.gayaNama, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900));
  }

  Widget _buildUsername(BuildContext context) {
    final u = context.watch<AppState>().user;
    if (u == null) return const SizedBox.shrink();
    return Text('@${u.username ?? 'username'}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: XyTheme.primary));
  }

  Widget _buildBadges(BuildContext context) {
    final u = context.watch<AppState>().user;
    if (u == null) return const SizedBox.shrink();
    return Wrap(spacing: 6, children: [
      LencanaTier(u.tier),
      if (u.badge != null) LencanaKhusus(u.badge!),
    ]);
  }

  Widget _buildSlogan(BuildContext context) {
    final u = context.watch<AppState>().user;
    if (u == null || (u.slogan ?? '').isEmpty) return const SizedBox.shrink();
    return Text('“${u.slogan}”', style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: XyTheme.of(context).muted));
  }

  Widget _buildBio(BuildContext context) {
    final u = context.watch<AppState>().user;
    if (u == null || (u.bio ?? '').isEmpty) return Text('Bio kosong — tulis di Edit Profil', style: TextStyle(color: XyTheme.of(context).muted, fontSize: 13));
    return Text(u.bio!, style: const TextStyle(fontSize: 13.5, height: 1.5, fontWeight: FontWeight.w600));
  }

  Widget _buildBioLink(BuildContext context) {
    final u = context.watch<AppState>().user;
    if (u == null || (u.bioLink ?? '').isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: XyTheme.primary.withOpacity(.12), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.link_rounded, size: 14, color: XyTheme.primary),
        const SizedBox(width: 6),
        Text(u.bioLink!.replaceFirst(RegExp(r'^https?://'), ''), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: XyTheme.primary)),
      ]),
    );
  }

  Widget _buildStats(BuildContext context) {
    final t = XyTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(color: t.surface, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        _statItem(context, '12', 'Posting'),
        _divider(context),
        _statItem(context, '1.2K', 'Pengikut'),
        _divider(context),
        _statItem(context, '89', 'Mengikuti'),
      ]),
    );
  }

  Widget _statItem(BuildContext context, String value, String label) {
    return Expanded(
      child: Column(children: [
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: XyTheme.of(context).muted)),
      ]),
    );
  }

  Widget _divider(BuildContext context) => Container(width: 1, height: 28, color: XyTheme.of(context).lineSoft);

  Widget _buildAction(BuildContext context) {
    return Row(children: [
      Expanded(child: GradientButton(label: 'Edit Profil', icon: Icons.edit_rounded, onPressed: () {})),
      const SizedBox(width: 10),
      Expanded(child: OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.share_rounded, size: 16), label: const Text('Bagikan'))),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final t = XyTheme.of(context);
    if (_memuat) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0A0A),
        appBar: AppBar(title: const Text('Atur Layout Profil')),
        body: const Center(child: SkeletonList(count: 6)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        title: const Text('Atur Layout Profil', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          TextButton(onPressed: _simpanLayout, child: const Text('Simpan', style: TextStyle(fontWeight: FontWeight.w800))),
        ],
      ),
      body: Column(
        children: [
          // Preview TikTok style
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Pratinjau Profil Publik (TikTok Style)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF8A8B8F))),
                const SizedBox(height: 14),
                ..._elements.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: e.builder(context),
                    )),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFF1E1E1E)),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
            child: Row(children: [
              const Icon(Icons.drag_indicator_rounded, size: 18, color: Color(0xFF8A8B8F)),
              const SizedBox(width: 8),
              const Text('Drag & Drop untuk atur posisi', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF8A8B8F))),
              const Spacer(),
              TextButton.icon(
                onPressed: () async {
                  await Prefs.remove('profile_layout_order');
                  _muatLayout();
                },
                icon: const Icon(Icons.restart_alt_rounded, size: 16),
                label: const Text('Reset', style: TextStyle(fontSize: 12)),
              ),
            ]),
          ),
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              itemCount: _elements.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex--;
                  final item = _elements.removeAt(oldIndex);
                  _elements.insert(newIndex, item);
                });
              },
              itemBuilder: (ctx, i) {
                final e = _elements[i];
                return Container(
                  key: ValueKey(e.id),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(14)),
                  child: ListTile(
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(color: XyTheme.primary.withOpacity(.15), borderRadius: BorderRadius.circular(10)),
                      child: Icon(e.icon, size: 18, color: XyTheme.primary),
                    ),
                    title: Text(e.label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    subtitle: Text('Drag untuk pindah posisi', style: TextStyle(fontSize: 11, color: t.muted)),
                    trailing: const Icon(Icons.drag_handle_rounded, color: Color(0xFF8A8B8F)),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _simpanLayout,
        backgroundColor: XyTheme.primary,
        icon: const Icon(Icons.check_rounded, color: Colors.white),
        label: const Text('Simpan Layout', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
      ),
    );
  }
}

class ProfileElement {
  final String id;
  final String label;
  final IconData icon;
  final Widget Function(BuildContext) builder;
  ProfileElement({required this.id, required this.label, required this.icon, required this.builder});
}
