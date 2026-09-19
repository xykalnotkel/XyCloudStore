import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xycloud_order/core/stiker_cipher.dart';
import 'package:xycloud_order/core/theme.dart';
import 'package:xycloud_order/core/komentar_thread.dart';
import 'package:xycloud_order/models/models.dart';
import 'package:xycloud_order/models/stiker.dart';
import 'package:xycloud_order/ui/widgets/banner_slider.dart';
import 'package:xycloud_order/ui/widgets/common.dart';

void main() {
  test('AES-GCM mengenkripsi, nonce berbeda, dan menolak modifikasi', () async {
    final key = await StikerCipher.kunciBaru(),
        data = utf8.encode('private-sticker-metadata');
    final a = await StikerCipher.enkripsi(data, key),
        b = await StikerCipher.enkripsi(data, key);
    expect(a, isNot(equals(b)));
    expect(await StikerCipher.dekripsi(a, key), data);
    expect(
        utf8
            .decode(a, allowMalformed: true)
            .contains('private-sticker-metadata'),
        false);
    a[a.length - 1] ^= 1;
    await expectLater(StikerCipher.dekripsi(a, key), throwsA(anything));
    await expectLater(StikerCipher.dekripsi(b, await StikerCipher.kunciBaru()),
        throwsA(anything));
  });
  test(
      'Thread mengelompokkan balasan dan tetap aman terhadap parent hilang/siklus',
      () {
    ForumBalasan b(String id, String? parent) => ForumBalasan(
        id: id,
        postId: 'p',
        nama: 'N',
        isi: 'T',
        dibuat: DateTime(2026),
        balasKe: parent);
    final rows = susunKomentar([
      b('a', null),
      b('b', null),
      b('c', 'a'),
      b('d', 'c'),
      b('e', 'missing'),
      b('f', 'g'),
      b('g', 'f')
    ]);
    expect(rows.take(4).map((x) => x.komentar.id), ['a', 'c', 'd', 'b']);
    expect(rows.map((x) => x.komentar.id).toSet().length, 7);
    expect(rows[2].kedalaman, 2);
  });
  test('Stiker dan teks tidak saling menggantikan di model komentar', () {
    final b = ForumBalasan.fromJson({
      'id': 'b',
      'isi': 'Teks di atas',
      'stiker': {
        'url': 'https://media.giphy.com/media/x/giphy.webp',
        'sumber': 'giphy'
      }
    });
    expect(b.isi, 'Teks di atas');
    expect(b.stiker, isA<Stiker>());
    expect(b.stiker!.dariGiphy, true);
  });
  testWidgets('Permukaan kartu benar-benar mengikuti dark mode',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
            body: Builder(
                builder: (context) => XyCard(
                    child: Text('Terbaca',
                        style: TextStyle(color: XyTheme.of(context).ink)))))));
    final containers =
        tester.widgetList<AnimatedContainer>(find.byType(AnimatedContainer));
    // Batch I: kartu mode gelap memakai gradasi midnight (XyTheme.gradDarkCard)
    // alih-alih warna datar; keduanya sama-sama "permukaan gelap".
    expect(
        containers.any((x) {
          final d = x.decoration as BoxDecoration?;
          if (d?.color == XyTheme.surfaceGelap) return true;
          final g = d?.gradient;
          final target = XyTheme.gradDarkCard?.colors.first;
          return g is LinearGradient && target != null && g.colors.first == target;
        }),
        true);
    expect(tester.widget<Text>(find.text('Terbaca')).style!.color,
        XyTheme.inkGelap);
    await tester.pumpWidget(const SizedBox());
  });
  for (final width in [320.0, 390.0]) {
    testWidgets('Banner dan tombol tidak terpotong pada lebar $width',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final banner = PromoBanner.fromJson({
        'id': 'b',
        'judul': 'Promo paket cloud untuk main lebih nyaman',
        'subjudul': 'Keterangan yang cukup panjang untuk dua baris pada HP',
        'label': 'PROMO TERBARU',
        'cta': 'Lihat Penawaran',
        'aksi': 'sewa'
      });
      await tester.pumpWidget(MaterialApp(
          home: MediaQuery(
              data: MediaQueryData(
                  size: Size(width, 800),
                  textScaler: const TextScaler.linear(1.5)),
              child: Scaffold(
                  body: Padding(
                      padding: const EdgeInsets.all(20),
                      child: BannerSlider(items: [banner]))))));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(find.text('Lihat Penawaran'), findsOneWidget);
      final r = tester.getRect(find.text('Lihat Penawaran'));
      expect(r.bottom, lessThan(600));
      expect(r.left, greaterThanOrEqualTo(0));
      expect(r.right, lessThanOrEqualTo(width));
      await tester.pumpWidget(const SizedBox());
    });
  }
}
