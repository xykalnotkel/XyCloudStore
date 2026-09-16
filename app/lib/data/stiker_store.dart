import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../core/stiker_cipher.dart';
import '../core/media_lokal.dart';
import '../models/stiker.dart';

/// Koleksi per akun, disimpan TERENKRIPSI di direktori media privat aplikasi
/// (`/Android/media/<paket>/xycloudstore/media/stiker/<id>/` pada Android;
/// application support di platform lain), bukan di galeri. Nama berkas
/// disamarkan menjadi `<sha256>.webp.crypto15` supaya tidak terlihat sebagai
/// berkas stiker mentah, dan isinya tetap tersandi (kunci di secure storage).
/// Koleksi lama (`.xys`, `.byscrt`, direktori `media/stiker`) dipindahkan
/// otomatis. Sumber galeri milik pengguna tidak dihapus/diubah. Preview hanya
/// didekripsi di RAM.
class StikerStore {
  StikerStore._(String akun)
      : _id = sha256.convert(utf8.encode(akun)).toString();
  static final _stores = <String, StikerStore>{};
  static StikerStore untuk(String akun) =>
      _stores.putIfAbsent(akun, () => StikerStore._(akun));
  static const batasBytes = 2 * 1024 * 1024;
  static const _secure = FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true));
  final String _id;
  Directory? _dir;
  Uint8List? _key;
  Future<void>? _initializing;
  Future<void> _queue = Future.value();
  List<StikerLokal> _items = [];
  final Map<String,Future<Uint8List>> _downloads = {};
  static const batasCache = 32 * 1024 * 1024;

  /// Ekstensi samaran: berkas stiker tersandi menyaru sebagai webp.
  static const _extStiker = '.webp.crypto15';
  static const _extIndex = '.crypto15';
  String _namaStiker(String id) => '$id$_extStiker';
  String get _namaIndex => 'index$_extIndex';

  /// Direktori koleksi: media privat aplikasi di Android (tidak terscan
  /// galeri karena di bawah direktori app + ada .nomedia), fallback
  /// application support. Selaras MediaLokal (`/xycloudstorage/Stiker/`).
  Future<Directory> _direktoriStiker() async {
    try {
      final akar = await MediaLokal.akar();
      return Directory('${akar.path}/Stiker/$_id');
    } catch (_) {
      // fallback di bawah
    }
    return Directory(
        '${(await getApplicationSupportDirectory()).path}/xy_stiker/$_id');
  }

  /// Pindahkan isi satu direktori koleksi lama ke direktori aktif, menyamakan
  /// ekstensi samaran lama (.xys, .byscrt) ke yang baru (.crypto15).
  Future<void> _pindahDari(Directory lama) async {
    if (lama.path == _dir!.path || !await lama.exists()) return;
    await for (final e in lama.list()) {
      if (e is! File) continue;
      var nama = e.path.split('/').last;
      if (nama.endsWith('.xys')) {
        nama = nama.substring(0, nama.length - 4) +
            (nama.startsWith('index') ? _extIndex : _extStiker);
      } else if (nama.endsWith('.webp.byscrt')) {
        nama = nama.substring(0, nama.length - '.webp.byscrt'.length) +
            _extStiker;
      } else if (nama.endsWith('.byscrt')) {
        nama = nama.substring(0, nama.length - '.byscrt'.length) +
            (nama.startsWith('index') ? _extIndex : _extStiker);
      }
      final tujuan = File('${_dir!.path}/$nama');
      try {
        await e.rename(tujuan.path);
      } catch (_) {
        await tujuan.writeAsBytes(await e.readAsBytes(), flush: true);
        await e.delete();
      }
    }
    try {
      await lama.delete(recursive: true);
    } catch (_) {
      // direktori lama dibiarkan bila gagal menghapus
    }
  }

  /// Pindahkan koleksi lama (application support `.xys`, dan direktori
  /// eksternal lama `xycloudstore/media/stiker` & `media/stiker` dengan
  /// `.byscrt`) ke lokasi baru supaya stiker pengguna tidak hilang saat
  /// memperbarui.
  Future<void> _pindahkanLama() async {
    await _pindahDari(Directory(
        '${(await getApplicationSupportDirectory()).path}/xy_stiker/$_id'));
    if (Platform.isAndroid) {
      try {
        final ext = await getExternalStorageDirectory();
        if (ext != null) {
          await _pindahDari(Directory('${ext.path}/xycloudstore/media/stiker/$_id'));
          await _pindahDari(Directory('${ext.path}/media/stiker/$_id'));
        }
      } catch (_) {}
    }
  }

  String get _keyName => 'xy_stiker_key_$_id';

  Future<void> _siap() => _initializing ??= _buka();
  Future<void> _buka() async {
    _dir = await _direktoriStiker();
    await _dir!.create(recursive: true);
    await _pindahkanLama();
    final saved = await _secure.read(key: _keyName);
    if (saved != null) {
      _key = base64Decode(saved);
    } else {
      if (await File('${_dir!.path}/$_namaIndex').exists())
        throw const FormatException(
            'Kunci koleksi lokal tidak tersedia pada perangkat ini.');
      _key = await StikerCipher.kunciBaru();
      await _secure.write(key: _keyName, value: base64Encode(_key!));
    }
    final index = File('${_dir!.path}/$_namaIndex');
    if (await index.exists()) {
      final json = jsonDecode(utf8.decode(
              await StikerCipher.dekripsi(await index.readAsBytes(), _key!)))
          as List;
      _items = json
          .map((x) => StikerLokal.fromJson(Map<String, dynamic>.from(x)))
          .toList();
    }
  }

  Future<T> _urut<T>(Future<T> Function() work) {
    final c = Completer<T>();
    _queue = _queue.then((_) async {
      try {
        c.complete(await work());
      } catch (e, st) {
        c.completeError(e, st);
      }
    });
    return c.future;
  }

  Future<void> _tulis(String nama, List<int> data) async {
    final tmp = File('${_dir!.path}/$nama.tmp');
    await tmp.writeAsBytes(await StikerCipher.enkripsi(data, _key!),
        flush: true);
    await tmp.rename('${_dir!.path}/$nama');
  }

  Future<void> _index() => _tulis(_namaIndex,
      utf8.encode(jsonEncode(_items.map((x) => x.toJson()).toList())));
  Future<List<StikerLokal>> daftar() async {
    await _siap();
    await _queue;
    return List.unmodifiable(_items);
  }

  Future<Uint8List> baca(StikerLokal item) async {
    await _siap();
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(item.id))
      throw const FormatException('ID stiker tidak valid.');
    return StikerCipher.dekripsi(
        await File('${_dir!.path}/${_namaStiker(item.id)}').readAsBytes(), _key!);
  }

  Future<StikerLokal> simpan(Stiker sticker, {Uint8List? bytes}) =>
      _urut(() async {
        await _siap();
        bytes ??= await bytesUntuk(sticker);
        if (bytes!.length > batasBytes)
          throw const FormatException('Stiker maksimal 2 MB.');
        final id = sha256.convert(bytes!).toString();
        final ada = _items.where((x) => x.id == id);
        if (ada.isNotEmpty) return ada.first;
        if (_items.length >= 100)
          throw const FormatException(
              'Koleksi penuh (100 stiker). Hapus beberapa stiker dahulu.');
        final item = StikerLokal(id, sticker);
        await _tulis(_namaStiker(id), bytes!);
        _items.insert(0, item);
        try {
          await _index();
        } catch (_) {
          _items.remove(item);
          rethrow;
        }
        return item;
      });
  Future<void> hapus(StikerLokal item) => _urut(() async {
        await _siap();
        _items.removeWhere((x) => x.id == item.id);
        await _index();
        final file = File('${_dir!.path}/${_namaStiker(item.id)}');
        if (await file.exists()) await file.delete();
      });
  Future<void> hapusSemua() => _urut(() async {
        final dir = _dir ??
            Directory(
                '${(await getApplicationSupportDirectory()).path}/xy_stiker/$_id');
        if (await dir.exists()) await dir.delete(recursive: true);
        await _secure.delete(key: _keyName);
        _items = [];
        _key = null;
        _initializing = null;
      });

  Future<Uint8List> bytesUntuk(Stiker stiker) {
    final id=sha256.convert(utf8.encode(stiker.url)).toString();
    final active=_downloads[id];if(active!=null)return active;
    final job=_cacheRead(stiker,id);_downloads[id]=job;
    job.then<void>((_){_downloads.remove(id);},onError:(Object _,StackTrace __){_downloads.remove(id);});
    return job;
  }
  Future<Uint8List> _cacheRead(Stiker stiker,String id) async {
    await _siap();final file=File('${_dir!.path}/cache_$id$_extStiker');
    if(await file.exists()){
      try{final bytes=await StikerCipher.dekripsi(await file.readAsBytes(),_key!);await file.setLastModified(DateTime.now());return bytes;}
      catch(_){await file.delete();}
    }
    final bytes=await unduh(stiker.url);
    await _tulis('cache_$id$_extStiker',bytes);
    await _rapikanCache();return bytes;
  }
  Future<void> _rapikanCache() async {
    final files=await _dir!.list().where((x)=>x is File&&x.path.split('/').last.startsWith('cache_')&&x.path.endsWith(_extStiker)).cast<File>().toList();
    final sizes=<String,int>{},times=<String,DateTime>{};var total=0;
    for(final file in files){final stat=await file.stat();sizes[file.path]=stat.size;times[file.path]=stat.modified;total+=stat.size;}
    files.sort((a,b)=>times[a.path]!.compareTo(times[b.path]!));
    for(final file in files){if(total<=batasCache)break;total-=sizes[file.path]!;try{await file.delete();}catch(_){}}
  }
  Future<Map<String,dynamic>> informasi() async {
    await _siap();await _queue;var cache=0,collection=0;
    await for(final entry in _dir!.list()){
      if(entry is! File)continue;final size=await entry.length();
      if(entry.path.split('/').last.startsWith('cache_'))cache+=size;else collection+=size;
    }
    return {'path':_dir!.path,'count':_items.length,'cacheBytes':cache,'collectionBytes':collection,'maxCache':batasCache};
  }
  Future<void> bersihkanCache() async {
    await _siap();
    await for(final f in _dir!.list())if(f is File&&f.path.split('/').last.startsWith('cache_')){try{await f.delete();}catch(_){}}
  }

  static Future<Uint8List> unduh(String value) async {
    var u = Uri.tryParse(value);
    if (u == null ||
        u.scheme != 'https' ||
        !(u.host == 'res.cloudinary.com' ||
            RegExp(r'^(media\d*|i)\.giphy\.com$').hasMatch(u.host)))
      throw const FormatException('Alamat stiker tidak didukung.');
    final client = http.Client();
    try {
      http.StreamedResponse? response;
      for(var hop=0;hop<4;hop++){
        final current=await client.send(http.Request('GET',u!)..followRedirects=false).timeout(const Duration(seconds:20));
        if([301,302,303,307,308].contains(current.statusCode)){
          final location=current.headers['location'];await current.stream.drain<void>().timeout(const Duration(seconds:20));
          if(location==null)throw const HttpException('Alamat stiker tidak tersedia.');
          final next=u.resolve(location);
          if(next.scheme!='https'||!(next.host=='res.cloudinary.com'||RegExp(r'^(media\d*|i)\.giphy\.com$').hasMatch(next.host)))throw const FormatException('Pengalihan stiker tidak diizinkan.');
          u=next;continue;
        }
        response=current;break;
      }
      if(response==null||response.statusCode!=200)throw const HttpException('Gagal mengunduh stiker.');
      final r=response;
      if ((r.contentLength ?? 0) > batasBytes)
        throw const FormatException('Stiker maksimal 2 MB.');
      final b = BytesBuilder();
      await for (final chunk in r.stream.timeout(const Duration(seconds: 20))) {
        if (b.length + chunk.length > batasBytes)
          throw const FormatException('Stiker maksimal 2 MB.');
        b.add(chunk);
      }
      final data = b.takeBytes();
      if (format(data) == null)
        throw const FormatException('Alamat ini tidak berisi gambar stiker.');
      return data;
    } finally {
      client.close();
    }
  }

  static String? format(Uint8List b) {
    if (b.length < 12) return null;
    final s = String.fromCharCodes(b.take(12));
    if (s.startsWith('GIF87a') || s.startsWith('GIF89a')) return 'image/gif';
    if (s.startsWith('RIFF') && s.substring(8, 12) == 'WEBP')
      return 'image/webp';
    if (b[0] == 137 && s.substring(1, 4) == 'PNG') return 'image/png';
    if (b[0] == 255 && b[1] == 216 && b[2] == 255) return 'image/jpeg';
    return null;
  }

  static Future<PilihanStiker> dariGaleri(Uint8List bytes) async {
    if (bytes.length > 8 * 1024 * 1024)
      throw const FormatException('Gambar asal maksimal 8 MB.');
    var mime = format(bytes);
    if (mime == null)
      throw const FormatException('Pilih PNG, JPG, GIF, atau WebP.');
    if (mime == 'image/jpeg' || mime == 'image/png') {
      bytes = await FlutterImageCompress.compressWithList(bytes,
          minWidth: 512,
          minHeight: 512,
          quality: 85,
          format: CompressFormat.webp);
      mime = 'image/webp';
    }
    if (bytes.length > batasBytes)
      throw const FormatException(
          'Animasi terlalu besar. Gunakan stiker di bawah 2 MB.');
    return PilihanStiker(Stiker(mime: mime), bytes: bytes);
  }
}
