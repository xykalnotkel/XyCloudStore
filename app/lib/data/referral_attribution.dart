import 'package:flutter/services.dart';

/// Capability referral yang ditangkap Android dari
/// `xycloudstore://referral?...` setelah APK sideload dipasang.
///
/// Token tetap berada di SharedPreferences privat native, tidak disalin ke
/// log/cache umum. Server tetap memvalidasi hash, unduhan, perangkat, umur
/// akun, verifikasi email, self-referral, expiry, dan single-use.
class ReferralAttribution {
  ReferralAttribution._();

  static const MethodChannel _channel = MethodChannel('xycloud/settings');
  static final RegExp _ticketPattern = RegExp(r'^[a-f0-9]{64}$');
  static String? _ticket;
  static String? _kode;
  static int? _capturedAt;
  static int? _packageInstalledAt;
  static int? _packageUpdatedAt;

  static String? get ticket => _ticket;
  static String? get kode => _kode;
  static int? get capturedAt => _capturedAt;
  static int? get packageInstalledAt => _packageInstalledAt;
  static int? get packageUpdatedAt => _packageUpdatedAt;
  static bool get ada => _ticket != null;

  /// Boleh dipanggil berulang (misalnya sesudah app menerima deep link baru).
  static Future<bool> prepare() async {
    try {
      final raw = await _channel.invokeMethod<Object?>('referralAttribution');
      if (raw is! Map) {
        _resetMemory();
        return false;
      }
      final map = Map<Object?, Object?>.from(raw);
      final ticket = '${map['ticket'] ?? ''}'.trim().toLowerCase();
      if (!_ticketPattern.hasMatch(ticket)) {
        _resetMemory();
        return false;
      }
      final kode = '${map['code'] ?? ''}'.trim().toUpperCase();
      _ticket = ticket;
      _kode = RegExp(r'^[A-Z0-9]{6,16}$').hasMatch(kode) ? kode : null;
      _capturedAt = int.tryParse('${map['capturedAt'] ?? ''}');
      _packageInstalledAt = int.tryParse('${map['packageInstalledAt'] ?? ''}');
      _packageUpdatedAt = int.tryParse('${map['packageUpdatedAt'] ?? ''}');
      if (_packageInstalledAt == null || _packageInstalledAt! <= 0) {
        _resetMemory();
        return false;
      }
      return true;
    } on MissingPluginException {
      _resetMemory();
      return false;
    } on PlatformException {
      _resetMemory();
      return false;
    }
  }

  /// Dipanggil hanya setelah server mengonfirmasi klaim/idempotensi atau
  /// menyatakan tiket terminal (tidak valid, kedaluwarsa, atau fraud).
  static Future<void> clear() async {
    _resetMemory();
    try {
      await _channel.invokeMethod<void>('clearReferralAttribution');
    } on MissingPluginException {
      // Widget test / platform selain Android tidak memiliki channel ini.
    } on PlatformException {
      // Memori sudah bersih; native akan membersihkan tiket basi setelah 8 hari.
    }
  }

  static void _resetMemory() {
    _ticket = null;
    _kode = null;
    _capturedAt = null;
    _packageInstalledAt = null;
    _packageUpdatedAt = null;
  }
}
