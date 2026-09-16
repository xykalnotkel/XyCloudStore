import 'package:flutter/services.dart';

class NativeStream {
  static const _channel = MethodChannel('xycloud/stream');
  static Future<void> Function(Map<String, dynamic>)? onEvent;
  static bool _registered = false;
  static void init() {
    if (_registered) return;
    _registered = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'event' && call.arguments is Map)
        await onEvent?.call(Map<String, dynamic>.from(call.arguments));
    });
  }

  static Future<bool> tersedia() async {
    init();
    try {
      return await _channel.invokeMethod<bool>('available') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> hubungkan(
      {required String host,
      required String session,
      required String hostKey}) async {
    init();
    final data = await _channel.invokeListMethod<dynamic>(
        'prepare', {'host': host, 'session': session, 'hostKey': hostKey});
    return (data ?? []).map((x) => Map<String, dynamic>.from(x)).toList();
  }

  static Future<void> mulai(int appId, Map<String, dynamic> options) =>
      _channel.invokeMethod('start', {'appId': appId, 'options': options});
  static Future<void> batal() async {
    try {
      await _channel.invokeMethod('cancel');
    } catch (_) {}
  }

  static Future<void> resetPairing() => _channel.invokeMethod('resetPairing');

  /// Mode kontrol untuk sesi streaming berikutnya:
  /// true = kontrol bawaan (Moonlight), false = HUD XyCloudStore.
  static Future<void> setKontrolBawaan(bool bawaan) async {
    try {
      await _channel.invokeMethod('setKontrol', {'bawaan': bawaan});
    } catch (_) {}
  }

  /// Kirim layout HUD aktif ke SharedPreferences milik overlay Android.
  /// Mengembalikan false pada web/build lama supaya UI dapat memberi pesan
  /// yang jelas tanpa menghilangkan preset yang sudah tersimpan lokal.
  static Future<bool> terapkanHud(Map<String, dynamic>? data) async {
    try {
      await _channel.invokeMethod('setHudPreset', {'data': data});
      return true;
    } catch (_) {
      return false;
    }
  }
}

class NativeSettings {
  static const _channel = MethodChannel('xycloud/settings');
  static Future<Map<String, dynamic>> statusNotifikasi() async =>
      Map<String, dynamic>.from(
          await _channel.invokeMethod('notificationStatus') ?? {});
  static Future<void> bukaNotifikasi([String? channel]) =>
      _channel.invokeMethod('notificationSettings', {'channel': channel ?? ''});
}
