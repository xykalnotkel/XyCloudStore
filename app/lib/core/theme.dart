import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// ============================================================
///  XyCloud Design System — Violet-Indigo Glossy v3.2
///  Token spasi, radius, elevasi, gradien, dan tema Material 3.
/// ============================================================
/// Referensi warna dari popup contoh XyCloudStore_rental_pc_morphing.jpg:
/// - BG indigo tua: #100030 / #200050 / #100040
/// - Aksen violet glossy: #7830C0 / #8B5CF6 / #A855F7
/// Tema ini diterapkan ke SELURUH UI/UX (app + web + console).
class XySpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 28;
  static const double page = 22;
}

class XyRadius {
  // Skala radius SATU untuk seluruh aplikasi (audit UI 2026-09-13):
  // 10 -> kontrol kecil, 14 -> input/tombol, 18 -> kartu, 20 -> panel,
  // 24 -> lembar/hero, 28 -> lembar besar, 99 -> pil.
  static const double xs = 10;
  static const double sm = 14;
  static const double md = 18;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 28;
  static const double pill = 99;

  /// Radius khusus tombol: pil penuh (rounded-full) di SELURUH aplikasi —
  /// permintaan UI 2026-09-14: "semua button rounded full agar bagus".
  static const double tombol = 99;
}

class XyTheme {
  static XyPalette of(BuildContext context) =>
      XyPalette(Theme.of(context).brightness == Brightness.dark);

  // ---------- palet ungu XyCloudStore — VIOLET-INDIGO GLOSSY v3.2 ----------
  // Diterapkan ke seluruh UI/UX sesuai permintaan: "warnanya pakai ke ui ux semua"
  static const Color primary = Color(0xFF7C3AED); // violet utama glossy (7830C0 / 7C3AED)
  static const Color primaryDeep = Color(0xFF5B21B6); // violet pekat
  static const Color primaryDark = Color(0xFF2E1065); // indigo tua untuk hero/midnight
  static const Color primarySoft = Color(0xFFF5F3FF); // latar lembut lavender tint
  static const Color violet = Color(0xFF8B5CF6); // ungu terang glossy (dari referensi)
  static const Color lavender = Color(0xFFC4B5FD); // aksen lembut
  static const Color plum = Color(0xFFA855F7); // magenta-violet accent

  static const Color ink = Color(0xFF1E1B2E); // teks utama indigo kehitaman
  static const Color inkSoft = Color(0xFF4B445F);
  static const Color muted = Color(0xFF7C738F);
  static const Color line = Color(0xFFE9E3F5);
  static const Color lineSoft = Color(0xFFF3F0FF);
  static const Color bg = Color(0xFFF5F3FF); // bg app light lavender
  static const Color surface = Color(0xFFFFFFFF);

  static const Color success = Color(0xFF2D7357);
  static const Color warning = Color(0xFFD9880F);
  static const Color danger = Color(0xFFB54450);
  static const Color gold = Color(0xFFD9A441);
  static const Color goldSoft = Color(0xFFE8C07A); // aksen emas lembut (tier/medal)
  static const Color goldBright = Color(0xFFF0D28A);
  static const Color goldMid = Color(0xFFC9A227);
  static const Color goldPale = Color(0xFFEBD08C);
  static const Color goldDeep = Color(0xFF8A6A12);
  static const Color lilac = Color(0xFFA78BFA); // atas grad tombol glossy
  static const Color violetDeep2 = Color(0xFF4B1DA6);
  static const Color midnightDeep = Color(0xFF130236);
  static const Color midnightInk = Color(0xFF12042E);
  static const Color okBright = Color(0xFF22C55E); // indikator online (tailwind green-500)
  static const Color bronze = Color(0xFF9A6B4A);
  static const Color graySoft = Color(0xFF9CA3AF);
  static const Color csRead = Color(0xFF7DD3FC); // centang dibaca (chat)
  static const Color csFail = Color(0xFFFCA5A5); // gagal kirim
  static const Color vipAmber = Color(0xFFC08A2E);
  static const Color shimmerA = Color(0xFFF1EAFF);
  static const Color shimmerB = Color(0xFFFBF8FF);
  static const Color warnInk = Color(0xFF8A5A08);
  static const Color dangerBright = Color(0xFFE05B5B);
  static const Color dangerDeep = Color(0xFFC81E1E);

  // ---------- gradien (VIOLET-INDIGO GLOSSY) ----------
  // Glossy vertikal: terang di atas (efek kaca) → pekat di bawah.
  // - gradPrimary: tombol & kartu saldo (paling sering dipakai)
  // - gradDeep: header / CTA penting
  // - gradMidnight: latar indigo tua #2E1065 → #100030 (persis BG referensi popup)
  // - gradAurora: aksen lembut / shimmer
  static const LinearGradient gradPrimary = LinearGradient(
    colors: [Color(0xFFA78BFA), Color(0xFF7C3AED)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  static const LinearGradient gradDeep = LinearGradient(
    colors: [Color(0xFF8B5CF6), Color(0xFF4C1D95)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  static const LinearGradient gradMidnight = LinearGradient(
    colors: [Color(0xFF2E1065), Color(0xFF100030)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  static const LinearGradient gradAurora = LinearGradient(
    colors: [Color(0xFFC4B5FD), Color(0xFF8B5CF6)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
  static const LinearGradient gradSoft = LinearGradient(
    colors: [Color(0xFFF5F3FF), Color(0xFFEEE8FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient gradGold = LinearGradient(
    colors: [Color(0xFFD3BB8A), Color(0xFFD3BB8A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ---------- elevasi — FLAT OPTIMIZED Batch P ----------
  /// Alias lama supaya kode lain tetap jalan.
  static const Color cyan = violet;

  // Flat: no shadows by default (hemat compositing, lebih ringan di low-end)
  static List<BoxShadow> get shadowXs => const [];
  static List<BoxShadow> get shadowSm => const [];
  static List<BoxShadow> get shadowMd => const [];

  /// Glow diabaikan untuk flat mode — return empty biar tidak ada blur mahal
  static List<BoxShadow> glow(Color c, [double o = .28]) => const [];

  // ---------- palet gelap — TIKTOK STYLE (No Border, Abu-abu) ----------
  // TikTok: background hitam pekat, card abu-abu gelap tanpa border, clean
  // Light mode juga dibikin ala TikTok dark biar tidak ada garis border
  static const Color bgGelap = Color(0xFF0A0A0A); // TikTok black
  static const Color bgGelap2 = Color(0xFF141414); // TikTok subtle
  static const Color surfaceGelap = Color(0xFF1E1E1E); // Card abu-abu TikTok
  static const Color surfaceGelap2 = Color(0xFF262626); // Elevated
  static const Color lineGelap = Color(0xFF1E1E1E); // No visible border — same as surface
  static const Color inkGelap = Color(0xFFF1F1F2); // Teks putih TikTok
  static const Color mutedGelap = Color(0xFF8A8B8F); // Muted abu TikTok

  /// Tanpa gradasi glassmorphism di kartu mode gelap — solid & crisp
  static const LinearGradient? gradDarkCard = null;

  // ---------- tema ----------
  static ThemeData light() {
    // TikTok style: even light mode pakai background hitam ke abu-abuan, card abu-abu tanpa border
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark, // pakai dark brightness biar TikTok style di light mode juga
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        surface: surfaceGelap,
        onSurface: inkGelap,
        onSurfaceVariant: mutedGelap,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xFF0A0A0A),
      splashFactory: InkSparkle.splashFactory,
    );

    final text = GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: inkGelap,
      displayColor: inkGelap,
    );

    return base.copyWith(
      textTheme: text.copyWith(
        displayLarge: text.displayLarge
            ?.copyWith(color: inkGelap, fontWeight: FontWeight.w700, letterSpacing: -1),
        headlineMedium: text.headlineMedium
            ?.copyWith(color: inkGelap, fontWeight: FontWeight.w700, letterSpacing: -1),
        titleLarge: text.titleLarge
            ?.copyWith(color: inkGelap, fontWeight: FontWeight.w700, letterSpacing: -.5),
        titleMedium: text.titleMedium
            ?.copyWith(color: inkGelap, fontWeight: FontWeight.w600, letterSpacing: -.1),
        titleSmall: text.titleSmall
            ?.copyWith(color: inkGelap, fontWeight: FontWeight.w600),
        bodyLarge: text.bodyLarge?.copyWith(color: inkGelap),
        bodyMedium: text.bodyMedium?.copyWith(color: inkGelap, height: 1.55),
        bodySmall: text.bodySmall?.copyWith(color: mutedGelap),
        labelLarge: text.labelLarge?.copyWith(color: inkGelap, fontWeight: FontWeight.w700),
        labelMedium: text.labelMedium?.copyWith(color: mutedGelap),
        labelSmall: text.labelSmall?.copyWith(color: mutedGelap),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0A0A0A),
        foregroundColor: inkGelap,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: inkGelap,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -.4,
        ),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFF2A2A2A),
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(XyRadius.tombol)),
          textStyle: const TextStyle(
              fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: -.1),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: inkGelap,
          backgroundColor: surfaceGelap,
          minimumSize: const Size.fromHeight(52),
          side: BorderSide.none, // No border ala TikTok
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(XyRadius.tombol)),
          textStyle:
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle:
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceGelap,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
        prefixIconColor: mutedGelap,
        suffixIconColor: mutedGelap,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(XyRadius.md),
          borderSide: BorderSide.none, // No border
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(XyRadius.md),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(XyRadius.md),
          borderSide: const BorderSide(color: primary, width: 1.2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(XyRadius.md),
          borderSide: const BorderSide(color: danger),
        ),
        hintStyle: const TextStyle(color: mutedGelap, fontWeight: FontWeight.w500),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: surfaceGelap2,
        side: BorderSide.none,
        labelStyle:
            const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(XyRadius.pill)),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFF1E1E1E), space: 1, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceGelap2,
        contentTextStyle: const TextStyle(
            color: inkGelap, fontWeight: FontWeight.w600, fontSize: 13),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(XyRadius.sm)),
        insetPadding: const EdgeInsets.all(16),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: DialogTheme(
        backgroundColor: surfaceGelap2,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(XyRadius.xl)),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      }),
    );
  }

  /// Tema gelap: TikTok style hitam pekat + card abu-abu tanpa border
  static ThemeData gelap() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: violet,
        surface: surfaceGelap,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xFF0A0A0A),
      splashFactory: InkSparkle.splashFactory,
    );

    final text = GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: inkGelap,
      displayColor: inkGelap,
    );

    return base.copyWith(
      textTheme: text.copyWith(
        headlineMedium: text.headlineMedium
            ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -1),
        titleLarge: text.titleLarge
            ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -.5),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        bodyMedium: text.bodyMedium?.copyWith(height: 1.55),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0A0A0A),
        foregroundColor: inkGelap,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: inkGelap,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -.4,
        ),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: violet,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(XyRadius.tombol)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: inkGelap,
          backgroundColor: surfaceGelap,
          minimumSize: const Size.fromHeight(52),
          side: BorderSide.none,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(XyRadius.tombol)),
          textStyle:
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: lavender,
          textStyle:
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceGelap,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
        prefixIconColor: mutedGelap,
        suffixIconColor: mutedGelap,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(XyRadius.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(XyRadius.md),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(XyRadius.md),
          borderSide: const BorderSide(color: violet, width: 1.2),
        ),
        hintStyle:
            const TextStyle(color: mutedGelap, fontWeight: FontWeight.w500),
      ),
      dividerTheme:
          const DividerThemeData(color: Color(0xFF1E1E1E), space: 1, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceGelap2,
        contentTextStyle: const TextStyle(
            color: inkGelap, fontWeight: FontWeight.w600, fontSize: 13),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(XyRadius.sm)),
        insetPadding: const EdgeInsets.all(16),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: DialogTheme(
        backgroundColor: surfaceGelap2,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(XyRadius.xl)),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      }),
    );
  }
}

/// Warna permukaan/teks harus mengikuti tema pada BuildContext, bukan konstanta terang.
@immutable
class XyPalette {
  const XyPalette(this.dark);
  final bool dark;
  Color get bg => const Color(0xFF0A0A0A); // TikTok black untuk light & dark
  Color get surface => const Color(0xFF1E1E1E); // Card abu-abu TikTok
  Color get surfaceHigh => const Color(0xFF262626);
  Color get ink => const Color(0xFFF1F1F2);
  Color get inkSoft => const Color(0xFFC7C7C7);
  Color get muted => const Color(0xFF8A8B8F);
  Color get line => const Color(0xFF1E1E1E); // No visible border
  Color get lineSoft => const Color(0xFF232323);
  Color get primarySoft => const Color(0xFF262626);
  Color get accent => XyTheme.lavender;
  LinearGradient? get gradSoft => null;
  LinearGradient? get gradCard => null;
}


/// Tema banner profil (Batch D). Nilai harus sama dengan whitelist
/// BANNER_PROFIL di api/src/index.js.
class XyBannerTema {
  XyBannerTema._();

  static const Map<String, List<Color>> peta = {
    'ungu': [Color(0xFF8B5CF6), Color(0xFF4C1D95)],
    'senja': [Color(0xFFFBBF24), Color(0xFFB91C1C)],
    'midnight': [Color(0xFF2E1065), Color(0xFF0F172A)],
    'permen': [Color(0xFFF472B6), Color(0xFF7C3AED)],
    'anggrek': [Color(0xFFA855F7), Color(0xFF4F46E5)],
  };

  static const Map<String, String> label = {
    'ungu': 'Ungu Glossy',
    'senja': 'Senja',
    'midnight': 'Midnight',
    'permen': 'Permen Kapas',
    'anggrek': 'Anggrek Neon',
  };

  static List<Color> warna(String? id) => peta[id ?? ''] ?? peta['ungu']!;
}
