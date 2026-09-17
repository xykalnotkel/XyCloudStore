import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/app_state.dart';
import '../widgets/common.dart';

/// Status unit PC live — katalog pc_plans (stok realtime via WebSocket)
/// DIGABUNG dengan laporan agen host (Batch J): spek CPU/RAM/GPU/hostname
/// terdeteksi otomatis oleh agen di mesin host dan dikirim lewat heartbeat,
/// jadi kartu menampilkan spesifikasi SUNGGUHAN tiap PC, bukan katalog saja.
class LiveUnitScreen extends StatefulWidget {
  const LiveUnitScreen({super.key});

  @override
  State<LiveUnitScreen> createState() => _LiveUnitScreenState();
}

class _LiveUnitScreenState extends State<LiveUnitScreen> {
  Map<String, UnitLive> _live = {};
  bool _memuat = true;
  // Batch K: jajak otomatis tiap 30 detik + penanda waktu pembaruan.
  Timer? _poll;
  DateTime? _update;

  @override
  void initState() {
    super.initState();
    _muat();
    _poll = Timer.periodic(const Duration(seconds: 30), (_) => _muat(senyap: true));
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _muat({bool senyap = false}) async {
    try {
      final list = await context.read<AppState>().repo.unitLive();
      final peta = <String, UnitLive>{};
      for (final u in list) {
        // Agen online dengan spek lengkap menang; offline hanya pengisi.
        final lama = peta[u.planId];
        if (lama == null || (u.online && !lama.online)) peta[u.planId] = u;
      }
      if (!mounted) return;
      setState(() {
        _live = peta;
        _memuat = false;
        _update = DateTime.now();
      });
    } catch (_) {
      if (mounted) setState(() => _memuat = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plans = context.watch<AppState>().plans;
    final t = XyTheme.of(context);
    final siap = plans.where((p) => p.unitTersedia > 0).length;
    return Scaffold(
      appBar: AppBar(title: const Text('Status Unit Live')),
      body: RefreshIndicator(
        onRefresh: () => _muat(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [XyTheme.bgGelap, XyTheme.primary], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: XyTheme.okBright, shape: BoxShape.circle, boxShadow: [BoxShadow(color: XyTheme.okBright, blurRadius: 8)])),
                const SizedBox(width: 10),
                const Expanded(child: Text('Live — update realtime via WebSocket', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13))),
                Text('${plans.fold(0, (a, p) => a + p.unitTersedia)} unit ready', style: TextStyle(color: Colors.white.withOpacity(.75), fontSize: 11.5)),
              ]),
            ),
            const SizedBox(height: 8),
            Text('$siap dari ${plans.length} paket siap dipakai', style: TextStyle(color: t.muted, fontSize: 12.5, fontWeight: FontWeight.w600)),
            if (_update != null)
              Text(
                  'Spek agen diperbarui ${_update!.toLocal().hour.toString().padLeft(2, '0')}:${_update!.toLocal().minute.toString().padLeft(2, '0')}:${_update!.toLocal().second.toString().padLeft(2, '0')} • otomatis tiap 30 detik',
                  style: TextStyle(color: t.muted.withOpacity(.75), fontSize: 11)),
            const SectionHeader('Paket PC'),
            if (plans.isEmpty)
              const Kosong(icon: Icons.desktop_windows_rounded, judul: 'Belum ada data unit', sub: 'Tarik untuk refresh.', ilustrasi: 'pc')
            else
              ...plans.map((p) {
                final live = _live[p.id];
                final spekAsli = live != null && live.spec.isNotEmpty && live.online;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: XyCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        // Batch J: ilustrasi AI menggantikan ikon material.
                        Image.asset('assets/ikon/3d_unitpc.webp',
                            width: 46,
                            height: 46,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.medium,
                            errorBuilder: (_, __, ___) => Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(gradient: XyTheme.gradPrimary, borderRadius: BorderRadius.circular(14)),
                                child: const Icon(Icons.memory_rounded, color: Colors.white, size: 20))),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(p.nama, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                          const SizedBox(height: 2),
                          Text(
                            spekAsli
                                ? '${live.hostname} • ${live.ram}GB RAM • ${live.gpu.isNotEmpty ? live.gpu : live.cpu}'
                                : '${p.cpu} • ${p.gpu} • ${p.ramGb}GB RAM',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: t.muted, fontSize: 11.5),
                          ),
                        ])),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text('${p.unitTersedia}/${p.totalUnit}', style: const TextStyle(fontWeight: FontWeight.w700, color: XyTheme.primary)),
                          Text('ready', style: TextStyle(color: t.muted, fontSize: 10)),
                        ]),
                      ]),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(value: p.totalUnit == 0 ? 0 : p.unitTersedia / p.totalUnit, minHeight: 6, backgroundColor: t.line, valueColor: const AlwaysStoppedAnimation(XyTheme.primary)),
                      ),
                      const SizedBox(height: 8),
                      Row(children: [
                        _Chip(p.region, Icons.location_on_rounded),
                        const SizedBox(width: 6),
                        _Chip(p.tag.isEmpty ? '${p.storageGb}GB' : p.tag, Icons.sell_rounded),
                        const SizedBox(width: 6),
                        _Chip(p.unitTersedia > 0 ? 'Online' : 'Penuh', Icons.circle, color: p.unitTersedia > 0 ? XyTheme.okBright : XyTheme.danger),
                        if (live != null && live.online) ...[
                          const SizedBox(width: 6),
                          _Chip('Spek terdeteksi', Icons.speed_rounded, color: XyTheme.okBright),
                          if (live.versi.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            _Chip('agen ${live.versi}', Icons.verified_rounded),
                          ],
                        ],
                      ]),
                      if (live == null || !live.online)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text('Agen host belum melapor — spek masih dari katalog paket.',
                              style: TextStyle(color: t.muted.withOpacity(.8), fontSize: 10.5, fontStyle: FontStyle.italic)),
                        ),
                    ]),
                  ),
                );
              }),
            if (_memuat)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: XyTheme.primary))),
              ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color? color;
  const _Chip(this.label, this.icon, {this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: XyTheme.of(context).primarySoft, borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: color ?? XyTheme.primary),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: XyTheme.of(context).muted)),
        ]),
      );
}
