import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

/// Penyimpanan preset HUD sepenuhnya lokal. Payload yang sama dikirim lewat
/// MethodChannel ke overlay native sehingga tidak ada ketergantungan jaringan
/// ketika sesi PC dimulai.
class HudStore {
  static const _kDaftar = 'xy_hud_daftar_v1';
  static const _kAktif = 'xy_hud_aktif_v1';

  static List<HudLayout> bawaan() => [
        HudLayout(
          id: 'bawaan_fps',
          nama: 'FPS Kompetitif',
          deskripsi: 'WASD, sprint, lompat, reload, interaksi, dan slot senjata.',
          game: 'FPS',
          bawaan: true,
          tombol: [
            _b('W', 51, .12, .55),
            _b('A', 29, .05, .70),
            _b('S', 47, .12, .70),
            _b('D', 32, .19, .70),
            _b('Shift', 59, .035, .43, w: 82, h: 44),
            _b('Space', 62, .34, .83, w: 150, h: 44),
            _b('R', 46, .79, .37),
            _b('E', 33, .87, .51),
            _b('F', 34, .77, .59),
            _b('Ctrl', 113, .70, .75, w: 76, h: 44),
            _b('1', 8, .65, .12, cara: 'ketuk'),
            _b('2', 9, .73, .12, cara: 'ketuk'),
            _b('3', 10, .81, .12, cara: 'ketuk'),
            _b('Esc', 111, .02, .04, cara: 'ketuk'),
          ],
        ),
        HudLayout(
          id: 'bawaan_moba',
          nama: 'MOBA & RPG',
          deskripsi: 'Skill QWER, item, gerak WASD, interaksi, dan peta skor.',
          game: 'MOBA / RPG',
          bawaan: true,
          tombol: [
            _b('W', 51, .12, .55),
            _b('A', 29, .05, .70),
            _b('S', 47, .12, .70),
            _b('D', 32, .19, .70),
            _b('Q', 45, .66, .64, w: 62, h: 62),
            _b('W', 51, .74, .54, w: 62, h: 62),
            _b('E', 33, .82, .64, w: 62, h: 62),
            _b('R', 46, .89, .48, w: 68, h: 68),
            _b('1', 8, .62, .82, cara: 'ketuk'),
            _b('2', 9, .70, .82, cara: 'ketuk'),
            _b('3', 10, .78, .82, cara: 'ketuk'),
            _b('4', 11, .86, .82, cara: 'ketuk'),
            _b('Tab', 61, .02, .05, w: 72, h: 42, cara: 'ketuk'),
            _b('Space', 62, .33, .84, w: 150, h: 42),
          ],
        ),
        HudLayout(
          id: 'bawaan_desktop',
          nama: 'Desktop Ringkas',
          deskripsi: 'Navigasi desktop, modifier, Enter, Escape, dan F-key penting.',
          game: 'Desktop',
          bawaan: true,
          tombol: [
            _b('Esc', 111, .02, .05, cara: 'ketuk'),
            _b('Tab', 61, .11, .05, cara: 'ketuk'),
            _b('Ctrl', 113, .02, .80, w: 78, h: 44),
            _b('Alt', 57, .12, .80, w: 72, h: 44),
            _b('Enter', 66, .84, .70, w: 92, h: 52, cara: 'ketuk'),
            _b('↑', 19, .70, .62, cara: 'ketuk'),
            _b('←', 21, .63, .76, cara: 'ketuk'),
            _b('↓', 20, .70, .76, cara: 'ketuk'),
            _b('→', 22, .77, .76, cara: 'ketuk'),
            _b('F1', 131, .38, .05, cara: 'ketuk'),
            _b('F5', 135, .47, .05, cara: 'ketuk'),
            _b('F11', 141, .56, .05, cara: 'ketuk'),
          ],
        ),
      ];

  static HudTombol _b(
    String label,
    int kode,
    double x,
    double y, {
    double w = 56,
    double h = 56,
    String cara = 'tahan',
  }) =>
      HudTombol(
        id: 'b_${label}_${(x * 1000).round()}_${(y * 1000).round()}',
        label: label,
        kode: kode,
        x: x,
        y: y,
        lebar: w,
        tinggi: h,
        cara: cara,
      );

  static Future<List<HudLayout>> lokal() async {
    final p = await SharedPreferences.getInstance();
    try {
      final raw = jsonDecode(p.getString(_kDaftar) ?? '[]') as List;
      return raw
          .whereType<Map>()
          .map((e) => HudLayout.fromJson(Map<String, dynamic>.from(e)))
          .where((e) => e.tombol.length <= 48)
          .toList();
    } catch (_) {
      return <HudLayout>[];
    }
  }

  static Future<List<HudLayout>> semua() async {
    final tersimpan = await lokal();
    return [...bawaan(), ...tersimpan];
  }

  static Future<String?> aktifId() async =>
      (await SharedPreferences.getInstance()).getString(_kAktif);

  static Future<void> aktifkan(String? id) async {
    final p = await SharedPreferences.getInstance();
    if (id == null || id.isEmpty) {
      await p.remove(_kAktif);
    } else {
      await p.setString(_kAktif, id);
    }
  }

  /// Simpan atau perbarui. Preset bawaan selalu disalin agar templat asli tidak
  /// pernah rusak ketika diedit pengguna.
  static Future<HudLayout> simpan(HudLayout layout) async {
    final p = await SharedPreferences.getInstance();
    final daftar = await lokal();
    var hasil = layout;
    if (layout.bawaan || layout.id.startsWith('bawaan_')) {
      hasil = layout.copyWith(
        id: 'lokal_${DateTime.now().microsecondsSinceEpoch}',
        bawaan: false,
      );
    }
    final i = daftar.indexWhere((e) => e.id == hasil.id);
    if (i < 0) {
      daftar.insert(0, hasil);
    } else {
      daftar[i] = hasil;
    }
    await p.setString(_kDaftar, jsonEncode(daftar.map((e) => e.toJson()).toList()));
    return hasil;
  }

  static Future<void> hapus(String id) async {
    final p = await SharedPreferences.getInstance();
    final daftar = (await lokal())..removeWhere((e) => e.id == id);
    await p.setString(_kDaftar, jsonEncode(daftar.map((e) => e.toJson()).toList()));
    if (p.getString(_kAktif) == id) await p.remove(_kAktif);
  }
}
