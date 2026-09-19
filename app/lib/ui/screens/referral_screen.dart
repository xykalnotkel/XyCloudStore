import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/referral_attribution.dart';
import '../../providers/app_state.dart';
import '../widgets/common.dart';
import '../widgets/error_state.dart';

/// ============================================================
///  Undang teman: kode referral, bonus, dan daftar undangan
/// ============================================================
class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  Map<String, dynamic>? data;
  String? galat;
  final _kode = TextEditingController();
  bool proses = false;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  @override
  void dispose() {
    _kode.dispose();
    super.dispose();
  }

  Future<void> _muat() async {
    setState(() => galat = null);
    try {
      final state = context.read<AppState>();
      // Menangkap deep link baru bila Activity membangunkan app yang sudah hidup,
      // lalu mencoba klaim otomatis setelah login/verifikasi tersedia.
      await state.sinkronAtribusiReferral();
      final d = await state.dataReferral();
      final attr = d['atribusi'];
      final kodeTiket = ReferralAttribution.kode ??
          (attr is Map ? '${attr['kode'] ?? ''}' : '');
      if (mounted) {
        if (_kode.text.isEmpty && kodeTiket.isNotEmpty) _kode.text = kodeTiket;
        setState(() => data = d);
      }
    } catch (e) {
      if (mounted) setState(() => galat = 'Belum bisa memuat data undangan.');
    }
  }

  Future<void> _pakaiKode() async {
    final kode = _kode.text.trim().toUpperCase();
    if (kode.length < 4) {
      setState(() => galat = 'Kode referral terlalu pendek');
      return;
    }
    setState(() {
      proses = true;
      galat = null;
    });

    final s = context.read<AppState>();
    final hasil = await s.pakaiReferral(kode);
    if (!mounted) return;
    setState(() => proses = false);

    if (hasil == null) {
      setState(() => galat = s.error ?? 'Kode tidak bisa dipakai');
      return;
    }
    _kode.clear();
    await _muat();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Bonus ${rupiah(hasil['bonus'] ?? 0)} masuk ke saldomu.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final sudahDiundang = (s.user?.diundangOleh ?? '').isNotEmpty;
    final programAktif = data?['aktif'] != false;
    final punyaTiket = ReferralAttribution.ada;
    final atribusiOk = s.atribusiReferral?['ok'] == true ||
        ['terpasang', 'diklaim'].contains(s.atribusiReferral?['status']);
    final daftar = (data?['daftar'] as List?) ?? const [];

    return Scaffold(
      appBar: AppBar(title: const Text('Undang Teman')),
      body: data == null && galat != null
          ? GagalMuat(pesan: galat!, ilustrasi: 'offline', onCoba: _muat)
          : data == null
              ? const Padding(padding: EdgeInsets.all(20), child: SkeletonCard(height: 220))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
                  children: [
                    // ---- kartu kode ----
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        gradient: XyTheme.gradDeep,
                        borderRadius: BorderRadius.circular(XyRadius.xl),
                        boxShadow: XyTheme.glow(XyTheme.primary, .24),
                      ),
                      child: Column(children: [
                        Text('Kode referralmu',
                            style: TextStyle(color: Colors.white.withOpacity(.68), fontSize: 12.5)),
                        const SizedBox(height: 10),
                        Text(
                          '${data!['kode'] ?? '-'}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 4,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(children: [
                          Expanded(
                            child: Pressable(
                              onTap: programAktif ? () {
                                Clipboard.setData(ClipboardData(text: '${data!['tautan']}'));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Tautan undangan disalin'), duration: Duration(seconds: 1)),
                                );
                              } : null,
                              child: Container(
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(XyRadius.pill),
                                ),
                                child: const Center(
                                  child: Text('Salin Tautan',
                                      style: TextStyle(
                                          color: XyTheme.primaryDeep,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13.5)),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Pressable(
                              onTap: programAktif ? () {
                                Clipboard.setData(ClipboardData(
                                  text: 'Pasang XyCloudStore dari tautan undanganku ${data!['tautan']}. '
                                      'Sesudah APK terpasang, tekan “Buka aplikasi & aktifkan undangan”, '
                                      'buat akun baru, lalu verifikasi email agar kita berdua mendapat bonus.',
                                ));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Ajakan disalin, tinggal tempel ke chat')),
                                );
                              } : null,
                              child: Container(
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(.14),
                                  borderRadius: BorderRadius.circular(XyRadius.pill),
                                  border: Border.all(color: Colors.white.withOpacity(.2)),
                                ),
                                child: const Center(
                                  child: Text('Salin Ajakan',
                                      style: TextStyle(
                                          color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13.5)),
                                ),
                              ),
                            ),
                          ),
                        ]),
                      ]),
                    ),

                    if (!programAktif) ...[
                      const SizedBox(height: 14),
                      const XyCard(
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Icon(Icons.system_update_rounded, color: XyTheme.warning),
                          SizedBox(width: 11),
                          Expanded(
                            child: Text(
                              'Pembagian tautan baru dipause sampai APK terbaru yang mendukung verifikasi instalasi resmi dirilis. Riwayat dan bonus lama tetap aman.',
                              style: TextStyle(fontSize: 12.5, height: 1.55, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ]),
                      ),
                    ],
                    const SizedBox(height: 18),
                    XyCard(
                      child: Column(children: [
                        Row(children: [
                          Expanded(
                            child: Column(children: [
                              Text(rupiah(data!['bonusPengundang'] ?? 0),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700, fontSize: 18, color: XyTheme.primary)),
                              const SizedBox(height: 3),
                               Text('Bonus untukmu',
                                  style: TextStyle(color: XyTheme.of(context).muted, fontSize: 11.5)),
                            ]),
                          ),
                          Container(width: 1, height: 36, color: XyTheme.of(context).line),
                          Expanded(
                            child: Column(children: [
                              Text(rupiah(data!['bonusDiundang'] ?? 0),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700, fontSize: 18, color: XyTheme.success)),
                              const SizedBox(height: 3),
                               Text('Bonus temanmu',
                                  style: TextStyle(color: XyTheme.of(context).muted, fontSize: 11.5)),
                            ]),
                          ),
                          Container(width: 1, height: 36, color: XyTheme.of(context).line),
                          Expanded(
                            child: Column(children: [
                              Text(rupiah(data!['totalBonus'] ?? 0),
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                              const SizedBox(height: 3),
                               Text('Total didapat',
                                  style: TextStyle(color: XyTheme.of(context).muted, fontSize: 11.5)),
                            ]),
                          ),
                        ]),
                        const SizedBox(height: 14),
                         Text(
                          'Bagikan tautannya. Bonus cair setelah teman mengunduh dan memasang baru APK dari tautan itu, membuka aplikasi, membuat akun baru di perangkat yang sama, dan memverifikasi email.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: XyTheme.of(context).muted, fontSize: 12.3, height: 1.55),
                        ),
                      ]),
                    ),

                    // ---- status/aktivasi atribusi install ----
                    if (s.pesanAtribusiReferral != null) ...[
                      const SizedBox(height: 14),
                      XyCard(
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Icon(
                            atribusiOk ? Icons.verified_rounded : Icons.info_outline_rounded,
                            color: atribusiOk ? XyTheme.success : XyTheme.warning,
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Text(
                              s.pesanAtribusiReferral!,
                              style: const TextStyle(fontSize: 12.5, height: 1.5, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ]),
                      ),
                    ],
                    if (sudahDiundang) ...[
                      const SectionHeader('Status Referral'),
                      XyCard(
                        child: Row(children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: XyTheme.success.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check_circle_rounded, color: XyTheme.success, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Bonus Referral Aktif',
                                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                                const SizedBox(height: 2),
                                Text('Kamu sudah menerima bonus pendaftaran melalui referral.',
                                    style: TextStyle(color: XyTheme.of(context).muted, fontSize: 11.5)),
                              ],
                            ),
                          ),
                        ]),
                      ),
                    ] else if (punyaTiket) ...[
                      const SectionHeader('Aktifkan Undangan Resmi'),
                      XyCard(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Row(children: [
                            Icon(Icons.verified_rounded, color: XyTheme.success, size: 20),
                            SizedBox(width: 8),
                            Text('Tiket Undangan Resmi Terdeteksi',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                          ]),
                          const SizedBox(height: 8),
                          Text(
                            'Aplikasi dipasang melalui tautan undangan resmi temanmu (${_kode.text.isEmpty ? 'resmi' : 'Kode: ' + _kode.text}). Tekan tombol di bawah untuk mengaktifkan bonus saldo Rp${rupiah(data!['bonusDiundang'] ?? 5000)}.',
                            style: TextStyle(fontSize: 12.5, height: 1.5, color: XyTheme.of(context).inkSoft),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: GradientButton(
                              label: 'Klaim Bonus Saldo Undangan',
                              height: 48,
                              loading: proses,
                              onPressed: proses ? null : _pakaiKode,
                            ),
                          ),
                          if (galat != null) ...[
                            const SizedBox(height: 10),
                            Row(children: [
                              const Icon(Icons.error_outline_rounded, size: 16, color: XyTheme.danger),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(galat!,
                                    style: const TextStyle(
                                        color: XyTheme.danger, fontSize: 12, fontWeight: FontWeight.w600)),
                              ),
                            ]),
                          ],
                        ]),
                      ),
                    ] else ...[
                      const SectionHeader('Menerima Undangan Teman?'),
                      XyCard(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: XyTheme.primary.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.link_rounded, color: XyTheme.primary, size: 20),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Wajib Melalui Tautan Unduhan',
                                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                                  SizedBox(height: 2),
                                  Text('Kebijakan Anti-Farming & Bot Akun',
                                      style: TextStyle(fontSize: 11, color: XyTheme.warning)),
                                ],
                              ),
                            ),
                          ]),
                          const SizedBox(height: 12),
                          Text(
                            'Minta temanmu mengirim tautan unduhan referral. Kode yang diketik tanpa mengunduh dan membuka aplikasi dari tautan itu tidak dapat menghasilkan bonus demi mencegah farming akun dan akun palsu.',
                            style: TextStyle(color: XyTheme.of(context).muted, fontSize: 12.3, height: 1.55),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: XyTheme.of(context).surfaceHigh,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: XyTheme.of(context).line),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Cara Mendapatkan Bonus:',
                                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                                const SizedBox(height: 6),
                                _LangkahUndangan('1', 'Buka tautan undangan yang dibagikan temanmu di browser.'),
                                const SizedBox(height: 4),
                                _LangkahUndangan('2', 'Unduh dan pasang APK XyCloudStore dari halaman tersebut.'),
                                const SizedBox(height: 4),
                                _LangkahUndangan('3', 'Buka aplikasi dari tombol aktivasi, daftar akun baru & verifikasi email.'),
                              ],
                            ),
                          ),
                        ]),
                      ),
                    ],

                    // ---- daftar undangan ----
                    SectionHeader('Teman yang bergabung', sub: '${daftar.length} orang'),
                    if (daftar.isEmpty)
                      const Kosong(
                        icon: Icons.group_add_outlined,
                        judul: 'Belum ada yang bergabung',
                        sub: 'Bagikan kodemu ke grup atau teman main.',
                        ilustrasi: 'forum',
                      )
                    else
                      ...daftar.map((r) {
                        final m = r as Map;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: XyCard(
                            padding: const EdgeInsets.all(14),
                            child: Row(children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration:
                                    BoxDecoration(gradient: XyTheme.gradPrimary, shape: BoxShape.circle),
                                child: Center(
                                  child: Text(
                                    '${m['nama_diundang'] ?? 'X'}'.characters.first.toUpperCase(),
                                    style: const TextStyle(
                                        color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text('${m['nama_diundang'] ?? 'Pengguna baru'}',
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                                  const SizedBox(height: 3),
                                  Text('${m['dibuat'] ?? ''}'.replaceFirst('T', ' ').split('.').first,
                                      style:  TextStyle(color: XyTheme.of(context).muted, fontSize: 11)),
                                ]),
                              ),
                              Text('+ ${rupiah(m['bonus_pengundang'] ?? 0)}',
                                  style: const TextStyle(
                                      color: XyTheme.success, fontWeight: FontWeight.w700, fontSize: 13)),
                            ]),
                          ),
                        );
                      }),
                  ],
                ),
    );
  }
}

class _LangkahUndangan extends StatelessWidget {
  const _LangkahUndangan(this.nomor, this.teks);
  final String nomor;
  final String teks;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: XyTheme.primary.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              nomor,
              style: const TextStyle(
                color: XyTheme.primary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            teks,
            style: TextStyle(
              fontSize: 11.5,
              color: XyTheme.of(context).inkSoft,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}
