import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// ============================================================
///  MediaLokal — penyimpanan media lokal terstruktur (Batch N)
/// ============================================================
///  Fondasi folder media ala WhatsApp, tapi app-scoped (aman + privat):
///
///    /Android/data/<paket>/files/xycloudstorage/
///    ├─ .nomedia      (agar tidak ter-scan galeri)
///    ├─ Stiker/       (koleksi stiker terenkripsi — dipakai StikerStore)
///    ├─ Video/
///    ├─ Image/
///    ├─ Voicenote/
///    ├─ Document/
///    └─ Database/
///
///  Catatan: pada Android modern (scoped storage), aplikasi tidak boleh
///  menulis ke /Android/media milik aplikasi lain. Direktori milik sendiri
///  (dari getExternalStorageDirectory) adalah lokasi yang sah dan tidak
///  butuh izin tambahan. Koleksi stiker tetap tersandi AES-256-GCM
///  (lihat StikerStore) — folder ini hanya kerangka + penanda .nomedia.
class MediaLokal {
  MediaLokal._();

  static Directory? _dir;

  /// Direktori akar penyimpanan media lokal.
  static Future<Directory> akar() async {
    if (_dir != null) return _dir!;
    if (Platform.isAndroid) {
      try {
        final ext = await getExternalStorageDirectory();
        if (ext != null) {
          _dir = Directory('${ext.path}/xycloudstorage');
        }
      } catch (_) {}
    }
    _dir ??= Directory(
        '${(await getApplicationSupportDirectory()).path}/xycloudstorage');
    return _dir!;
  }

  /// Subfolder terstandar yang selalu dipastikan ada.
  static const subfolder = [
    'Stiker',
    'Video',
    'Image',
    'Voicenote',
    'Document',
    'Database',
  ];

  /// Pastikan seluruh struktur folder + penanda .nomedia ada.
  static Future<Directory> siapkan() async {
    final akar_ = await akar();
    await akar_.create(recursive: true);
    for (final nama in subfolder) {
      await Directory('${akar_.path}/$nama').create(recursive: true);
    }
    // Penanda .nomedia: galeri sistem tidak memindai folder ini.
    final nomedia = File('${akar_.path}/.nomedia');
    if (!await nomedia.exists()) await nomedia.writeAsString('', flush: true);
    return akar_;
  }

  /// Ringkasan ukuran per subfolder (byte) — dipakai layar Penyimpanan.
  static Future<Map<String, int>> ukuranPerFolder() async {
    final akar_ = await akar();
    final hasil = <String, int>{};
    for (final nama in subfolder) {
      hasil[nama] = await _ukuranDir(Directory('${akar_.path}/$nama'));
    }
    return hasil;
  }

  static Future<int> _ukuranDir(Directory d) async {
    var total = 0;
    try {
      await for (final e in d.list(recursive: true)) {
        if (e is File) total += await e.length();
      }
    } catch (_) {}
    return total;
  }
}
