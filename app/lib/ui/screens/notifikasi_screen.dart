import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/format.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/app_state.dart';
import '../widgets/common.dart';
import '../widgets/lembar.dart';
import 'forum_screen.dart';
import 'profil_publik_screen.dart';

/// ============================================================
///  Pusat pemberitahuan
/// ============================================================
///  Menampung semua kabar: suka, balasan, peringatan admin,
///  pesanan, dan saldo. Menyentuh satu baris membawa pengguna
///  ke tempat kejadiannya.
class NotifikasiScreen extends StatefulWidget {
  const NotifikasiScreen({super.key});

  @override
  State<NotifikasiScreen> createState() => _NotifikasiScreenState();
}

class _NotifikasiScreenState extends State<NotifikasiScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().muatNotifikasi();
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final daftar = s.notifikasi;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pemberitahuan'),
        actions: [
          if (daftar.isNotEmpty)
            IconButton(
              tooltip: 'Tandai semua dibaca',
              icon: const Icon(Icons.done_all_rounded),
              onPressed: () => s.bacaNotifikasi(),
            ),
          if (daftar.isNotEmpty)
            IconButton(
              tooltip: 'Bersihkan',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () async {
                final yakin = await konfirmasi(
                  context,
                  judul: 'Bersihkan semua pemberitahuan?',
                  pesan: 'Daftar ini akan dikosongkan. Kabar baru tetap akan masuk seperti biasa.',
                  tombolYa: 'Bersihkan',
                  ikon: Icons.delete_sweep_outlined,
                  bahaya: true,
                );
                if (yakin) await s.hapusNotifikasi();
              },
            ),
        ],
      ),
      body: s.notifMemuat && daftar.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : daftar.isEmpty
              ? const Kosong(
                  icon: Icons.notifications_none_rounded,
                  judul: 'Belum ada pemberitahuan',
                  sub: 'Kabar tentang pesanan, komunitas, dan saldo akan muncul di sini.',
                  ilustrasi: 'notifikasi',
                )
              : RefreshIndicator(
                  color: XyTheme.primary,
                  onRefresh: () => s.muatNotifikasi(),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
                    itemCount: daftar.length,
                    itemBuilder: (_, i) => _Baris(notif: daftar[i]),
                  ),
                ),
    );
  }
}

class _Baris extends StatelessWidget {
  const _Baris({required this.notif});
  final Notifikasi notif;

  (IconData, Color) _tampilan(BuildContext context) => switch (notif.jenis) {
        'suka' => (Icons.favorite_rounded, XyTheme.danger),
        'balasan' => (Icons.reply_rounded, XyTheme.primary),
        'komunitas' => (Icons.groups_2_rounded, XyTheme.violet),
        'peringatan' => (Icons.warning_amber_rounded, XyTheme.warning),
        'sistem' => (Icons.verified_user_rounded, XyTheme.primary),
        'order' => (Icons.receipt_long_rounded, XyTheme.success),
        'wallet' => (Icons.account_balance_wallet_rounded, XyTheme.success),
        _ => (Icons.notifications_rounded, XyTheme.of(context).muted),
      };

  Future<void> _buka(BuildContext context) async {
    final s = context.read<AppState>();
    await s.bacaNotifikasi(id: notif.id);
    if (!context.mounted) return;

    // Audit 2026-09-18: notifikasi sosial (mis. "mulai mengikuti kamu")
    // membawa ke profil aktornya — sebelumnya ketukan tidak berbuat apa-apa.
    if (notif.refJenis == 'profil' && notif.refId != null) {
      Navigator.push(
          context, xyRoute(ProfilPublikScreen(userId: notif.refId!)));
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final (ikon, warna) = _tampilan(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: XyCard(
        padding: const EdgeInsets.all(14),
        onTap: () => _buka(context),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: warna.withOpacity(.11), borderRadius: BorderRadius.circular(14)),
            child: Icon(ikon, size: 19, color: warna),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(
                    notif.judul,
                    style: TextStyle(
                      fontWeight: notif.dibaca ? FontWeight.w700 : FontWeight.w700,
                      fontSize: 13.8,
                      height: 1.35,
                    ),
                  ),
                ),
                if (!notif.dibaca)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(left: 8, top: 4),
                    decoration: BoxDecoration(color: XyTheme.primary, shape: BoxShape.circle),
                  ),
              ]),
              if (notif.pesan.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(notif.pesan,
                    style:  TextStyle(color: XyTheme.of(context).muted, fontSize: 12.5, height: 1.5)),
              ],
              const SizedBox(height: 6),
              Text(tanggal(notif.dibuat),
                  style:  TextStyle(color: XyTheme.of(context).muted, fontSize: 11)),
            ]),
          ),
        ]),
      ),
    );
  }
}
