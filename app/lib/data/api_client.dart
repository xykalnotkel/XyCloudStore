import 'device_identity.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../core/config.dart';

class ApiException implements Exception {
  final int status;
  final String pesan;
  final String? code;
  ApiException(this.status, this.pesan, {this.code});

  /// Benar kalau server sedang dalam mode pemeliharaan (HTTP 503).
  bool get sedangPerawatan => status == 503 && (code=='MAINTENANCE'||RegExp(r'perawatan|pemeliharaan',caseSensitive:false).hasMatch(pesan));

  @override
  String toString() => 'ApiException($status): $pesan';
}

/// Client HTTP ke Cloudflare Worker XyCloud.
class ApiClient {
  ApiClient({http.Client? client}) : _http = client ?? http.Client();
  final http.Client _http;
  String? _token;

  /// Dipanggil setiap kali server menjawab 503 (mode pemeliharaan), supaya
  /// aplikasi bisa menampilkan halaman perawatan yang jelas. Diisi oleh AppState.
  void Function(String pesan)? onPerawatan;
  void Function()? onSesiBerakhir;

  String? get token => _token;
  void setToken(String? t) => _token = t;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        // Payment UI v2 dapat menampilkan nomor VA, biaya, dan kedaluwarsa.
        // Server membatasi APK lama ke hosted QRIS agar tetap kompatibel.
        'X-Xy-Payment-Version': '2',
        ...DeviceIdentity.headers,
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Uri _uri(String path, [Map<String, dynamic>? q]) =>
      Uri.parse('${XyConfig.apiUrl}$path').replace(
        queryParameters: q?.map((k, v) => MapEntry(k, '$v')),
      );

  /// Jalankan permintaan; kalau jaringan gagal, coba sekali lagi lewat alamat cadangan.
  Future<dynamic> _coba(Future<http.Response> Function() aksi) async {
    final sesi = _token;
    Future<dynamic> jalankan() async {
      final hasil = await aksi();
      if (sesi != null && sesi != _token) throw ApiException(401, 'Sesi telah berubah.');
      return _parse(hasil);
    }
    try {
      return await jalankan();
    } on ApiException {
      rethrow;
    } catch (e) {
      if (XyConfig.pindahKeCadangan()) return jalankan();
      rethrow;
    }
  }

  Future<dynamic> get(String path, [Map<String, dynamic>? q]) =>
      _coba(() => _http.get(_uri(path, q), headers: _headers).timeout(const Duration(seconds: 20)));

  Future<dynamic> post(String path, [Map<String, dynamic>? body]) => _coba(() => _http
      .post(_uri(path), headers: _headers, body: jsonEncode(body ?? {}))
      .timeout(const Duration(seconds: 20)));

  /// Unggah (POST) dengan pelaporan progres pengiriman riil per byte.
  /// Dipakai untuk berkas besar (banner GIF/video, foto profil) supaya
  /// pengguna melihat progres bar + persen, bukan spinner berputar yang
  /// terasa "tidak terhubung".
  Future<dynamic> postUnggah(
    String path,
    Map<String, dynamic> body, {
    void Function(int terkirim, int total)? onProgress,
    int timeoutDetik = 150,
  }) async {
    final sesi = _token;
    Future<dynamic> jalankan() async {
      final bytes = Uint8List.fromList(utf8.encode(jsonEncode(body)));
      var sudah = 0;
      final kiriman = http.StreamedRequest('POST', _uri(path))
        ..headers.addAll(_headers)
        ..contentLength = bytes.length;

      final respFuture = _http.send(kiriman).timeout(Duration(seconds: timeoutDetik));
      const chunkBytes = 64 * 1024;
      for (var i = 0; i < bytes.length; i += chunkBytes) {
        final akhir = (i + chunkBytes > bytes.length) ? bytes.length : i + chunkBytes;
        kiriman.sink.add(bytes.sublist(i, akhir));
        sudah += (akhir - i);
        onProgress?.call(sudah, bytes.length);
        await Future.delayed(const Duration(milliseconds: 10));
      }
      await kiriman.sink.close();
      final resp = await respFuture;
      final bodyTeks = await resp.stream.bytesToString();
      if (sesi != null && sesi != _token) throw ApiException(401, 'Sesi telah berubah.');
      return _parse(http.Response(bodyTeks, resp.statusCode,
          headers: resp.headers, request: kiriman));
    }
    try {
      return await jalankan();
    } on ApiException {
      rethrow;
    } catch (e) {
      if (XyConfig.pindahKeCadangan()) return await jalankan();
      rethrow;
    }
  }

  Future<dynamic> patch(String path, [Map<String, dynamic>? body]) => _coba(() => _http
      .patch(_uri(path), headers: _headers, body: jsonEncode(body ?? {}))
      .timeout(const Duration(seconds: 20)));

  Future<dynamic> delete(String path) =>
      _coba(() => _http.delete(_uri(path), headers: _headers).timeout(const Duration(seconds: 20)));

  /// Hapus dengan badan permintaan, dipakai saat menghapus akun.
  Future<dynamic> hapus(String path, [Map<String, dynamic>? body]) => _coba(() => _http
      .delete(_uri(path), headers: _headers, body: jsonEncode(body ?? {}))
      .timeout(const Duration(seconds: 20)));

  dynamic _parse(http.Response r) {
    final body = r.body.isEmpty ? {} : jsonDecode(r.body);
    if (r.statusCode >= 200 && r.statusCode < 300) {
      if (body is Map && body['data'] != null) return body['data'];
      return body;
    }
    final msg = (body is Map ? body['error'] ?? body['message'] : null) ?? 'Terjadi kesalahan';
    final e=ApiException(r.statusCode,'$msg',code:body is Map?body['code'] as String?:null);
    if(e.sedangPerawatan)onPerawatan?.call('$msg');
    if(r.statusCode==401&&_token!=null&&('$msg'=='Unauthorized'||'$msg'.startsWith('Sesi berakhir')))onSesiBerakhir?.call();
    throw e;
  }

  void dispose() => _http.close();
}
