import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/pengaturan.dart';
import '../../data/stiker_store.dart';
import '../widgets/waktu_relatif.dart';
import '../widgets/bingkai_profil.dart';
import '../widgets/gaya_nama.dart';
import '../../models/stiker.dart';
import '../../core/komentar_thread.dart';
import '../widgets/stiker_picker.dart';
import 'package:flutter/material.dart';
import '../widgets/galeri_picker.dart';
import 'package:provider/provider.dart';
import '../../core/format.dart';
import '../../core/kompres.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../core/waktu.dart';
import '../../models/models.dart';
import '../../providers/app_state.dart';
import '../widgets/common.dart';
import 'profil_publik_screen.dart';
import 'follows_screen.dart';
import '../widgets/error_state.dart';
import '../widgets/lembar.dart';
import 'story_editor_screen.dart';
import 'package:video_player/video_player.dart';

/// ============================================================
///  Forum komunitas XyCloudStore
/// ============================================================
class ForumScreen extends StatefulWidget {
  const ForumScreen({super.key});

  @override
  State<ForumScreen> createState() => _ForumScreenState();
}

class _ForumScreenState extends State<ForumScreen> {
  static const kategori = [
    'Semua',
    'Umum',
    'Tanya Jawab',
    'Tips',
    'Jual Beli',
    'Keluhan'
  ];
  String pilih = 'Semua';
  String cari = '';
  bool hanyaSimpan = false;
  // Batch J: urutan diskusi (terbaru / terpopuler / teramai).
  String urut = 'Terbaru';
  final _cari = TextEditingController();

  @override
  void dispose() {
    _cari.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().muatForum();
      context.read<AppState>().muatStories();
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final kunci = cari.trim().toLowerCase();
    final daftar = s.forum.where((f) {
      final cocokKategori = pilih == 'Semua' || f.kategori == pilih;
      final cocokCari = kunci.isEmpty ||
          f.judul.toLowerCase().contains(kunci) ||
          f.isi.toLowerCase().contains(kunci) ||
          f.nama.toLowerCase().contains(kunci);
      final cocokSimpan = !hanyaSimpan || s.forumDisimpan.contains(f.id);
      return cocokKategori && cocokCari && cocokSimpan;
    }).toList();

    // Diskusi tersemat selalu di atas; sisanya mengikuti pilihan urutan.
    daftar.sort((x, y) {
      if (x.disematkan != y.disematkan) return x.disematkan ? -1 : 1;
      switch (urut) {
        case 'Terpopuler':
          return y.suka.compareTo(x.suka);
        case 'Teramai':
          return y.balasan.compareTo(x.balasan);
        default:
          return y.dibuat.compareTo(x.dibuat);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Feed & Story'),
        actions: [
          IconButton(
            tooltip: 'Pesan & Pertemanan',
            onPressed: () => Navigator.push(context, xyRoute(const FollowsScreen())),
            icon: const Icon(Icons.people_alt_outlined),
          ),
          IconButton(
            tooltip: hanyaSimpan ? 'Tampilkan semua postingan' : 'Hanya yang disimpan',
            onPressed: () => setState(() => hanyaSimpan = !hanyaSimpan),
            icon: Icon(
                hanyaSimpan
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                color: hanyaSimpan ? XyTheme.primary : null),
          ),
          IconButton(
            tooltip: 'Urutkan postingan: $urut',
            icon: const Icon(Icons.swap_vert_rounded),
            onPressed: () {
              final pal = XyTheme.of(context);
              showModalBottomSheet<void>(
                context: context,
                backgroundColor: Colors.transparent,
                builder: (ctx) => Container(
                  decoration: BoxDecoration(
                    color: pal.surfaceHigh,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                    border: Border.all(color: pal.line),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 10),
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: pal.line,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Urutkan Postingan',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.close_rounded, size: 20),
                                onPressed: () => Navigator.pop(ctx),
                              ),
                            ],
                          ),
                        ),
                        Divider(height: 1, color: pal.line),
                        ...[
                          ('Terbaru', 'Diskusi paling baru diunggah', Icons.access_time_rounded),
                          ('Terpopuler', 'Paling banyak disukai anggota', Icons.favorite_rounded),
                          ('Teramai', 'Paling banyak mendapat balasan', Icons.forum_rounded),
                        ].map((item) {
                          final sel = item.$1 == urut;
                          return ListTile(
                            leading: Icon(item.$3, color: sel ? XyTheme.primary : pal.inkSoft),
                            title: Text(item.$1,
                                style: TextStyle(
                                    fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                                    color: sel ? XyTheme.primary : pal.ink)),
                            subtitle: Text(item.$2),
                            trailing: sel
                                ? const Icon(Icons.check_rounded, color: XyTheme.primary)
                                : null,
                            onTap: () {
                              Navigator.pop(ctx);
                              setState(() => urut = item.$1);
                            },
                          );
                        }),
                        const SizedBox(height: 14),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: () => s.muatForum(paksa: true),
            icon: const Icon(Icons.refresh_rounded),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
            child: Pressable(
              onTap: () => bukaTulisDiskusi(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  gradient: XyTheme.gradPrimary,
                  borderRadius: BorderRadius.circular(XyRadius.pill),
                  boxShadow: XyTheme.glow(XyTheme.primary, .25),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.edit_rounded, size: 15, color: Colors.white),
                  SizedBox(width: 6),
                  Text('Tulis',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13)),
                ]),
              ),
            ),
          ),
        ],
      ),
      body: Column(children: [
        BilahOffline(tampil: s.offline, onCoba: () => s.muatForum(paksa: true)),

        // ---- Stories Bar (24 Jam) ----
        _StoriesBar(
          stories: s.stories,
          onBuatStory: () {
            Navigator.push(
              context,
              xyRoute(StoryEditorScreen(
                onStoryDibuat: (st) => s.stories.insert(0, st),
              )),
            );
          },
          onLihatStory: (st) {
            Navigator.push(
              context,
              xyRoute(StoryFullScreenViewer(
                stories: s.stories,
                awalIndex: s.stories.indexOf(st),
                onHapus: (id) => s.hapusStory(id),
              )),
            );
          },
        ),

        const Divider(height: 1, thickness: 0.5),

        // ---- kolom pencarian ----
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 4),
          child: TextField(
            controller: _cari,
            onChanged: (v) => setState(() => cari = v),
            decoration: InputDecoration(
              hintText: 'Cari diskusi, isi, atau nama penulis',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: cari.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () {
                        _cari.clear();
                        setState(() => cari = '');
                      },
                    ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            ),
          ),
        ),

        // ---- pilihan kategori ----
        SizedBox(
          height: 46,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            itemCount: kategori.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final k = kategori[i];
              final on = k == pilih;
              return Pressable(
                onTap: () => setState(() => pilih = k),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                  decoration: BoxDecoration(
                    color: on ? XyTheme.primary : XyTheme.of(context).surface,
                    borderRadius: BorderRadius.circular(XyRadius.pill),
                    border: Border.all(
                        color: on ? XyTheme.primary : XyTheme.of(context).line),
                  ),
                  child: Text(k,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: on ? Colors.white : XyTheme.of(context).inkSoft,
                      )),
                ),
              );
            },
          ),
        ),

        Expanded(
          child: s.forumGalat != null && s.forum.isEmpty
              ? GagalMuat(
                  pesan: s.forumGalat!,
                  ilustrasi: s.offline ? 'offline' : 'error',
                  onCoba: () => s.muatForum(paksa: true),
                )
              : s.forumMemuat && s.forum.isEmpty
                  ? const SkeletonForumList(count: 4)
                  : daftar.isEmpty
                      ? Kosong(
                          icon: Icons.forum_outlined,
                          judul: kunci.isEmpty
                              ? 'Belum ada diskusi di sini'
                              : 'Tidak ada yang cocok',
                          sub: kunci.isEmpty
                              ? 'Jadi yang pertama bertanya atau berbagi tips.'
                              : 'Coba kata kunci lain atau ganti kategorinya.',
                          ilustrasi: kunci.isEmpty ? 'forum' : 'kosong',
                        )
                      : RefreshIndicator(
                          color: XyTheme.primary,
                          onRefresh: () => s.muatForum(paksa: true),
                          child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                            padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
                            cacheExtent: 1000,
                            addAutomaticKeepAlives: false,
                            addRepaintBoundaries: true,
                            itemCount: daftar.length + 1,
                            itemBuilder: (_, i) => i == 0
                                ? RepaintBoundary(child: _AjakanTulis(nama: s.user?.nama ?? ''))
                                : RepaintBoundary(child: _KartuPost(post: daftar[i - 1])),
                          ),
                        ),
        ),
      ]),
    );
  }
}

/// Kotak ajakan menulis, sekaligus pengganti tombol melayang
/// yang dulu tertutup menu bawah.
class _AjakanTulis extends StatelessWidget {
  const _AjakanTulis({required this.nama});
  final String nama;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: XyCard(
        onTap: () => bukaTulisDiskusi(context),
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
                gradient: XyTheme.gradPrimary, shape: BoxShape.circle),
            child: Center(
              child: Text(nama.isEmpty ? 'X' : nama[0].toUpperCase(),
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text('Ada yang ingin dibagikan? Posting apa saja ke Feed…',
                style: TextStyle(
                    color: XyTheme.of(context).muted, fontSize: 13.2)),
          ),
          Icon(Icons.edit_rounded, size: 18, color: XyTheme.primary),
        ]),
      ),
    );
  }
}

/// Teks isi forum dengan @mention bergaya beda (tebal + warna tema) supaya
/// sebutan terlihat jelas dari teks biasa.
Widget teksForum(String isi, TextStyle gaya, {int? maxLines}) {
  final spans = <InlineSpan>[];
  final re = RegExp(r'@[A-Za-z0-9_.]{2,30}');
  var last = 0;
  for (final m in re.allMatches(isi)) {
    if (m.start > last) spans.add(TextSpan(text: isi.substring(last, m.start)));
    spans.add(TextSpan(
        text: m.group(0),
        style: gaya.copyWith(
            color: XyTheme.primary, fontWeight: FontWeight.w800)));
    last = m.end;
  }
  if (last < isi.length) spans.add(TextSpan(text: isi.substring(last)));
  if (spans.isEmpty) spans.add(const TextSpan(text: ''));
  return Text.rich(TextSpan(style: gaya, children: spans),
      maxLines: maxLines, overflow: TextOverflow.ellipsis);
}

/// Lencana keanggotaan yang tampil di samping nama penulis.
/// Lencana tier dengan animasi kilau (shimmer) untuk PRO/VIP/ADMIN
/// (Batch M: "tier animasi"). BASIC tetap statis — lencana ini muncul
/// berulang di daftar forum, jadi animasi hanya untuk tier premium agar
/// tetap hemat GPU di ponsel kelas menengah.
class LencanaTier extends StatefulWidget {
  const LencanaTier(this.tier, {super.key});
  final String tier;

  @override
  State<LencanaTier> createState() => _LencanaTierState();
}

class _LencanaTierState extends State<LencanaTier>
    with SingleTickerProviderStateMixin {
  late final AnimationController _kilau = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  bool get _premium =>
      const {'pro', 'vip', 'admin'}.contains(widget.tier.toLowerCase());

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Widget test memakai TickerMode nonaktif → animasi tidak jalan dan
    // pumpAndSettle tetap settle. Di device asli animasi menyala.
    if (_premium && TickerMode.of(context)) {
      if (!_kilau.isAnimating) _kilau.repeat();
    } else if (_kilau.isAnimating) {
      _kilau.stop();
    }
  }

  @override
  void dispose() {
    _kilau.stop();
    _kilau.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tier.toLowerCase();
    if (t.isEmpty) return const SizedBox.shrink();

    final (warna, label, ikon) = switch (t) {
      'admin' => (XyTheme.primary, 'ADMIN', Icons.verified_rounded),
      'vip' => (
          XyTheme.vipAmber,
          'VIP',
          Icons.workspace_premium_rounded
        ),
      'pro' => (XyTheme.violet, 'PRO', Icons.bolt_rounded),
      _ => (XyTheme.of(context).muted, 'BASIC', Icons.person_rounded),
    };

    final inti = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: warna.withOpacity(.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: warna.withOpacity(.28)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(ikon, size: 9.5, color: warna),
        const SizedBox(width: 3),
        Text(label,
            style: TextStyle(
                color: warna,
                fontSize: 8.5,
                fontWeight: FontWeight.w700,
                letterSpacing: .5)),
      ]),
    );

    if (!_premium) {
      return Padding(padding: const EdgeInsets.only(left: 6), child: inti);
    }

    // Gelombang cahaya diagonal menyapu lencana (55% dari durasi), lalu jeda.
    final sapu = CurvedAnimation(
        parent: _kilau, curve: const Interval(0, .55, curve: Curves.easeInOut));
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(clipBehavior: Clip.hardEdge, children: [
          inti,
          AnimatedBuilder(
            animation: sapu,
            builder: (context, _) {
              final x = -1.6 + sapu.value * 3.2;
              return Positioned.fill(
                child: Opacity(
                  opacity: .35,
                  child: FractionalTranslation(
                    translation: Offset(x, -0.25),
                    child: Container(
                      width: 46,
                      color: Colors.white,
                      transform: Matrix4.rotationZ(-0.5),
                    ),
                  ),
                ),
              );
            },
          ),
        ]),
      ),
    );
  }
}
/// Lencana khusus pemberian admin, contohnya XyVerse atau Staff.
class LencanaKhusus extends StatelessWidget {
  const LencanaKhusus(this.teks, {super.key});
  final String teks;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(left: 5),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
        decoration: BoxDecoration(
          gradient: XyTheme.gradPrimary,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.verified_rounded, size: 9.5, color: Colors.white),
          const SizedBox(width: 3),
          Text(teks.toUpperCase(),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .5)),
        ]),
      );
}

/// Tombol Ikuti / Mengikuti di samping nama penulis feed & komentar
class _TombolIkuti extends StatelessWidget {
  const _TombolIkuti({required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    if (s.user == null || userId.isEmpty || userId == s.user!.id) {
      return const SizedBox.shrink();
    }
    final diikuti = s.penggunaDiikuti.contains(userId);
    final pal = XyTheme.of(context);

    return Pressable(
      onTap: () => s.toggleIkuti(userId),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
        decoration: BoxDecoration(
          color: diikuti ? Colors.transparent : XyTheme.primary.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: diikuti ? pal.line : XyTheme.primary,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              diikuti ? Icons.check_rounded : Icons.person_add_alt_1_rounded,
              size: 11,
              color: diikuti ? pal.muted : XyTheme.primary,
            ),
            const SizedBox(width: 3),
            Text(
              diikuti ? 'Mengikuti' : 'Ikuti',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: diikuti ? pal.muted : XyTheme.primary,
                letterSpacing: .1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KartuPost extends StatelessWidget {
  const _KartuPost({required this.post});
  final ForumPost post;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final disukai = s.forumDisukai.contains(post.id);
    final disimpan = s.forumDisimpan.contains(post.id);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: XyCard(
        onTap: () =>
            Navigator.push(context, xyRoute(ForumDetailScreen(post: post))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            GestureDetector(
              onTap: post.userId.isEmpty
                  ? null
                  : () => Navigator.push(context,
                      xyRoute(ProfilPublikScreen(userId: post.userId))),
              // Batch M: bingkai penulis ikut tampil di daftar diskusi
              // (sebelumnya hanya di detail & komentar — "bingkai belum
              // terlihat di komunitas").
              child: AvatarBingkai(
                  bingkai: post.bingkai,
                  size: 38,
                  child: _Avatar(nama: post.nama, foto: post.foto)),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(
                        child: GestureDetector(
                          onTap: post.userId.isEmpty
                              ? null
                              : () => Navigator.push(context,
                                  xyRoute(ProfilPublikScreen(userId: post.userId))),
                          child: GayaNama(post.nama,
                              gaya: post.gayaNama,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 13.5)),
                        ),
                      ),
                      LencanaTier(post.tier),
                      if (post.badge != null) LencanaKhusus(post.badge!),
                      if (post.disematkan) ...[
                        const SizedBox(width: 5),
                        const Icon(Icons.push_pin_rounded,
                            size: 13, color: XyTheme.primary),
                      ],
                      if (post.userId.isNotEmpty && (s.user == null || post.userId != s.user!.id)) ...[
                        const SizedBox(width: 8),
                        _TombolIkuti(userId: post.userId),
                      ],
                    ]),
                    const SizedBox(height: 3),
                    Row(children: [
                      Text(tanggal(post.dibuat),
                          style: TextStyle(
                              color: XyTheme.of(context).muted, fontSize: 11)),
                      const SizedBox(width: 6),
                      Text('•',
                          style: TextStyle(
                              color: XyTheme.of(context).muted, fontSize: 10)),
                      const SizedBox(width: 6),
                      Text(post.kategori,
                          style: TextStyle(
                              color: XyTheme.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 11)),
                    ]),
                  ]),
            ),
          ]),
          const SizedBox(height: 12),
          Text(post.judul,
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  height: 1.32,
                  letterSpacing: -.2)),
          const SizedBox(height: 6),
          teksForum(
            post.isi,
            TextStyle(
                color: XyTheme.of(context).muted, fontSize: 13, height: 1.55),
            maxLines: 3,
          ),
          if (post.gambar != null && !s.hematData) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(XyRadius.md),
              child: Image.network(post.gambar!,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  cacheWidth: 900),
            ),
          ],
          const SizedBox(height: 12),
          Row(children: [
            Pressable(
              onTap: () => s.sukaForum(post.id),
              child: Row(children: [
                Icon(
                    disukai
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    size: 17,
                    color:
                        disukai ? XyTheme.danger : XyTheme.of(context).muted),
                const SizedBox(width: 5),
                Text('${post.suka}',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: disukai
                            ? XyTheme.danger
                            : XyTheme.of(context).muted)),
              ]),
            ),
            const SizedBox(width: 18),
            Icon(Icons.mode_comment_outlined,
                size: 16, color: XyTheme.of(context).muted),
            const SizedBox(width: 5),
            Text('${post.balasan} balasan',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: XyTheme.of(context).muted)),
            const SizedBox(width: 18),
            Pressable(
              onTap: () => s.simpanForum(post.id),
              child: Row(children: [
                Icon(
                    disimpan
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    size: 17,
                    color: disimpan
                        ? XyTheme.primary
                        : XyTheme.of(context).muted),
                const SizedBox(width: 5),
                Text(disimpan ? 'Disimpan' : 'Simpan',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: disimpan
                            ? XyTheme.primary
                            : XyTheme.of(context).muted)),
              ]),
            ),
            const Spacer(),
            const Text('Lihat',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: XyTheme.primary)),
            const Icon(Icons.chevron_right_rounded,
                size: 17, color: XyTheme.primary),
          ]),
        ]),
      ),
    );
  }
}

/// ---------------- detail diskusi ----------------
class ForumDetailScreen extends StatefulWidget {
  const ForumDetailScreen({super.key, required this.post});
  final ForumPost post;
  @override
  State<ForumDetailScreen> createState() => _ForumDetailScreenState();
}

class _ForumDetailScreenState extends State<ForumDetailScreen> {
  final _balas = TextEditingController();
  final _fokusBalas = FocusNode();
  ForumBalasan? _reply;
  PilihanStiker? _stiker;
  List<ForumBalasan> _balasan = [];
  bool _memuat = true, _mengirim = false;
  int _revisi = -1, _req = 0;
  String? _galat;

  // Batch L: autocomplete @mention di composer.
  List<Map<String, dynamic>> _saranMention = [];
  Timer? _mentionTimer;
  int _reqMention = 0;

  /// Kata @ yang sedang diketik pada posisi kursor; null bila tidak ada.
  String? _kataMentionAktif() {
    final sel = _balas.selection;
    if (!sel.isValid || !sel.isCollapsed) return null;
    final teks = _balas.text.substring(0, sel.baseOffset);
    final m = RegExp(r'@([a-z0-9_.]{1,20})$', caseSensitive: false)
        .firstMatch(teks);
    return m?.group(1)?.toLowerCase();
  }

  void _cekMention() {
    final kata = _kataMentionAktif();
    _mentionTimer?.cancel();
    if (kata == null || kata.isEmpty) {
      if (_saranMention.isNotEmpty) setState(() => _saranMention = []);
      return;
    }
    _mentionTimer = Timer(const Duration(milliseconds: 300), () async {
      final no = ++_reqMention;
      try {
        final hasil = await context.read<AppState>().cariMention(kata);
        if (mounted && no == _reqMention) {
          setState(() => _saranMention = hasil);
        }
      } catch (_) {/* saran mention gagal — biarkan senyap */}
    });
  }

  void _pakaiMention(String username) {
    final sel = _balas.selection;
    if (!sel.isValid) return;
    final sebelum = _balas.text.substring(0, sel.baseOffset);
    final sesudah = _balas.text.substring(sel.baseOffset);
    final baru = sebelum.replaceFirst(
        RegExp(r'@[a-z0-9_.]{1,20}$', caseSensitive: false), '@$username ');
    _balas.value = TextEditingValue(
      text: baru + sesudah,
      selection: TextSelection.collapsed(offset: baru.length),
    );
    setState(() => _saranMention = []);
  }
  @override
  void initState() {
    super.initState();
    _muat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final n = context.watch<AppState>().forumRevisi;
    if (_revisi >= 0 && n != _revisi) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _muat(diam: true);
      });
    }
    _revisi = n;
  }

  @override
  void dispose() {
    _balas.dispose();
    _fokusBalas.dispose();
    _mentionTimer?.cancel();
    super.dispose();
  }

  Future<void> _muat({bool diam = false}) async {
    final no = ++_req;
    if (!diam)
      setState(() {
        _memuat = true;
        _galat = null;
      });
    try {
      final s = context.read<AppState>();
      unawaited(s.muatSukaBalasan());
      final d = await s.detailForum(widget.post.id);
      if (mounted && no == _req)
        setState(() {
          _balasan = d;
          _galat = null;
        });
    } catch (e) {
      if (mounted && no == _req)
        setState(() =>
            _galat = 'Komentar belum bisa dimuat. Tarik untuk mencoba lagi.');
    } finally {
      if (mounted && no == _req) setState(() => _memuat = false);
    }
  }

  Future<void> _kirim() async {
    final text = _balas.text.trim();
    final stickerUntukDisimpan = _stiker;
    final s = context.read<AppState>();
    final pemilik = s.user?.id;
    if (_mengirim || (text.isEmpty && _stiker == null)) return;
    setState(() => _mengirim = true);

    // Optimistic update: langsung masukkan balasan ke tampilan agar tidak terasa lambat.
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final balasanOpt = ForumBalasan(
      id: tempId,
      postId: widget.post.id,
      userId: pemilik ?? '',
      nama: s.user?.nama ?? 'Saya',
      foto: s.user?.foto,
      isi: text,
      admin: false,
      dibuat: DateTime.now(),
      balasKe: _reply?.id,
      suka: 0,
      tier: s.user?.tier ?? 'basic',
      gayaNama: s.user?.gayaNama,
      bingkai: s.user?.bingkai,
      stiker: _stiker?.stiker,
    );
    setState(() {
      _balasan = [..._balasan, balasanOpt];
    });

    final pesan = await s.balasForum(
        widget.post.id, text,
        balasKe: _reply?.id, stiker: _stiker?.toPayload());
    if (!mounted) return;
    setState(() => _mengirim = false);
    if (pesan != null) {
      // Rollback bila gagal kirim
      setState(() {
        _balasan.removeWhere((x) => x.id == tempId);
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(pesan)));
      return;
    }
    if (stickerUntukDisimpan != null && pemilik != null && PengaturanLokal.nilai['stickerAutoSave'] != false) {
      unawaited(StikerStore.untuk(pemilik).simpan(stickerUntukDisimpan.stiker, bytes: stickerUntukDisimpan.bytes).then((_) {}).catchError((e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Komentar terkirim, tetapi stiker belum tersimpan lokal.')));
      }));
    }
    _balas.clear();
    setState(() {
      _reply = null;
      _stiker = null;
    });
    _fokusBalas.unfocus();
    await _muat(diam: true);
  }

  Future<void> _lapor(String jenis, String id) async {
    final alasan = await pilihAlasanLaporan(context);
    if (alasan == null || !mounted) return;
    final e = await context
        .read<AppState>()
        .laporkan(jenis: jenis, refId: id, alasan: alasan);
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e ?? 'Laporan dikirim untuk ditinjau admin.')));
  }

  Future<void> _hapusBalasan(ForumBalasan b) async {
    if (!await konfirmasi(context,
            judul: 'Hapus komentar?',
            pesan: 'Balasan pengguna lain tetap disimpan.',
            tombolYa: 'Hapus',
            bahaya: true) ||
        !mounted) return;
    final e =
        await context.read<AppState>().hapusBalasanForum(b.id, widget.post.id);
    if (!mounted) return;
    if (e != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e)));
    } else {
      await _muat(diam: true);
    }
  }

  Future<void> _tampilkanMenuKomentar(BuildContext context, ForumBalasan b, AppState s) async {
    final pal = XyTheme.of(context);
    final isOwner = b.userId == s.user?.id;
    final nama = s.namaPengguna(b.userId, b.nama);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: pal.surfaceHigh,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          border: Border.all(color: pal.line),
        ),
        padding: EdgeInsets.fromLTRB(18, 12, 18, MediaQuery.of(ctx).padding.bottom + 18),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: pal.line, borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 14),
              Row(
                children: [
                  AvatarBingkai(bingkai: b.bingkai, size: 40, child: _Avatar(nama: nama, foto: s.fotoPengguna(b.userId, b.foto), ukuran: 40)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(nama, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                      const SizedBox(height: 2),
                      Text(b.isi.length > 60 ? '${b.isi.substring(0, 60)}...' : b.isi,
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: pal.muted, fontSize: 12)),
                    ]),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _OpsiMenu(
                icon: Icons.content_copy_rounded,
                label: 'Salin Komentar',
                onTap: () {
                  Navigator.pop(ctx);
                  Clipboard.setData(ClipboardData(text: b.isi));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Komentar disalin.')));
                },
              ),
              _OpsiMenu(
                icon: Icons.reply_rounded,
                label: 'Balas Komentar',
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _reply = b);
                  _fokusBalas.requestFocus();
                },
              ),
              _OpsiMenu(
                icon: Icons.favorite_rounded,
                label: s.balasanDisukai.contains(b.id) ? 'Batal Suka' : 'Suka Komentar',
                onTap: () async {
                  Navigator.pop(ctx);
                  final n = await s.sukaBalasan(b.id);
                  if (mounted && n != null) setState(() => b.suka = n);
                },
              ),
              _OpsiMenu(
                icon: Icons.share_rounded,
                label: 'Bagikan Komentar',
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link komentar disalin (fitur share).')));
                },
              ),
              if (!isOwner) ...[
                _OpsiMenu(
                  icon: Icons.block_rounded,
                  label: 'Blokir $nama',
                  color: XyTheme.warning,
                  onTap: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Blokir $nama (fitur).')));
                  },
                ),
                _OpsiMenu(
                  icon: Icons.flag_rounded,
                  label: 'Laporkan Komentar',
                  color: XyTheme.danger,
                  onTap: () {
                    Navigator.pop(ctx);
                    _lapor('balasan', b.id);
                  },
                ),
              ],
              if (isOwner)
                _OpsiMenu(
                  icon: Icons.delete_rounded,
                  label: 'Hapus Komentar',
                  color: XyTheme.danger,
                  onTap: () {
                    Navigator.pop(ctx);
                    _hapusBalasan(b);
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _tampilkanMenuPost(BuildContext context, ForumPost p, AppState s, bool milik) async {
    final pal = XyTheme.of(context);
    final nama = s.namaPengguna(p.userId, p.nama);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: pal.surfaceHigh,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          border: Border.all(color: pal.line),
        ),
        padding: EdgeInsets.fromLTRB(18, 12, 18, MediaQuery.of(ctx).padding.bottom + 18),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: pal.line, borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 14),
              Text(p.judul, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16), maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text('oleh $nama • ${tanggal(p.dibuat)}', style: TextStyle(color: pal.muted, fontSize: 12)),
              const SizedBox(height: 18),
              _OpsiMenu(
                icon: Icons.link_rounded,
                label: 'Salin Link Diskusi',
                onTap: () {
                  Navigator.pop(ctx);
                  Clipboard.setData(ClipboardData(text: 'https://xycloud.my.id/forum/${p.id}'));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link diskusi disalin.')));
                },
              ),
              _OpsiMenu(
                icon: Icons.share_rounded,
                label: 'Bagikan Diskusi',
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fitur bagikan.')));
                },
              ),
              _OpsiMenu(
                icon: s.forumDisimpan.contains(p.id) ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                label: s.forumDisimpan.contains(p.id) ? 'Hapus dari Simpanan' : 'Simpan Diskusi',
                onTap: () {
                  Navigator.pop(ctx);
                  s.simpanForum(p.id);
                },
              ),
              _OpsiMenu(
                icon: Icons.content_copy_rounded,
                label: 'Salin Isi Diskusi',
                onTap: () {
                  Navigator.pop(ctx);
                  Clipboard.setData(ClipboardData(text: p.isi));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Isi disalin.')));
                },
              ),
              if (!milik) ...[
                _OpsiMenu(
                  icon: Icons.person_off_rounded,
                  label: 'Blokir $nama',
                  color: XyTheme.warning,
                  onTap: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Blokir $nama (fitur).')));
                  },
                ),
                _OpsiMenu(
                  icon: Icons.flag_rounded,
                  label: 'Laporkan Diskusi',
                  color: XyTheme.danger,
                  onTap: () {
                    Navigator.pop(ctx);
                    _lapor('forum', p.id);
                  },
                ),
              ],
              if (milik) ...[
                _OpsiMenu(
                  icon: Icons.edit_rounded,
                  label: 'Sunting Diskusi',
                  onTap: () {
                    Navigator.pop(ctx);
                    bukaTulisDiskusi(context, postLama: p);
                  },
                ),
                _OpsiMenu(
                  icon: Icons.delete_rounded,
                  label: 'Hapus Diskusi',
                  color: XyTheme.danger,
                  onTap: () async {
                    Navigator.pop(ctx);
                    if (!await konfirmasi(context,
                            judul: 'Hapus diskusi?',
                            pesan: 'Seluruh komentar di diskusi ini ikut terhapus.',
                            tombolYa: 'Hapus',
                            bahaya: true) ||
                        !context.mounted) return;
                    final e = await s.hapusForum(p.id);
                    if (!context.mounted) return;
                    if (e == null) {
                      Navigator.pop(context);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e)));
                    }
                  },
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _post(ForumPost p, AppState s) {
    final pal = XyTheme.of(context), nama = s.namaPengguna(p.userId, p.nama);
    return XyCard(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            // Audit 2026-09-18: penulis bisa diketuk untuk lihat profil.
            Pressable(
                onTap: p.userId.isEmpty
                    ? null
                    : () => Navigator.push(context,
                        xyRoute(ProfilPublikScreen(userId: p.userId))),
                child: AvatarBingkai(
                    bingkai: p.bingkai,
                    size: 38,
                    child: _Avatar(
                        nama: nama, foto: s.fotoPengguna(p.userId, p.foto)))),
            const SizedBox(width: 10),
            Expanded(
                child: Pressable(
                    onTap: p.userId.isEmpty
                        ? null
                        : () => Navigator.push(context,
                            xyRoute(ProfilPublikScreen(userId: p.userId))),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GayaNama(nama,
                              gaya: p.gayaNama,
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text(tanggal(p.dibuat),
                              style: TextStyle(color: pal.muted, fontSize: 11))
                        ]))),
            LencanaTier(p.tier),
            if (p.userId.isNotEmpty && (s.user == null || p.userId != s.user!.id)) ...[
              const SizedBox(width: 8),
              _TombolIkuti(userId: p.userId),
            ],
          ]),
          const SizedBox(height: 16),
          Pill(p.kategori),
          const SizedBox(height: 12),
          Text(p.judul,
              style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                  letterSpacing: -.5)),
          const SizedBox(height: 10),
          Text(p.isi,
              style: TextStyle(fontSize: 14, height: 1.7, color: pal.inkSoft)),
          if (p.gambar != null) ...[
            const SizedBox(height: 14),
            ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.network(p.gambar!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.broken_image_outlined)))
          ],
          const SizedBox(height: 10),
          TextButton.icon(
              onPressed: () => s.sukaForum(p.id),
              icon: Icon(
                  s.forumDisukai.contains(p.id)
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: XyTheme.danger,
                  size: 19),
              label: Text('${p.suka} suka')),
        ]));
  }

  Widget _komentar(BarisKomentar row, AppState s) {
    final b = row.komentar,
        pal = XyTheme.of(context),
        depth = row.kedalaman.clamp(0, 3);
    final nama = s.namaPengguna(b.userId, b.nama);
    final parent = _balasan.where((x) => x.id == b.balasKe).firstOrNull;
    final parentNama = parent != null ? s.namaPengguna(parent.userId, parent.nama) : '';
    // Format balasan: "Ambatukam > Rino : isi" — bold isi
    final isBalasan = parent != null;

    return RepaintBoundary(
      child: CustomPaint(
        painter: _GarisThread(depth, row.lanjutan, row.punyaAnak, pal.line),
        child: Padding(
          padding: EdgeInsets.only(left: depth * 20.0, bottom: 14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Pressable(
                onTap: b.userId.isEmpty || b.admin
                    ? null
                    : () => Navigator.push(context, xyRoute(ProfilPublikScreen(userId: b.userId))),
                child: AvatarBingkai(
                  bingkai: b.bingkai,
                  size: 36,
                  child: _Avatar(nama: nama, foto: s.fotoPengguna(b.userId, b.foto), ukuran: 36, admin: b.admin),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Bubble dengan ujung (tail) — flat tapi ada ujung mengarah ke avatar
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Tail / ujung bubble — segitiga kecil di kiri atas
                    Positioned(
                      left: -6,
                      top: 14,
                      child: CustomPaint(
                        size: const Size(12, 12),
                        painter: _BubbleTailPainter(
                          color: pal.surface,
                          borderColor: pal.lineSoft,
                          isReply: isBalasan,
                        ),
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                      decoration: BoxDecoration(
                        color: isBalasan ? pal.surfaceHigh : pal.surface,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(4),
                          topRight: const Radius.circular(18),
                          bottomLeft: const Radius.circular(18),
                          bottomRight: const Radius.circular(18),
                        ),
                        border: Border.all(color: isBalasan ? pal.line : pal.lineSoft, width: isBalasan ? 1.2 : 1),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                          Expanded(
                            child: Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 4,
                              runSpacing: 2,
                              children: [
                                GayaNama(nama,
                                    gaya: b.gayaNama,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                                if (b.admin || b.tier != 'basic') LencanaTier(b.admin ? 'admin' : b.tier),
                                if (b.badge != null) LencanaKhusus(b.badge!),
                                if (b.userId.isNotEmpty && (s.user == null || b.userId != s.user!.id))
                                  _TombolIkuti(userId: b.userId),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          WaktuRelatif(b.dibuat),
                        ]),
                        const SizedBox(height: 6),
                        if (b.isi.isNotEmpty)
                          isBalasan
                              // Format baru: "Ambatukam > Rino : ya gitulah" — tanpa label chip
                              ? Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: nama,
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                            color: pal.ink,
                                            height: 1.5),
                                      ),
                                      TextSpan(
                                        text: ' > ',
                                        style: TextStyle(
                                            fontSize: 13, fontWeight: FontWeight.w600, color: pal.muted, height: 1.5),
                                      ),
                                      TextSpan(
                                        text: parentNama,
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                            color: XyTheme.primary,
                                            height: 1.5),
                                      ),
                                      TextSpan(
                                        text: ' : ',
                                        style: TextStyle(
                                            fontSize: 13, fontWeight: FontWeight.w600, color: pal.muted, height: 1.5),
                                      ),
                                      TextSpan(
                                        text: b.isi,
                                        style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w700,
                                            height: 1.5,
                                            color: pal.ink),
                                      ),
                                    ],
                                  ),
                                )
                              // Komentar top-level: isi tebal
                              : Text(
                                  b.isi,
                                  style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      height: 1.6,
                                      color: pal.ink,
                                      letterSpacing: -0.1),
                                ),
                        if (b.stiker != null) ...[
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () => menuStiker(context, b.stiker!),
                            onLongPress: () => menuStiker(context, b.stiker!),
                            child: GambarStiker(b.stiker!, ukuran: 156),
                          ),
                          if (b.stiker!.dariGiphy)
                            Text('via GIPHY', style: TextStyle(fontSize: 10, color: pal.muted)),
                        ],
                      ]),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Action bar flat
                Row(
                  children: [
                    Pressable(
                      onTap: () async {
                        final n = await s.sukaBalasan(b.id);
                        if (mounted && n != null) setState(() => b.suka = n);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: s.balasanDisukai.contains(b.id)
                              ? XyTheme.danger.withOpacity(.12)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: s.balasanDisukai.contains(b.id) ? XyTheme.danger.withOpacity(.3) : pal.lineSoft),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(
                              s.balasanDisukai.contains(b.id)
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              size: 14,
                              color: s.balasanDisukai.contains(b.id) ? XyTheme.danger : pal.muted),
                          const SizedBox(width: 4),
                          Text('${b.suka}',
                              style: TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w700, color: pal.muted)),
                        ]),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Pressable(
                      onTap: _mengirim
                          ? null
                          : () {
                              setState(() => _reply = b);
                              _fokusBalas.requestFocus();
                            },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: pal.lineSoft)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.reply_rounded, size: 14, color: pal.muted),
                          const SizedBox(width: 4),
                          Text('Balas',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: pal.muted)),
                        ]),
                      ),
                    ),
                    const Spacer(),
                    Pressable(
                      onTap: () => _tampilkanMenuKomentar(context, b, s),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: pal.lineSoft,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.more_horiz_rounded, size: 16, color: pal.muted),
                      ),
                    ),
                  ],
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>(), pal = XyTheme.of(context);
    final p =
        s.forum.where((x) => x.id == widget.post.id).firstOrNull ?? widget.post;
    final rows = susunKomentar(_balasan), milik = p.userId == s.user?.id;
    return Scaffold(
        appBar: AppBar(title: const Text('Diskusi'), actions: [
          if (milik)
            IconButton(
                tooltip: 'Sunting diskusi',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => bukaTulisDiskusi(context, postLama: p)),
          IconButton(
            tooltip: 'Opsi diskusi',
            icon: const Icon(Icons.more_horiz_rounded),
            onPressed: () => _tampilkanMenuPost(context, p, s, milik),
          ),
        ]),
        body: Column(children: [
          Expanded(
              child: RefreshIndicator(
                  onRefresh: () => _muat(),
                  child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
                      // Performa ala app gede: cacheExtent besar, no keepAlive, repaintBoundary
                      cacheExtent: 800,
                      addAutomaticKeepAlives: false,
                      addRepaintBoundaries: true,
                      itemCount: rows.length + 2,
                      itemBuilder: (ctx, i) {
                        if (i == 0) return RepaintBoundary(child: _post(p, s));
                        if (i == 1)
                          return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [
                                      const Text('Percakapan',
                                          style: TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.w700)),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                            color: XyTheme.primary.withOpacity(.12),
                                            borderRadius: BorderRadius.circular(20)),
                                        child: Text('${_balasan.length}',
                                            style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: XyTheme.primary)),
                                      ),
                                    ]),
                                    if (p.balasan > 200)
                                      Text('Menampilkan 200 komentar terbaru',
                                          style: TextStyle(
                                              color: pal.muted, fontSize: 11)),
                                    if (_memuat) ...[
                                      const SizedBox(height: 12),
                                      // Skeleton presisi mirror bubble komentar dengan ujung
                                      const SkeletonKomentarList(count: 4),
                                    ],
                                    if (_galat != null)
                                      TextButton(
                                          onPressed: () => _muat(),
                                          child: Text(_galat!)),
                                    if (!_memuat &&
                                        _galat == null &&
                                        rows.isEmpty)
                                      Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 26),
                                          child: Text(
                                              'Mulai percakapan. Kirim pesan, stiker, atau keduanya.',
                                              style: TextStyle(
                                                  color: pal.muted,
                                                  height: 1.5))),
                                  ]));
                        return RepaintBoundary(
                          child: KeyedSubtree(
                              key: ValueKey(rows[i - 2].komentar.id),
                              child: _komentar(rows[i - 2], s)),
                        );
                      }))),
          Container(
              decoration: BoxDecoration(
                  color: pal.surface,
                  boxShadow: [BoxShadow(color: pal.ink.withOpacity(.07), blurRadius: 22, offset: const Offset(0, -6))]),
              child: SafeArea(
                  top: false,
                  child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        if (_reply != null)
                          Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.only(left: 12),
                              decoration: BoxDecoration(
                                  color: pal.primarySoft,
                                  borderRadius: BorderRadius.circular(14)),
                              child: Row(children: [
                                Icon(Icons.reply_rounded,
                                    size: 18, color: pal.accent),
                                const SizedBox(width: 7),
                                Expanded(
                                    child: Text(
                                        'Membalas ${s.namaPengguna(_reply!.userId, _reply!.nama)}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            color: pal.inkSoft, fontSize: 12))),
                                IconButton(
                                    onPressed: _mengirim
                                        ? null
                                        : () => setState(() => _reply = null),
                                    icon: const Icon(Icons.close_rounded,
                                        size: 17),
                                    tooltip: 'Batal membalas')
                              ])),
                        if (_stiker != null)
                          Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(children: [
                                GambarStiker(_stiker!.stiker,
                                    bytes: _stiker!.bytes, ukuran: 76),
                                const SizedBox(width: 12),
                                Expanded(
                                    child: Text(
                                        'Pesan di atas, stiker di bawah',
                                        style: TextStyle(
                                            color: pal.muted, fontSize: 11.5))),
                                IconButton(
                                    onPressed: _mengirim
                                        ? null
                                        : () => setState(() => _stiker = null),
                                    tooltip: 'Hapus lampiran stiker',
                                    icon: const Icon(Icons.close_rounded,
                                        size: 18))
                              ])),
                        // Batch L: saran @mention muncul di atas composer.
                        if (_saranMention.isNotEmpty)
                          Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              constraints: const BoxConstraints(maxHeight: 190),
                              decoration: BoxDecoration(
                                  color: pal.surface,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: pal.line),
                                  boxShadow: XyTheme.shadowSm),
                              child: ListView.builder(
                                  shrinkWrap: true,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  itemCount: _saranMention.length,
                                  itemBuilder: (_, i) {
                                    final m = _saranMention[i];
                                    final un = '${m['username'] ?? ''}';
                                    return ListTile(
                                        dense: true,
                                        visualDensity: VisualDensity.compact,
                                        leading: _Avatar(
                                            nama: '${m['nama'] ?? un}',
                                            foto: (m['foto'] as String?),
                                            ukuran: 30),
                                        title: Text('${m['nama'] ?? un}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700)),
                                        subtitle: Text('@$un',
                                            style: TextStyle(
                                                fontSize: 11.5,
                                                color: XyTheme.primary,
                                                fontWeight: FontWeight.w700)),
                                        onTap: () => _pakaiMention(un));
                                  })),
                        Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              IconButton(
                                  tooltip: 'Pilih stiker',
                                  onPressed: _mengirim
                                      ? null
                                      : () async {
                                          _fokusBalas.unfocus();
                                          final v = await pilihStiker(context);
                                          if (v != null && mounted)
                                            setState(() => _stiker = v);
                                        },
                                  icon: Icon(Icons.emoji_emotions_outlined,
                                      color: pal.accent)),
                              Expanded(
                                  child: TextField(
                                      controller: _balas,
                                      focusNode: _fokusBalas,
                                      enabled: !_mengirim,
                                      minLines: 1,
                                      maxLines: 4,
                                      maxLength: 4000,
                                      textCapitalization:
                                          TextCapitalization.sentences,
                                      decoration: InputDecoration(
                                          hintText: 'Tulis komentar…',
                                          counterText: '',
                                          fillColor: pal.lineSoft,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 14,
                                                  vertical: 12)),
                                      onChanged: (_) {
                                        setState(() {});
                                        _cekMention();
                                      })),
                              const SizedBox(width: 8),
                              IconButton.filled(
                                  tooltip: 'Kirim komentar',
                                  onPressed: _mengirim ||
                                          (_balas.text.trim().isEmpty &&
                                              _stiker == null)
                                      ? null
                                      : _kirim,
                                  style: IconButton.styleFrom(
                                      backgroundColor: XyTheme.primary,
                                      foregroundColor: Colors.white),
                                  icon: _mengirim
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white))
                                      : const Icon(Icons.arrow_upward_rounded)),
                            ]),
                      ])))),
        ]));
  }
}

/// Opsi menu custom bottom sheet (ganti PopupMenuButton bawaan Android)
class _OpsiMenu extends StatelessWidget {
  const _OpsiMenu({required this.icon, required this.label, required this.onTap, this.color});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final pal = XyTheme.of(context);
    final c = color ?? pal.ink;
    return Pressable(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: pal.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: pal.line),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: (color ?? XyTheme.primary).withOpacity(.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: c),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c))),
            Icon(Icons.chevron_right_rounded, size: 18, color: pal.muted),
          ],
        ),
      ),
    );
  }
}

/// Tail / ujung bubble komentar — flat, ada ujung mengarah ke avatar
class _BubbleTailPainter extends CustomPainter {
  _BubbleTailPainter({required this.color, required this.borderColor, this.isReply = false});
  final Color color;
  final Color borderColor;
  final bool isReply;

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()..color = color..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Segitiga ujung: pointy ke kiri
    final path = Path()
      ..moveTo(size.width, 0)
      ..lineTo(0, size.height / 2)
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(path, fillPaint);
    // Border atas dan bawah untuk matching bubble border
    canvas.drawLine(Offset(size.width, 0), Offset(0, size.height / 2), borderPaint);
    canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height), borderPaint);
  }

  @override
  bool shouldRepaint(covariant _BubbleTailPainter old) =>
      old.color != color || old.borderColor != borderColor || old.isReply != isReply;
}

class _GarisThread extends CustomPainter {
  _GarisThread(this.depth, this.lanjut, this.anak, this.warna);
  final int depth;
  final List<bool> lanjut;
  final bool anak;
  final Color warna;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = warna
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (var level = 0; level < depth; level++) {
      final x = 17.0 + level * 20;
      if (level == depth - 1) {
        final path = Path()
          ..moveTo(x, 0)
          ..lineTo(x, 12)
          ..quadraticBezierTo(x, 21, x + 9, 21)
          ..lineTo(x + 13, 21);
        canvas.drawPath(path, p);
        if (level < lanjut.length && lanjut[level])
          canvas.drawLine(Offset(x, 12), Offset(x, size.height), p);
      } else if (level < lanjut.length && lanjut[level]) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
      }
    }
    if (anak && depth < 3)
      canvas.drawLine(Offset(17.0 + depth * 20, 40),
          Offset(17.0 + depth * 20, size.height), p);
  }

  @override
  bool shouldRepaint(covariant _GarisThread old) =>
      old.warna != warna ||
      old.depth != depth ||
      old.anak != anak ||
      old.lanjut != lanjut;
}

/// ---------------- tulis diskusi ----------------
Future<void> bukaTulisDiskusi(BuildContext context, {ForumPost? postLama}) =>
    Navigator.push(context, xyRouteBawah(_FormTulis(postLama: postLama)));

class _FormTulis extends StatefulWidget {
  const _FormTulis({this.postLama});
  final ForumPost? postLama;

  @override
  State<_FormTulis> createState() => _FormTulisState();
}

class _FormTulisState extends State<_FormTulis> {
  late final _judul = TextEditingController(text: widget.postLama?.judul ?? '');
  late final _isi = TextEditingController(text: widget.postLama?.isi ?? '');
  late String kategori = widget.postLama?.kategori ?? 'Umum';
  String? gambar;
  bool proses = false;

  bool get sunting => widget.postLama != null;

  @override
  void dispose() {
    _judul.dispose();
    _isi.dispose();
    super.dispose();
  }

  Future<void> _pilihGambar() async {
    final f = await GaleriPicker.pilihGambar(context);
    if (f == null) return;
    final bytes = await f.readAsBytes();
    final uri = await Kompres.dataUri(bytes, f.path.split('/').last);
    if (!mounted) return;
    setState(() => gambar = uri);
  }

  Future<void> _kirim() async {
    final isiTeks = _isi.text.trim();
    if (isiTeks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tuliskan sesuatu untuk dibagikan ke feed.')));
      return;
    }
    String judulTeks = _judul.text.trim();
    if (judulTeks.isEmpty) {
      judulTeks = isiTeks.split('\n')[0].trim();
      if (judulTeks.length > 70) judulTeks = '${judulTeks.substring(0, 67)}...';
      if (judulTeks.length < 5) judulTeks = '$judulTeks • Feed';
    }

    setState(() => proses = true);
    final s = context.read<AppState>();
    final pesan = sunting
        ? await s.suntingForum(
            id: widget.postLama!.id,
            judul: judulTeks,
            isi: isiTeks,
            kategori: kategori,
          )
        : await s.buatForum(
            judul: judulTeks,
            isi: isiTeks,
            kategori: kategori,
            gambar: gambar,
          );
    if (!mounted) return;
    setState(() => proses = false);
    if (pesan != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(pesan)));
      return;
    }
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              sunting ? 'Postingan diperbarui.' : 'Postingan kamu sudah tayang di Feed.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    const pilihan = ['Umum', 'Tanya Jawab', 'Tips', 'Jual Beli', 'Keluhan'];

    return Scaffold(
      appBar:
          AppBar(title: Text(sunting ? 'Sunting Post' : 'Buat Post Feed')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
        children: [
          const Text('Topik Feed',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: pilihan.map((k) {
              final on = k == kategori;
              return Pressable(
                onTap: () => setState(() => kategori = k),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: on ? XyTheme.primary : XyTheme.of(context).surface,
                    borderRadius: BorderRadius.circular(XyRadius.pill),
                    border: Border.all(
                        color: on ? XyTheme.primary : XyTheme.of(context).line),
                  ),
                  child: Text(k,
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color:
                              on ? Colors.white : XyTheme.of(context).inkSoft)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
          const Text('Isi postingan feed',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
          const SizedBox(height: 9),
          TextField(
            controller: _isi,
            maxLines: 8,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText:
                  'Apa yang sedang kamu pikirkan? Tulis apa saja, tanya jawab, tips, atau info mabar…',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 18),
          const Text('Judul (opsional)',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
          const SizedBox(height: 9),
          TextField(
            controller: _judul,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
                hintText: 'Boleh dikosongkan — otomatis dari kalimat pertama'),
          ),
          if (!sunting) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _pilihGambar,
              icon: Icon(
                  gambar == null ? Icons.image_outlined : Icons.check_rounded,
                  size: 18),
              label: Text(gambar == null
                  ? 'Tambah Foto / Gambar (opsional)'
                  : 'Foto siap dibagikan'),
            ),
          ],
          const SizedBox(height: 22),
          GradientButton(
            label: sunting ? 'Simpan Perubahan' : 'Bagikan ke Feed',
            icon: sunting ? Icons.check_rounded : Icons.send_rounded,
            loading: proses,
            onPressed: proses ? null : _kirim,
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
                'Hormati sesama pengguna. Diskusi yang melanggar akan dihapus admin.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: XyTheme.of(context).muted,
                    fontSize: 11.8,
                    height: 1.5)),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar(
      {required this.nama, this.foto, this.ukuran = 38, this.admin = false});
  final String nama;
  final String? foto;
  final double ukuran;
  final bool admin;

  @override
  Widget build(BuildContext context) {
    if ((foto ?? '').isNotEmpty) {
      // Pakai CachedNetworkImage + memCache biar cepet kayak app gede
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: foto!,
          width: ukuran,
          height: ukuran,
          fit: BoxFit.cover,
          memCacheWidth: (ukuran * 2).toInt(),
          memCacheHeight: (ukuran * 2).toInt(),
          placeholder: (_, __) => Container(
            width: ukuran,
            height: ukuran,
            color: XyTheme.of(context).lineSoft,
            child: Center(
                child: Text(nama.isEmpty ? 'X' : nama[0].toUpperCase(),
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: ukuran * .42))),
          ),
          errorWidget: (_, __, ___) => Container(
            width: ukuran,
            height: ukuran,
            decoration: BoxDecoration(
              gradient: admin ? XyTheme.gradDeep : XyTheme.gradPrimary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(nama.isEmpty ? 'X' : nama[0].toUpperCase(),
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: ukuran * .42)),
            ),
          ),
        ),
      );
    }
    return Container(
      width: ukuran,
      height: ukuran,
      decoration: const BoxDecoration(
        color: XyTheme.primary,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: admin
            ? Icon(Icons.verified_user_rounded,
                size: ukuran * .5, color: Colors.white)
            : Text(nama.isEmpty ? 'X' : nama[0].toUpperCase(),
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: ukuran * .42)),
      ),
    );
  }
}

/// Barisan horizontal Story di Feed (24 Jam)
class _StoriesBar extends StatelessWidget {
  const _StoriesBar({
    required this.stories,
    required this.onBuatStory,
    required this.onLihatStory,
  });
  final List<StoryItem> stories;
  final VoidCallback onBuatStory;
  final ValueChanged<StoryItem> onLihatStory;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final user = s.user;
    final punyaStorySaya = stories.any(
        (st) => st.punyaSaya || (user != null && st.userId == user.id));
    final storySaya = stories
        .where((st) => st.punyaSaya || (user != null && st.userId == user.id))
        .toList();
    final storyTeman = stories
        .where((st) => !st.punyaSaya && (user == null || st.userId != user.id))
        .toList();

    return Container(
      height: 104,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: 1 + storyTeman.length,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Pressable(
                onTap: () {
                  if (storySaya.isNotEmpty) {
                    onLihatStory(storySaya.first);
                  } else {
                    onBuatStory();
                  }
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(2.5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: punyaStorySaya
                                ? const LinearGradient(
                                    colors: [
                                      Color(0xFFF59E0B),
                                      Color(0xFFEC4899),
                                      Color(0xFF8B5CF6)
                                    ],
                                  )
                                : null,
                            border: !punyaStorySaya
                                ? Border.all(color: Colors.white24, width: 1.5)
                                : null,
                          ),
                          child: AvatarBingkai(
                            size: 52,
                            bingkai: user?.bingkai,
                            child: _Avatar(
                              nama: user?.nama ?? 'Kamu',
                              foto: user?.foto,
                              ukuran: 52,
                            ),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: const BoxDecoration(
                              color: XyTheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.add,
                                size: 14, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      punyaStorySaya ? 'Story Kamu' : 'Buat Story',
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            );
          }

          final story = storyTeman[index - 1];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Pressable(
              onTap: () => onLihatStory(story),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(2.5),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFFF59E0B),
                          Color(0xFFEC4899),
                          Color(0xFF8B5CF6)
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: AvatarBingkai(
                      size: 52,
                      bingkai: story.bingkai,
                      child: _Avatar(
                        nama: story.nama,
                        foto: story.foto,
                        ukuran: 52,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  SizedBox(
                    width: 62,
                    child: Text(
                      story.nama,
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Layar Penuh Story Viewer (Instagram / WhatsApp Style)
class StoryFullScreenViewer extends StatefulWidget {
  const StoryFullScreenViewer({
    super.key,
    required this.stories,
    this.awalIndex = 0,
    required this.onHapus,
  });

  final List<StoryItem> stories;
  final int awalIndex;
  final Future<void> Function(String id) onHapus;

  @override
  State<StoryFullScreenViewer> createState() => _StoryFullScreenViewerState();
}

class _StoryFullScreenViewerState extends State<StoryFullScreenViewer>
    with SingleTickerProviderStateMixin {
  late int _index;
  late final AnimationController _ctrl;
  final _balasCtrl = TextEditingController();
  bool _terjeda = false;
  bool _sedangKirim = false;
  bool _animLike = false;
  VideoPlayerController? _videoCtrl;

  @override
  void initState() {
    super.initState();
    _index = widget.awalIndex.clamp(
        0, widget.stories.isEmpty ? 0 : widget.stories.length - 1);
    _ctrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 6));
    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        _lanjutStory();
      }
    });
    _ctrl.forward();
    _initVideo();
  }

  void _initVideo() {
    final s = widget.stories[_index];
    if (s.tipe == 'video' && (s.mediaUrl ?? '').isNotEmpty) {
      _videoCtrl?.dispose();
      _videoCtrl = VideoPlayerController.networkUrl(Uri.parse(s.mediaUrl!))
        ..initialize().then((_) {
          if (mounted) {
            setState(() {});
            _videoCtrl?.play();
            // sync duration with story timer
            final dur = _videoCtrl!.value.duration.inSeconds;
            if (dur > 0 && dur < 15) {
              _ctrl.duration = Duration(seconds: dur);
              _ctrl.forward(from: 0);
            }
          }
        });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _balasCtrl.dispose();
    _videoCtrl?.dispose();
    super.dispose();
  }

  void _jeda() {
    if (!_terjeda) {
      _terjeda = true;
      _ctrl.stop();
      _videoCtrl?.pause();
    }
  }

  void _lanjut() {
    if (_terjeda) {
      _terjeda = false;
      _ctrl.forward();
      _videoCtrl?.play();
    }
  }

  void _lanjutStory() {
    if (_index < widget.stories.length - 1) {
      setState(() {
        _index++;
        _ctrl.reset();
        _ctrl.forward();
      });
      _initVideo();
    } else {
      Navigator.pop(context);
    }
  }

  void _mundurStory() {
    if (_index > 0) {
      setState(() {
        _index--;
        _ctrl.reset();
        _ctrl.forward();
      });
      _initVideo();
    } else {
      _ctrl.reset();
      _ctrl.forward();
    }
  }

  Future<void> _kirimBalasan(StoryItem s) async {
    final pesan = _balasCtrl.text.trim();
    if (pesan.isEmpty) return;
    setState(() => _sedangKirim = true);
    _jeda();
    final galat = await context.read<AppState>().balasStory(s.id, pesan);
    if (!mounted) return;
    setState(() => _sedangKirim = false);
    if (galat == null) {
      _balasCtrl.clear();
      FocusScope.of(context).unfocus();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Balasan terkirim ke pesan langsung (DM).'),
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(galat)),
      );
    }
    _lanjut();
  }

  Future<void> _repostStory(StoryItem s) async {
    _jeda();
    // Improved repost UI - bottom sheet with preview instead of simple dialog
    final pal = XyTheme.of(context);
    final yakin = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: pal.surfaceHigh,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: pal.line, borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 16),
              const Icon(Icons.repeat_rounded, size: 36, color: XyTheme.primary),
              const SizedBox(height: 12),
              const Text('Posting Ulang Story?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('Story milik ${s.nama} akan dibagikan ulang ke profilmu dan terlihat publik selama 24 jam.',
                textAlign: TextAlign.center, style: TextStyle(color: pal.muted, fontSize: 13, height: 1.5)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: pal.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: pal.line)),
                child: Row(children: [
                  Container(width: 48, height: 48, decoration: BoxDecoration(color: pal.lineSoft, borderRadius: BorderRadius.circular(10)),
                    child: s.mediaUrl != null ? ClipRRect(borderRadius: BorderRadius.circular(10), child: CachedNetworkImage(imageUrl: s.mediaUrl!, fit: BoxFit.cover)) : const Icon(Icons.text_fields_rounded)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s.nama, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(height: 2),
                    Text(s.teks.isEmpty ? '(media story)' : s.teks, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: pal.muted, fontSize: 12)),
                  ])),
                ]),
              ),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal'))),
                const SizedBox(width: 12),
                Expanded(child: FilledButton.icon(onPressed: () => Navigator.pop(ctx, true), icon: const Icon(Icons.repeat_rounded, size: 18), label: const Text('Repost'))),
              ]),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (yakin == true) {
      final galat = await context.read<AppState>().repostStory(s.id);
      if (mounted) {
        if (galat == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Story berhasil diposting ulang!')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(galat)),
          );
        }
      }
    }
    _lanjut();
  }

  void _likeWithAnim(StoryItem s) {
    context.read<AppState>().likeStory(s.id);
    setState(() => _animLike = true);
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _animLike = false);
    });
  }

  LinearGradient _getGradient(String jenis) {
    switch (jenis) {
      case 'emas':
        return const LinearGradient(colors: [Color(0xFF78350F), Color(0xFFD97706), Color(0xFFF59E0B)]);
      case 'neon':
        return const LinearGradient(colors: [Color(0xFF0284C7), Color(0xFF06B6D4), Color(0xFF10B981)]);
      case 'senja':
        return const LinearGradient(colors: [Color(0xFF831843), Color(0xFFBE185D), Color(0xFFFB7185)]);
      case 'cyber':
        return const LinearGradient(colors: [Color(0xFF1E1B4B), Color(0xFF4C1D95), Color(0xFF06B6D4)]);
      case 'solid':
        return const LinearGradient(colors: [Color(0xFF1F2937), Color(0xFF374151)]);
      default:
        return const LinearGradient(colors: [Color(0xFF3B0764), Color(0xFF6B21A8), Color(0xFFA855F7)]);
    }
  }

  Color _hexToColor(String hex) {
    try {
      var h = hex.replaceAll('#', '');
      if (h.length == 6) h = 'FF$h';
      if (h.length == 8) return Color(int.parse(h, radix: 16));
      return Colors.white;
    } catch (_) {
      return Colors.white;
    }
  }

  TextStyle _gayaTeksStyle(StoryItem s) {
    final base = TextStyle(
      color: _hexToColor(s.warnaTeks),
      fontSize: s.ukuranTeks.toDouble(),
      fontWeight: s.gayaTeks.contains('bold') ? FontWeight.w800 : FontWeight.w700,
      fontStyle: s.gayaTeks.contains('italic') ? FontStyle.italic : FontStyle.normal,
      height: 1.4,
      letterSpacing: s.gayaTeks == 'ketik' ? 1.2 : -0.2,
      shadows: s.gayaTeks == 'neon'
          ? [Shadow(color: _hexToColor(s.warnaTeks).withOpacity(0.8), blurRadius: 12), Shadow(color: _hexToColor(s.warnaTeks).withOpacity(0.6), blurRadius: 24)]
          : s.gayaTeks == 'retro'
              ? [const Shadow(color: Colors.black, offset: Offset(3, 3), blurRadius: 0)]
              : null,
    );
    return base;
  }

  Widget _buildLabelChips(StoryItem s) {
    if (s.label.isEmpty) return const SizedBox.shrink();
    try {
      final list = jsonDecode(s.label) as List;
      if (list.isEmpty) return const SizedBox.shrink();
      return Wrap(
        spacing: 6,
        runSpacing: 6,
        children: list.map<Widget>((e) {
          final m = Map<String, dynamic>.from(e);
          final type = m['type'] ?? 'tag';
          final text = m['text'] ?? '';
          IconData icon;
          switch (type) {
            case 'location': icon = Icons.location_on_rounded; break;
            case 'mention': icon = Icons.alternate_email_rounded; break;
            case 'hashtag': icon = Icons.tag_rounded; break;
            case 'countdown': icon = Icons.timer_rounded; break;
            default: icon = Icons.label_rounded;
          }
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white24)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 12, color: Colors.white),
              const SizedBox(width: 4),
              Text(text, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
            ]),
          );
        }).toList(),
      );
    } catch (_) {
      // fallback: label as plain text chips separated by comma
      final parts = s.label.split(',').where((e) => e.trim().isNotEmpty).toList();
      if (parts.isEmpty) return const SizedBox.shrink();
      return Wrap(spacing: 6, children: parts.map((t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(20)),
        child: Text(t.trim(), style: const TextStyle(color: Colors.white, fontSize: 11)),
      )).toList());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.stories.isEmpty || _index >= widget.stories.length) {
      return const Scaffold(backgroundColor: Colors.black);
    }
    // Reactive: watch AppState to get updated likes
    final app = context.watch<AppState>();
    final raw = widget.stories[_index];
    final s = app.stories.where((e) => e.id == raw.id).firstOrNull ?? raw;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Konten Story
          Container(
            decoration: BoxDecoration(
              gradient: s.bgType == 'solid' && s.bgWarna.isNotEmpty
                  ? LinearGradient(colors: [_hexToColor(s.bgWarna), _hexToColor(s.bgWarna)])
                  : _getGradient(s.bgGradient),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (s.bgImageUrl != null && s.bgImageUrl!.isNotEmpty)
                  Positioned.fill(child: CachedNetworkImage(imageUrl: s.bgImageUrl!, fit: BoxFit.cover, placeholder: (_, __) => const SkeletonBox(height: double.infinity), errorWidget: (_, __, ___) => const SizedBox.shrink())),
                if (s.bgType == 'solid' && s.bgWarna.isNotEmpty)
                  Positioned.fill(child: Container(color: _hexToColor(s.bgWarna))),
                // Media
                if ((s.mediaUrl ?? '').isNotEmpty)
                  Positioned.fill(
                    child: s.tipe == 'video' && _videoCtrl != null && _videoCtrl!.value.isInitialized
                        ? Center(child: AspectRatio(aspectRatio: _videoCtrl!.value.aspectRatio, child: VideoPlayer(_videoCtrl!)))
                        : CachedNetworkImage(
                            imageUrl: s.mediaUrl!,
                            fit: BoxFit.contain,
                            placeholder: (_, __) => const Center(child: SkeletonBox(width: 200, height: 200)),
                            errorWidget: (_, __, ___) => const Center(child: Icon(Icons.broken_image_rounded, size: 54, color: Colors.white54)),
                          ),
                  ),
                // Teks with style
                if (s.teks.isNotEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Container(
                        padding: s.teksBg ? const EdgeInsets.symmetric(horizontal: 20, vertical: 16) : EdgeInsets.zero,
                        decoration: s.teksBg
                            ? BoxDecoration(
                                color: _hexToColor(s.teksBgWarna),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: Colors.white12),
                              )
                            : null,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              s.teks,
                              style: _gayaTeksStyle(s),
                              textAlign: s.alignTeks == 'left' ? TextAlign.left : s.alignTeks == 'right' ? TextAlign.right : TextAlign.center,
                            ),
                            if (s.label.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              _buildLabelChips(s),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                // Like anim overlay
                if (_animLike)
                  Center(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.5, end: 1.2),
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.elasticOut,
                      builder: (ctx, val, child) => Transform.scale(scale: val, child: child),
                      child: Icon(s.sudahLike ? Icons.favorite_rounded : Icons.favorite_border_rounded, size: 100, color: Colors.white.withOpacity(0.9)),
                    ),
                  ),
              ],
            ),
          ),

          // Tap & Hold detector + double tap to like
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onLongPressStart: (_) => _jeda(),
              onLongPressEnd: (_) => _lanjut(),
              onTapDown: (_) => _jeda(),
              onTapCancel: () => _lanjut(),
              onDoubleTap: () => _likeWithAnim(s),
              onTapUp: (details) {
                _lanjut();
                final w = MediaQuery.of(context).size.width;
                if (details.localPosition.dx < w * 0.3) {
                  _mundurStory();
                } else if (details.localPosition.dx > w * 0.7) {
                  _lanjutStory();
                }
              },
            ),
          ),

          // Top safe area: progress + header (FIXED OVERLAP)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  // Progress bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: Row(
                      children: List.generate(widget.stories.length, (i) {
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: AnimatedBuilder(
                                animation: _ctrl,
                                builder: (context, _) {
                                  double val;
                                  if (i < _index) val = 1.0;
                                  else if (i == _index) val = _ctrl.value;
                                  else val = 0.0;
                                  return LinearProgressIndicator(
                                    value: val,
                                    backgroundColor: Colors.white24,
                                    valueColor: const AlwaysStoppedAnimation(Colors.white),
                                    minHeight: 2.5,
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Header (now below progress with proper spacing)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        AvatarBingkai(
                          size: 40,
                          bingkai: s.bingkai,
                          child: _Avatar(nama: s.nama, foto: s.foto, ukuran: 40),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.nama, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14.5)),
                              const SizedBox(height: 2),
                              Text('${waktuRelatif(s.dibuat)} • ${s.privasi == "teman" ? "Teman" : "Publik"}${s.filter != 'normal' ? ' • ${s.filter}' : ''}',
                                style: const TextStyle(color: Colors.white70, fontSize: 11)),
                            ],
                          ),
                        ),
                        if (s.punyaSaya)
                          Container(
                            decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), shape: BoxShape.circle),
                            child: IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.white70, size: 20),
                              onPressed: () async {
                                _jeda();
                                final yakin = await konfirmasi(context, judul: 'Hapus Story', pesan: 'Story ini akan dihapus permanen dan tidak dapat dipulihkan.', tombolYa: 'Hapus', bahaya: true);
                                if (!mounted) return;
                                if (yakin) {
                                  await widget.onHapus(s.id);
                                  if (mounted) Navigator.pop(context);
                                } else {
                                  _lanjut();
                                }
                              },
                            ),
                          ),
                        const SizedBox(width: 6),
                        Container(
                          decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), shape: BoxShape.circle),
                          child: IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white, size: 22), onPressed: () => Navigator.pop(context)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Footer Interaksi (Like reactive, Komentar, Repost bagus)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 46,
                        decoration: BoxDecoration(color: Colors.black.withOpacity(0.55), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white24)),
                        child: Row(
                          children: [
                            const SizedBox(width: 14),
                            Expanded(
                              child: TextField(
                                controller: _balasCtrl,
                                style: const TextStyle(color: Colors.white, fontSize: 13.5),
                                decoration: InputDecoration(hintText: 'Balas ${s.nama}…', hintStyle: const TextStyle(color: Colors.white54, fontSize: 13), border: InputBorder.none, isDense: true),
                                onTap: () => _jeda(),
                                onSubmitted: (_) => _kirimBalasan(s),
                              ),
                            ),
                            IconButton(
                              icon: _sedangKirim
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                              onPressed: _sedangKirim ? null : () => _kirimBalasan(s),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Like button reactive
                    Pressable(
                      onTap: () => _likeWithAnim(s),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 46,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: s.sudahLike ? Colors.red.withOpacity(0.25) : Colors.black.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(23),
                          border: Border.all(color: s.sudahLike ? Colors.redAccent : Colors.white24, width: s.sudahLike ? 1.5 : 1),
                        ),
                        child: Row(
                          children: [
                            Icon(s.sudahLike ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: s.sudahLike ? Colors.redAccent : Colors.white, size: 22),
                            if (s.likes > 0) ...[
                              const SizedBox(width: 6),
                              Text('${s.likes}', style: TextStyle(color: s.sudahLike ? Colors.redAccent : Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Repost bagus
                    Pressable(
                      onTap: () => _repostStory(s),
                      child: Container(
                        height: 46,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(color: Colors.black.withOpacity(0.55), borderRadius: BorderRadius.circular(23), border: Border.all(color: Colors.white24)),
                        child: Row(children: [
                          const Icon(Icons.repeat_rounded, color: Colors.white, size: 22),
                          if (s.reposts > 0) ...[
                            const SizedBox(width: 6),
                            Text('${s.reposts}', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                          ],
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lembar Buat Story Baru (24 Jam)

/// Lembar Buat Story Baru (24 Jam) - Deprecated: now uses StoryEditorScreen
/// Kept for backward compat, redirects to full editor
class _SheetBuatStory extends StatelessWidget {
  const _SheetBuatStory({required this.onStoryDibuat});
  final ValueChanged<StoryItem> onStoryDibuat;

  @override
  Widget build(BuildContext context) {
    // Redirect to full editor
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pop(context);
      Navigator.push(context, xyRoute(StoryEditorScreen(onStoryDibuat: onStoryDibuat)));
    });
    return const SizedBox.shrink();
  }
}
