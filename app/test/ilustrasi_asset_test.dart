import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Menjaga agar setiap nama ilustrasi yang dirujuk kode benar-benar punya
/// berkasnya di `assets/ilustrasi/`.
///
/// Latar belakang (audit 2026-09-13): tiga layar baru v3.3 memakai nama
/// `favorit`, `pc`, dan `order` padahal berkasnya tidak pernah ada. Karena
/// `XyIlustrasi` waktu itu tidak punya `errorBuilder`, yang terjadi di
/// perangkat pengguna adalah "Unable to load asset" dan kotak galat — galatnya
/// bahkan sempat tercatat di tabel `galat` produksi. Sekarang `XyIlustrasi`
/// sudah punya jaring pengaman, DAN uji ini memastikan CI yang menangkap
/// kasus serupa lebih dulu, bukan pengguna.
void main() {
  test('setiap ilustrasi yang dirujuk kode punya berkasnya', () {
    final pola = RegExp(
        r"(?:XyIlustrasi\(\s*|ilustrasi:\s*|ilustrasi\s*=\s*)'([a-z][a-z0-9_]*)'");
    final dipakai = <String, Set<String>>{};

    for (final entitas in Directory('lib').listSync(recursive: true)) {
      if (entitas is! File || !entitas.path.endsWith('.dart')) continue;
      final isi = entitas.readAsStringSync();
      for (final m in pola.allMatches(isi)) {
        dipakai.putIfAbsent(m.group(1)!, () => {}).add(entitas.path);
      }
    }

    final ada = Directory('assets/ilustrasi')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.webp'))
        .map((f) => f.path.split(Platform.pathSeparator).last.replaceAll('.webp', ''))
        .toSet();

    final hilang = dipakai.keys.where((n) => !ada.contains(n)).toList()..sort();
    expect(hilang, isEmpty,
        reason: 'Ilustrasi dipakai kode tetapi berkasnya tidak ada di '
            'assets/ilustrasi/: '
            '${hilang.map((n) => '$n (dipakai di ${dipakai[n]!.join(', ')})').join('; ')}');
  });

  test('folder ilustrasi terdaftar di pubspec', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('assets/ilustrasi/'),
        reason: 'flutter hanya mem-bundel aset yang terdaftar di pubspec.yaml');
  });
}
