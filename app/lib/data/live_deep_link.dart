import 'package:flutter/services.dart';

/// Jembatan xycloudstore://live?id=... dari Activity Android. Hanya ID publik
/// yang dibawa; token player tetap diterbitkan server setelah pengguna login.
class LiveDeepLink {
  LiveDeepLink._();
  static const _channel = MethodChannel('xycloud/settings');
  static void Function(String id)? saatDiterima;
  static String? tertunda;

  static Future<void> periksa() async {
    try {
      final id = await _channel.invokeMethod<String>('consumeLiveDeepLink');
      if (id == null || !RegExp(r'^[A-Za-z0-9_-]{8,80}$').hasMatch(id)) return;
      final callback = saatDiterima;
      if (callback == null) {
        tertunda = id;
      } else {
        callback(id);
      }
    } on MissingPluginException {
      // Widget test/platform non-Android.
    } on PlatformException {
      // Link tetap dapat dibuka lagi dari browser.
    }
  }

  static void pasang(void Function(String id) callback) {
    saatDiterima = callback;
    final id = tertunda;
    tertunda = null;
    if (id != null) callback(id);
  }
}
