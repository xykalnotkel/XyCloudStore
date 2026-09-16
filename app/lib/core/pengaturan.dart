import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class PengaturanLokal {
  static const defaults = <String, dynamic>{
    'stickerAutoSave': true, 'resolution': '1280x720',
    'fps': 60,
    'bitrate': 10000,
    'codec': 'auto',
    'gamepad': true,
    'trackpad': true,
    'hostAudio': false,
    'stats': false,
    // Pemulihan dan pemilihan jalur streaming. Data rahasia host tidak
    // disimpan di sini; hanya preferensi kualitas milik pengguna.
    'adaptiveStreaming': true,
    'autoReconnect': true,
    'preferLan': false,
    'vibration': true,
    'textScale': 1.0,
    'animasi': true,
    'navTengah': 2,
  };
  static Map<String, dynamic> nilai = {...defaults};
  static Future<void> muat() async {
    final sp = await SharedPreferences.getInstance();
    try {
      nilai = {
        ...defaults,
        ...Map<String, dynamic>.from(
            jsonDecode(sp.getString('xy_settings_v1') ?? '{}'))
      };
    } catch (_) {
      nilai = {...defaults};
    }
  }

  static Future<void> set(String key, dynamic value) async {
    nilai[key] = value;
    await (await SharedPreferences.getInstance())
        .setString('xy_settings_v1', jsonEncode(nilai));
  }

  static Future<void> reset() async {
    nilai = {...defaults};
    await (await SharedPreferences.getInstance()).remove('xy_settings_v1');
  }

  static bool get animasi => nilai['animasi'] != false;
  static double get skala =>
      (nilai['textScale'] as num? ?? 1).toDouble().clamp(.85, 1.3);
}
