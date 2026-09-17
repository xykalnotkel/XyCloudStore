/// Konfigurasi endpoint XyCloud.
///
/// Ganti [baseUrl] dengan domain Cloudflare Worker milikmu, misalnya:
///   https://api.xycloud.my.id
/// atau  https://xycloud-api.<akun>.workers.dev
///
/// Bisa juga di-override saat build:
///   flutter build apk --dart-define=XY_BASE_URL=https://api.xycloud.id
class XyConfig {
  static const String baseUrl = String.fromEnvironment(
    'XY_BASE_URL',
    defaultValue: 'https://api.xycloud.my.id',
  );

  /// Kalau true, app jalan tanpa server (data dummy) — enak buat demo/UI test.
  static const bool useMock = bool.fromEnvironment(
    'XY_MOCK',
    defaultValue: false,
  );

  /// Alamat yang sedang dipakai. Otomatis pindah ke [baseUrlCadangan]
  /// kalau domain utama tidak bisa dihubungi.
  static String aktif = baseUrl;

  static bool _sudahPindah = false;

  /// Pindah ke alamat cadangan sekali saja. Mengembalikan true kalau berhasil pindah.
  static bool pindahKeCadangan() {
    if (_sudahPindah || baseUrlCadangan.isEmpty || baseUrlCadangan == aktif) return false;
    aktif = baseUrlCadangan;
    _sudahPindah = true;
    return true;
  }

  static String get apiUrl => '$aktif/api';

  /// WebSocket realtime (Cloudflare Durable Object).
  ///
  /// Room privat memakai capability satu menit dari `/api/ws/ticket`; bearer
  /// sesi jangka panjang tidak pernah diletakkan di URL atau access log.
  static String wsUrl(String room, {String? ticket}) {
    final dasar = Uri.parse(aktif);
    return dasar.replace(
      scheme: dasar.scheme == 'https' ? 'wss' : 'ws',
      path: '/ws/${Uri.encodeComponent(room)}',
      queryParameters: ticket == null || ticket.isEmpty ? null : {'ticket': ticket},
    ).toString();
  }

  static const String appName = 'XyCloudStore';

  /// Kalau domain utama bermasalah, aplikasi otomatis pindah ke alamat cadangan.
  static const String baseUrlCadangan = String.fromEnvironment(
    'XY_BASE_URL_FALLBACK',
    defaultValue: 'https://xycloud-api.akuntiktok76y.workers.dev',
  );
  /// Nomor CS cadangan bila `konfigurasi.whatsapp` dari server kosong/gagal.
  /// Sebelumnya berisi placeholder '6281234567890' yang tidak aktif, sehingga
  /// pengguna yang gagal memuat config diarahkan ke nomor mati.
  /// Nilai ini harus sama dengan `WA_ADMIN` di api/wrangler.toml.
  static const String waCs = '6283116632566';
}
