import 'device_identity.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../core/config.dart';

/// ============================================================
///  Login lewat Google atau Facebook
/// ============================================================
///  Google memakai dialog pemilih akun bawaan Android (native),
///  jadi pengguna tidak dilempar ke browser. Kalau dialog native
///  tidak tersedia di perangkat tersebut, aplikasi otomatis
///  memakai cara lama lewat halaman aman Google.
class LoginSosial {
  LoginSosial._();

  static const String skema = 'xycloudstore';
  static bool _ulangIzinEmailFacebook = false;

  /// Client ID tipe Web, dipakai sebagai audiens ID token.
  static const String serverClientId = String.fromEnvironment(
    'XY_GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '495336144977-1fu3nv7r35pi2i0t8qu6ng0u695t0veg.apps.googleusercontent.com',
  );

  /// Hasil login native: ID token Google yang harus ditukar ke server.
  /// Mengembalikan null bila native tidak bisa dipakai di perangkat ini.
  static Future<String?> idTokenGoogleNative() async {
    try {
      final google = GoogleSignIn(
        scopes: const ['email', 'profile'],
        serverClientId: serverClientId,
      );

      // pastikan pemilih akun selalu muncul
      await google.signOut();

      final akun = await google.signIn();
      if (akun == null) throw GagalLoginSosial('Login dibatalkan.');

      final auth = await akun.authentication;
      final idToken = auth.idToken;
      if (idToken == null || idToken.isEmpty) {
        debugPrint('Google native tidak mengembalikan idToken');
        return null; // jatuh ke cara browser
      }
      return idToken;
    } on GagalLoginSosial {
      rethrow;
    } catch (e) {
      final t = e.toString().toLowerCase();
      debugPrint('Google native gagal: $e');
      if (t.contains('canceled') || t.contains('cancelled')) {
        throw GagalLoginSosial('Login dibatalkan.');
      }
      // ApiException 10 = konfigurasi Android client belum cocok
      return null;
    }
  }

  /// Cara cadangan: halaman izin resmi di browser aman, hasilnya
  /// dikembalikan lewat tautan xycloudstore://auth?token=...
  static Future<String> tokenLewatHalaman(String provider) async {
    if (provider != 'google' && provider != 'facebook') {
      throw GagalLoginSosial('Penyedia login tidak dikenal.');
    }
    final mulai = Uri.parse('${XyConfig.aktif}/api/auth/$provider/start')
        .replace(queryParameters: {
          if (DeviceIdentity.id.isNotEmpty) 'device': DeviceIdentity.id,
          if (provider == 'facebook' && _ulangIzinEmailFacebook) 'rerequest': 'email',
        });

    try {
      final hasil = await FlutterWebAuth2.authenticate(
        url: mulai.toString(),
        callbackUrlScheme: skema,
        options: const FlutterWebAuth2Options(preferEphemeral: false, timeout: 300),
      );

      final u = Uri.parse(hasil);
      final token = u.queryParameters['token'];
      final galat = u.queryParameters['error'];
      if (token != null && token.isNotEmpty) {
        if (provider == 'facebook') _ulangIzinEmailFacebook = false;
        return token;
      }
      if (provider == 'facebook' &&
          (galat ?? '').toLowerCase().contains('tidak membagikan email')) {
        // Klik berikutnya memakai auth_type=rerequest. Pesan ini menjadi
        // education screen sebelum Meta meminta izin email sekali lagi.
        _ulangIzinEmailFacebook = true;
      }
      throw GagalLoginSosial(_pesanRamah(galat ?? 'Login dibatalkan'));
    } on GagalLoginSosial {
      rethrow;
    } catch (e) {
      debugPrint('Login lewat halaman gagal: $e');
      final t = e.toString().toLowerCase();
      if (t.contains('cancel')) throw GagalLoginSosial('Login dibatalkan.');
      throw GagalLoginSosial('Tidak bisa membuka halaman login. Coba lagi atau pakai email.');
    }
  }

  static String _pesanRamah(String kode) {
    if (kode.contains('access_denied') || kode.contains('dibatalkan')) return 'Login dibatalkan.';
    if (kode.contains('redirect_uri_mismatch')) {
      return 'Alamat callback belum terdaftar di konsol penyedia. Hubungi admin.';
    }
    return kode;
  }
}

class GagalLoginSosial implements Exception {
  GagalLoginSosial(this.pesan);
  final String pesan;
  @override
  String toString() => pesan;
}
