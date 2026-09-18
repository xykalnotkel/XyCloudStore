import '../../core/pengaturan.dart';
import '../../data/stiker_store.dart';
import '../widgets/waktu_relatif.dart';
import '../widgets/bingkai_profil.dart';
import '../widgets/gaya_nama.dart';
import 'dart:async';
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
import '../../models/models.dart';
import '../../providers/app_state.dart';
import '../widgets/common.dart';
import 'profil_publik_screen.dart';
import 'follows_screen.dart';
import '../widgets/error_state.dart';
import '../widgets/lembar.dart';

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
        title: const Text('Feed Komunitas'),
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
          PopupMenuButton<String>(
            tooltip: 'Urutkan diskusi',
            icon: const Icon(Icons.swap_vert_rounded),
            initialValue: urut,
            onSelected: (v) => setState(() => urut = v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'Terbaru', child: Text('Terbaru')),
              PopupMenuItem(value: 'Terpopuler', child: Text('Terpopuler (suka)')),
              PopupMenuItem(value: 'Teramai', child: Text('Teramai (balasan)')),
            ],
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
                  ? const Center(child: CircularProgressIndicator())
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
                            padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
                            itemCount: daftar.length + 1,
                            itemBuilder: (_, i) => i == 0
                                ? _AjakanTulis(nama: s.user?.nama ?? '')
                                : _KartuPost(post: daftar[i - 1]),
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
                        const SizedBox(width: 6),
                        const Icon(Icons.push_pin_rounded,
                            size: 13, color: XyTheme.primary),
                      ],
                    ]),
                    const SizedBox(height: 2),
                    Text(tanggal(post.dibuat),
                        style: TextStyle(
                            color: XyTheme.of(context).muted, fontSize: 11)),
                  ]),
            ),
            Pill(post.kategori, warna: XyTheme.violet),
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
      dibuat: DateTime.now().toIso8601String(),
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
            LencanaTier(p.tier)
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
    return CustomPaint(
        painter: _GarisThread(depth, row.lanjutan, row.punyaAnak, pal.line),
        child: Padding(
            padding: EdgeInsets.only(left: depth * 20.0, bottom: 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                  padding: const EdgeInsets.only(top: 4),
                  // Audit 2026-09-18: avatar penulis komentar bisa diketuk
                  // untuk membuka profil publiknya.
                  child: Pressable(
                      onTap: b.userId.isEmpty || b.admin
                          ? null
                          : () => Navigator.push(context,
                              xyRoute(ProfilPublikScreen(userId: b.userId))),
                      child: AvatarBingkai(
                          bingkai: b.bingkai,
                          size: 34,
                          child: _Avatar(
                              nama: nama,
                              foto: s.fotoPengguna(b.userId, b.foto),
                              ukuran: 34,
                              admin: b.admin)))),
              const SizedBox(width: 10),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    // Batch L: komentar gaya flat tanpa bubble — bersih
                    // seperti thread modern; pemisah cukup garis thread kiri.
                    Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(2, 2, 4, 4),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 2,
                                  runSpacing: 3,
                                  children: [
                                    GayaNama(nama,
                                        gaya: b.gayaNama,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700)),
                                    if (b.admin || b.tier != 'basic')
                                      LencanaTier(b.admin ? 'admin' : b.tier),
                                    if (b.badge != null) LencanaKhusus(b.badge!)
                                  ]),
                              if (parent != null) ...[
                                const SizedBox(height: 8),
                                // Kutipan "membalas siapa" bergaya chip dengan
                                // aksen garis kiri — beda dari teks isi & nama.
                                Container(
                                    padding: const EdgeInsets.fromLTRB(
                                        9, 6, 10, 6),
                                    decoration: BoxDecoration(
                                        color: XyTheme.primary.withOpacity(.08),
                                        borderRadius:
                                            BorderRadius.circular(10),
                                        border: Border(
                                            left: BorderSide(
                                                color: XyTheme.primary,
                                                width: 3))),
                                    child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.reply_rounded,
                                              size: 12,
                                              color: XyTheme.primary),
                                          const SizedBox(width: 5),
                                          Flexible(
                                              child: Text.rich(TextSpan(
                                                  children: [
                                                    TextSpan(
                                                        text: 'Membalas ',
                                                        style: TextStyle(
                                                            fontSize: 11,
                                                            color: pal.muted,
                                                            fontWeight:
                                                                FontWeight
                                                                    .w600)),
                                                    TextSpan(
                                                        text: s.namaPengguna(
                                                            parent.userId,
                                                            parent.nama),
                                                        style: TextStyle(
                                                            fontSize: 11,
                                                            color: XyTheme
                                                                .primary,
                                                            fontWeight:
                                                                FontWeight
                                                                    .w800)),
                                                  ]),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis)),
                                        ]))
                              ],
                              if (b.isi.isNotEmpty) ...[
                                const SizedBox(height: 7),
                                teksForum(
                                    b.isi,
                                    TextStyle(
                                        fontSize: 13.5,
                                        height: 1.6,
                                        color: pal.inkSoft))
                              ],
                              if (b.stiker != null) ...[
                                const SizedBox(height: 8),
                                GestureDetector(
                                    onTap: () => menuStiker(context, b.stiker!),
                                    onLongPress: () =>
                                        menuStiker(context, b.stiker!),
                                    child:
                                        GambarStiker(b.stiker!, ukuran: 156)),
                                if (b.stiker!.dariGiphy)
                                  Text('via GIPHY',
                                      style: TextStyle(
                                          fontSize: 10, color: pal.muted))
                              ],
                              const SizedBox(height: 6),
                              Align(
                                  alignment: Alignment.bottomRight,
                                  child: WaktuRelatif(b.dibuat)),
                            ])),
                    Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          TextButton.icon(
                              style: TextButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 8),
                                  minimumSize: const Size(40, 38)),
                              onPressed: () async {
                                final n = await s.sukaBalasan(b.id);
                                if (mounted && n != null)
                                  setState(() => b.suka = n);
                              },
                              icon: Icon(
                                  s.balasanDisukai.contains(b.id)
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                  size: 15,
                                  color: s.balasanDisukai.contains(b.id)
                                      ? XyTheme.danger
                                      : pal.muted),
                              label: Text('${b.suka}',
                                  style: TextStyle(
                                      fontSize: 11, color: pal.muted))),
                          TextButton(
                              onPressed: _mengirim
                                  ? null
                                  : () {
                                      setState(() => _reply = b);
                                      if (_balas.text.isEmpty) {
                                        final targetNama = s.namaPengguna(b.userId, b.nama);
                                        _balas.text = '@$targetNama ';
                                        _balas.selection = TextSelection.collapsed(offset: _balas.text.length);
                                      }
                                      _fokusBalas.requestFocus();
                                    },
                              style: TextButton.styleFrom(
                                  minimumSize: const Size(40, 38),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8)),
                              child: Text('Balas',
                                  style: TextStyle(
                                      fontSize: 11.5, color: pal.accent))),
                          PopupMenuButton<String>(
                              tooltip: 'Opsi komentar',
                              icon: Icon(Icons.more_horiz_rounded,
                                  size: 18, color: pal.muted),
                              padding: EdgeInsets.zero,
                              onSelected: (v) {
                                if (v == 'hapus')
                                  _hapusBalasan(b);
                                else
                                  _lapor('balasan', b.id);
                              },
                              itemBuilder: (_) => [
                                    if (b.userId == s.user?.id)
                                      const PopupMenuItem(
                                          value: 'hapus',
                                          child: Text('Hapus komentar'))
                                    else
                                      const PopupMenuItem(
                                          value: 'lapor',
                                          child: Text('Laporkan komentar'))
                                  ]),
                        ]),
                  ])),
            ])));
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
          PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'lapor') {
                  await _lapor('forum', p.id);
                  return;
                }
                if (!await konfirmasi(context,
                        judul: 'Hapus diskusi?',
                        pesan: 'Seluruh komentar di diskusi ini ikut terhapus.',
                        tombolYa: 'Hapus',
                        bahaya: true) ||
                    !mounted) return;
                final e = await s.hapusForum(p.id);
                if (!mounted) return;
                if (e == null) {
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(e)));
                }
              },
              itemBuilder: (_) => [
                    PopupMenuItem(
                        value: milik ? 'hapus' : 'lapor',
                        child:
                            Text(milik ? 'Hapus diskusi' : 'Laporkan diskusi'))
                  ]),
        ]),
        body: Column(children: [
          Expanded(
              child: RefreshIndicator(
                  onRefresh: () => _muat(),
                  child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
                      itemCount: rows.length + 2,
                      itemBuilder: (ctx, i) {
                        if (i == 0) return _post(p, s);
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
                                      Text('${_balasan.length}',
                                          style: TextStyle(color: pal.muted))
                                    ]),
                                    if (p.balasan > 200)
                                      Text('Menampilkan 200 komentar terbaru',
                                          style: TextStyle(
                                              color: pal.muted, fontSize: 11)),
                                    if (_memuat) ...[
                                      const SizedBox(height: 12),
                                      const LinearProgressIndicator(
                                          minHeight: 2)
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
                        return KeyedSubtree(
                            key: ValueKey(rows[i - 2].komentar.id),
                            child: _komentar(rows[i - 2], s));
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
      return CircleAvatar(
          radius: ukuran / 2, backgroundImage: NetworkImage(foto!));
    }
    return Container(
      width: ukuran,
      height: ukuran,
      decoration: BoxDecoration(
        gradient: admin ? XyTheme.gradDeep : XyTheme.gradPrimary,
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
