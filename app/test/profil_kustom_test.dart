import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:xycloud_order/core/theme.dart';
import 'package:xycloud_order/models/models.dart';
import 'package:xycloud_order/providers/app_state.dart';
import 'package:xycloud_order/ui/screens/pengaturan_screen.dart';
import 'package:xycloud_order/ui/widgets/common.dart';

void main() {
  late AppState state;

  setUp(() {
    state = AppState(mulaiOtomatis: false)
      ..user = UserProfile(
        id: 'uji',
        nama: 'Pengguna Uji',
        email: 'uji@example.invalid',
        username: 'pengguna_uji',
        tier: 'pro',
        bingkai: 'polos',
        gayaNama: 'normal',
        banner: 'ungu',
        badge: 'Kreator',
      );
  });

  tearDown(() {
    state.dispose();
  });

  Widget bungkus(Widget child) => ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(theme: XyTheme.light(), home: child),
      );

  testWidgets('pengaturan memakai list datar dan aksi akun sejajar di HP kecil',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(bungkus(const PengaturanScreen()));
    await tester.pump();

    expect(find.byType(XyCard), findsNothing);
    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('Hapus Akun'), 200.0, scrollable: scrollable);
    await tester.pumpAndSettle();
    expect(find.text('Hapus Akun'), findsOneWidget);
    expect(find.text('Keluar'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('kategori style nama membuka editor khusus, bukan form identitas',
      (tester) async {
    await tester.pumpWidget(
      bungkus(const UbahProfilScreen(fokus: FokusProfil.gayaNama)),
    );
    await tester.pump();

    expect(find.text('Style Nama'), findsOneWidget);
    expect(find.text('Gaya Nama'), findsOneWidget);
    expect(find.text('Nama Tampilan'), findsNothing);
    expect(find.text('Pakai Style Nama'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('layar kustom menampilkan enam kategori profil', (tester) async {
    await tester.pumpWidget(bungkus(const KustomProfilScreen()));
    await tester.pump();

    expect(find.text('Kustomisasi Profil'), findsOneWidget);
    expect(find.text('Badge'), findsOneWidget);
    expect(find.text('Bingkai'), findsOneWidget);
    expect(find.text('Lencana'), findsOneWidget);
    final daftar = tester.state<ScrollableState>(find.byType(Scrollable).first);
    daftar.position.jumpTo(daftar.position.maxScrollExtent);
    await tester.pump();
    expect(find.text('Style Nama'), findsOneWidget);
    expect(find.text('Banner'), findsOneWidget);
    expect(find.text('Tema Aplikasi'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
