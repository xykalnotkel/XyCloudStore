import 'dart:async';
import 'dart:math';
import '../core/config.dart';
import '../models/models.dart';
import 'api_client.dart';
import 'mock_data.dart';

/// Dilempar ketika akun ada tetapi emailnya belum diverifikasi.
class PerluVerifikasi implements Exception {
  PerluVerifikasi(this.email, this.nama, this.pesan);
  final String email;
  final String nama;
  final String pesan;
  @override
  String toString() => pesan;
}

/// Satu pintu untuk semua data. Mode mock & mode server (Cloudflare Worker)
/// punya kontrak yang sama, jadi UI tidak perlu tahu bedanya.
abstract class XyRepository {
  Future<UserProfile> login(String email, String password);
  /// Mendaftar. Hasilnya berupa peta berisi `perluVerifikasi`, `email`, dan `pesan`.
  Future<Map<String, dynamic>> daftar({required String nama, required String email, required String password, String? phone});

  /// Memverifikasi kode OTP lalu mengembalikan profil pengguna.
  Future<UserProfile> verifikasiEmail(String email, String kode);
  Future<String> kirimUlangKode(String email, {String tipe = 'verifikasi'});
  Future<String> lupaPassword(String email);
  Future<UserProfile> resetPassword({required String email, required String kode, required String password});

  /// Konfigurasi server: penyedia login aktif, nomor WhatsApp, rekening top up.
  Future<KonfigurasiApp> konfigurasi();

  /// Info rilis terbaru untuk pengecek pembaruan di dalam aplikasi.
  Future<Map<String, dynamic>> rilis();
  Future<Map<String, dynamic>> cekVoucher({required String kode, required String jenis, required int total});
  Future<void> hapusAkun({String? password, String? kode, bool paksa});

  // ---------- undang teman, favorit, ulasan paket ----------
  Future<Map<String, dynamic>> dataReferral();
  Future<Map<String, dynamic>> pakaiReferral(String kode);
  /// Status pembekuan akun + riwayat pelanggaran + daftar banding.
  Future<InfoBlokir> infoBlokir();

  /// Ajukan banding atas pembekuan. Galat API dilempar apa adanya.
  Future<Map<String, dynamic>> ajukanBanding(String pesan);

  Future<List<String>> favorit();
  Future<bool> ubahFavorit(String produkId);
  Future<List<Ulasan>> ulasanPaket(String planId);
  Future<void> kirimUlasanPaket({required String planId, required int rating, String? komentar, String? orderId});
  Future<Map<String, dynamic>> dataSaya();

  /// Dokumen legal: 'syarat' atau 'privasi'.
  Future<Map<String, dynamic>> legal(String jenis);

  /// Ambil profil memakai token yang sudah dipasang (dipakai setelah login sosial).
  Future<UserProfile> profilSaya();

  /// Tukar ID token Google (login native) dengan token XyCloudStore.
  Future<UserProfile> masukGoogleNative(String idToken);
  void pasangToken(String token);

  Future<List<Ulasan>> ulasan(String produkId);
  Future<Ulasan> kirimUlasan({required String produkId, required int rating, required String komentar, String? gambar});

  Future<PermintaanTopup> buatTopup(int nominal, String metode);
  Future<List<PermintaanTopup>> daftarTopup();
  Future<PermintaanTopup> unggahBukti(String idTopup, String dataUri);

  /// Status top up terakhir + saldo (dipakai polling otomatis sehabis bayar).
  Future<Map<String, dynamic>> statusTopup(String idTopup);

  /// Pancing server bertanya ke penyedia pembayaran: sudah benar-benar
  /// dibayar atau belum? (tombol "sudah bayar? cek sekarang")
  Future<Map<String, dynamic>> cekTopupPenyedia(String idTopup);

  // ---------- profil ----------
  Future<UserProfile> perbaruiProfil({String? nama, String? phone, String? foto, bool? notifForum, bool? notifDm, String? bio, String? banner, String? username, String? bingkai, String? slogan, String? bioLink, String? gayaNama});
  Future<Map<String, dynamic>> cekNama({String? nama, String? username});
  Future<Map<String, dynamic>> laporPengguna(String id, String alasan);
  Future<List<BisukanItem>> bisukanDaftar();
  Future<void> gantiPassword(String lama, String baru);

  // ---------- profil lengkap & dompet sosial (Batch I) ----------
  /// Unggah GIF/MP4 sebagai banner profil (server otomatis jadikan GIF).
  Future<Map<String, dynamic>> unggahBannerMedia(
    String dataUri, {
    void Function(int terkirim, int total)? onProgress,
  });
  Future<void> hapusBannerMedia();

  /// Leaderboard nyata: periode 'bulan' (belanja bulan ini) / 'total'.
  Future<DataLeaderboard> leaderboard({String periode = 'bulan'});

  /// Cari penerima transfer lewat @username / email persis.
  Future<Map<String, dynamic>> cariTransfer(String q);

  /// Batch L: autocomplete @mention di komunitas (awalan username).
  Future<List<Map<String, dynamic>>> cariMention(String q);

  /// Kirim saldo (butuh PIN transfer 6 digit).
  Future<Map<String, dynamic>> kirimTransfer({required String ke, required int nominal, required String pin, String? catatan});

  /// Minta kode email untuk memasang PIN (akun sosial tanpa password).
  Future<String> mintaKodePinTransfer();

  /// Pasang/ganti PIN transfer; konfirmasi = password atau kode email.
  Future<void> setPinTransfer(String pin, String konfirmasi);

  // ---------- sosial (Batch D) ----------
  Future<ProfilPublik> profilPublik(String id);
  Future<Map<String, dynamic>> ikuti(String id, bool ikut);
  Future<List<IkutanItem>> followsSaya({String arah = 'mengikuti'});
  Future<List<DmPesan>> dmAmbil(String id);
  Future<DmPesan> dmKirim(String id, {String? teks, String? audio, double? durasi, String? gambar});
  Future<Map<String, dynamic>> dmBaca(String id);
  Future<Map<String, dynamic>> simpanPost(String id);
  Future<List<String>> simpanSaya();
  Future<Map<String, dynamic>> bisukan(String thread, int menit);

  // ---------- HUD streaming & preset komunitas (Batch P) ----------
  Future<List<HudPresetPublik>> hudPresetPublik({String urut = 'populer'});
  Future<List<HudPresetPublik>> hudPresetSaya();
  Future<HudPresetPublik> terbitkanHud(HudLayout layout, {bool publik = true});
  Future<HudPresetPublik> perbaruiHudPublik(String id, HudLayout layout, {bool publik = true});
  Future<HudPresetPublik> pakaiHudPublik(String id);
  Future<Map<String, dynamic>> sukaiHud(String id);
  Future<void> hapusHudPublik(String id);

  // ---------- sesi main ----------
  Future<SesiMain> sesiMulai(String orderId);
  Future<SesiMain> sesiStatus(String id);
  Future<void> sesiPin(String id, String pin);
  Future<void> sesiAkhiri(String id);

  // ---------- forum ----------
  Future<List<ForumPost>> forum();
  Future<List<ForumBalasan>> forumDetail(String id);
  Future<ForumPost> forumBuat({required String judul, required String isi, required String kategori, String? gambar});
  Future<ForumBalasan> forumBalas(String id, String isi, {String? balasKe, Map<String, dynamic>? stiker});
  Future<Map<String, dynamic>> forumSuka(String id);
  Future<List<String>> forumSukaSaya();
  Future<void> forumHapus(String id);
  Future<ForumPost> forumSunting({required String id, required String judul, required String isi, String? kategori});
  Future<void> forumHapusBalasan(String id);
  Future<void> hapusPesan(String id);
  Future<void> hapusSemuaPesan();

  // ---------- pemberitahuan ----------
  Future<Map<String, dynamic>> notifikasi();
  Future<void> bacaNotifikasi({String? id});
  Future<void> hapusNotifikasi();

  // ---------- komunitas lanjutan ----------
  Future<Map<String, dynamic>> sukaBalasan(String id);
  Future<List<String>> balasanDisukai();
  Future<void> laporkan({required String jenis, required String refId, String? url, String? alasan});
  Future<List<PcPlan>> plans();

  /// Batch J: agen live + spek PC host terdeteksi otomatis.
  Future<List<UnitLive>> unitLive();
  Future<List<AkunProduk>> produkAkun();
  Future<List<PromoBanner>> banners();
  Future<List<RentOrder>> orders();
  Future<RentOrder> buatOrderSewa({required PcPlan plan, required int jam, required String metode, String? voucher, String? requestId, int? totalDisetujui});
  Future<RentOrder> orderDetail(String id);
  Future<Map<String, dynamic>> beliAkun({required AkunProduk produk, required String metode});
  Future<List<Transaksi>> transaksi();
  Future<List<ChatMessage>> riwayatChat();
  Future<ChatMessage> kirimChat(
    String teks, {
    String? gambar,
    String? audio,
    double? durasi,
    String? tipe,
    String? replyTo,
    String? replyTeks,
    String? replyTipe,
    String? clientId,
  });

  factory XyRepository.create(ApiClient api) =>
      XyConfig.useMock ? MockRepository() : RemoteRepository(api);
}

// ------------------------------------------------------------------
// REMOTE — Cloudflare Worker + D1
// ------------------------------------------------------------------
class RemoteRepository implements XyRepository {
  RemoteRepository(this.api);
  final ApiClient api;

  @override
  Future<UserProfile> login(String email, String password) async {
    final d = await api.post('/auth/login', {'email': email, 'password': password});
    if (d['perluVerifikasi'] == true) {
      throw PerluVerifikasi('${d['email']}', '${d['nama'] ?? ''}', '${d['pesan'] ?? ''}');
    }
    api.setToken(d['token']);
    return UserProfile.fromJson(d['user']);
  }

  @override
  Future<Map<String, dynamic>> daftar({
    required String nama,
    required String email,
    required String password,
    String? phone,
  }) async =>
      Map<String, dynamic>.from(await api.post('/auth/register', {
        'nama': nama,
        'email': email,
        'password': password,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
      }));

  @override
  Future<UserProfile> verifikasiEmail(String email, String kode) async {
    final d = await api.post('/auth/verify', {'email': email, 'kode': kode});
    api.setToken(d['token']);
    return UserProfile.fromJson(d['user']);
  }

  @override
  Future<String> kirimUlangKode(String email, {String tipe = 'verifikasi'}) async =>
      '${(await api.post('/auth/resend', {'email': email, 'tipe': tipe}))['pesan']}';

  @override
  Future<String> lupaPassword(String email) async =>
      '${(await api.post('/auth/forgot', {'email': email}))['pesan']}';

  @override
  Future<UserProfile> resetPassword({
    required String email,
    required String kode,
    required String password,
  }) async {
    final d = await api.post('/auth/reset', {'email': email, 'kode': kode, 'password': password});
    api.setToken(d['token']);
    return UserProfile.fromJson(d['user']);
  }

  @override
  Future<KonfigurasiApp> konfigurasi() async =>
      KonfigurasiApp.fromJson(Map<String, dynamic>.from(await api.get('/config')));

  @override
  Future<Map<String, dynamic>> legal(String jenis) async =>
      Map<String, dynamic>.from(await api.get('/legal/$jenis'));

  @override
  Future<Map<String, dynamic>> rilis() async => Map<String, dynamic>.from(await api.get('/rilis'));

  @override
  Future<Map<String, dynamic>> cekVoucher({
    required String kode,
    required String jenis,
    required int total,
  }) async =>
      Map<String, dynamic>.from(await api.post('/voucher/cek', {
        'kode': kode,
        'jenis': jenis,
        'total': total,
      }));

  @override
  Future<void> hapusAkun({String? password, String? kode, bool paksa = false}) async =>
      api.hapus('/me', {if (password != null) 'password': password, if (kode != null) 'kode': kode, 'konfirmasi': 'HAPUS'});

  @override
  Future<Map<String, dynamic>> dataReferral() async =>
      Map<String, dynamic>.from(await api.get('/referral'));

  @override
  Future<Map<String, dynamic>> pakaiReferral(String kode) async =>
      Map<String, dynamic>.from(await api.post('/referral/pakai', {'kode': kode}));

  @override
  Future<InfoBlokir> infoBlokir() async => InfoBlokir.fromJson(
      Map<String, dynamic>.from(await api.get('/me/blokir')));

  @override
  Future<Map<String, dynamic>> ajukanBanding(String pesan) async =>
      Map<String, dynamic>.from(await api.post('/me/banding', {'pesan': pesan}));

  @override
  Future<List<String>> favorit() async =>
      ((await api.get('/favorit')) as List).map((e) => '$e').toList();

  @override
  Future<bool> ubahFavorit(String produkId) async =>
      (await api.post('/favorit/$produkId'))['favorit'] == true;

  @override
  Future<List<Ulasan>> ulasanPaket(String planId) async =>
      ((await api.get('/pc/plans/$planId/ulasan')) as List).map((e) => Ulasan.fromJson(e)).toList();

  @override
  Future<void> kirimUlasanPaket({
    required String planId,
    required int rating,
    String? komentar,
    String? orderId,
  }) async =>
      api.post('/pc/ulasan', {
        'plan_id': planId,
        'rating': rating,
        if (komentar != null) 'komentar': komentar,
        if (orderId != null) 'order_id': orderId,
      });

  @override
  Future<Map<String, dynamic>> dataSaya() async => Map<String, dynamic>.from(await api.get('/me/data'));

  @override
  Future<UserProfile> profilSaya() async => UserProfile.fromJson(await api.get('/me'));

  @override
  Future<UserProfile> masukGoogleNative(String idToken) async {
    final d = await api.post('/auth/google/native', {'id_token': idToken});
    api.setToken(d['token']);
    return UserProfile.fromJson(d['user']);
  }

  @override
  void pasangToken(String token) => api.setToken(token);

  @override
  Future<List<Ulasan>> ulasan(String produkId) async =>
      ((await api.get('/akun/produk/$produkId/ulasan')) as List).map((e) => Ulasan.fromJson(e)).toList();

  @override
  Future<Ulasan> kirimUlasan({
    required String produkId,
    required int rating,
    required String komentar,
    String? gambar,
  }) async =>
      Ulasan.fromJson(Map<String, dynamic>.from(await api.post('/ulasan', {
        'produk_id': produkId,
        'rating': rating,
        'komentar': komentar,
        if (gambar != null) 'gambar': gambar,
      })));

  @override
  Future<PermintaanTopup> buatTopup(int nominal, String metode) async =>
      PermintaanTopup.fromJson(Map<String, dynamic>.from(
          await api.post('/wallet/topup', {'nominal': nominal, 'metode': metode})));

  @override
  Future<List<PermintaanTopup>> daftarTopup() async =>
      ((await api.get('/wallet/topup')) as List).map((e) => PermintaanTopup.fromJson(e)).toList();

  @override
  Future<Map<String, dynamic>> statusTopup(String idTopup) async =>
      Map<String, dynamic>.from(await api.get('/wallet/topup/$idTopup'));

  @override
  Future<Map<String, dynamic>> cekTopupPenyedia(String idTopup) async =>
      Map<String, dynamic>.from(await api.post('/wallet/topup/$idTopup/cek'));

  @override
  Future<PermintaanTopup> unggahBukti(String idTopup, String dataUri) async =>
      PermintaanTopup.fromJson(Map<String, dynamic>.from(
          await api.post('/wallet/topup/$idTopup/bukti', {'file': dataUri})));

  @override
  Future<UserProfile> perbaruiProfil({String? nama, String? phone, String? foto, bool? notifForum, bool? notifDm, String? bio, String? banner, String? username, String? bingkai, String? slogan, String? bioLink, String? gayaNama}) async =>
      UserProfile.fromJson(Map<String, dynamic>.from(await api.patch('/me', {
        if (nama != null) 'nama': nama,
        if (phone != null) 'phone': phone,
        if (foto != null) 'foto': foto,
        if (notifForum != null) 'notif_forum': notifForum ? 1 : 0,
        if (notifDm != null) 'notif_dm': notifDm ? 1 : 0,
        if (bio != null) 'bio': bio,
        if (banner != null) 'banner': banner,
        if (username != null) 'username': username,
        if (bingkai != null) 'bingkai': bingkai,
        if (slogan != null) 'slogan': slogan,
        if (bioLink != null) 'bio_link': bioLink,
        if (gayaNama != null) 'gaya_nama': gayaNama,
      })));

  @override
  Future<Map<String, dynamic>> cekNama({String? nama, String? username}) async =>
      Map<String, dynamic>.from(await api.post('/cek-nama', {
        if (nama != null) 'nama': nama,
        if (username != null) 'username': username,
      }));

  // ---------- Batch I ----------
  @override
  Future<Map<String, dynamic>> unggahBannerMedia(
    String dataUri, {
    void Function(int terkirim, int total)? onProgress,
  }) async =>
      Map<String, dynamic>.from(await api.postUnggah(
        '/me/banner-media',
        {'berkas': dataUri},
        onProgress: onProgress,
      ));

  @override
  Future<void> hapusBannerMedia() async => api.delete('/me/banner-media');

  @override
  Future<DataLeaderboard> leaderboard({String periode = 'bulan'}) async =>
      DataLeaderboard.fromJson(
          Map<String, dynamic>.from(await api.get('/leaderboard', {'periode': periode})));

  @override
  Future<Map<String, dynamic>> cariTransfer(String q) async =>
      Map<String, dynamic>.from(await api.get('/me/transfer/cari', {'q': q}));

  @override
  Future<List<Map<String, dynamic>>> cariMention(String q) async =>
      List<Map<String, dynamic>>.from(((await api.get(
              '/pengguna/mention?q=${Uri.encodeQueryComponent(q)}')) as List)
          .map((e) => Map<String, dynamic>.from(e as Map)));

  @override
  Future<Map<String, dynamic>> kirimTransfer({required String ke, required int nominal, required String pin, String? catatan}) async =>
      Map<String, dynamic>.from(await api.post('/me/transfer', {
        'ke': ke,
        'nominal': nominal,
        'pin': pin,
        if (catatan != null && catatan.isNotEmpty) 'catatan': catatan,
      }));

  @override
  Future<String> mintaKodePinTransfer() async =>
      '${(await api.post('/me/pin-transfer/kode'))['pesan'] ?? 'Kode dikirim ke email kamu.'}';

  @override
  Future<void> setPinTransfer(String pin, String konfirmasi) async =>
      api.post('/me/pin-transfer', {'pin': pin, 'konfirmasi': konfirmasi});

  @override
  Future<Map<String, dynamic>> laporPengguna(String id, String alasan) async =>
      Map<String, dynamic>.from(await api.post('/users/$id/lapor', {'alasan': alasan}));

  // ---------- sosial (Batch D) ----------
  @override
  Future<ProfilPublik> profilPublik(String id) async =>
      ProfilPublik.fromJson(Map<String, dynamic>.from(await api.get('/users/$id/profil')));

  @override
  Future<Map<String, dynamic>> ikuti(String id, bool ikut) async =>
      Map<String, dynamic>.from(await api.post('/users/$id/ikuti', {'ikuti': ikut}));

  @override
  Future<List<IkutanItem>> followsSaya({String arah = 'mengikuti'}) async =>
      ((await api.get('/me/follows', {'arah': arah})) as List)
          .map((e) => IkutanItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();

  @override
  Future<List<DmPesan>> dmAmbil(String id) async => ((await api.get('/dm/$id')) as List)
      .map((e) => DmPesan.fromJson(Map<String, dynamic>.from(e)))
      .toList();

  @override
  Future<DmPesan> dmKirim(String id, {String? teks, String? audio, double? durasi, String? gambar}) async =>
      DmPesan.fromJson(Map<String, dynamic>.from(await api.post('/dm/$id', {
        if (teks != null) 'teks': teks,
        if (audio != null) 'audio': audio,
        if (durasi != null) 'durasi': durasi,
        if (gambar != null) 'gambar': gambar,
      })));

  @override
  Future<Map<String, dynamic>> dmBaca(String id) async =>
      Map<String, dynamic>.from(await api.post('/dm/$id/dibaca', {}));

  @override
  Future<Map<String, dynamic>> simpanPost(String id) async =>
      Map<String, dynamic>.from(await api.post('/forum/$id/simpan', {}));

  @override
  Future<List<String>> simpanSaya() async =>
      ((await api.get('/me/simpan')) as List).map((e) => '$e').toList();

  @override
  Future<Map<String, dynamic>> bisukan(String thread, int menit) async =>
      Map<String, dynamic>.from(await api.post('/me/bisukan', {'thread': thread, 'menit': menit}));

  @override
  Future<List<BisukanItem>> bisukanDaftar() async => ((await api.get('/me/bisukan')) as List)
      .map((e) => BisukanItem.fromJson(Map<String, dynamic>.from(e)))
      .toList();

  @override
  Future<void> gantiPassword(String lama, String baru) async =>
      api.post('/me/password', {'lama': lama, 'baru': baru});

  // ---------- HUD streaming & preset komunitas (Batch P) ----------
  @override
  Future<List<HudPresetPublik>> hudPresetPublik({String urut = 'populer'}) async =>
      ((await api.get('/hud/presets', {'urut': urut})) as List)
          .map((e) => HudPresetPublik.fromJson(Map<String, dynamic>.from(e)))
          .toList();

  @override
  Future<List<HudPresetPublik>> hudPresetSaya() async =>
      ((await api.get('/me/hud-presets')) as List)
          .map((e) => HudPresetPublik.fromJson(Map<String, dynamic>.from(e)))
          .toList();

  @override
  Future<HudPresetPublik> terbitkanHud(HudLayout layout, {bool publik = true}) async =>
      HudPresetPublik.fromJson(Map<String, dynamic>.from(await api.post('/hud/presets', {
        'nama': layout.nama,
        'deskripsi': layout.deskripsi,
        'game': layout.game,
        'data': layout.toData(),
        'publik': publik,
      })));

  @override
  Future<HudPresetPublik> perbaruiHudPublik(String id, HudLayout layout, {bool publik = true}) async =>
      HudPresetPublik.fromJson(Map<String, dynamic>.from(await api.patch('/hud/presets/$id', {
        'nama': layout.nama,
        'deskripsi': layout.deskripsi,
        'game': layout.game,
        'data': layout.toData(),
        'publik': publik,
      })));

  @override
  Future<HudPresetPublik> pakaiHudPublik(String id) async =>
      HudPresetPublik.fromJson(Map<String, dynamic>.from(
          await api.post('/hud/presets/$id/pakai', {})));

  @override
  Future<Map<String, dynamic>> sukaiHud(String id) async =>
      Map<String, dynamic>.from(await api.post('/hud/presets/$id/suka', {}));

  @override
  Future<void> hapusHudPublik(String id) async => api.delete('/hud/presets/$id');

  @override
  Future<SesiMain> sesiMulai(String orderId) async =>
      SesiMain.fromJson(Map<String, dynamic>.from(await api.post('/sesi/mulai', {'order_id': orderId})));

  @override
  Future<SesiMain> sesiStatus(String id) async =>
      SesiMain.fromJson(Map<String, dynamic>.from(await api.get('/sesi/$id')));

  @override
  Future<void> sesiPin(String id, String pin) async => api.post('/sesi/$id/pin', {'pin': pin});

  @override
  Future<void> sesiAkhiri(String id) async => api.post('/sesi/$id/akhiri');

  @override
  Future<List<ForumPost>> forum() async =>
      ((await api.get('/forum')) as List).map((e) => ForumPost.fromJson(e)).toList();

  @override
  Future<List<ForumBalasan>> forumDetail(String id) async {
    final d = await api.get('/forum/$id');
    return ((d['balasan'] as List?) ?? const []).map((e) => ForumBalasan.fromJson(e)).toList();
  }

  @override
  Future<ForumPost> forumBuat({
    required String judul,
    required String isi,
    required String kategori,
    String? gambar,
  }) async =>
      ForumPost.fromJson(Map<String, dynamic>.from(await api.post('/forum', {
        'judul': judul,
        'isi': isi,
        'kategori': kategori,
        if (gambar != null) 'gambar': gambar,
      })));

  @override
  Future<ForumBalasan> forumBalas(String id, String isi, {String? balasKe, Map<String, dynamic>? stiker}) async =>
      ForumBalasan.fromJson(Map<String, dynamic>.from(
          await api.post('/forum/$id/balas', {'isi': isi, if (balasKe != null) 'balas_ke': balasKe, if (stiker != null) 'stiker': stiker})));

  @override
  Future<Map<String, dynamic>> forumSuka(String id) async =>
      Map<String, dynamic>.from(await api.post('/forum/$id/suka'));

  @override
  Future<List<String>> forumSukaSaya() async =>
      ((await api.get('/forum/suka/saya')) as List).map((e) => '$e').toList();

  @override
  Future<void> forumHapus(String id) async => api.delete('/forum/$id');

  @override
  Future<ForumPost> forumSunting({
    required String id,
    required String judul,
    required String isi,
    String? kategori,
  }) async =>
      ForumPost.fromJson(Map<String, dynamic>.from(await api.patch('/forum/$id', {
        'judul': judul,
        'isi': isi,
        if (kategori != null) 'kategori': kategori,
      })));

  @override
  Future<void> forumHapusBalasan(String id) async => api.delete('/forum/balasan/$id');

  @override
  Future<void> hapusPesan(String id) async => api.delete('/cs/messages/$id');

  @override
  Future<void> hapusSemuaPesan() async => api.delete('/cs/messages');

  @override
  Future<Map<String, dynamic>> notifikasi() async =>
      Map<String, dynamic>.from(await api.get('/notifikasi'));

  @override
  Future<void> bacaNotifikasi({String? id}) async =>
      api.post('/notifikasi/baca', {if (id != null) 'id': id});

  @override
  Future<void> hapusNotifikasi() async => api.delete('/notifikasi');

  @override
  Future<Map<String, dynamic>> sukaBalasan(String id) async =>
      Map<String, dynamic>.from(await api.post('/forum/balasan/$id/suka'));

  @override
  Future<List<String>> balasanDisukai() async =>
      ((await api.get('/forum/balasan/suka/saya')) as List).map((e) => '$e').toList();

  @override
  Future<void> laporkan({required String jenis, required String refId, String? url, String? alasan}) async =>
      api.post('/laporan', {'jenis': jenis, 'ref_id': refId, if (url != null) 'url': url, 'alasan': alasan ?? ''});

  @override
  Future<List<PcPlan>> plans() async =>
      ((await api.get('/pc/plans')) as List).map((e) => PcPlan.fromJson(e)).toList();

  @override
  Future<List<UnitLive>> unitLive() async => ((await api.get('/pc/unit-live')) as List)
      .map((e) => UnitLive.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();

  @override
  Future<List<AkunProduk>> produkAkun() async =>
      ((await api.get('/akun/produk')) as List).map((e) => AkunProduk.fromJson(e)).toList();

  @override
  Future<List<PromoBanner>> banners() async =>
      ((await api.get('/banners')) as List).map((e) => PromoBanner.fromJson(e)).toList();

  @override
  Future<List<RentOrder>> orders() async =>
      ((await api.get('/orders')) as List).map((e) => RentOrder.fromJson(e)).toList();

  @override
  Future<RentOrder> buatOrderSewa({
    required PcPlan plan,
    required int jam,
    required String metode,
    String? voucher,
    String? requestId, int? totalDisetujui,
  }) async =>
      RentOrder.fromJson(Map<String, dynamic>.from(await api.post('/orders', {
        'plan_id': plan.id,
        'durasi_jam': jam,
        'metode': metode,
        if(requestId!=null)'request_id':requestId,
        if(totalDisetujui!=null)'total_disetujui':totalDisetujui,
        if (voucher != null && voucher.isNotEmpty) 'voucher': voucher,
      })));

  @override
  Future<RentOrder> orderDetail(String id) async => RentOrder.fromJson(await api.get('/orders/$id'));

  @override
  Future<Map<String, dynamic>> beliAkun({required AkunProduk produk, required String metode}) async =>
      Map<String, dynamic>.from(await api.post('/akun/beli', {'produk_id': produk.id, 'metode': metode}));

  @override
  Future<List<Transaksi>> transaksi() async =>
      ((await api.get('/wallet/transaksi')) as List).map((e) => Transaksi.fromJson(e)).toList();

  @override
  Future<List<ChatMessage>> riwayatChat() async =>
      ((await api.get('/cs/messages')) as List).map((e) => ChatMessage.fromJson(e)).toList();

  @override
  Future<ChatMessage> kirimChat(
    String teks, {
    String? gambar,
    String? audio,
    double? durasi,
    String? tipe,
    String? replyTo,
    String? replyTeks,
    String? replyTipe,
    String? clientId,
  }) async =>
      ChatMessage.fromJson(Map<String, dynamic>.from(await api.post('/cs/messages', {
        'teks': teks,
        if (gambar != null) 'gambar': gambar,
        if (audio != null) 'audio': audio,
        if (durasi != null) 'durasi': durasi,
        if (tipe != null) 'tipe': tipe,
        if (replyTo != null) 'reply_to': replyTo,
        if (replyTeks != null) 'reply_teks': replyTeks,
        if (replyTipe != null) 'reply_tipe': replyTipe,
        if (clientId != null) 'client_id': clientId,
      })));
}

// ------------------------------------------------------------------
// MOCK — jalan tanpa server
// ------------------------------------------------------------------
class MockRepository implements XyRepository {
  final _plans = MockData.plans();
  final _akun = MockData.akun();
  final _orders = MockData.orders();
  final _trx = MockData.transaksi();
  final _chat = MockData.chatAwal();

  Future<T> _delay<T>(T v, [int ms = 500]) =>
      Future.delayed(Duration(milliseconds: ms + Random().nextInt(250)), () => v);

  @override
  Future<UserProfile> login(String email, String password) => _delay(MockData.user, 800);

  @override
  Future<Map<String, dynamic>> daftar({
    required String nama,
    required String email,
    required String password,
    String? phone,
  }) async {
    MockData.user = UserProfile(id: 'u_demo', nama: nama, email: email, phone: phone, saldo: 0, tier: 'basic');
    return _delay({'perluVerifikasi': true, 'email': email, 'nama': nama, 'pesan': 'Kode demo: 123456'}, 700);
  }

  @override
  Future<UserProfile> verifikasiEmail(String email, String kode) => _delay(MockData.user, 600);

  @override
  Future<String> kirimUlangKode(String email, {String tipe = 'verifikasi'}) =>
      _delay('Kode demo dikirim ulang: 123456', 400);

  @override
  Future<String> lupaPassword(String email) => _delay('Kode demo reset: 123456', 400);

  @override
  Future<UserProfile> resetPassword({required String email, required String kode, required String password}) =>
      _delay(MockData.user, 600);

  @override
  Future<KonfigurasiApp> konfigurasi() =>
      _delay(const KonfigurasiApp(googleAktif: false, facebookAktif: false, whatsapp: '', minTopup: 10000), 200);

  @override
  Future<Map<String, dynamic>> rilis() => _delay({'versi': 'v0.0.0', 'berkas': const []}, 200);

  @override
  Future<Map<String, dynamic>> cekVoucher({required String kode, required String jenis, required int total}) =>
      _delay({'potongan': 0, 'kode': kode}, 200);

  @override
  Future<void> hapusAkun({String? password, String? kode, bool paksa = false}) async {}

  @override
  Future<Map<String, dynamic>> dataReferral() =>
      _delay({'kode': 'DEMO1234', 'tautan': '', 'bonusPengundang': 10000,
              'bonusDiundang': 5000, 'totalBonus': 0, 'daftar': const []}, 300);

  @override
  Future<Map<String, dynamic>> pakaiReferral(String kode) => _delay({'ok': true, 'bonus': 5000}, 300);

  @override
  Future<InfoBlokir> infoBlokir() async => const InfoBlokir();

  @override
  Future<Map<String, dynamic>> ajukanBanding(String pesan) async =>
      {'ok': true};

  @override
  Future<List<String>> favorit() => _delay(<String>[], 200);

  @override
  Future<bool> ubahFavorit(String produkId) => _delay(true, 200);

  @override
  Future<List<Ulasan>> ulasanPaket(String planId) => _delay(<Ulasan>[], 200);

  @override
  Future<void> kirimUlasanPaket({
    required String planId,
    required int rating,
    String? komentar,
    String? orderId,
  }) async {}

  @override
  Future<Map<String, dynamic>> dataSaya() => _delay({'profil': const {}}, 300);

  @override
  Future<Map<String, dynamic>> legal(String jenis) => _delay(
        {'judul': jenis, 'pembaruan': '-', 'bagian': const [], 'lisensi': const []},
        200,
      );

  @override
  Future<UserProfile> profilSaya() => _delay(MockData.user, 200);

  @override
  Future<UserProfile> masukGoogleNative(String idToken) => _delay(MockData.user, 500);

  @override
  void pasangToken(String token) {}

  @override
  Future<List<Ulasan>> ulasan(String produkId) => _delay(<Ulasan>[], 300);

  @override
  Future<Ulasan> kirimUlasan({
    required String produkId,
    required int rating,
    required String komentar,
    String? gambar,
  }) =>
      _delay(
        Ulasan(
          id: 'r_demo', produkId: produkId, nama: MockData.user.nama, rating: rating,
          komentar: komentar, waktu: DateTime.now(),
        ),
        400,
      );

  @override
  Future<PermintaanTopup> buatTopup(int nominal, String metode) => _delay(
        PermintaanTopup(
          id: 'tp_demo', nominal: nominal, kodeUnik: 123, total: nominal + 123,
          metode: metode, status: 'menunggu', dibuat: DateTime.now(),
        ),
        400,
      );

  @override
  Future<List<PermintaanTopup>> daftarTopup() => _delay(<PermintaanTopup>[], 300);

  Future<Map<String, dynamic>> statusTopup(String idTopup) =>
      _delay(<String, dynamic>{'status': 'disetujui', 'saldo': 150000}, 300);

  Future<Map<String, dynamic>> cekTopupPenyedia(String idTopup) =>
      _delay(<String, dynamic>{'status': 'disetujui', 'saldo': 150000}, 300);

  @override
  Future<UserProfile> perbaruiProfil({String? nama, String? phone, String? foto, bool? notifForum, bool? notifDm, String? bio, String? banner, String? username, String? bingkai, String? slogan, String? bioLink, String? gayaNama}) =>
      _delay(MockData.user, 400);

  @override
  Future<Map<String, dynamic>> cekNama({String? nama, String? username}) async => _delay({
    if (nama != null) 'nama': {'bersih': true},
    if (username != null) 'username': {'tersedia': true},
  }, 300);

  // ---------- Batch I ----------
  @override
  Future<Map<String, dynamic>> unggahBannerMedia(
    String dataUri, {
    void Function(int terkirim, int total)? onProgress,
  }) =>
      _delay({'ok': true, 'banner_media': null}, 600);

  @override
  Future<void> hapusBannerMedia() => _delay(null, 250);

  @override
  Future<DataLeaderboard> leaderboard({String periode = 'bulan'}) => _delay(
      DataLeaderboard(
        periode: periode,
        peringkatSaya: 4,
        poinSaya: 120000,
        papan: const [
          PapanPeringkat(peringkat: 1, id: 'u1', nama: 'Rizky Pro', username: 'rizky', tier: 'vip', poin: 1250000),
          PapanPeringkat(peringkat: 2, id: 'u2', nama: 'Ayu Gamer', username: 'ayu.gg', tier: 'pro', poin: 980000),
          PapanPeringkat(peringkat: 3, id: 'u3', nama: 'Budi', username: 'budi', poin: 720000),
        ],
      ),
      400);

  @override
  Future<Map<String, dynamic>> cariTransfer(String q) => _delay(
      {'id': 'u2', 'nama': 'Ayu Gamer', 'username': 'ayu.gg', 'tier': 'pro'}, 350);

  @override
  Future<List<Map<String, dynamic>>> cariMention(String q) async =>
      _delay(<Map<String, dynamic>>[], 200);

  @override
  Future<Map<String, dynamic>> kirimTransfer({required String ke, required int nominal, required String pin, String? catatan}) =>
      _delay({'ok': true, 'id': 'tf_demo', 'saldo': 100000}, 600);

  @override
  Future<String> mintaKodePinTransfer() => _delay('Kode demo dikirim.', 400);

  @override
  Future<void> setPinTransfer(String pin, String konfirmasi) => _delay(null, 400);

  @override
  Future<Map<String, dynamic>> laporPengguna(String id, String alasan) async =>
      _delay({'ok': true, 'id': 'lp_demo'}, 300);

  @override
  Future<List<BisukanItem>> bisukanDaftar() async => _delay(const <BisukanItem>[], 200);

  @override
  Future<void> gantiPassword(String lama, String baru) async {}

  // ---------- HUD streaming & preset komunitas (Batch P) ----------
  @override
  Future<List<HudPresetPublik>> hudPresetPublik({String urut = 'populer'}) async =>
      _delay(const <HudPresetPublik>[], 350);

  @override
  Future<List<HudPresetPublik>> hudPresetSaya() async =>
      _delay(const <HudPresetPublik>[], 300);

  @override
  Future<HudPresetPublik> terbitkanHud(HudLayout layout, {bool publik = true}) async =>
      _delay(HudPresetPublik(
        id: 'hud_demo', userId: 'u_demo', nama: layout.nama,
        deskripsi: layout.deskripsi, game: layout.game, layout: layout,
        publik: publik, saya: true, pembuatNama: 'Pengguna Demo',
      ), 500);

  @override
  Future<HudPresetPublik> perbaruiHudPublik(String id, HudLayout layout, {bool publik = true}) async =>
      _delay(HudPresetPublik(
        id: id, userId: 'u_demo', nama: layout.nama,
        deskripsi: layout.deskripsi, game: layout.game, layout: layout,
        publik: publik, saya: true, pembuatNama: 'Pengguna Demo',
      ), 450);

  @override
  Future<HudPresetPublik> pakaiHudPublik(String id) async =>
      _delay(HudPresetPublik(
        id: id, userId: 'u_lain', nama: 'Preset Demo',
        layout: HudLayout(id: 'komunitas_$id', nama: 'Preset Demo'),
        pembuatNama: 'Komunitas', dipakai: 1,
      ), 300);

  @override
  Future<Map<String, dynamic>> sukaiHud(String id) async =>
      _delay({'disukai': true, 'suka': 1}, 250);

  @override
  Future<void> hapusHudPublik(String id) async => _delay(null, 250);

  // ---------- sosial (Batch D) ----------
  @override
  Future<ProfilPublik> profilPublik(String id) async =>
      _delay(const ProfilPublik(id: 'u_demo', nama: 'Anggota Demo', bio: 'Halo, ini profil contoh.'), 300);

  @override
  Future<Map<String, dynamic>> ikuti(String id, bool ikut) async => _delay({'ikuti': ikut}, 250);

  @override
  Future<List<IkutanItem>> followsSaya({String arah = 'mengikuti'}) async => _delay(const <IkutanItem>[], 250);

  @override
  Future<List<DmPesan>> dmAmbil(String id) async => _delay(const <DmPesan>[], 250);

  @override
  Future<DmPesan> dmKirim(String id, {String? teks, String? audio, double? durasi, String? gambar}) async => _delay(
      DmPesan(id: 'dm_${DateTime.now().millisecondsSinceEpoch}', dariId: 'u_demo', keId: id,
          teks: teks, audio: audio, tipe: teks != null ? 'text' : (audio != null ? 'audio' : 'gambar'),
          waktu: DateTime.now().millisecondsSinceEpoch),
      250);

  @override
  Future<Map<String, dynamic>> dmBaca(String id) async => _delay({'dibaca': 0}, 200);

  @override
  Future<Map<String, dynamic>> simpanPost(String id) async => _delay({'disimpan': 1}, 200);

  @override
  Future<List<String>> simpanSaya() async => _delay(const <String>[], 200);

  @override
  Future<Map<String, dynamic>> bisukan(String thread, int menit) async => _delay({'menit': menit}, 200);

  @override
  Future<SesiMain> sesiMulai(String orderId) => _delay(
        SesiMain(id: 's_demo', orderId: orderId, status: 'siap', host: '103.10.20.30', durasiMenit: 60),
        700,
      );

  @override
  Future<SesiMain> sesiStatus(String id) => _delay(
        SesiMain(id: id, orderId: 'o_demo', status: 'siap', host: '103.10.20.30'),
        300,
      );

  @override
  Future<void> sesiPin(String id, String pin) async {}

  @override
  Future<void> sesiAkhiri(String id) async {}

  @override
  Future<List<ForumPost>> forum() => _delay(<ForumPost>[], 300);

  @override
  Future<List<ForumBalasan>> forumDetail(String id) => _delay(<ForumBalasan>[], 300);

  @override
  Future<ForumPost> forumBuat({
    required String judul,
    required String isi,
    required String kategori,
    String? gambar,
  }) =>
      _delay(
        ForumPost(
          id: 'f_demo', userId: 'u_demo', nama: MockData.user.nama, kategori: kategori,
          judul: judul, isi: isi, dibuat: DateTime.now(),
        ),
        400,
      );

  @override
  Future<ForumBalasan> forumBalas(String id, String isi, {String? balasKe, Map<String, dynamic>? stiker}) => _delay(
        ForumBalasan(id: 'fb_demo', postId: id, nama: MockData.user.nama, isi: isi, dibuat: DateTime.now()),
        300,
      );

  @override
  Future<Map<String, dynamic>> forumSuka(String id) => _delay({'suka': 1, 'disukai': true}, 200);

  @override
  Future<List<String>> forumSukaSaya() => _delay(<String>[], 200);

  @override
  Future<void> forumHapus(String id) async {}

  @override
  Future<ForumPost> forumSunting({
    required String id,
    required String judul,
    required String isi,
    String? kategori,
  }) =>
      _delay(
        ForumPost(
          id: id, userId: 'u_demo', nama: MockData.user.nama, kategori: kategori ?? 'Umum',
          judul: judul, isi: isi, dibuat: DateTime.now(),
        ),
        300,
      );

  @override
  Future<void> forumHapusBalasan(String id) async {}

  @override
  Future<void> hapusPesan(String id) async {}

  @override
  Future<void> hapusSemuaPesan() async {}

  @override
  Future<Map<String, dynamic>> notifikasi() => _delay({'daftar': const [], 'belumDibaca': 0}, 200);

  @override
  Future<void> bacaNotifikasi({String? id}) async {}

  @override
  Future<void> hapusNotifikasi() async {}

  @override
  Future<Map<String, dynamic>> sukaBalasan(String id) => _delay({'suka': 1, 'disukai': true}, 200);

  @override
  Future<List<String>> balasanDisukai() => _delay(<String>[], 200);

  @override
  Future<void> laporkan({required String jenis, required String refId, String? url, String? alasan}) async {}

  @override
  Future<PermintaanTopup> unggahBukti(String idTopup, String dataUri) => _delay(
        PermintaanTopup(
          id: idTopup, nominal: 0, kodeUnik: 0, total: 0, metode: 'transfer',
          status: 'diperiksa', dibuat: DateTime.now(),
        ),
        400,
      );

  @override
  Future<List<PcPlan>> plans() => _delay(_plans);

  @override
  Future<List<UnitLive>> unitLive() async => const [];

  @override
  Future<List<AkunProduk>> produkAkun() => _delay(_akun);

  @override
  Future<List<PromoBanner>> banners() => _delay(MockData.banners(), 200);

  @override
  Future<List<RentOrder>> orders() => _delay(_orders);

  @override
  Future<RentOrder> buatOrderSewa({required PcPlan plan, required int jam, required String metode, String? voucher, String? requestId, int? totalDisetujui}) async {
    final kode = 'XY-${9000 + Random().nextInt(999)}';
    final o = RentOrder(
      id: 'o_${DateTime.now().millisecondsSinceEpoch}',
      kode: kode,
      planId: plan.id,
      planNama: plan.nama,
      durasiJam: jam,
      total: plan.hargaPerJam * jam,
      status: OrderStatus.pending,
      dibuat: DateTime.now(),
    );
    _orders.insert(0, o);
    if (plan.unitTersedia > 0) plan.unitTersedia--;
    _trx.insert(0, Transaksi(id: 'tx${o.id}', judul: 'Sewa ${plan.nama} $jam jam', tipe: 'sewa', nominal: -o.total, waktu: DateTime.now(), status: 'sukses'));
    return _delay(o, 700);
  }

  @override
  Future<RentOrder> orderDetail(String id) async => _delay(_orders.firstWhere((e) => e.id == id), 200);

  @override
  Future<Map<String, dynamic>> beliAkun({required AkunProduk produk, required String metode}) async {
    _trx.insert(0, Transaksi(id: 'tx${DateTime.now().millisecondsSinceEpoch}', judul: 'Beli ${produk.nama}', tipe: 'akun', nominal: -produk.harga, waktu: DateTime.now(), status: 'sukses'));
    return _delay({
      'kode': 'AK-${1000 + Random().nextInt(8999)}',
      'email': 'xy${Random().nextInt(9999)}@mail.xycloud.id',
      'password': 'Xy${Random().nextInt(99999)}!',
      'catatan': 'Segera ganti password setelah login. Garansi ${produk.garansi}.',
    }, 1200);
  }

  @override
  Future<List<Transaksi>> transaksi() => _delay(_trx);

  @override
  Future<List<ChatMessage>> riwayatChat() => _delay(_chat, 300);

  @override
  Future<ChatMessage> kirimChat(
    String teks, {
    String? gambar,
    String? audio,
    double? durasi,
    String? tipe,
    String? replyTo,
    String? replyTeks,
    String? replyTipe,
    String? clientId,
  }) async => ChatMessage(
        id: clientId ?? 'local-test',
        room: 'cs',
        dari: 'user',
        tipe: tipe ?? (audio != null ? 'audio' : (gambar != null ? 'gambar' : 'teks')),
        teks: teks,
        gambar: gambar,
        audio: audio,
        durasi: durasi,
        replyTo: replyTo,
        replyTeks: replyTeks,
        replyTipe: replyTipe,
        clientId: clientId,
        waktu: DateTime.now(),
      );
}
