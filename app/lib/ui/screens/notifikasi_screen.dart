import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/format.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/app_state.dart';
import '../widgets/common.dart';
import '../widgets/lembar.dart';
import 'dm_chat_screen.dart';
import 'forum_screen.dart';
import 'livestream_screen.dart';
import 'order_list_screen.dart';
import 'profil_publik_screen.dart';
import 'wallet_screen.dart';

/// ============================================================
///  Pusat Pemberitahuan Modern (Card-Free Feed UI/UX)
/// ============================================================
///  Didesain bersih tanpa kartu tebal berulang:
///  - Feed interaktif dengan pembatas garis halus
///  - Indikator "Baru" menyala untuk notifikasi belum dibaca
///  - Tab filter cepat: Semua, Belum Dibaca, Transaksi, Sosial
///  - Waktu relatif manusiawi (5m lalu, 2j lalu, Kemarin)
class NotifikasiScreen extends StatefulWidget {
  const NotifikasiScreen({super.key});

  @override
  State<NotifikasiScreen> createState() => _NotifikasiScreenState();
}

class _NotifikasiScreenState extends State<NotifikasiScreen> {
  String _filterAktif = 'semua';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().muatNotifikasi();
    });
  }

  List<Notifikasi> _saringDaftar(List<Notifikasi> asal) {
    switch (_filterAktif) {
      case 'belum_dibaca':
        return asal.where((n) => !n.dibaca).toList();
      case 'transaksi':
        return asal.where((n) => ['order', 'sewa', 'wallet', 'topup'].contains(n.jenis)).toList();
      case 'sosial':
        return asal.where((n) => ['suka', 'balasan', 'komunitas', 'dm', 'livestream'].contains(n.jenis)).toList();
      default:
        return asal;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final semua = s.notifikasi;
    final daftar = _saringDaftar(semua);
    final belumDibacaCount = semua.where((n) => !n.dibaca).length;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Pemberitahuan'),
            if (belumDibacaCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: XyTheme.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$belumDibacaCount baru',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (semua.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              tooltip: 'Opsi pemberitahuan',
              onSelected: (aksi) async {
                if (aksi == 'baca_semua') {
                  await s.bacaNotifikasi();
                } else if (aksi == 'bersihkan') {
                  final yakin = await konfirmasi(
                    context,
                    judul: 'Bersihkan semua notifikasi?',
                    pesan: 'Daftar pemberitahuan akan dikosongkan secara permanen.',
                    tombolYa: 'Bersihkan',
                    ikon: Icons.delete_sweep_outlined,
                    bahaya: true,
                  );
                  if (yakin && mounted) await s.hapusNotifikasi();
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'baca_semua',
                  child: Row(
                    children: [
                      Icon(Icons.done_all_rounded, size: 18),
                      SizedBox(width: 10),
                      Text('Tandai semua dibaca'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'bersihkan',
                  child: Row(
                    children: [
                      Icon(Icons.delete_sweep_outlined, size: 18, color: XyTheme.danger),
                      SizedBox(width: 10),
                      Text('Bersihkan semua', style: TextStyle(color: XyTheme.danger)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          // Filter chip horizontal bar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
            child: Row(
              children: [
                _FilterChip(
                  label: 'Semua',
                  count: semua.length,
                  aktif: _filterAktif == 'semua',
                  onTap: () => setState(() => _filterAktif = 'semua'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Belum Dibaca',
                  count: belumDibacaCount,
                  aktif: _filterAktif == 'belum_dibaca',
                  onTap: () => setState(() => _filterAktif = 'belum_dibaca'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Transaksi',
                  aktif: _filterAktif == 'transaksi',
                  onTap: () => setState(() => _filterAktif = 'transaksi'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Sosial & Komunitas',
                  aktif: _filterAktif == 'sosial',
                  onTap: () => setState(() => _filterAktif = 'sosial'),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
          ),

          // Konten Utama
          Expanded(
            child: s.notifMemuat && semua.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : daftar.isEmpty
                    ? Center(
                        child: Kosong(
                          icon: _filterAktif == 'belum_dibaca'
                              ? Icons.mark_email_read_rounded
                              : Icons.notifications_none_rounded,
                          judul: _filterAktif == 'belum_dibaca'
                              ? 'Semua sudah dibaca'
                              : 'Tidak ada pemberitahuan',
                          sub: _filterAktif == 'belum_dibaca'
                              ? 'Bagus! Tidak ada kabar yang terlewatkan.'
                              : 'Kabar tentang transaksi, komunitas, dan akun akan muncul di sini.',
                          ilustrasi: 'notifikasi',
                        ),
                      )
                    : RefreshIndicator(
                        color: XyTheme.primary,
                        onRefresh: () => s.muatNotifikasi(),
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: daftar.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            thickness: 1,
                            indent: 68,
                            color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                          ),
                          itemBuilder: (_, i) => _ItemNotifikasi(notif: daftar[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    this.count,
    required this.aktif,
    required this.onTap,
  });

  final String label;
  final int? count;
  final bool aktif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          decoration: BoxDecoration(
            color: aktif
                ? XyTheme.primary
                : (isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04)),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: aktif
                  ? Colors.transparent
                  : (isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.08)),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: aktif ? FontWeight.w700 : FontWeight.w500,
                  color: aktif ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                ),
              ),
              if (count != null && count! > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: aktif ? Colors.white.withOpacity(0.25) : XyTheme.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: aktif ? Colors.white : XyTheme.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemNotifikasi extends StatelessWidget {
  const _ItemNotifikasi({required this.notif});
  final Notifikasi notif;

  (IconData, Color, String) _tampilan(BuildContext context) => switch (notif.jenis) {
        'suka' => (Icons.favorite_rounded, const Color(0xFFF43F5E), 'Suka'),
        'balasan' => (Icons.reply_rounded, XyTheme.primary, 'Balasan'),
        'komunitas' => (Icons.groups_2_rounded, const Color(0xFF8B5CF6), 'Komunitas'),
        'peringatan' => (Icons.warning_amber_rounded, const Color(0xFFF59E0B), 'Penting'),
        'sistem' => (Icons.verified_user_rounded, const Color(0xFF3B82F6), 'Sistem'),
        'order' => (Icons.receipt_long_rounded, const Color(0xFF10B981), 'Pesanan'),
        'wallet' => (Icons.account_balance_wallet_rounded, const Color(0xFF059669), 'Dompet'),
        'dm' => (Icons.chat_bubble_rounded, const Color(0xFF8B5CF6), 'Pesan'),
        'livestream' => (Icons.live_tv_rounded, const Color(0xFFEC4899), 'Live'),
        _ => (Icons.notifications_rounded, XyTheme.primary, 'Kabar'),
      };

  String _formatWaktuRelatif(DateTime dt) {
    final now = DateTime.now();
    final beda = now.difference(dt);
    if (beda.inMinutes < 1) return 'Baru saja';
    if (beda.inMinutes < 60) return '${beda.inMinutes}m lalu';
    if (beda.inHours < 24) return '${beda.inHours}j lalu';
    if (beda.inDays == 1) return 'Kemarin';
    if (beda.inDays < 7) return '${beda.inDays}h lalu';
    return tanggal(dt);
  }

  Future<void> _buka(BuildContext context) async {
    final s = context.read<AppState>();
    await s.bacaNotifikasi(id: notif.id);
    if (!context.mounted) return;

    if (notif.refJenis == 'profil' && notif.refId != null) {
      Navigator.push(context, xyRoute(ProfilPublikScreen(userId: notif.refId!)));
      return;
    }
    if (notif.refJenis == 'forum' && notif.refId != null) {
      final post = s.forum.where((f) => f.id == notif.refId).toList();
      if (post.isNotEmpty) {
        Navigator.push(context, xyRoute(ForumDetailScreen(post: post.first)));
      } else {
        await s.muatForum(paksa: true);
        if (!context.mounted) return;
        final lagi = s.forum.where((f) => f.id == notif.refId).toList();
        if (lagi.isNotEmpty) {
          Navigator.push(context, xyRoute(ForumDetailScreen(post: lagi.first)));
        }
      }
      return;
    }
    if ((notif.refJenis == 'dm' || notif.jenis == 'dm') && notif.refId != null) {
      Navigator.push(
        context,
        xyRoute(DmChatScreen(
          userId: notif.refId!,
          nama: notif.aktor ?? 'Pengguna',
        )),
      );
      return;
    }
    if (notif.refJenis == 'livestream' || notif.jenis == 'livestream') {
      Navigator.push(context, xyRoute(const XyLiveScreen()));
      return;
    }
    if (notif.refJenis == 'order' || notif.refJenis == 'sewa' || notif.jenis == 'order') {
      Navigator.push(context, xyRoute(const OrderListScreen()));
      return;
    }
    if (notif.refJenis == 'wallet' || notif.refJenis == 'topup' || notif.jenis == 'wallet') {
      Navigator.push(context, xyRoute(const WalletScreen()));
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final (ikon, warna, badgeLabel) = _tampilan(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: notif.dibaca
          ? Colors.transparent
          : (isDark ? XyTheme.primary.withOpacity(0.08) : XyTheme.primary.withOpacity(0.05)),
      child: InkWell(
        onTap: () => _buka(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar / Icon badge
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: warna.withOpacity(0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(ikon, size: 20, color: warna),
              ),
              const SizedBox(width: 14),

              // Teks isi pemberitahuan
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Label kategori kecil
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: warna.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badgeLabel,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: warna,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Waktu relatif
                        Text(
                          _formatWaktuRelatif(notif.dibuat),
                          style: TextStyle(
                            color: isDark ? Colors.white38 : Colors.black38,
                            fontSize: 11,
                          ),
                        ),
                        const Spacer(),
                        // Titik indikator belum dibaca
                        if (!notif.dibaca)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: XyTheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      notif.judul,
                      style: TextStyle(
                        fontWeight: notif.dibaca ? FontWeight.w600 : FontWeight.w700,
                        fontSize: 14,
                        letterSpacing: -0.2,
                        color: notif.dibaca
                            ? (isDark ? Colors.white.withOpacity(0.85) : Colors.black87)
                            : (isDark ? Colors.white : Colors.black),
                      ),
                    ),
                    if (notif.pesan.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        notif.pesan,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDark ? Colors.white60 : Colors.black54,
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
