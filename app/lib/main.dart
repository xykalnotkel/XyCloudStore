import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'core/pengaturan.dart';
import 'core/keamanan.dart';
import 'core/media_lokal.dart';
import 'core/prefs.dart';
import 'package:flutter/foundation.dart';
import 'data/lapor_galat.dart';
import 'data/push_service.dart';
import 'data/device_identity.dart';
import 'data/referral_attribution.dart';
import 'providers/app_state.dart';
import 'ui/screens/flow_gate.dart';
import 'ui/screens/kunci_biometrik_screen.dart';
import 'ui/screens/lengkapi_profil_screen.dart';
import 'ui/screens/splash_screen.dart';
import 'ui/screens/shell.dart';
import 'ui/screens/blokir_screen.dart';
import 'ui/widgets/latar_aurora.dart';
import 'ui/widgets/perawatan_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DeviceIdentity.prepare();
  await ReferralAttribution.prepare();
  await initializeDateFormatting('id_ID', null);
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));
  LicenseRegistry.addLicense(() async* {yield LicenseEntryWithLineBreaks(['Moonlight Android / XyCloudStore Streaming'],await rootBundle.loadString('assets/licenses/moonlight-gpl3.txt'));});
  // Batch N: siapkan struktur folder media lokal (Stiker/Video/Image dsb).
  MediaLokal.siapkan().then((d) => d, onError: (Object e, StackTrace s) =>
      Future<Directory>.value(Directory.systemTemp));
  await PushService.mulai();
  await LaporGalat.siapkan();
  // Pulihkan mode privasi (FLAG_SECURE) sebelum layar pertama tampil.
  Keamanan.setelPrivasi(await Prefs.modePrivasi());

  // semua galat yang lolos ditangkap dan dilaporkan ke server sendiri
  LaporGalat.pasang(() => runApp(const XyCloudStoreApp()));
}

class XyCloudStoreApp extends StatelessWidget {
  const XyCloudStoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: Builder(builder: (context) => MaterialApp(
        key: ValueKey(context.watch<AppState>().user?.id ?? 'tamu'),
        title: 'XyCloudStore',
        debugShowCheckedModeBanner: false,
        theme: XyTheme.light(),
        darkTheme: XyTheme.gelap(),
        themeMode: context.watch<AppState>().modeTema,
        builder: (context, child) {
          final gelap = Theme.of(context).brightness == Brightness.dark;
          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: gelap ? Brightness.light : Brightness.dark,
              systemNavigationBarColor: XyTheme.of(context).surface,
              systemNavigationBarIconBrightness: gelap ? Brightness.light : Brightness.dark,
            ),
            // Batch I: latar aurora global — semua scaffold transparan di atasnya.
            child: XyLatar(
              child: MediaQuery(data:MediaQuery.of(context).copyWith(textScaler:TextScaler.linear((MediaQuery.textScalerOf(context).scale(1)*PengaturanLokal.skala).clamp(.85,1.6))),child:child!),
            ),
          );
        },
        home: const _Root(),
      )),
    );
  }
}

/// Begitu user berhasil login, seluruh stack flow (splash/onboarding/welcome/login)
/// diganti oleh shell aplikasi.
class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();

    // selama token tersimpan sedang diperiksa, tetap tampilkan splash
    if (s.memeriksaSesi) {
      return const SplashScreen(pesan: 'Memulihkan sesi kamu');
    }

    // server sedang mode pemeliharaan: tampilkan halaman perawatan yang jelas
    // (baik sebelum maupun sesudah login), bukan deretan galat yang membingungkan
    // Selama pemeliharaan: tampilkan halaman perawatan, KECUALI staf internal
    // yang belum login dan sudah mengetuk jalan masuk uji — mereka perlu
    // melihat halaman login. Server yang memutuskan siapa yang dikecualian.
    if (s.perawatan && !(s.paksaMasukPerawatan && !s.masuk)) {
      return PerawatanScreen(
        pesan: s.pesanPerawatan,
        onCoba: s.cobaLagiPerawatan,
        onKeluar: s.masuk ? s.logout : null,
        onMasuk: s.masuk ? null : s.ujiMasukPerawatan,
      );
    }

    final masuk = s.masuk;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 480),
      switchInCurve: Curves.easeOutCubic,
      transitionBuilder: (child, a) => FadeTransition(
        opacity: a,
        child: ScaleTransition(scale: Tween(begin: .98, end: 1.0).animate(a), child: child),
      ),
      child: !masuk
          ? const FlowGate(key: ValueKey('flow'))
          // Batch I: kunci passkey/sidik jari — sesi tersimpan tetap ada,
          // tapi pintu masuk aplikasi dijaga biometrik sampai dibuka.
          : (s.perluKunciBiometrik
              ? const KunciBiometrikScreen(key: ValueKey('kunci'))
              : (s.user?.diblokir == true
                  ? const BlokirScreen(key: ValueKey('blokir'))
                  : (s.perluLengkapiProfil
                      ? const LengkapiProfilScreen(key: ValueKey('lengkapi'))
                      : const XyShell(key: ValueKey('shell'))))),
    );
  }
}
