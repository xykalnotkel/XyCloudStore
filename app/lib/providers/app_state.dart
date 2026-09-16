import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../core/cache.dart';
import '../core/config.dart';
import '../core/prefs.dart';
import '../core/pengaturan.dart';
import '../data/api_client.dart';
import '../data/lapor_galat.dart';
import '../data/login_sosial.dart';
import '../data/push_service.dart';
import '../data/realtime_service.dart';
import '../data/repository.dart';
import '../models/models.dart';
import '../models/stiker.dart';
import '../models/promosi.dart';
import '../data/stiker_store.dart';

/// State global aplikasi + jembatan ke channel realtime.
class AppState extends ChangeNotifier {
  AppState({bool mulaiOtomatis = true}) {
    _api = ApiClient();
    _api.onPerawatan = (pesan) {
      perawatan = true;
      pesanPerawatan = pesan;
      offline = false;
      notifyListeners();
    };
    _api.onSesiBerakhir=(){if(user!=null&&!sedangKeluar)unawaited(logout());};
    _repo = XyRepository.create(_api);
    // Mode non-otomatis dipakai widget test/screenshot agar tidak menyalakan
    // jaringan, plugin native, realtime, atau pemulihan sesi di latar belakang.
    if (!mulaiOtomatis) return;
    unawaited(muatKonfigurasi());
    unawaited(muatPromosi());
    unawaited(muatTema());
    unawaited(muatPengaturan());
    unawaited(muatKunciBiometrik());
    unawaited(periksaPembaruan());
    unawaited(pulihkanSesi());
  }

  // ================= passkey / sidik jari (Batch I) =================
  /// Pengaturan "login dengan sidik jari" aktif (tersimpan di Prefs).
  bool kunciBiometrikAktif = false;
  bool _biometrikDibuka = false;

  /// Sesi tersimpan ada, tapi pintu biometrik belum dibuka → tampilkan
  /// KunciBiometrikScreen di depan shell (lihat gate di main.dart).
  bool get perluKunciBiometrik => masuk && kunciBiometrikAktif && !_biometrikDibuka;

  Future<void> muatKunciBiometrik() async {
    kunciBiometrikAktif = await Prefs.kunciBiometrik();
    notifyListeners();
  }

  /// Dipanggil KunciBiometrikScreen setelah verifikasi berhasil.
  void bukaKunciBiometrik() {
    _biometrikDibuka = true;
    notifyListeners();
  }

  /// Toggle dari layar Keamanan. Saat baru diaktifkan, langsung dianggap
  /// terbuka (pengguna barusan lolos autentikasi untuk menyalakannya).
  Future<void> setelKunciBiometrik(bool aktif) async {
    await Prefs.simpanKunciBiometrik(aktif);
    kunciBiometrikAktif = aktif;
    if (aktif) _biometrikDibuka = true;
    notifyListeners();
  }

  /// True selama server dalam mode pemeliharaan (HTTP 503) — aplikasi
  /// menampilkan halaman perawatan yang jelas alih-alih galat membingungkan.
  bool perawatan = false;

  /// True bila pengguna mengetuk "Staf internal? Masuk untuk uji" di halaman
  /// perawatan — halaman login ditampilkan meski server sedang pemeliharaan.
  /// Setelah login, pengguna yang tidak dikecualikan tetap mendapat 503 dan
  /// kembali ke halaman perawatan; yang dikecualikan (setelan
  /// `pemeliharaan_bebas` di server) lanjut memakai aplikasi.
  bool paksaMasukPerawatan = false;

  void ujiMasukPerawatan() {
    paksaMasukPerawatan = true;
    notifyListeners();
  }

  /// Pesan dari server saat mode pemeliharaan menyala.
  String pesanPerawatan =
      'Kami sedang melakukan perawatan singkat. Silakan coba lagi beberapa menit lagi.';

  /// Status pembekuan akun (alasan, masa, pelanggaran, banding) untuk layar
  /// Akun Dibekukan. Null berarti belum dimuat.
  InfoBlokir? infoBlokir;

  /// Muat (atau muat ulang) status pembekuan dari server. Bila masa blokir
  /// sementara ternyata sudah habis, profil dimuat ulang supaya aplikasi
  /// langsung keluar dari layar pembekuan.
  Future<void> muatInfoBlokir() async {
    try {
      final info = await _repo.infoBlokir();
      infoBlokir = info;
      if (!info.diblokir && (user?.diblokir ?? false)) {
        user = await _repo.profilSaya();
      }
    } catch (_) {
      // layar pembekuan menampilkan keadaan terakhir yang diketahui
    }
    notifyListeners();
  }

  /// Ajukan banding; mengembalikan pesan galat atau null bila berhasil.
  Future<String?> ajukanBanding(String pesan) async {
    try {
      await _repo.ajukanBanding(pesan);
      await muatInfoBlokir();
      return null;
    } catch (e) {
      return e is ApiException ? e.pesan : e.toString();
    }
  }

  /// True selama aplikasi masih memeriksa token tersimpan.
  bool memeriksaSesi = true;

  /// True kalau permintaan terakhir ke server gagal karena jaringan.
  bool offline = false;

  /// Data yang tampil sekarang berasal dari singgahan, bukan server.
  bool dariCache = false;

  /// Hemat kuota: gambar produk dan banner tidak diunduh.
  bool hematData = false;

  /// Tema tampilan: sistem, terang, atau gelap.
  ThemeMode modeTema = ThemeMode.light;

  Future<void> muatTema() async {
    final t = await Prefs.tema();
    modeTema = switch (t) {
      'terang' => ThemeMode.light,
      'gelap' => ThemeMode.dark,
      _ => ThemeMode.light,
    };
    notifyListeners();
  }

  Future<void> setTema(String pilihan) async {
    await Prefs.simpanTema(pilihan);
    await muatTema();
  }

  Future<void> muatPengaturan() async {try{await PengaturanLokal.muat();notifyListeners();}catch(_){}}
  Future<void> setPengaturan(String key,dynamic value) async {await PengaturanLokal.set(key,value);notifyListeners();}
  Future<String?> tesNotifikasi() async {try{await _api.post('/me/notifikasi/tes');return null;}catch(e){return _pesan(e);}}
  Future<void> tandaiVideo(String id) async {try{await _api.post('/sesi/$id/stream');}catch(_){}}
  Future<String?> batalOrder(String id) async {try{await _api.post('/orders/$id/batal');await muatSemua(paksa:true);await muatProfilRingkas();return null;}catch(e){return _pesan(e);}}

  /// Info rilis terbaru untuk pengecek pembaruan.
  Map<String, dynamic>? rilisTerbaru;
  String versiSekarang = '';
  bool _bannerRilisDitampilkan = false;

  /// Benar kalau ada versi baru dan popup rilis belum ditampilkan sesi ini.
  bool get tampilkanBannerRilis =>
      adaPembaruan && !_bannerRilisDitampilkan;

  void tandaiBannerRilis() {
    _bannerRilisDitampilkan = true;
    notifyListeners();
  }

  void resetBannerRilis() {
    _bannerRilisDitampilkan = false;
    notifyListeners();
  }

  Future<void> periksaPembaruan() async {
    try {
      final info = await PackageInfo.fromPlatform();
      versiSekarang = info.version;
      final d = await _repo.rilis();
      rilisTerbaru = d;
      notifyListeners();
    } catch (_) {}
  }

  /// True kalau versi di server lebih baru daripada yang terpasang.
  bool get adaPembaruan {
    final v = '${rilisTerbaru?['versi'] ?? ''}'.replaceAll('v', '').trim();
    if (v.isEmpty || versiSekarang.isEmpty) return false;
    int nilai(String x) {
      final b = x.split('.').map((e) => int.tryParse(e.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0).toList();
      while (b.length < 3) {
        b.add(0);
      }
      return b[0] * 1000000 + b[1] * 1000 + b[2];
    }

    return nilai(v) > nilai(versiSekarang);
  }

  Future<void> setHematData(bool v) async {
    hematData = v;
    await Cache.setHematData(v);
    notifyListeners();
  }

  /// Coba masuk otomatis memakai token yang tersimpan di perangkat.
  Future<void> pulihkanSesi() async {
    try {
      final t = await Prefs.token();
      if (t == null || t.isEmpty) return;
      _repo.pasangToken(t);
      user = await _repo.profilSaya();
      await muatSemua();
      _mulaiRealtime();
      _daftarkanPush();
      unawaited(muatNotifikasi());
      unawaited(muatFavorit());
    } catch (e) {
      if (e is ApiException && e.sedangPerawatan) {
        // server lagi perawatan: jangan buang token, biarkan pengguna tetap
        // "masuk" lewat perangkat; halaman perawatan yang akan tampil
        perawatan = true;
        pesanPerawatan = e.pesan;
        user = null;
      } else {
        // token kedaluwarsa atau tidak valid
        await Prefs.hapusToken();
        _repo.pasangToken('');
        user = null;
      }
    } finally {
      memeriksaSesi = false;
      notifyListeners();
    }
  }

  /// Dipanggil tombol "Coba Lagi" di halaman perawatan: coba pulihkan sesi
  /// dan muat data lagi. Begitu server menjawab normal, [perawatan] mati
  /// sendiri lewat [muatSemua].
  Future<void> cobaLagiPerawatan() async {
    perawatan = false;
    error = null;
    notifyListeners();
    if (user == null) {
      memeriksaSesi = true;
      notifyListeners();
      await pulihkanSesi();
    } else {
      await muatSemua(paksa: true);
      await muatNotifikasi();
      notifyListeners();
    }
  }

  late final ApiClient _api;
  late final XyRepository _repo;

  /// Akses repository untuk layar sosial (Batch D): profil publik, DM, follows.
  XyRepository get repo => _repo;
  RealtimeService? _rt;
  RealtimeService? _rtKatalog;
  RealtimeService? _rtForum;
  StreamSubscription? _rtSub;
  StreamSubscription? _rtState;
  Timer? _mockTicker;
  Timer? _clock;

  List<Promosi> promosi = [];
  Future<void> muatPromosi() async {
    try {
      final d = await _api.get('/promosi');
      promosi = (d as List).map((x)=>Promosi.fromJson(Map<String,dynamic>.from(x)))
          .where((x)=>x.platform=='app'||x.platform=='semua').toList();
      notifyListeners();
    } catch (_) {}
  }
  Future<Map<String,dynamic>> cariStiker(String q, {String jenis='stiker', int offset=0}) async =>
    Map<String,dynamic>.from(await _api.get('/stiker/giphy',{'q':q,'jenis':jenis,'offset':offset}));
  Future<Stiker> imporStiker(String url) async => Stiker.fromJson(Map<String,dynamic>.from(await _api.post('/stiker/impor',{'url':url})));
  Future<Map<String,dynamic>> infoHapusAkun() async => Map<String,dynamic>.from(await _api.get('/me/hapus/info'));
  Future<void> mintaKodeHapus() async { await _api.post('/me/hapus/kode'); }
  int forumRevisi = 0;
  final Map<String,Map<String,dynamic>> _identitasForum = {};
  String namaPengguna(String id, String cadangan) => id==user?.id ? user!.nama : '${_identitasForum[id]?['nama']??cadangan}';
  String? fotoPengguna(String id, String? cadangan) => id==user?.id ? user!.foto : _identitasForum[id]?['foto'] as String? ?? cadangan;

  // ---------------- state ----------------
  UserProfile? user;
  bool loading = false;
  String? error;

  List<PcPlan> plans = [];
  List<AkunProduk> produk = [];
  List<PromoBanner> banners = [];
  List<RentOrder> orders = [];
  List<Transaksi> transaksi = [];
  List<ChatMessage> chat = [];

  RealtimeState koneksi = RealtimeState.offline;
  bool csMengetik = false;
  int notifBelumDibaca = 0;

  bool get masuk => user != null;

  /// True bila pengguna sudah masuk tapi profilnya belum lengkap (username
  /// kosong) — aplikasi menampilkan layar Lengkapi Profil sekali, termasuk
  /// untuk akun yang mendaftar lewat Google.
  bool get perluLengkapiProfil =>
      user != null && (user!.username ?? '').trim().isEmpty;
  RentOrder? get orderAktif {
    try {
      return orders.firstWhere((o) =>
          o.status == OrderStatus.aktif ||
          o.status == OrderStatus.provisioning ||
          o.status == OrderStatus.dibayar ||
          o.status == OrderStatus.pending);
    } catch (_) {
      return null;
    }
  }

  // ---------------- auth ----------------
  Future<bool> login(String email, String password) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      user = await _repo.login(email, password);
      await _simpanSesi();
      await muatSemua();
      _mulaiRealtime();
      _daftarkanPush();
      unawaited(muatNotifikasi());
      unawaited(muatFavorit());
      return true;
    } on PerluVerifikasi catch (e) {
      emailMenungguVerifikasi = e.email;
      error = e.pesan;
      return false;
    } catch (e) {
      error = _pesan(e);
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Hasil pendaftaran: minta pengguna memasukkan kode dari email.
  String? emailMenungguVerifikasi;

  Future<Map<String, dynamic>?> daftar({
    required String nama,
    required String email,
    required String password,
    String? phone,
  }) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final d = await _repo.daftar(nama: nama, email: email, password: password, phone: phone);
      emailMenungguVerifikasi = '${d['email'] ?? email}';
      return d;
    } catch (e) {
      error = _pesan(e);
      return null;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> verifikasiEmail(String email, String kode) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      user = await _repo.verifikasiEmail(email, kode);
      emailMenungguVerifikasi = null;
      await _simpanSesi();
      await muatSemua();
      _mulaiRealtime();
      _daftarkanPush();
      return true;
    } catch (e) {
      error = _pesan(e);
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<String?> kirimUlangKode(String email, {String tipe = 'verifikasi'}) async {
    try {
      return await _repo.kirimUlangKode(email, tipe: tipe);
    } catch (e) {
      error = _pesan(e);
      return null;
    }
  }

  Future<String?> lupaPassword(String email) async {
    loading = true;
    notifyListeners();
    try {
      return await _repo.lupaPassword(email);
    } catch (e) {
      error = _pesan(e);
      return null;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> resetPassword({required String email, required String kode, required String password}) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      user = await _repo.resetPassword(email: email, kode: kode, password: password);
      await _simpanSesi();
      await muatSemua();
      _mulaiRealtime();
      _daftarkanPush();
      return true;
    } catch (e) {
      error = _pesan(e);
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  // ================= konfigurasi server =================
  KonfigurasiApp konfigurasi = const KonfigurasiApp();

  Future<void> muatKonfigurasi() async {
    try {
      konfigurasi = await _repo.konfigurasi();
      // Batch M: perangkat yang belum login tidak pernah menerima 503
      // (auth/* sengaja tetap terbuka saat pemeliharaan) — statusnya kini
      // terbaca lewat /config, jadi halaman perawatan tampil juga untuk
      // mereka, bukan onboarding/login.
      if (konfigurasi.pemeliharaanAktif && !perawatan) {
        perawatan = true;
        if (konfigurasi.pemeliharaanPesan.isNotEmpty) {
          pesanPerawatan = konfigurasi.pemeliharaanPesan;
        }
      }
      notifyListeners();
    } catch (_) {
      // biarkan memakai nilai bawaan kalau server belum bisa dihubungi
    }
  }

  /// Ambil dokumen legal dari server (dengan singgahan sederhana).
  final Map<String, Map<String, dynamic>> _legal = {};

  Future<Map<String, dynamic>> dokumenLegal(String jenis) async {
    if (_legal.containsKey(jenis)) return _legal[jenis]!;
    final d = await _repo.legal(jenis);
    _legal[jenis] = d;
    return d;
  }

  // ================= login lewat Google atau Facebook =================
  /// Dipanggil setelah aplikasi menerima token dari halaman OAuth.
  Future<bool> masukDenganToken(String token) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      _repo.pasangToken(token);
      await Prefs.simpanToken(token);
      user = await _repo.profilSaya();
      await muatSemua();
      _mulaiRealtime();
      _daftarkanPush();
      return true;
    } catch (e) {
      error = _pesan(e);
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Login Google: coba dialog native dulu, kalau tidak bisa baru lewat halaman.
  Future<bool> masukGoogle() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final idToken = await LoginSosial.idTokenGoogleNative();
      if (idToken != null) {
        user = await _repo.masukGoogleNative(idToken);
        await _simpanSesi();
        await muatSemua();
        _mulaiRealtime();
        _daftarkanPush();
        return true;
      }
      // perangkat belum mendukung dialog native
      final token = await LoginSosial.tokenLewatHalaman('google');
      _repo.pasangToken(token);
      await Prefs.simpanToken(token);
      user = await _repo.profilSaya();
      await muatSemua();
      _mulaiRealtime();
      _daftarkanPush();
      return true;
    } on GagalLoginSosial catch (e) {
      error = e.pesan;
      return false;
    } catch (e) {
      error = _pesan(e);
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  // ================= sesi main di PC sewaan =================
  Future<SesiMain?> mulaiSesi(String orderId) async {
    error = null;
    try {
      return await _repo.sesiMulai(orderId);
    } catch (e) {
      error = _pesan(e);
      return null;
    }
  }

  Future<SesiMain?> statusSesi(String id) async {
    try {
      return await _repo.sesiStatus(id);
    } catch (_) {
      return null;
    }
  }

  Future<String?> kirimPinSesi(String id, String pin, {String? clientId}) async {
    try {
      await _api.post('/sesi/$id/pin', {'pin':pin,if(clientId!=null)'client_id':clientId});
      return null;
    } catch (e) {
      return _pesan(e);
    }
  }

  Future<String?> akhiriSesi(String id) async {
    try { await _repo.sesiAkhiri(id); return null; } catch(e) { return _pesan(e); }
  }

  // ================= pemberitahuan =================
  List<Notifikasi> notifikasi = [];
  int notifBelum = 0;
  bool notifMemuat = false;

  Future<void> muatNotifikasi() async {
    if (user == null) return;
    notifMemuat = true;
    notifyListeners();
    try {
      final d = await _repo.notifikasi();
      notifikasi = ((d['daftar'] as List?) ?? const [])
          .map((e) => Notifikasi.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      notifBelum = d['belumDibaca'] ?? 0;
    } catch (_) {
      // biarkan daftar lama tetap tampil
    } finally {
      notifMemuat = false;
      notifyListeners();
    }
  }

  Future<void> bacaNotifikasi({String? id}) async {
    try {
      await _repo.bacaNotifikasi(id: id);
      if (id == null) {
        notifikasi = notifikasi
            .map((n) => Notifikasi(
                  id: n.id, jenis: n.jenis, judul: n.judul, pesan: n.pesan, aktor: n.aktor,
                  refJenis: n.refJenis, refId: n.refId, dibaca: true, dibuat: n.dibuat,
                ))
            .toList();
        notifBelum = 0;
      } else {
        final i = notifikasi.indexWhere((n) => n.id == id);
        if (i >= 0) {
          final n = notifikasi[i];
          notifikasi[i] = Notifikasi(
            id: n.id, jenis: n.jenis, judul: n.judul, pesan: n.pesan, aktor: n.aktor,
            refJenis: n.refJenis, refId: n.refId, dibaca: true, dibuat: n.dibuat,
          );
          if (notifBelum > 0) notifBelum--;
        }
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> hapusNotifikasi() async {
    try {
      await _repo.hapusNotifikasi();
      notifikasi = [];
      notifBelum = 0;
      notifyListeners();
    } catch (_) {}
  }

  // ================= suka komentar dan laporan =================
  Set<String> balasanDisukai = {};

  Future<void> muatSukaBalasan() async {
    try {
      balasanDisukai = (await _repo.balasanDisukai()).toSet();
      notifyListeners();
    } catch (_) {}
  }

  Future<int?> sukaBalasan(String id) async {
    final tadinya = balasanDisukai.contains(id);
    tadinya ? balasanDisukai.remove(id) : balasanDisukai.add(id);
    notifyListeners();
    try {
      final d = await _repo.sukaBalasan(id);
      if (d['disukai'] == true) {
        balasanDisukai.add(id);
      } else {
        balasanDisukai.remove(id);
      }
      notifyListeners();
      return d['suka'] as int?;
    } catch (_) {
      tadinya ? balasanDisukai.add(id) : balasanDisukai.remove(id);
      notifyListeners();
      return null;
    }
  }

  Future<String?> laporkan({
    required String jenis,
    required String refId,
    String? url,
    String? alasan,
  }) async {
    try {
      await _repo.laporkan(jenis: jenis, refId: refId, url: url, alasan: alasan);
      return null;
    } catch (e) {
      return _pesan(e);
    }
  }

  /// Segarkan profil saja, dipakai setelah transaksi supaya tier ikut terbarui.
  Future<void> muatProfilRingkas() async {
    try {
      user = await _repo.profilSaya();
      notifyListeners();
    } catch (_) {}
  }

  // ================= undang teman =================
  Future<Map<String, dynamic>> dataReferral() => _repo.dataReferral();

  Future<Map<String, dynamic>?> pakaiReferral(String kode) async {
    error = null;
    try {
      final d = await _repo.pakaiReferral(kode);
      await muatProfilRingkas();
      return d;
    } catch (e) {
      error = _pesan(e);
      return null;
    }
  }

  // ================= favorit produk =================
  Set<String> favorit = {};

  Future<void> muatFavorit() async {
    if (user == null) return;
    try {
      favorit = (await _repo.favorit()).toSet();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> ubahFavorit(String produkId) async {
    final tadinya = favorit.contains(produkId);
    tadinya ? favorit.remove(produkId) : favorit.add(produkId);
    notifyListeners();
    try {
      final hasil = await _repo.ubahFavorit(produkId);
      hasil ? favorit.add(produkId) : favorit.remove(produkId);
    } catch (_) {
      tadinya ? favorit.add(produkId) : favorit.remove(produkId);
    }
    notifyListeners();
  }

  // ================= ulasan paket PC =================
  Future<List<Ulasan>> ulasanPaket(String planId) => _repo.ulasanPaket(planId);

  Future<String?> nilaiPaket({
    required String planId,
    required int rating,
    String? komentar,
    String? orderId,
  }) async {
    try {
      await _repo.kirimUlasanPaket(planId: planId, rating: rating, komentar: komentar, orderId: orderId);
      await muatSemua();
      return null;
    } catch (e) {
      return _pesan(e);
    }
  }

  /// Unduh seluruh data pribadi dalam bentuk JSON.
  Future<Map<String, dynamic>?> dataSaya() async {
    try {
      return await _repo.dataSaya();
    } catch (e) {
      error = _pesan(e);
      return null;
    }
  }

  // ================= voucher =================
  Future<Map<String, dynamic>?> cekVoucher({
    required String kode,
    required String jenis,
    required int total,
  }) async {
    error = null;
    try {
      return await _repo.cekVoucher(kode: kode, jenis: jenis, total: total);
    } catch (e) {
      error = _pesan(e);
      return null;
    }
  }

  // ================= hapus akun =================
  Future<String?> hapusAkun({String? password, String? kode, bool paksa = false}) async {
    try {
      final id = user?.id;
      await _repo.hapusAkun(password: password, kode: kode);
      if (id != null) {
        try { await StikerStore.untuk(id).hapusSemua(); } catch (_) {}
      }
      await logout();
      return null;
    } catch (e) { return _pesan(e); }
  }

  // ================= profil =================
  Future<String?> perbaruiProfil({String? nama, String? phone, String? foto, bool? notifForum, bool? notifDm, String? bio, String? banner, String? username, String? bingkai, String? slogan, String? bioLink, String? gayaNama}) async {
    try {
      user = await _repo.perbaruiProfil(nama: nama, phone: phone, foto: foto, notifForum: notifForum, notifDm: notifDm, bio: bio, banner: banner, username: username, bingkai: bingkai, slogan: slogan, bioLink: bioLink, gayaNama: gayaNama);
      forumRevisi++;
      forum = forum.map((p) => p.userId == user!.id ? ForumPost.fromJson({...p.toJson(), 'nama': user!.nama, 'foto': user!.foto}) : p).toList();
      _ulasan.clear();
      unawaited(muatForum(paksa: true));
      notifyListeners();
      return null;
    } catch (e) {
      return _pesan(e);
    }
  }

  // ================= banner media kustom (Batch I) =================
  /// Unggah GIF/MP4 jadi banner profil. Server menolak akun basic (403).
  Future<String?> unggahBannerMedia(
    String dataUri, {
    void Function(int terkirim, int total)? onProgress,
  }) async {
    try {
      await _repo.unggahBannerMedia(dataUri, onProgress: onProgress);
      await muatProfilRingkas();
      return null;
    } catch (e) {
      return _pesan(e);
    }
  }

  Future<String?> hapusBannerMedia() async {
    try {
      await _repo.hapusBannerMedia();
      await muatProfilRingkas();
      return null;
    } catch (e) {
      return _pesan(e);
    }
  }

  // ================= transfer saldo (Batch I) =================
  Future<Map<String, dynamic>> cariPenerimaTransfer(String q) =>
      _repo.cariTransfer(q);

  /// Batch L: autocomplete @mention di composer komunitas.
  Future<List<Map<String, dynamic>>> cariMention(String q) =>
      _repo.cariMention(q);

  /// Kirim saldo. Melempar ApiException dengan pesan server (PIN salah,
  /// saldo kurang, batas harian, dsb.) — pemanggil yang menampilkan.
  Future<Map<String, dynamic>> kirimTransfer({
    required String ke,
    required int nominal,
    required String pin,
    String? catatan,
  }) async {
    final hasil = await _repo.kirimTransfer(
        ke: ke, nominal: nominal, pin: pin, catatan: catatan);
    await muatProfilRingkas();
    return hasil;
  }

  Future<String> mintaKodePinTransfer() => _repo.mintaKodePinTransfer();

  Future<void> setPinTransfer(String pin, String konfirmasi) async {
    await _repo.setPinTransfer(pin, konfirmasi);
    await muatProfilRingkas();
  }

  Future<String?> kodePasswordSosial() async {try{await _api.post('/me/password/kode');return null;}catch(e){return _pesan(e);}}
  Future<String?> gantiPassword(String lama, String baru) async {
    try {
      await _repo.gantiPassword(lama, baru);
      await logout();
      return null;
    } catch (e) {
      return _pesan(e);
    }
  }

  // ================= forum komunitas =================
  List<ForumPost> forum = [];
  Set<String> forumDisukai = {};

  /// Posting yang dibookmark pengguna (Batch D).
  Set<String> forumDisimpan = {};
  bool _simpanPernahDimuat = false;

  /// Bisukan thread notifikasi (dipakai tombol aksi "Bisukan" pada push).
  Future<String?> bisukanThread(String thread, int menit) async {
    try {
      await _repo.bisukan(thread, menit);
      return null;
    } catch (e) {
      return _pesan(e);
    }
  }

  Future<void> muatSimpanan({bool paksa = false}) async {
    if (_simpanPernahDimuat && !paksa) return;
    _simpanPernahDimuat = true;
    try {
      forumDisimpan = (await _repo.simpanSaya()).toSet();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> simpanForum(String id) async {
    final tadinya = forumDisimpan.contains(id);
    forumDisimpan = {...forumDisimpan}..remove(id);
    if (!tadinya) forumDisimpan.add(id); // optimis
    notifyListeners();
    try {
      final r = await _repo.simpanPost(id);
      final disimpan = r['disimpan'] == true || r['disimpan'] == 1;
      forumDisimpan = {...forumDisimpan}..remove(id);
      if (disimpan) forumDisimpan.add(id);
      notifyListeners();
    } catch (_) {
      forumDisimpan = {...forumDisimpan}..remove(id);
      if (tadinya) forumDisimpan.add(id); // rollback
      notifyListeners();
    }
  }
  bool forumMemuat = false;
  String? forumGalat;

  Future<void> muatForum({bool paksa = false}) async {
    if (forumMemuat) return;
    forumMemuat = true;
    forumGalat = null;
    notifyListeners();

    if (!paksa && forum.isEmpty) {
      final simpanan = await Cache.daftar('forum');
      if (simpanan.isNotEmpty) {
        forum = simpanan.map((e) => ForumPost.fromJson(Map<String, dynamic>.from(e))).toList();
        notifyListeners();
      }
    }

    try {
      forum = await _repo.forum();
      offline = false;
      unawaited(Cache.simpan('forum', forum.map((e) => e.toJson()).toList()));
      if (user != null) {
        try {
          forumDisukai = (await _repo.forumSukaSaya()).toSet();
          unawaited(muatSimpanan());
        } catch (_) {}
      }
    } catch (e) {
      offline = _masalahJaringan(e);
      forumGalat = _pesan(e);
    } finally {
      forumMemuat = false;
      notifyListeners();
    }
  }

  Future<List<ForumBalasan>> detailForum(String id) => _repo.forumDetail(id);

  Future<String?> buatForum({
    required String judul,
    required String isi,
    required String kategori,
    String? gambar,
  }) async {
    try {
      final post = await _repo.forumBuat(judul: judul, isi: isi, kategori: kategori, gambar: gambar);
      forum.insert(0, post);
      notifyListeners();
      return null;
    } catch (e) {
      return _pesan(e);
    }
  }

  Future<String?> balasForum(String id, String isi, {String? balasKe, Map<String,dynamic>? stiker}) async {
    try {
      await _repo.forumBalas(id, isi, balasKe: balasKe, stiker: stiker);
      unawaited(muatForum(paksa: true));
      notifyListeners();
      return null;
    } catch (e) {
      return _pesan(e);
    }
  }

  Future<void> sukaForum(String id) async {
    // tampilkan perubahan lebih dulu supaya terasa cepat
    final i = forum.indexWhere((f) => f.id == id);
    final tadinya = forumDisukai.contains(id);
    if (i >= 0) forum[i].suka += tadinya ? -1 : 1;
    tadinya ? forumDisukai.remove(id) : forumDisukai.add(id);
    notifyListeners();

    try {
      final d = await _repo.forumSuka(id);
      if (i >= 0) forum[i].suka = d['suka'] ?? forum[i].suka;
      if (d['disukai'] == true) {
        forumDisukai.add(id);
      } else {
        forumDisukai.remove(id);
      }
    } catch (_) {
      // kembalikan seperti semula kalau gagal
      if (i >= 0) forum[i].suka += tadinya ? 1 : -1;
      tadinya ? forumDisukai.add(id) : forumDisukai.remove(id);
    }
    notifyListeners();
  }

  Future<String?> suntingForum({
    required String id,
    required String judul,
    required String isi,
    String? kategori,
  }) async {
    try {
      final baru = await _repo.forumSunting(id: id, judul: judul, isi: isi, kategori: kategori);
      final i = forum.indexWhere((f) => f.id == id);
      if (i >= 0) forum[i] = baru;
      notifyListeners();
      return null;
    } catch (e) {
      return _pesan(e);
    }
  }

  Future<String?> hapusBalasanForum(String id, String postId) async {
    try {
      await _repo.forumHapusBalasan(id);
      unawaited(muatForum(paksa: true));
      notifyListeners();
      return null;
    } catch (e) {
      return _pesan(e);
    }
  }

  /// Hapus satu pesan chat milik sendiri.
  Future<String?> hapusPesan(String id) async {
    try {
      await _repo.hapusPesan(id);
      chat.removeWhere((m) => m.id == id);
      notifyListeners();
      return null;
    } catch (e) {
      return _pesan(e);
    }
  }

  /// Bersihkan seluruh pesan yang pernah kukirim.
  Future<String?> hapusSemuaPesan() async {
    try {
      await _repo.hapusSemuaPesan();
      await muatChat();
      return null;
    } catch (e) {
      return _pesan(e);
    }
  }

  Future<String?> hapusForum(String id) async {
    try {
      await _repo.forumHapus(id);
      forum.removeWhere((f) => f.id == id);
      notifyListeners();
      return null;
    } catch (e) {
      return _pesan(e);
    }
  }

  // ================= ulasan produk =================
  final Map<String, List<Ulasan>> _ulasan = {};

  List<Ulasan> ulasanProduk(String produkId) => _ulasan[produkId] ?? const [];

  Future<List<Ulasan>> muatUlasan(String produkId) async {
    try {
      final data = await _repo.ulasan(produkId);
      _ulasan[produkId] = data;
      notifyListeners();
      return data;
    } catch (_) {
      return _ulasan[produkId] ?? const [];
    }
  }

  Future<String?> kirimUlasan({
    required String produkId,
    required int rating,
    required String komentar,
    String? gambar,
  }) async {
    try {
      await _repo.kirimUlasan(produkId: produkId, rating: rating, komentar: komentar, gambar: gambar);
      await muatUlasan(produkId);
      await muatProduk();
      return null;
    } catch (e) {
      return _pesan(e);
    }
  }

  // ================= dompet: top up sungguhan =================
  List<PermintaanTopup> topupSaya = [];

  Future<void> muatTopup() async {
    try {
      topupSaya = await _repo.daftarTopup();
      notifyListeners();
    } catch (_) {}
  }

  Future<PermintaanTopup?> buatTopup(int nominal, String metode) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final t = await _repo.buatTopup(nominal, metode);
      await muatTopup();
      return t;
    } catch (e) {
      error = _pesan(e);
      return null;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Polling status top up sehabis bayar. [paksa] = sekalian memicu server
  /// bertanya ke penyedia pembayaran (QRIS/DANA sudah benar-benar dibayar?).
  /// Mengembalikan status terbaru; saldo disinkronkan begitu 'disetujui'.
  Future<String?> cekStatusTopup(String idTopup, {bool paksa = false}) async {
    try {
      final r = paksa
          ? await _repo.cekTopupPenyedia(idTopup)
          : await _repo.statusTopup(idTopup);
      final status = '${r['status'] ?? ''}';
      if (status == 'disetujui' && user != null) {
        final saldoBaru = r['saldo'];
        if (saldoBaru is num && user!.saldo != saldoBaru.toInt()) {
          user = user!.copyWith(saldo: saldoBaru.toInt());
          notifyListeners();
        }
      }
      return status.isEmpty ? null : status;
    } catch (_) {
      return null;
    }
  }

  Future<String?> unggahBukti(String idTopup, String dataUri) async {
    try {
      await _repo.unggahBukti(idTopup, dataUri);
      await muatTopup();
      return null;
    } catch (e) {
      return _pesan(e);
    }
  }

  /// Simpan token aktif supaya sesi bertahan setelah aplikasi ditutup.
  Future<void> _simpanSesi() async {
    final t = _api.token;
    if (t != null && t.isNotEmpty) await Prefs.simpanToken(t);
  }

  /// Hubungkan akun ini ke OneSignal supaya notifikasi tetap masuk saat aplikasi tertutup.
  void _daftarkanPush() {
    final id = user?.id;
    if (id != null) {
      PushService.masuk(id);
      LaporGalat.userId = id;
    }
  }

  /// Ubah pesan kesalahan teknis jadi kalimat yang mudah dimengerti.
  String _pesan(Object e) {
    final t = e.toString();
    final i = t.indexOf('): ');
    if (i > 0) return t.substring(i + 3);
    if (t.contains('SocketException') || t.contains('Failed host lookup') || t.contains('TimeoutException')) {
      return 'Tidak bisa terhubung ke server. Cek koneksi internet kamu.';
    }
    return t.replaceFirst('Exception: ', '');
  }

  bool sedangKeluar = false;
  Future<void> logout() async {
    if (sedangKeluar) return;
    sedangKeluar = true;
    _api.setToken(null);
    _rtSub?.cancel(); _rtState?.cancel();
    _rt?.dispose(); _rtKatalog?.dispose(); _rtForum?.dispose();
    _rt = null; _rtKatalog = null; _rtForum = null;
    _mockTicker?.cancel(); _clock?.cancel();
    await Prefs.hapusToken();
    await Cache.bersihkan();
    await PushService.keluar().timeout(const Duration(seconds: 5), onTimeout: () {});
    LaporGalat.userId = null;
    perawatan = false; memeriksaSesi = false; loading = false;
    offline = false; dariCache = false; error = null;
    user = null; orders = []; transaksi = []; chat = []; topupSaya = [];
    forum = []; forumDisukai.clear(); balasanDisukai.clear();
    notifikasi = []; notifBelum = 0; notifBelumDibaca = 0;
    favorit.clear(); _ulasan.clear(); _identitasForum.clear();
    csMengetik = false; koneksi = RealtimeState.offline;
    _biometrikDibuka = false; // sesi berikutnya harus lewat biometrik lagi
    sedangKeluar = false;
    notifyListeners();
  }

  // ---------------- data ----------------
  /// Ambil semua data. Singgahan ditampilkan lebih dulu supaya layar
  /// langsung terisi, lalu diperbarui begitu server menjawab.
  Future<void> muatSemua({bool paksa = false}) async {
    hematData = await Cache.hematData();
    if (!paksa) await _muatDariCache();

    try {
      final hasil = await Future.wait([
        _repo.plans(),
        _repo.produkAkun(),
        _repo.banners(),
        _repo.orders(),
        _repo.transaksi(),
        _repo.riwayatChat(),
      ]);
      plans = hasil[0] as List<PcPlan>;
      produk = hasil[1] as List<AkunProduk>;
      banners = hasil[2] as List<PromoBanner>;
      orders = hasil[3] as List<RentOrder>;
      transaksi = hasil[4] as List<Transaksi>;
      chat = hasil[5] as List<ChatMessage>;

      offline = false;
      dariCache = false;
      perawatan = false; // server menjawab normal
      error = null;
      unawaited(_simpanCache());
      unawaited(muatTopup());
    } catch (e) {
      if (e is ApiException && e.sedangPerawatan) {
        perawatan = true;
        pesanPerawatan = e.pesan;
        offline = false;
      } else {
        offline = _masalahJaringan(e);
        error = _pesan(e);
      }
      // kalau belum ada isi sama sekali, coba singgahan sebagai penyelamat
      if (plans.isEmpty && produk.isEmpty) await _muatDariCache();
    }
    notifyListeners();
  }

  bool _masalahJaringan(Object e) {
    final t = e.toString().toLowerCase();
    return t.contains('socket') ||
        t.contains('failed host') ||
        t.contains('timeout') ||
        t.contains('connection') ||
        t.contains('jaringan') ||
        t.contains('koneksi');
  }

  Future<void> _muatDariCache() async {
    try {
      final p = await Cache.daftar('plans');
      final pr = await Cache.daftar('produk');
      final bn = await Cache.daftar('banners');
      final od = await Cache.daftar('orders_${user?.id}');
      final tr = await Cache.daftar('transaksi_${user?.id}');
      if (p.isEmpty && pr.isEmpty) return;

      plans = p.map((e) => PcPlan.fromJson(Map<String, dynamic>.from(e))).toList();
      produk = pr.map((e) => AkunProduk.fromJson(Map<String, dynamic>.from(e))).toList();
      banners = bn.map((e) => PromoBanner.fromJson(Map<String, dynamic>.from(e))).toList();
      orders = od.map((e) => RentOrder.fromJson(Map<String, dynamic>.from(e))).toList();
      transaksi = tr.map((e) => Transaksi.fromJson(Map<String, dynamic>.from(e))).toList();
      dariCache = true;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _simpanCache() async {
    try {
      await Cache.simpan('plans', plans.map((e) => e.toJson()).toList());
      await Cache.simpan('produk', produk.map((e) => e.toJson()).toList());
      await Cache.simpan('banners', banners.map((e) => e.toJson()).toList());
      await Cache.simpan('orders_${user?.id}', orders.map((e) => e.toJson()).toList());
      await Cache.simpan('transaksi_${user?.id}', transaksi.map((e) => e.toJson()).toList());
    } catch (_) {}
  }

  /// Muat ulang daftar produk saja (dipakai setelah menulis ulasan).
  Future<void> muatProduk() async {
    try {
      produk = await _repo.produkAkun();
      notifyListeners();
    } catch (_) {}
  }

  /// Muat ulang riwayat chat.
  Future<void> muatChat() async {
    if(!masuk)return;
    try {
      final remote=await _repo.riwayatChat();
      final clients=remote.map((x)=>x.clientId).whereType<String>().toSet();
      final pending=chat.where((x)=>x.id.startsWith('local_')&&!clients.contains(x.clientId)).toList();
      chat=[...remote,...pending]..sort((a,b)=>a.waktu.compareTo(b.waktu));
      notifyListeners();
    } catch (_) {}
  }

  Future<void> refresh() => muatSemua(paksa: true);

  // ---------------- realtime ----------------
  void _mulaiRealtime() {
    // jam berdetak: countdown sesi aktif ter-update tiap detik
    _clock?.cancel();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (orders.any((o) => o.status == OrderStatus.aktif)) notifyListeners();
    });

    if (XyConfig.useMock) {
      _mulaiSimulasi();
      koneksi = RealtimeState.online;
      notifyListeners();
      return;
    }

    _rt = RealtimeService();
    _rtState = _rt!.state.listen((s) {
      koneksi = s;
      if(s==RealtimeState.online)unawaited(muatChat());
      notifyListeners();
    });
    _rtSub = _rt!.events.listen(_handleEvent);
    _rt!.connect(room: 'user:${user!.id}', token: _api.token ?? '');

    // channel katalog: stok unit dan banner promo untuk semua pengguna
    _rtKatalog = RealtimeService();
    _rtKatalog!.events.listen(_handleEvent);
    _rtKatalog!.connect(room: 'katalog', token: _api.token ?? '');

    _rtForum = RealtimeService();
    _rtForum!.events.listen(_handleEvent);
    _rtForum!.connect(room: 'forum', token: _api.token ?? '');
  }

  void _handleEvent(RealtimeEvent e) {
    if (!masuk) return;
    if (e.type.startsWith('forum.')) forumRevisi++;
    switch (e.type) {
      case 'promosi.update':
        unawaited(muatPromosi());
        break;
      case 'forum.profil':
        _identitasForum['${e.payload['user_id']}'] = Map<String,dynamic>.from(e.payload);
        unawaited(muatForum(paksa: true));
        break;
      case 'forum.refresh':
        unawaited(muatForum(paksa: true));
        break;
      case 'order.update':
        final upd = RentOrder.fromJson(e.payload);
        final i = orders.indexWhere((o) => o.id == upd.id);
        if (i >= 0) {
          orders[i] = upd;
        } else {
          orders.insert(0, upd);
        }
        notifBelumDibaca++;
        break;
      case 'stock.update':
        final id = '${e.payload['id']}';
        final n = e.payload['unitTersedia'] ?? e.payload['unit_tersedia'];
        final p = plans.where((x) => x.id == id).firstOrNull;
        if (p != null && n is int) p.unitTersedia = n;
        break;
      case 'chat.message':
        _terimaPesan(ChatMessage.fromJson(e.payload));
        break;
      case 'cs.typing':
        csMengetik = e.payload['typing'] == true;
        break;
      case 'banner.update':
        try {
          final list = (e.payload['banners'] as List?) ?? const [];
          banners = list.map((x) => PromoBanner.fromJson(Map<String, dynamic>.from(x))).toList();
        } catch (_) {}
        break;
      case 'sesi.update':
        // status sesi diperbarui oleh agen PC
        break;
      case 'notif.baru':
        try {
          notifikasi.insert(0, Notifikasi.fromJson(Map<String, dynamic>.from(e.payload)));
          notifBelum++;
        } catch (_) {}
        break;
      case 'forum.balasan.suka':
        break;
      case 'chat.hapus':
        chat.removeWhere((m) => m.id == '${e.payload['id']}');
        break;
      case 'forum.ubah':
        try {
          final p = ForumPost.fromJson(Map<String, dynamic>.from(e.payload));
          final i = forum.indexWhere((f) => f.id == p.id);
          if (i >= 0) forum[i] = p;
        } catch (_) {}
        break;
      case 'forum.balasan.hapus':
        unawaited(muatForum(paksa: true));
        break;
      case 'forum.baru':
        try {
          final p = ForumPost.fromJson(Map<String, dynamic>.from(e.payload));
          if (!forum.any((f) => f.id == p.id)) forum.insert(0, p);
        } catch (_) {}
        break;
      case 'forum.balasan':
        unawaited(muatForum(paksa: true));
        break;
      case 'forum.suka':
        try {
          final i = forum.indexWhere((f) => f.id == '${e.payload['id']}');
          if (i >= 0) forum[i].suka = e.payload['suka'] ?? forum[i].suka;
        } catch (_) {}
        break;
      case 'forum.hapus':
        forum.removeWhere((f) => f.id == '${e.payload['id']}');
        break;
      case 'wallet.update':
        user = user?.copyWith(saldo: e.payload['saldo'] as int);
        break;
    }
    notifyListeners();
  }

  /// Simulasi event realtime untuk mode demo.
  void _mulaiSimulasi() {
    _mockTicker?.cancel();
    _mockTicker = Timer.periodic(const Duration(seconds: 3), (_) {
      var berubah = false;

      // stok PC naik-turun seperti trafik asli
      if (plans.isNotEmpty && Random().nextBool()) {
        final p = plans[Random().nextInt(plans.length)];
        final delta = Random().nextBool() ? 1 : -1;
        final baru = (p.unitTersedia + delta).clamp(0, p.totalUnit);
        if (baru != p.unitTersedia) {
          p.unitTersedia = baru;
          berubah = true;
        }
      }

      // alur order otomatis: pending -> dibayar -> provisioning -> aktif
      for (final o in orders) {
        switch (o.status) {
          case OrderStatus.pending:
            o.status = OrderStatus.dibayar;
            berubah = true;
            break;
          case OrderStatus.dibayar:
            o.status = OrderStatus.provisioning;
            o.progress = 10;
            berubah = true;
            break;
          case OrderStatus.provisioning:
            o.progress = (o.progress + 25 + Random().nextInt(20)).clamp(0, 100);
            if (o.progress >= 100) {
              o.status = OrderStatus.aktif;
              o.mulai = DateTime.now();
              o.berakhir = DateTime.now().add(Duration(hours: o.durasiJam));
              o.host = '103.44.12.${20 + Random().nextInt(200)}:3389';
              o.username = 'xy_${o.kode.toLowerCase().replaceAll('-', '')}';
              o.password = 'Xy#${Random().nextInt(9999)}ok';
            }
            berubah = true;
            break;
          case OrderStatus.aktif:
            if (o.berakhir != null && o.berakhir!.isBefore(DateTime.now())) {
              o.status = OrderStatus.selesai;
              berubah = true;
            }
            break;
          default:
            break;
        }
      }
      if (berubah) notifyListeners();
    });
  }

  // ---------------- aksi ----------------
  Future<RentOrder?> sewaPc(PcPlan plan, int jam, String metode, {String? voucher, String? requestId, int? totalDisetujui}) async {
    try {
      final o = await _repo.buatOrderSewa(plan: plan, jam: jam, metode: metode, voucher: voucher, requestId:requestId,totalDisetujui:totalDisetujui);
      if (!orders.any((x) => x.id == o.id)) orders.insert(0, o);

      try { transaksi = await _repo.transaksi(); } catch(_) {}
      // tier bisa naik setelah belanja
      await muatProfilRingkas();
      notifyListeners();
      return o;
    } catch (e) {
      error = '$e';
      notifyListeners();
      return null;
    }
  }

  Future<Map<String, dynamic>?> beliAkun(AkunProduk p, String metode) async {
    try {
      final r = await _repo.beliAkun(produk: p, metode: metode);
      if (metode == 'saldo' && user != null) {
        user = user!.copyWith(saldo: (user!.saldo - p.harga).clamp(0, 1 << 31));
      }
      transaksi = await _repo.transaksi();
      notifyListeners();
      return r;
    } catch (e) {
      error = '$e';
      notifyListeners();
      return null;
    }
  }



  Future<String?> kirimChat(
    String teks, {
    String? gambar,
    String? audio,
    double? durasi,
    String? replyTo,
    String? replyTeks,
    String? replyTipe,
    String? pratinjauGambar,
    String? pratinjauAudio,
    String? ulangId,
  }) async {
    final client = ulangId ?? 'msg_${DateTime.now().microsecondsSinceEpoch}_${Random.secure().nextInt(1 << 30)}';
    chat.removeWhere((m) => m.clientId == client && m.id.startsWith('local_'));
    final tipe = audio != null ? 'audio' : (gambar != null ? 'gambar' : 'teks');
    final msg = ChatMessage(
      id: 'local_$client',
      clientId: client,
      room: 'user:${user?.id}',
      dari: 'user',
      tipe: tipe,
      teks: teks,
      gambar: pratinjauGambar,
      audio: pratinjauAudio,
      durasi: durasi,
      replyTo: replyTo,
      replyTeks: replyTeks,
      replyTipe: replyTipe,
      waktu: DateTime.now(),
      terkirim: false,
    );
    chat.add(msg);
    notifyListeners();
    try {
      final result = await _repo.kirimChat(
        teks,
        gambar: gambar,
        audio: audio,
        durasi: durasi,
        tipe: tipe,
        replyTo: replyTo,
        replyTeks: replyTeks,
        replyTipe: replyTipe,
        clientId: client,
      );
      _terimaPesan(result);
      return null;
    } catch (e) {
      msg.gagal = true;
      error = _pesan(e);
      notifyListeners();
      return error;
    }
  }

  /// Masukkan pesan dari server sambil mencegah pesan kembar.
  ///
  /// Pesan yang baru saja kita kirim sudah tampil duluan sebagai pesan
  /// sementara, jadi versi dari server dipakai untuk menggantikannya,
  /// bukan ditambahkan lagi.
  void _terimaPesan(ChatMessage baru) {
    // sudah ada dengan id yang sama
    if (chat.any((m) => m.id == baru.id)) return;

    if (baru.milikSaya) {
      final i = chat.lastIndexWhere(
        (m) => m.id.startsWith('local_') && m.dari == 'user' && ((baru.clientId!=null&&m.clientId==baru.clientId)||(baru.clientId==null&&m.teks==baru.teks)),
      );
      if (i >= 0) {
        chat[i] = baru;
        csMengetik = false;
        notifyListeners();
        return;
      }
    }

    chat.add(baru);
    csMengetik = false;
    if (!baru.milikSaya) notifBelumDibaca++;
    notifyListeners();
  }

  DateTime _ketikTerakhir=DateTime(2000);
  void ketikCs(bool val) { if(DateTime.now().difference(_ketikTerakhir).inMilliseconds<1400)return;_ketikTerakhir=DateTime.now();unawaited(_api.post('/cs/typing',{'typing':val}).catchError((_){return null;})); }

  void bacaNotif() {
    notifBelumDibaca = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _rtSub?.cancel();
    _rtState?.cancel();
    _rt?.dispose();
    _rtKatalog?.dispose();
    _rtForum?.dispose();
    _mockTicker?.cancel();
    _clock?.cancel();
    _api.dispose();
    super.dispose();
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
