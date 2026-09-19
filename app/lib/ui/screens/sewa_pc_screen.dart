import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/format.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/app_state.dart';
import '../widgets/common.dart';
import 'checkout_sewa_screen.dart';

class SewaPcScreen extends StatefulWidget {
  const SewaPcScreen({super.key, this.fokusId});
  final String? fokusId;
  @override
  State<SewaPcScreen> createState() => _SewaPcScreenState();
}

class _SewaPcScreenState extends State<SewaPcScreen> {
  String filter = 'Semua';
  final filters = const ['Semua', 'Jakarta', 'Singapore', 'Ready'];
  Map<String, dynamic>? _antreanAktif;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    var list = s.plans;
    if (filter == 'Ready') list = list.where((p) => p.ready).toList();
    if (filter == 'Jakarta' || filter == 'Singapore') list = list.where((p) => p.region == filter).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sewa PC Cloud', style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -.4)),
        actions: [Padding(padding: const EdgeInsets.only(right: 16), child: Center(child: LiveDot(state: s.koneksi)))],
      ),
      body: RefreshIndicator(
        onRefresh: s.refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
          children: [
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: filters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final f = filters[i];
                  final aktif = f == filter;
                  return ChoiceChip(
                    label: Text(f),
                    selected: aktif,
                    onSelected: (_) => setState(() => filter = f),
                    selectedColor: XyTheme.primary,
                    labelStyle: TextStyle(
                      color: aktif ? Colors.white : XyTheme.of(context).ink,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  );
                },
              ),
            ),
            if (_antreanAktif != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E1730), Color(0xFF2E1065)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: XyTheme.primary.withOpacity(.35)),
                  boxShadow: XyTheme.glow(XyTheme.primary, .18),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: XyTheme.primary.withOpacity(.25),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.confirmation_number_rounded, color: Colors.white, size: 21),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('Antrean #${_antreanAktif!['nomor'] ?? 1}',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13.5)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(.18),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Text('${_antreanAktif!['prioritas_label'] ?? 'Aktif'}',
                                    style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w700)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text('${_antreanAktif!['plan_nama'] ?? 'PC Cloud'} · Estimasi ~${_antreanAktif!['estimasi_menit'] ?? 20} menit',
                              style: TextStyle(color: Colors.white.withOpacity(.8), fontSize: 11.5)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
                      tooltip: 'Batalkan antrean',
                      onPressed: () {
                        setState(() => _antreanAktif = null);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Tiket antrean telah dibatalkan.')),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: XyTheme.cyan.withOpacity(.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(children: [
                Icon(Icons.bolt_rounded, color: XyTheme.cyan, size: 18),
                const SizedBox(width: 8),
                 Expanded(
                  child: Text('Stok unit diperbarui otomatis setiap detik dari server XyCloud.',
                      style: TextStyle(fontSize: 12, color: XyTheme.of(context).ink)),
                ),
              ]),
            ),
            if (list.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 60),
                child: Kosong(icon: Icons.search_off_rounded, judul: 'Tidak ada PC di filter ini'),
              ),
            ...list.map((p) => Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _KartuPlan(
                    plan: p,
                    onAntreanDibuat: (antrean) => setState(() => _antreanAktif = antrean),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class _KartuPlan extends StatelessWidget {
  const _KartuPlan({required this.plan, this.onAntreanDibuat});
  final PcPlan plan;
  final ValueChanged<Map<String, dynamic>>? onAntreanDibuat;

  @override
  Widget build(BuildContext context) {
    final pakai = plan.totalUnit == 0 ? 0.0 : 1 - (plan.unitTersedia / plan.totalUnit);
    return XyCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (plan.gambar.isNotEmpty) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(XyRadius.md),
            child: AspectRatio(
              aspectRatio: 16 / 7,
              child: Image.network(
                plan.gambar,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                loadingBuilder: (_, anak, kemajuan) =>
                    kemajuan == null ? anak : Container(color: XyTheme.of(context).lineSoft),
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],
        Row(children: [
          GradientThumb(seed: plan.id, icon: Icons.memory_rounded, size: 54),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(plan.nama, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16.5, letterSpacing: -.3)),
                const SizedBox(width: 8),
                if (plan.tag.isNotEmpty) Pill(plan.tag, warna: XyTheme.violet),
              ]),
              const SizedBox(height: 3),
              Text(plan.gpu, style:  TextStyle(color: XyTheme.of(context).muted, fontSize: 12.5)),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        Wrap(spacing: 14, runSpacing: 8, children: [
          SpecChip(Icons.developer_board_rounded, plan.cpu),
          SpecChip(Icons.memory_outlined, 'RAM ${plan.ramGb}GB'),
          SpecChip(Icons.sd_storage_outlined, 'SSD ${plan.storageGb}GB'),
          SpecChip(Icons.location_on_outlined, plan.region),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: pakai),
                duration: const Duration(milliseconds: 600),
                builder: (_, v, __) => LinearProgressIndicator(
                  value: v,
                  minHeight: 7,
                  backgroundColor: XyTheme.of(context).line,
                  color: plan.ready ? XyTheme.success : XyTheme.danger,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text('${plan.unitTersedia}/${plan.totalUnit} unit',
              style:  TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: XyTheme.of(context).muted)),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(rupiah(plan.hargaPerJam),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 19, color: XyTheme.primary, letterSpacing: -.5)),
               Text('  /jam', style: TextStyle(color: XyTheme.of(context).muted, fontSize: 12)),
            ]),
            Text('atau ${rupiah(plan.hargaPerHari)} /hari', style:  TextStyle(color: XyTheme.of(context).muted, fontSize: 11.5)),
          ]),
          const Spacer(),
          SizedBox(
            width: 148,
            child: GradientButton(
              label: plan.ready ? 'Sewa' : 'Booking / Antre',
              icon: plan.ready ? Icons.bolt_rounded : Icons.schedule_rounded,
              height: 46,
              onPressed: plan.ready
                  ? () => Navigator.push(context, xyRoute(CheckoutSewaScreen(plan: plan)))
                  : () => _bukaSheetAntrean(context, plan),
            ),
          ),
        ]),
      ]),
    );
  }

  void _bukaSheetAntrean(BuildContext context, PcPlan plan) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SheetBookingAntrean(
        plan: plan,
        onAntreanDibuat: onAntreanDibuat,
      ),
    );
  }
}

class _SheetBookingAntrean extends StatefulWidget {
  const _SheetBookingAntrean({required this.plan, this.onAntreanDibuat});
  final PcPlan plan;
  final ValueChanged<Map<String, dynamic>>? onAntreanDibuat;

  @override
  State<_SheetBookingAntrean> createState() => _SheetBookingAntreanState();
}

class _SheetBookingAntreanState extends State<_SheetBookingAntrean> {
  int durasiJam = 2;
  bool memuat = false;

  @override
  Widget build(BuildContext context) {
    final t = XyTheme.of(context);
    final u = context.watch<AppState>().user;
    final tier = u?.tier ?? 'basic';
    final prioritasLabel = tier == 'vip'
        ? 'VIP Priority (Antrean Terdepan)'
        : (tier == 'pro' ? 'Pro Priority (Didahulukan)' : 'Antrean Reguler');
    final prioritasWarna = tier == 'vip'
        ? XyTheme.goldSoft
        : (tier == 'pro' ? XyTheme.violet : t.muted);

    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: t.line),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(color: t.line, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: XyTheme.warning.withOpacity(.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.schedule_rounded, color: XyTheme.warning, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Antrean & Booking Unit',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -.4)),
                    const SizedBox(height: 2),
                    Text(widget.plan.nama,
                        style: TextStyle(color: t.muted, fontSize: 12.5, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: prioritasWarna.withOpacity(.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: prioritasWarna.withOpacity(.25)),
            ),
            child: Row(
              children: [
                Icon(Icons.workspace_premium_rounded, color: prioritasWarna, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(prioritasLabel,
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: prioritasWarna)),
                      const SizedBox(height: 2),
                      Text(
                        tier == 'vip' || tier == 'pro'
                            ? 'Sebagai member ${tier.toUpperCase()}, antreanmu otomatis didahulukan di urutan teratas saat unit selesai!'
                            : 'Naikkan tier ke Pro/VIP untuk menikmati prioritas antrean terdepan.',
                        style: TextStyle(fontSize: 11, color: t.inkSoft, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('Pilih Rencana Durasi Booking',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [1, 2, 4, 8, 24].map((j) {
              final aktif = durasiJam == j;
              return ChoiceChip(
                label: Text('$j Jam'),
                selected: aktif,
                onSelected: (_) => setState(() => durasiJam = j),
                selectedColor: XyTheme.primary,
                labelStyle: TextStyle(
                  color: aktif ? Colors.white : t.ink,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(Icons.hourglass_top_rounded, size: 16, color: t.muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Estimasi unit siap: ~15–30 menit (mengikuti durasi sewa aktif).',
                  style: TextStyle(color: t.muted, fontSize: 11.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          GradientButton(
            label: memuat ? 'Mendaftarkan Antrean…' : 'Konfirmasi Masuk Antrean',
            icon: Icons.bookmark_add_rounded,
            loading: memuat,
            onPressed: memuat
                ? null
                : () async {
                    setState(() => memuat = true);
                    final s = context.read<AppState>();
                    final res = await s.antreSewa(widget.plan.id, durasiJam);
                    if (!mounted) return;
                    setState(() => memuat = false);
                    Navigator.pop(context);
                    if (res != null) {
                      final pesan = res['pesan'] ?? 'Kamu berhasil masuk antrean!';
                      if (res['antrean'] != null) {
                        widget.onAntreanDibuat?.call(Map<String, dynamic>.from(res['antrean']));
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(pesan),
                          backgroundColor: XyTheme.primary,
                          duration: const Duration(seconds: 4),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(s.error ?? 'Gagal mendaftar antrean.')),
                      );
                    }
                  },
          ),
        ],
      ),
    );
  }
}
