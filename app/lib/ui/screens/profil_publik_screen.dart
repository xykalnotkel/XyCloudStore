import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';

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

/// ============================================================
///  Profil publik pengguna lain (Batch D): banner tema, bio,
///  statistik, tombol ikuti/kirim pesan.
/// ============================================================
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
    // optimis
    setState(() {
      _profil = p.copyWith(
        sayaIkuti: baru,
        pengikut: p.pengikut + (baru ? 1 : -1),
      );
    });
    try {
      await context.read<AppState>().repo.ikuti(p.id, baru);
    } catch (_) {
      if (mounted) setState(() => _profil = p); // rollback
    }
    if (mounted) setState(() => _sibuk = false);
  }

  /// Laporkan pengguna ke moderasi (Batch E): pilih kategori + rincian.
  Future<void> _laporkan(ProfilPublik p) async {
    const opsi = [
      'Menghina / pelecehan',
      'SARA / ujaran kebencian',
      'Konten pornografi',
      'Spam / penipuan',
      'Lainnya',
    ];
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
            decoration: BoxDecoration(
              color: XyTheme.of(ctx).surface,
              borderRadius: BorderRadius.circular(XyRadius.xxl),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Laporkan pengguna',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                const SizedBox(height: 4),
                Text(
                    'Laporan terhadap ${p.nama} akan ditinjau tim moderasi. Laporan palsu dapat dikenai sanksi.',
                    style: TextStyle(
                        fontSize: 12, height: 1.5, color: XyTheme.of(ctx).muted)),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final o in opsi)
                      ChoiceChip(
                        label: Text(o, style: const TextStyle(fontSize: 11.5)),
                        selected: jenis == o,
                        onSelected: (_) => setSheet(() => jenis = o),
                        selectedColor: XyTheme.primarySoft,
                        labelStyle: TextStyle(
                            color: jenis == o ? XyTheme.primary : XyTheme.of(ctx).inkSoft,
                            fontWeight: FontWeight.w700),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(XyRadius.pill),
                          side: BorderSide(
                              color: jenis == o ? XyTheme.primary : XyTheme.of(ctx).line),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: rincian,
                  maxLines: 3,
                  maxLength: 300,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Jelaskan singkat apa yang terjadi (opsional)',
                  ),
                ),
                const SizedBox(height: 8),
                GradientButton(
                  label: 'Kirim Laporan',
                  icon: Icons.flag_rounded,
                  onPressed: () => Navigator.pop(ctx, true),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (dikirim != true) {
      rincian.dispose();
      return;
    }
    final gabungan =
        rincian.text.trim().isEmpty ? jenis : '$jenis — ${rincian.text.trim()}';
    rincian.dispose();
    try {
      await context.read<AppState>().repo.laporPengguna(p.id, gabungan);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Laporan terkirim. Tim moderasi akan meninjau.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gagal mengirim laporan. Coba lagi.')));
      }
    }
  }

  String _inisial(String nama) {
    final bagian = nama.trim().split(RegExp(r'\s+'));
    if (bagian.isEmpty || bagian.first.isEmpty) return '?';
    if (bagian.length == 1) return bagian.first[0].toUpperCase();
    return (bagian[0][0] + bagian[1][0]).toUpperCase();
  }

  static const _namaBulan = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
  ];

  /// 'YYYY-MM-DD HH:MM:SS' (UTC dari D1) → 'September 2026'.
  String _bulanTahun(String iso) {
    final d = DateTime.tryParse(
        iso.contains('T') ? iso : '${iso.replaceFirst(' ', 'T')}Z');
    if (d == null) return '';
    return '${_namaBulan[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final t = XyTheme.of(context);
    final p = _profil;
    return Scaffold(
      body: _memuat
          ? const Center(child: CircularProgressIndicator(color: XyTheme.primary))
          : _galat != null
              ? Kosong(
                  icon: Icons.person_off_rounded,
                  judul: 'Waduh',
                  sub: _galat,
                  aksi: GradientButton(label: 'Coba Lagi', onPressed: _muat),
                )
              : ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    // ---------- banner + avatar ----------
                    Stack(clipBehavior: Clip.none, children: [
                      SizedBox(
                        height: 190,
                        child: BannerProfil(
                          tema: p!.banner,
                          media: p.bannerMedia,
                          bingkai: p.bingkai,
                          child: const SizedBox.expand(),
                        ),
                      ),
                      Positioned(
                        top: MediaQuery.of(context).padding.top + 6,
                        left: 8,
                        child: IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black.withOpacity(.25),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 20,
                        top: 140,
                        child: AvatarBingkai(
                          bingkai: p.bingkai,
                          size: 96,
                          child: Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(.18),
                                blurRadius: 18,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: (p.foto ?? '').isNotEmpty
                                ? AppImage(p.foto!)
                                : Container(
                                    color: XyTheme.primarySoft,
                                    alignment: Alignment.center,
                                    child: Text(_inisial(p.nama),
                                        style: const TextStyle(
                                            fontSize: 30,
                                            fontWeight: FontWeight.w800,
                                            color: XyTheme.primary)),
                                  ),
                          ),
                        ),
                        ),
                      ),
                    ]),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 56, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                            // Batch L: nama memakai gaya kustom pemiliknya.
                            GayaNama(p.nama,
                                gaya: p.gayaNama,
                                style: const TextStyle(
                                    fontSize: 21, fontWeight: FontWeight.w800)),
                            LencanaTier(p.tier ?? 'basic'),
                            if (p.badge != null) LencanaKhusus(p.badge!),
                          ]),
                          // Audit konsistensi 2026-09-18: urutan identitas
                          // sama dengan profil sendiri — nama, @username,
                          // baru slogan.
                          if ((p.username ?? '').isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text('@${p.username}',
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: XyTheme.primary,
                                    letterSpacing: .2)),
                          ],
                          if ((p.slogan ?? '').isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text('“${p.slogan}”',
                                style: TextStyle(
                                    fontSize: 12.5,
                                    fontStyle: FontStyle.italic,
                                    fontWeight: FontWeight.w600,
                                    color: t.inkSoft)),
                          ],
                          if ((p.bio ?? '').isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(p.bio!,
                                style: TextStyle(
                                    fontSize: 13, height: 1.45, color: t.inkSoft)),
                          ],
                          // Batch L: bio link — chip tautan yang bisa dibuka.
                          if ((p.bioLink ?? '').isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Pressable(
                              onTap: () => launchUrl(Uri.parse(p.bioLink!),
                                  mode: LaunchMode.externalApplication),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 11, vertical: 6),
                                decoration: BoxDecoration(
                                  color: XyTheme.primary.withOpacity(.08),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: XyTheme.primary.withOpacity(.3)),
                                ),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  const Icon(Icons.link_rounded,
                                      size: 14, color: XyTheme.primary),
                                  const SizedBox(width: 5),
                                  ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(maxWidth: 230),
                                    child: Text(
                                      p.bioLink!
                                          .replaceFirst(RegExp(r'^https?://'), '')
                                          .replaceFirst(RegExp(r'/$'), ''),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: XyTheme.primary),
                                    ),
                                  ),
                                ]),
                              ),
                            ),
                          ],
                          if ((p.createdAt ?? '').isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Row(children: [
                              Icon(Icons.calendar_today_rounded,
                                  size: 12, color: t.muted),
                              const SizedBox(width: 5),
                              Text('Bergabung ${_bulanTahun(p.createdAt!)}',
                                  style: TextStyle(
                                      fontSize: 11.5, color: t.muted)),
                            ]),
                          ],
                          const SizedBox(height: 16),
                          // ---------- statistik ----------
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: t.surface,
                              borderRadius: BorderRadius.circular(XyRadius.md),
                              border: Border.all(color: t.line),
                            ),
                            child: Row(children: [
                              _stat('Posting', '${p.posting}'),
                              _pisah(),
                              _stat('Pengikut', '${p.pengikut}'),
                              _pisah(),
                              _stat('Mengikuti', '${p.mengikuti}'),
                            ]),
                          ),
                          const SizedBox(height: 18),
                          // ---------- aksi ----------
                          if (p.saya)
                            GradientButton(
                              label: 'Ubah Profil Saya',
                              icon: Icons.edit_rounded,
                              onPressed: () => Navigator.push(context,
                                  xyRoute(const pengaturan.UbahProfilScreen())),
                            )
                          else
                            Row(children: [
                              Expanded(
                                flex: 3,
                                child: GradientButton(
                                  label: p.sayaIkuti ? 'Mengikuti' : 'Ikuti',
                                  icon: p.sayaIkuti
                                      ? Icons.person_remove_alt_1_rounded
                                      : Icons.person_add_alt_1_rounded,
                                  loading: _sibuk,
                                  gradient: p.sayaIkuti
                                      ? const LinearGradient(colors: [Color(0xFF94A3B8), Color(0xFF64748B)])
                                      : XyTheme.gradPrimary,
                                  glowColor: p.sayaIkuti ? const Color(0xFF64748B) : XyTheme.primary,
                                  onPressed: _toggleIkuti,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 3,
                                child: OutlinedButton.icon(
                                  onPressed: () => Navigator.push(
                                      context,
                                      xyRoute(DmChatScreen(
                                          userId: p.id, nama: p.nama, foto: p.foto))),
                                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                                  label: const Text('Kirim Pesan'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: XyTheme.primary,
                                    side: const BorderSide(color: XyTheme.primary),
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(XyRadius.tombol),
                                    ),
                                  ),
                                ),
                              ),
                            ]),
                          if (!p.saya) ...[
                            const SizedBox(height: 8),
                            Center(
                              child: TextButton.icon(
                                onPressed: () => _laporkan(p),
                                icon: Icon(Icons.flag_outlined, size: 15, color: t.muted),
                                label: Text('Laporkan pengguna',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: t.muted,
                                        fontWeight: FontWeight.w600)),
                              ),
                            ),
                          ],
                          const SizedBox(height: 30),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _stat(String label, String nilai) => Expanded(
        child: Column(children: [
          Text(nilai,
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w800, color: XyTheme.primary)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: XyTheme.of(context).muted)),
        ]),
      );

  Widget _pisah() => Container(width: 1, height: 28, color: XyTheme.of(context).line);
}
