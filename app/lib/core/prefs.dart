import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mutasi dukungan livestream yang mungkin sudah diterima server, tetapi belum
/// mendapat respons pasti. Payload disimpan bersama client ID agar retry selalu
/// identik, termasuk setelah proses aplikasi mati atau perangkat restart.
class LiveTipTertunda {
  const LiveTipTertunda({
    required this.userId,
    required this.liveId,
    required this.amount,
    required this.message,
    required this.clientId,
    required this.dibuatPada,
  });

  final String userId;
  final String liveId;
  final int amount;
  final String message;
  final String clientId;
  final String dibuatPada;

  bool payloadSama({
    required String liveId,
    required int amount,
    required String message,
  }) => this.liveId == liveId && this.amount == amount && this.message == message;

  String encode() => jsonEncode({
        'v': 1,
        'user_id': userId,
        'live_id': liveId,
        'amount': amount,
        'message': message,
        'client_id': clientId,
        'created_at': dibuatPada,
      });

  static LiveTipTertunda decode(String raw) {
    final value = jsonDecode(raw);
    if (value is! Map<String, dynamic> || value['v'] != 1) {
      throw const FormatException('Format retry dukungan tidak dikenal');
    }
    final userId = value['user_id'];
    final liveId = value['live_id'];
    final amount = value['amount'];
    final message = value['message'];
    final clientId = value['client_id'];
    final dibuatPada = value['created_at'];
    if (userId is! String || userId.isEmpty ||
        liveId is! String || !RegExp(r'^[A-Za-z0-9_-]{8,80}$').hasMatch(liveId) ||
        amount is! int || amount <= 0 || amount > 1000000000 ||
        message is! String || message.length > 120 ||
        clientId is! String || !RegExp(r'^[A-Za-z0-9_-]{12,80}$').hasMatch(clientId) ||
        dibuatPada is! String || DateTime.tryParse(dibuatPada) == null) {
      throw const FormatException('Data retry dukungan rusak');
    }
    return LiveTipTertunda(
      userId: userId,
      liveId: liveId,
      amount: amount,
      message: message,
      clientId: clientId,
      dibuatPada: dibuatPada,
    );
  }
}

/// Penyimpanan lokal.
///
/// Token login disimpan di penyimpanan terenkripsi bawaan Android
/// (EncryptedSharedPreferences), bukan di preferensi biasa.
class Prefs {
  static const _kOnboarding = 'xy_onboarding_selesai';
  static const _kEmail = 'xy_email_terakhir';
  static const _kToken = 'xy_token';
  static const _kSaldoTampil = 'xy_saldo_tampil';
  static const _kSaringKonten = 'xy_saring_konten';
  static const _kTema = 'xy_tema';
  static const _kPrivasi = 'xy_mode_privasi';
  static const _kKunciBiometrik = 'xy_kunci_biometrik';

  static const _aman = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // ---------- onboarding ----------
  static Future<bool> onboardingSelesai() async =>
      (await SharedPreferences.getInstance()).getBool(_kOnboarding) ?? false;

  static Future<void> tandaiOnboardingSelesai() async =>
      (await SharedPreferences.getInstance()).setBool(_kOnboarding, true);

  static Future<void> resetOnboarding() async =>
      (await SharedPreferences.getInstance()).remove(_kOnboarding);

  // ---------- email terakhir ----------
  static Future<String?> emailTerakhir() async =>
      (await SharedPreferences.getInstance()).getString(_kEmail);

  static Future<void> simpanEmail(String e) async =>
      (await SharedPreferences.getInstance()).setString(_kEmail, e);

  // ---------- tampilan saldo ----------
  static Future<bool> saldoTampil() async =>
      (await SharedPreferences.getInstance()).getBool(_kSaldoTampil) ?? true;

  static Future<void> simpanSaldoTampil(bool v) async =>
      (await SharedPreferences.getInstance()).setBool(_kSaldoTampil, v);

  // ---------- saringan konten ----------
  static Future<bool> saringKonten() async =>
      (await SharedPreferences.getInstance()).getBool(_kSaringKonten) ?? true;

  static Future<void> simpanSaringKonten(bool v) async =>
      (await SharedPreferences.getInstance()).setBool(_kSaringKonten, v);

  // ---------- tema tampilan ----------
  /// sistem | terang | gelap
  static Future<String> tema() async =>
      (await SharedPreferences.getInstance()).getString(_kTema) ?? 'terang';

  static Future<void> simpanTema(String v) async =>
      (await SharedPreferences.getInstance()).setString(_kTema, v);

  // ---------- mode privasi (anti screenshot / FLAG_SECURE) ----------
  static Future<bool> modePrivasi() async =>
      (await SharedPreferences.getInstance()).getBool(_kPrivasi) ?? false;

  static Future<void> simpanModePrivasi(bool v) async =>
      (await SharedPreferences.getInstance()).setBool(_kPrivasi, v);

  // ---------- kunci passkey / sidik jari (Batch I) ----------
  static Future<bool> kunciBiometrik() async =>
      (await SharedPreferences.getInstance()).getBool(_kKunciBiometrik) ?? false;

  static Future<void> simpanKunciBiometrik(bool v) async =>
      (await SharedPreferences.getInstance()).setBool(_kKunciBiometrik, v);

  // ---------- idempotensi dukungan livestream ----------
  // Satu mutasi belum pasti per akun. Jangan hapus saat logout: jika respons
  // jaringan hilang, akun yang sama wajib mengulang payload dan key identik.
  static String _kTipLive(String userId) {
    final akun = base64Url.encode(utf8.encode(userId)).replaceAll('=', '');
    return 'xy_live_tip_pending_v1_$akun';
  }

  /// Kegagalan baca/parse sengaja dilempar. Membuat key baru ketika mutasi lama
  /// mungkin sudah berhasil dapat menagih saldo dua kali.
  static Future<LiveTipTertunda?> tipLiveTertunda(String userId) async {
    final raw = await _aman.read(key: _kTipLive(userId));
    if (raw == null || raw.isEmpty) return null;
    final pending = LiveTipTertunda.decode(raw);
    if (pending.userId != userId) {
      throw const FormatException('Pemilik retry dukungan tidak cocok');
    }
    return pending;
  }

  static Future<void> simpanTipLiveTertunda(LiveTipTertunda pending) =>
      _aman.write(key: _kTipLive(pending.userId), value: pending.encode());

  static Future<void> hapusTipLiveTertunda(String userId, String clientId) async {
    final pending = await tipLiveTertunda(userId);
    if (pending == null || pending.clientId != clientId) return;
    await _aman.delete(key: _kTipLive(userId));
  }

  // ---------- idempotensi payout livestream ----------
  // Satu key terenkripsi per akun. Jangan hapus saat logout: bila respons
  // payout hilang, akun yang sama harus memakai key identik setelah restart.
  static String _kPayoutLive(String userId) {
    final akun = base64Url.encode(utf8.encode(userId)).replaceAll('=', '');
    return 'xy_live_payout_client_v1_$akun';
  }

  /// Berbeda dari helper token, kegagalan secure storage sengaja dilempar.
  /// Mengirim payout tanpa bisa membaca key lama berisiko mengulang transaksi.
  static Future<String?> payoutLiveClientId(String userId) =>
      _aman.read(key: _kPayoutLive(userId));

  static Future<void> simpanPayoutLiveClientId(String userId, String clientId) =>
      _aman.write(key: _kPayoutLive(userId), value: clientId);

  static Future<void> hapusPayoutLiveClientId(String userId) =>
      _aman.delete(key: _kPayoutLive(userId));

  // ---------- sesi login ----------
  static Future<String?> token() async {
    try {
      return await _aman.read(key: _kToken);
    } catch (_) {
      // perangkat lama kadang gagal membaca keystore; jangan sampai aplikasi mati
      return null;
    }
  }

  static Future<void> simpanToken(String t) async {
    try {
      await _aman.write(key: _kToken, value: t);
    } catch (_) {}
  }

  static Future<void> hapusToken() async {
    try {
      await _aman.delete(key: _kToken);
    } catch (_) {}
  }

  // ---------- generic (untuk layout profil custom grid dll) ----------
  static Future<String?> getString(String key) async =>
      (await SharedPreferences.getInstance()).getString(key);

  static Future<void> setString(String key, String value) async =>
      (await SharedPreferences.getInstance()).setString(key, value);

  static Future<void> remove(String key) async =>
      (await SharedPreferences.getInstance()).remove(key);
}
