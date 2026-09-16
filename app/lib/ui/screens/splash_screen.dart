import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/prefs.dart';
import '../../core/theme.dart';
import '../widgets/common.dart';

/// Splash sederhana: hanya wordmark XyCloudStore di atas latar ungu.
/// Sengaja tanpa animasi supaya terasa cepat dan menyambung mulus
/// dengan splash bawaan Android.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.onSelesai, this.pesan});

  final void Function(bool onboardingSelesai)? onSelesai;
  final String? pesan;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.onSelesai != null) _lanjut();
  }

  Future<void> _lanjut() async {
    final selesai = await Prefs.onboardingSelesai();
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    widget.onSelesai!(selesai);
  }

  @override
  Widget build(BuildContext context) {
    // Container tidak punya konstruktor const → AnnotatedRegion di luar const,
    // bagian dalamnya saja yang di-const.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light, systemNavigationBarColor: Color(0xFF100030),
        systemNavigationBarIconBrightness: Brightness.light),
      child: Scaffold(backgroundColor: XyTheme.primaryDark,
        body: Container(
          // gradMidnight #2E1065 → #100030: senada dengan splash native
          // (flutter_native_splash color #2E1065) supaya transisi mulus.
          decoration: const BoxDecoration(gradient: XyTheme.gradMidnight),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo aplikasi XyCloudStore (tetap).
                const XyWordmark(tinggi: 40, putih: true),
                const SizedBox(height: 14),
                // Kredit pengembang: logo studio XyVerse (bukan logo aplikasi).
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Image(
                      image: AssetImage('assets/brand/xyverse_icon_kecil.png'),
                      height: 17,
                    ),
                    const SizedBox(width: 6),
                    Text('Built by XyVerse',
                        style: TextStyle(
                            color: Colors.white.withOpacity(.72),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: .3)),
                  ],
                ),
              ],
            ),
          ),
        )),
    );
  }
}
