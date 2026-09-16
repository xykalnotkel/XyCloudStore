import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:xycloud_order/core/stiker_cipher.dart';
import 'package:xycloud_order/data/stiker_store.dart';
import 'package:xycloud_order/models/stiker.dart';

void main(){
 TestWidgetsFlutterBinding.ensureInitialized();
 test('Koleksi ada di folder aplikasi, metadata/media terenkripsi, hapus cache tidak menghapus koleksi',()async{
  final temp=await Directory.systemTemp.createTemp('xy-sticker-test');
  FlutterSecureStorage.setMockInitialValues({});
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'),(call)async=>temp.path);
  final store=StikerStore.untuk('storage-test-owner');
  try{
   final bytes=Uint8List.fromList([137,80,78,71,13,10,26,10,0,0,0,13,73,72,68,82]);
   final item=await store.simpan(const Stiker(nama:'Private test label',mime:'image/png'),bytes:bytes);
   final info=await store.informasi();
   expect(info['count'],1);expect('${info['path']}',contains('Stiker'));
   expect(await store.baca(item),bytes);
   final index=await File('${info['path']}/index.crypto15').readAsBytes();
   expect(utf8.decode(index,allowMalformed:true),isNot(contains('Private test label')));
   final media=await File('${info['path']}/${item.id}.webp.crypto15').readAsBytes();expect(media,isNot(equals(bytes)));
   final keys=await const FlutterSecureStorage().readAll();
   final key=base64Decode(keys.entries.firstWhere((e)=>e.key.startsWith('xy_stiker_key_')).value);
   final cache=File('${info['path']}/cache_test.webp.crypto15');await cache.writeAsBytes(await StikerCipher.enkripsi(bytes,key));
   await store.bersihkanCache();expect(await cache.exists(),false);expect((await store.daftar()).length,1);expect(await store.baca(item),bytes);
  }finally{await store.hapusSemua();await temp.delete(recursive:true);}
 });
}
