import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../providers/app_state.dart';
import '../widgets/common.dart';
import '../widgets/elemen_melayang.dart';
import 'cs_screen.dart';

/// ============================================================
///  Layar Akun Dibekukan — blokir sementara & permanen
/// ============================================================
///  Menggantikan seluruh aplikasi saat `user.diblokir` benar. Menampilkan:
///   - jenis pembekuan (SEMENTARA dengan hitung mundur, atau PERMANEN),
///   - alasan pembekuan,
///   - riwayat pelanggaran yang tercatat di server,
///   - formulir banding dalam aplikasi + status banding sebelumnya,
///   - jalan ke chat CS dan keluar akun.
///  Pengguna hanya bisa menyentuh layar ini, chat CS, dan pemberitahuan
///  (dibatasi di sisi server).
class BlokirScreen extends StatefulWidget {
  const BlokirScreen({super.key});

  @override
  State<BlokirScreen> createState() => _BlokirScreenState();
}

class _BlokirScreenState extends State<BlokirScreen> {
  final _ctl = TextEditingController();
  bool _kirim = false;
  String? _galat;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().muatInfoBlokir();
    });
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  Future<void> _kirimBanding() async {
    final pesan = _ctl.text.trim();
    setState(() {
      _kirim = true;
      _galat = null;
    });
    final galat = await context.read<AppState>().ajukanBanding(pesan);
    if (!mounted) return;
    setState(() {
      _kirim = false;
      _galat = galat;
    });
    if (galat == null) _ctl.clear();
  }

  static String _tanggal(String iso) {
    final d = DateTime.tryParse(iso)?.toLocal();
    if (d == null) return iso;
    String p(int n) => n.toString().padLeft(2, '0');
    return '${p(d.day)}/${p(d.month)}/${d.year} ${p(d.hour)}:${p(d.minute)}';
  }

  static String _sisa(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return '';
    final sel = d.difference(DateTime.now());
    if (sel.isNegative) return 'segera pulih';
    final hari = sel.inDays;
    final jam = sel.inHours % 24;
    final menit = sel.inMinutes % 60;
    if (hari > 0) return '$hari hari $jam jam lagi';
    if (jam > 0) return '$jam jam $menit menit lagi';
    return '$menit menit lagi';
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final p = XyTheme.of(context);
    final info = s.infoBlokir;
    final u = s.user;

    return Scaffold(
      backgroundColor: p.bg,
      // Batch L: partikel apung lembut supaya layar tidak terasa "mati"
      // — nadanya tenang (biru dingin), bukan meriah.
      body: ElemenMelayang(
        jumlah: 7,
        warna: [
          const Color(0xFF64748B).withOpacity(.14),
          XyTheme.primary.withOpacity(.10),
          const Color(0xFF94A3B8).withOpacity(.12),
        ],
        child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          children: [
            // Batch J: ilustrasi hero generate AI (sebelumnya hanya ikon).
            Center(child: XyIlustrasi('blokir', tinggi: 170)),
            const SizedBox(height: 12),
            // ---------------- kepala: jenis pembekuan ----------------
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: XyTheme.danger.withOpacity(.12),
                    borderRadius: BorderRadius.circular(XyRadius.md),
                    border: Border.all(color: XyTheme.danger.withOpacity(.35)),
                  ),
                  child: Icon(Icons.lock_rounded, color: XyTheme.danger, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Akun Dibekukan',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -.4),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(
                          color: (info?.sementara ?? false)
                              ? XyTheme.warning.withOpacity(.14)
                              : XyTheme.danger.withOpacity(.14),
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(
                            color: (info?.sementara ?? false)
                                ? XyTheme.warning.withOpacity(.5)
                                : XyTheme.danger.withOpacity(.5)),
                        ),
                        child: Text(
                          (info?.sementara ?? false) ? 'BLOKIR SEMENTARA' : 'BLOKIR PERMANEN',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                            color: (info?.sementara ?? false) ? XyTheme.warning : XyTheme.danger,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => s.muatInfoBlokir(),
                  tooltip: 'Muat ulang status',
                  icon: Icon(Icons.refresh_rounded, color: p.muted, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ---------------- masa & alasan ----------------
            if (info?.sementara ?? false) ...[
              _Kartu(
                ikon: Icons.hourglass_bottom_rounded,
                judul: 'Pulih otomatis',
                isi: 'Akunmu aktif kembali ${_sisa(info!.sampai!)} (sekitar ${_tanggal(info.sampai!)}). '
                    'Kamu tidak perlu melakukan apa-apa setelah masa itu lewat.',
              ),
              const SizedBox(height: 10),
            ],
            if ((info?.alasan ?? u?.alasanBlokir) != null) ...[
              _Kartu(
                ikon: Icons.flag_rounded,
                judul: 'Alasan pembekuan',
                isi: info?.alasan ?? u?.alasanBlokir ?? '',
              ),
              const SizedBox(height: 10),
            ],

            // ---------------- riwayat pelanggaran ----------------
            _JudulSeksi('Riwayat Pelanggaran'),
            const SizedBox(height: 8),
            if (info == null)
              _Kartu(ikon: Icons.hourglass_top_rounded, judul: 'Memuat…', isi: 'Mengambil status akun dari server.')
            else if (info.pelanggaran.isEmpty)
              _Kartu(
                ikon: Icons.verified_user_rounded,
                judul: 'Tidak ada catatan',
                isi: 'Tidak ada riwayat pelanggaran lain pada akun ini.',
              )
            else
              ...info.pelanggaran.map(
                (pl) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _Kartu(
                    ikon: Icons.warning_amber_rounded,
                    judul: pl.jenis == 'peringatan' ? 'Peringatan' : 'Pembekuan',
                    isi: pl.alasan.isEmpty ? '(tanpa keterangan)' : pl.alasan,
                    kaki: _tanggal(pl.waktu) +
                        (pl.sampai != null && pl.sampai!.isNotEmpty
                            ? ' · s/d ${_tanggal(pl.sampai!)}'
                            : ' · permanen'),
                  ),
                ),
              ),
            const SizedBox(height: 6),

            // ---------------- banding ----------------
            _JudulSeksi('Banding'),
            const SizedBox(height: 8),
            if (info?.bandingTerbuka != null)
              _Kartu(
                ikon: Icons.fact_check_outlined,
                judul: 'Banding sedang diproses',
                isi: info!.bandingTerbuka!.pesan,
                kaki: 'Dikirim ${_tanggal(info.bandingTerbuka!.waktu)} — admin akan meninjau dan '
                    'memberitahumu lewat pemberitahuan.',
              )
            else ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(XyRadius.md),
                  border: Border.all(color: p.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Merasa ini keliru? Jelaskan situasimu kepada admin.',
                      style: TextStyle(fontSize: 12.5, height: 1.55, color: p.muted),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _ctl,
                      maxLines: 4,
                      maxLength: 600,
                      style: const TextStyle(fontSize: 13, height: 1.5),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Tuliskan penjelasan minimal 20 karakter…',
                        hintStyle: TextStyle(color: p.muted.withOpacity(.7), fontSize: 12.5),
                        filled: true,
                        fillColor: p.bg,
                        contentPadding: const EdgeInsets.all(12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(XyRadius.sm),
                          borderSide: BorderSide(color: p.line),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(XyRadius.sm),
                          borderSide: BorderSide(color: p.line),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(XyRadius.sm),
                          borderSide: const BorderSide(color: XyTheme.primary, width: 1.4),
                        ),
                      ),
                    ),
                    if (_galat != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          _galat!,
                          style: TextStyle(color: XyTheme.danger, fontSize: 11.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                    GradientButton(
                      label: _kirim ? 'Mengirim…' : 'Ajukan Banding',
                      icon: Icons.send_rounded,
                      height: 46,
                      onPressed: _kirim ? null : _kirimBanding,
                    ),
                  ],
                ),
              ),
            ],
            if ((info?.banding.where((b) => b.status != 'baru').length ?? 0) > 0) ...[
              const SizedBox(height: 10),
              ...info!.banding.where((b) => b.status != 'baru').map(
                    (b) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _Kartu(
                        ikon: b.status == 'diterima'
                            ? Icons.task_alt_rounded
                            : Icons.cancel_outlined,
                        judul: b.status == 'diterima' ? 'Banding diterima' : 'Banding ditolak',
                        isi: (b.tanggapan ?? '').isEmpty ? b.pesan : b.tanggapan!,
                        kaki: _tanggal(b.waktu),
                      ),
                    ),
                  ),
            ],
            const SizedBox(height: 18),

            // ---------------- tindakan ----------------
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(xyRoute(const CsScreen())),
              icon: const Icon(Icons.support_agent_rounded, size: 17),
              label: const Text('Chat CS admin'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(XyRadius.sm)),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => s.logout(),
              child: Text(
                'Keluar dari akun',
                style: TextStyle(color: p.muted, fontWeight: FontWeight.w700, fontSize: 12.5),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              u?.email ?? '',
              textAlign: TextAlign.center,
              style: TextStyle(color: p.muted.withOpacity(.8), fontSize: 11.5),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _JudulSeksi extends StatelessWidget {
  const _JudulSeksi(this.teks);
  final String teks;

  @override
  Widget build(BuildContext context) => Text(
        teks.toUpperCase(),
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          color: XyTheme.of(context).muted,
        ),
      );
}

class _Kartu extends StatelessWidget {
  const _Kartu({required this.ikon, required this.judul, required this.isi, this.kaki});
  final IconData ikon;
  final String judul;
  final String isi;
  final String? kaki;

  @override
  Widget build(BuildContext context) {
    final p = XyTheme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(XyRadius.md),
        border: Border.all(color: p.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(ikon, size: 17, color: p.muted),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(judul, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(isi, style: TextStyle(fontSize: 12, height: 1.55, color: p.muted)),
                if (kaki != null) ...[
                  const SizedBox(height: 6),
                  Text(kaki!, style: TextStyle(fontSize: 10.5, color: p.muted.withOpacity(.85))),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
