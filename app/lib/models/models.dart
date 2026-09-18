export 'livestream.dart';

import '../core/waktu.dart';
import 'stiker.dart';
import 'dart:convert';
// ============================================================
// XyCloudStore — Model data (mirror dari tabel D1 Cloudflare)
// ============================================================

/// Media banner profil kustom (Batch I): GIF langsung, atau MP4 yang
/// disajikan Cloudinary sebagai GIF animasi (transformasi f_gif).
class BannerMedia {
  final String tipe; // 'gif' | 'video'
  final String url; // berkas asli (gif/mp4)
  final String gif; // URL sajian GIF animasi (untuk video = f_gif)

  const BannerMedia({required this.tipe, required this.url, required this.gif});

  /// Server menyimpan kolom `banner_media` sebagai TEKS JSON; kadang sudah
  /// terurai jadi Map oleh klien JSON — terima keduanya.
  static BannerMedia? parse(dynamic v) {
    if (v == null) return null;
    try {
      Map<String, dynamic>? m;
      if (v is String) {
        if (v.trim().isEmpty) return null;
        m = Map<String, dynamic>.from(jsonDecode(v) as Map);
      } else if (v is Map) {
        m = Map<String, dynamic>.from(v);
      }
      if (m == null || (m['url'] ?? '').toString().isEmpty) return null;
      return BannerMedia(
        tipe: (m['tipe'] ?? 'gif').toString(),
        url: m['url'].toString(),
        gif: (m['gif'] ?? m['url']).toString(),
      );
    } catch (_) {
      return null;
    }
  }
}

class UserProfile {
  final String id;
  final String nama;
  final String email;
  final String? phone;
  final int saldo;
  final String tier; // basic | pro | vip
  final String? avatar;

  /// Foto profil dari server (Cloudinary atau Google).
  final String? foto;

  /// Bio singkat dan tema banner profil (Batch D: profil bisa dikustom).
  final String? bio;
  final String? banner;

  /// Banner media kustom GIF/MP4→GIF (Batch I, khusus langganan).
  final BannerMedia? bannerMedia;

  /// Bingkai avatar profil (Batch I): polos/ungu/emas/neon/aurora/permata.
  final String? bingkai;

  /// Username publik unik (Batch E): @nama_pengguna.
  final String? username;

  /// Cap waktu pendinginan (Batch I): nama 7 hari, username 30 hari.
  final String? namaDiubahPada;
  final String? usernameDiubahPada;

  /// Total belanja lunas — dasar progres tier & leaderboard (Batch I).
  final int totalBelanja;

  /// PIN transfer 6 digit sudah dipasang (hash tidak pernah dikirim).
  final bool pinTransferAktif;

  /// Terima pemberitahuan kegiatan forum komunitas.
  final bool notifForum;

  /// Terima pemberitahuan pesan langsung (DM).
  final bool notifDm;

  /// Terima pemberitahuan saat kreator yang diikuti mulai livestream.
  final bool notifLive;

  /// Batch L: slogan pendek di bawah nama (maks 60 huruf).
  final String? slogan;

  /// Batch L: satu tautan publik di profil (divalidasi server).
  final String? bioLink;

  /// Batch L: gaya tampilan nama (font/efek). Lihat gaya_nama.dart.
  final String? gayaNama;

  /// Lencana khusus dari admin, contohnya XyVerse.
  final String? badge;
  final bool diblokir;
  final String? alasanBlokir;
  final int peringatan;
  final String? kodeReferral;
  final String? diundangOleh;

  UserProfile({
    required this.id,
    required this.nama,
    required this.email,
    this.phone,
    this.saldo = 0,
    this.tier = 'basic',
    this.avatar,
    this.foto,
    this.bio,
    this.banner,
    this.bannerMedia,
    this.bingkai,
    this.username,
    this.namaDiubahPada,
    this.usernameDiubahPada,
    this.totalBelanja = 0,
    this.pinTransferAktif = false,
    this.notifForum = true,
    this.notifDm = true,
    this.notifLive = true,
    this.slogan,
    this.bioLink,
    this.gayaNama,
    this.badge,
    this.diblokir = false,
    this.alasanBlokir,
    this.peringatan = 0,
    this.kodeReferral,
    this.diundangOleh,
  });

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        id: '${j['id']}',
        nama: j['nama'] ?? j['name'] ?? 'User',
        email: j['email'] ?? '',
        phone: j['phone'],
        saldo: (j['saldo'] ?? 0) as int,
        tier: j['tier'] ?? 'basic',
        avatar: j['avatar'],
        foto: (j['foto'] as String?)?.isNotEmpty == true ? j['foto'] : null,
        bio: (j['bio'] as String?)?.isNotEmpty == true ? j['bio'] : null,
        banner: (j['banner'] as String?)?.isNotEmpty == true ? j['banner'] : null,
        bannerMedia: BannerMedia.parse(j['banner_media']),
        bingkai: (j['bingkai'] as String?)?.isNotEmpty == true ? j['bingkai'] : null,
        username: (j['username'] as String?)?.isNotEmpty == true ? j['username'] : null,
        namaDiubahPada: j['nama_diubah_pada'] as String?,
        usernameDiubahPada: j['username_diubah_pada'] as String?,
        totalBelanja: (j['total_belanja'] ?? 0) as int,
        pinTransferAktif: (j['pin_transfer_aktif'] ?? 0) == 1,
        notifForum: (j['notif_forum'] ?? 1) == 1,
        notifDm: (j['notif_dm'] ?? 1) == 1,
        notifLive: (j['notif_live'] ?? 1) == 1,
        slogan: (j['slogan'] as String?)?.isNotEmpty == true ? j['slogan'] : null,
        bioLink: (j['bio_link'] as String?)?.isNotEmpty == true ? j['bio_link'] : null,
        gayaNama: (j['gaya_nama'] as String?)?.isNotEmpty == true ? j['gaya_nama'] : null,
        badge: (j['badge'] as String?)?.isNotEmpty == true ? j['badge'] : null,
        diblokir: (j['diblokir'] ?? 0) == 1,
        alasanBlokir: j['alasan_blokir'] as String?,
        peringatan: j['peringatan'] ?? 0,
        kodeReferral: j['kode_referral'],
        diundangOleh: j['diundang_oleh'],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nama': nama,
        'email': email,
        'phone': phone,
        'saldo': saldo,
        'tier': tier,
        'avatar': avatar,
        'foto': foto,
        'bio': bio,
        'banner': banner,
        'banner_media': bannerMedia == null
            ? null
            : {
                'tipe': bannerMedia!.tipe,
                'url': bannerMedia!.url,
                'gif': bannerMedia!.gif,
              },
        'bingkai': bingkai,
        'username': username,
        'nama_diubah_pada': namaDiubahPada,
        'username_diubah_pada': usernameDiubahPada,
        'total_belanja': totalBelanja,
        'pin_transfer_aktif': pinTransferAktif ? 1 : 0,
        'notif_forum': notifForum ? 1 : 0,
        'notif_dm': notifDm ? 1 : 0,
        'notif_live': notifLive ? 1 : 0,
        'slogan': slogan,
        'bio_link': bioLink,
        'gaya_nama': gayaNama,
        'badge': badge,
      };

  UserProfile copyWith({int? saldo, String? nama, String? phone, String? foto, String? bio, String? banner, String? username, String? bingkai, BannerMedia? bannerMedia, bool hapusBannerMedia = false, int? totalBelanja, bool? pinTransferAktif, bool? diblokir, String? alasanBlokir, int? peringatan, String? slogan, String? bioLink, String? gayaNama}) => UserProfile(
        id: id,
        nama: nama ?? this.nama,
        email: email,
        phone: phone ?? this.phone,
        saldo: saldo ?? this.saldo,
        tier: tier,
        foto: foto ?? this.foto,
        avatar: avatar,
        bio: bio ?? this.bio,
        banner: banner ?? this.banner,
        bannerMedia:
            hapusBannerMedia ? null : (bannerMedia ?? this.bannerMedia),
        bingkai: bingkai ?? this.bingkai,
        username: username ?? this.username,
        namaDiubahPada: namaDiubahPada,
        usernameDiubahPada: usernameDiubahPada,
        totalBelanja: totalBelanja ?? this.totalBelanja,
        pinTransferAktif: pinTransferAktif ?? this.pinTransferAktif,
        notifForum: notifForum,
        notifDm: notifDm,
        notifLive: notifLive,
        slogan: slogan ?? this.slogan,
        bioLink: bioLink ?? this.bioLink,
        gayaNama: gayaNama ?? this.gayaNama,
        badge: badge,
        diblokir: diblokir ?? this.diblokir,
        alasanBlokir: alasanBlokir ?? this.alasanBlokir,
        peringatan: peringatan ?? this.peringatan,
        kodeReferral: kodeReferral,
        diundangOleh: diundangOleh,
      );
}

/// Paket / spesifikasi PC cloud yang bisa disewa.
class PcPlan {
  final String id;
  final String nama;
  final String gpu;
  final String cpu;
  final int ramGb;
  final int storageGb;
  final int hargaPerJam;
  final int hargaPerHari;
  final String region;
  final String tag; // Populer, Hemat, Ultra
  final int totalUnit;
  int unitTersedia; // realtime
  final String gambar;

  PcPlan({
    required this.id,
    required this.nama,
    required this.gpu,
    required this.cpu,
    required this.ramGb,
    required this.storageGb,
    required this.hargaPerJam,
    required this.hargaPerHari,
    required this.region,
    required this.tag,
    required this.totalUnit,
    required this.unitTersedia,
    required this.gambar,
  });

  bool get ready => unitTersedia > 0;

  factory PcPlan.fromJson(Map<String, dynamic> j) => PcPlan(
        id: '${j['id']}',
        nama: j['nama'],
        gpu: j['gpu'],
        cpu: j['cpu'],
        ramGb: j['ram_gb'] ?? j['ramGb'] ?? 16,
        storageGb: j['storage_gb'] ?? j['storageGb'] ?? 256,
        hargaPerJam: j['harga_per_jam'] ?? j['hargaPerJam'] ?? 0,
        hargaPerHari: j['harga_per_hari'] ?? j['hargaPerHari'] ?? 0,
        region: j['region'] ?? 'Jakarta',
        tag: j['tag'] ?? '',
        totalUnit: j['total_unit'] ?? j['totalUnit'] ?? 0,
        unitTersedia: j['unit_tersedia'] ?? j['unitTersedia'] ?? 0,
        gambar: j['gambar'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nama': nama,
        'gpu': gpu,
        'cpu': cpu,
        'ram_gb': ramGb,
        'storage_gb': storageGb,
        'harga_per_jam': hargaPerJam,
        'harga_per_hari': hargaPerHari,
        'region': region,
        'tag': tag,
        'total_unit': totalUnit,
        'unit_tersedia': unitTersedia,
        'gambar': gambar,
      };
}

enum OrderStatus { pending, dibayar, provisioning, aktif, selesai, batal }

OrderStatus statusFrom(String s) => OrderStatus.values.firstWhere(
      (e) => e.name == s,
      orElse: () => OrderStatus.pending,
    );

extension OrderStatusX on OrderStatus {
  String get label => switch (this) {
        OrderStatus.pending => 'Menunggu Pembayaran',
        OrderStatus.dibayar => 'Pembayaran Diterima',
        OrderStatus.provisioning => 'Menyiapkan Mesin',
        OrderStatus.aktif => 'Sesi Aktif',
        OrderStatus.selesai => 'Selesai',
        OrderStatus.batal => 'Dibatalkan',
      };
  int get step => switch (this) {
        OrderStatus.pending => 0,
        OrderStatus.dibayar => 1,
        OrderStatus.provisioning => 2,
        OrderStatus.aktif => 3,
        OrderStatus.selesai => 4,
        OrderStatus.batal => -1,
      };
}

/// Order sewa PC.
class RentOrder {
  final String id;
  final String kode;
  final String planId;
  final String planNama;
  final int durasiJam;
  final int total;
  OrderStatus status;
  final DateTime dibuat;
  DateTime? mulai;
  DateTime? berakhir;
  String? host;
  String? username;
  String? password;
  int progress; // 0-100 saat provisioning

  RentOrder({
    required this.id,
    required this.kode,
    required this.planId,
    required this.planNama,
    required this.durasiJam,
    required this.total,
    required this.status,
    required this.dibuat,
    this.mulai,
    this.berakhir,
    this.host,
    this.username,
    this.password,
    this.progress = 0,
  });

  factory RentOrder.fromJson(Map<String, dynamic> j) => RentOrder(
        id: '${j['id']}',
        kode: j['kode'] ?? j['code'] ?? '-',
        planId: '${j['plan_id'] ?? j['planId'] ?? ''}',
        planNama: j['plan_nama'] ?? j['planNama'] ?? '',
        durasiJam: j['durasi_jam'] ?? j['durasiJam'] ?? 1,
        total: j['total'] ?? 0,
        status: statusFrom(j['status'] ?? 'pending'),
        dibuat: DateTime.parse(j['dibuat'] ?? j['created_at']),
        mulai: (j['mulai'] ?? j['start_at']) == null ? null : DateTime.parse(j['mulai'] ?? j['start_at']),
        berakhir: (j['berakhir'] ?? j['end_at']) == null ? null : DateTime.parse(j['berakhir'] ?? j['end_at']),
        host: j['host'],
        username: j['username'],
        password: j['password'],
        progress: j['progress'] ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'kode': kode,
        'plan_id': planId,
        'plan_nama': planNama,
        'durasi_jam': durasiJam,
        'total': total,
        'status': status.name,
        'dibuat': dibuat.toIso8601String(),
        'mulai': mulai?.toIso8601String(),
        'berakhir': berakhir?.toIso8601String(),
        'host': host,
        'username': username,
        'password': password,
        'progress': progress,
      };
}

/// Produk akun digital yang dijual (Steam, Netflix, Game Pass, dsb).
/// Membaca kolom `detail` yang bisa berupa peta atau teks JSON.
Map<String, dynamic> _petaAman(dynamic v) {
  if (v == null) return const {};
  if (v is Map) return Map<String, dynamic>.from(v);
  if (v is String && v.trim().startsWith('{')) {
    try {
      return Map<String, dynamic>.from(jsonDecode(v));
    } catch (_) {}
  }
  return const {};
}

class AkunProduk {
  final String id;
  final String nama;
  final String kategori;
  final String deskripsi;
  final int harga;
  final int hargaCoret;
  final int stok; // realtime
  final double rating;
  final int terjual;
  final String gambar;
  final List<String> fitur;
  final String garansi;
  final int jumlahUlasan;
  final Map<String, dynamic> detail;

  AkunProduk({
    required this.id,
    required this.nama,
    required this.kategori,
    required this.deskripsi,
    required this.harga,
    required this.hargaCoret,
    required this.stok,
    required this.rating,
    required this.terjual,
    required this.gambar,
    required this.fitur,
    required this.garansi,
    this.jumlahUlasan = 0,
    this.detail = const {},
  });

  factory AkunProduk.fromJson(Map<String, dynamic> j) => AkunProduk(
        id: '${j['id']}',
        nama: j['nama'],
        kategori: j['kategori'] ?? 'Lainnya',
        deskripsi: j['deskripsi'] ?? '',
        harga: j['harga'] ?? 0,
        hargaCoret: j['harga_coret'] ?? j['hargaCoret'] ?? 0,
        stok: j['stok'] ?? 0,
        rating: (j['rating'] ?? 5).toDouble(),
        terjual: j['terjual'] ?? 0,
        gambar: j['gambar'] ?? '',
        fitur: (j['fitur'] as List?)?.map((e) => '$e').toList() ?? const [],
        garansi: j['garansi'] ?? '7 hari',
        jumlahUlasan: j['jumlah_ulasan'] ?? 0,
        detail: _petaAman(j['detail']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nama': nama,
        'kategori': kategori,
        'deskripsi': deskripsi,
        'harga': harga,
        'harga_coret': hargaCoret,
        'stok': stok,
        'rating': rating,
        'terjual': terjual,
        'gambar': gambar,
        'fitur': fitur,
        'garansi': garansi,
        'jumlah_ulasan': jumlahUlasan,
        'detail': detail,
      };
}

class ChatMessage {
  final String id;
  final String room;
  final String? clientId;
  final String dari; // 'user' | 'cs' | 'system'
  final String tipe; // 'teks' | 'gambar' | 'audio' | 'system'
  final String teks;
  final String? gambar;
  final String? audio;
  final double? durasi;
  final String? replyTo;
  final String? replyTeks;
  final String? replyTipe;
  final DateTime waktu;
  bool terkirim;
  bool dibaca;
  bool gagal;

  ChatMessage({
    required this.id,
    required this.room,
    required this.dari,
    required this.teks,
    required this.waktu,
    this.gambar,
    this.audio,
    this.durasi,
    this.tipe = 'teks',
    this.replyTo,
    this.replyTeks,
    this.replyTipe,
    this.clientId,
    this.terkirim = true,
    this.dibaca = false,
    this.gagal = false,
  });

  bool get milikSaya => dari == 'user';

  /// [audio] adalah URL server (bukan data URI) — data URI hanya dipakai
  /// untuk pratinjau lokal yang belum terkirim.
  bool get bisaPutarAudio => tipe == 'audio' && (audio?.startsWith('http') ?? false);

  factory ChatMessage.fromJson(Map<String, dynamic> j) {
    final gambar = (j['gambar'] as String?)?.isNotEmpty == true ? j['gambar'] : null;
    final audio = (j['audio'] as String?)?.isNotEmpty == true ? j['audio'] : null;
    final dari = j['dari'] ?? j['from'] ?? 'cs';
    var tipe = '${j['tipe'] ?? (audio != null ? 'audio' : (gambar != null ? 'gambar' : 'teks'))}';
    if (dari == 'system') tipe = 'system';
    final durasi = j['durasi'];
    return ChatMessage(
        id: '${j['id']}',
        room: j['room'] ?? '',
        clientId: j['client_id'],
        dari: dari,
        tipe: tipe,
        teks: j['teks'] ?? j['text'] ?? '',
        gambar: gambar,
        audio: audio,
        durasi: durasi is num ? durasi.toDouble() : null,
        replyTo: (j['reply_to'] as String?)?.isNotEmpty == true ? j['reply_to'] : null,
        replyTeks: (j['reply_teks'] as String?)?.isNotEmpty == true ? j['reply_teks'] : null,
        replyTipe: '${j['reply_tipe'] ?? 'teks'}',
        waktu: tanggalServer(j['waktu'] ?? j['at']),
        dibaca: (j['dibaca'] ?? 0) == 1,
      );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'room': room,
        'client_id': clientId,
        'dari': dari,
        'tipe': tipe,
        'teks': teks,
        'gambar': gambar,
        'audio': audio,
        'durasi': durasi,
        'reply_to': replyTo,
        'reply_teks': replyTeks,
        'reply_tipe': replyTipe,
        'waktu': waktu.toIso8601String(),
      };
}

class Transaksi {
  final String id;
  final String judul;
  final String tipe; // topup | sewa | akun | refund
  final int nominal; // + / -
  final DateTime waktu;
  final String status;

  Transaksi({
    required this.id,
    required this.judul,
    required this.tipe,
    required this.nominal,
    required this.waktu,
    required this.status,
  });

  factory Transaksi.fromJson(Map<String, dynamic> j) => Transaksi(
        id: '${j['id']}',
        judul: j['judul'] ?? '',
        tipe: j['tipe'] ?? 'sewa',
        nominal: j['nominal'] ?? 0,
        waktu: DateTime.parse(j['waktu']),
        status: j['status'] ?? 'sukses',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'judul': judul,
        'tipe': tipe,
        'nominal': nominal,
        'waktu': waktu.toIso8601String(),
        'status': status,
      };
}

/// Banner promo yang tampil sebagai slider di beranda.
/// Dikelola sepenuhnya lewat dashboard admin (tabel `banners` di D1).
class PromoBanner {
  final String id;
  final String judul;
  final String subjudul;
  final String label;
  final String cta;
  final String aksi; // sewa | akun | topup | url
  final String target;
  final String warna1;
  final String warna2;
  final String ikon;
  final int urutan;
  final String gambar; // opsional: URL/DataURI latar, bila kosong pakai gradasi warna

  PromoBanner({
    required this.id,
    required this.judul,
    this.subjudul = '',
    this.label = '',
    this.cta = 'Lihat',
    this.aksi = 'sewa',
    this.target = '',
    this.warna1 = '#2F5BFF',
    this.warna2 = '#6A4BFF',
    this.ikon = 'bolt',
    this.urutan = 1,
    this.gambar = '',
  });

  factory PromoBanner.fromJson(Map<String, dynamic> j) => PromoBanner(
        id: '${j['id']}',
        judul: j['judul'] ?? '',
        subjudul: j['subjudul'] ?? '',
        label: j['label'] ?? '',
        cta: j['cta'] ?? 'Lihat',
        aksi: j['aksi'] ?? 'sewa',
        target: j['target'] ?? '',
        warna1: j['warna1'] ?? '#2F5BFF',
        warna2: j['warna2'] ?? '#6A4BFF',
        ikon: j['ikon'] ?? 'bolt',
        urutan: (j['urutan'] ?? 1) is int ? (j['urutan'] ?? 1) as int : 1,
        gambar: '${j['gambar'] ?? ''}',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'judul': judul,
        'subjudul': subjudul,
        'label': label,
        'cta': cta,
        'aksi': aksi,
        'target': target,
        'warna1': warna1,
        'warna2': warna2,
        'ikon': ikon,
        'urutan': urutan,
        'gambar': gambar,
      };
}

/// Ulasan pembeli untuk sebuah produk akun.
class Ulasan {
  final String id;
  final String produkId;
  final String nama;
  final int rating;
  final String komentar;
  final String? gambar;
  final String? balasan;
  final DateTime waktu;

  Ulasan({
    required this.id,
    required this.produkId,
    required this.nama,
    required this.rating,
    required this.komentar,
    required this.waktu,
    this.gambar,
    this.balasan,
  });

  factory Ulasan.fromJson(Map<String, dynamic> j) => Ulasan(
        id: '${j['id']}',
        produkId: '${j['produk_id'] ?? ''}',
        nama: j['nama'] ?? 'Pengguna',
        rating: (j['rating'] ?? 5) is int ? (j['rating'] ?? 5) : int.tryParse('${j['rating']}') ?? 5,
        komentar: j['komentar'] ?? '',
        gambar: (j['gambar'] as String?)?.isNotEmpty == true ? j['gambar'] : null,
        balasan: (j['balasan'] as String?)?.isNotEmpty == true ? j['balasan'] : null,
        waktu: DateTime.tryParse('${j['waktu']}') ?? DateTime.now(),
      );
}

/// Permintaan isi saldo yang menunggu konfirmasi admin.
class PermintaanTopup {
  final String id;
  final int nominal;
  final int kodeUnik;
  final int total;
  final String metode;
  final String status; // menunggu | diperiksa | disetujui | ditolak
  final String provider;
  final String? bukti;
  final String? catatan;
  final DateTime dibuat;
  final Map<String, dynamic> rekening;

  /// Kalau penyedia pembayaran aktif, di sini ada tautan atau QR-nya.
  final bool otomatis;
  final Map<String, dynamic> bayar;

  PermintaanTopup({
    required this.id,
    required this.nominal,
    required this.kodeUnik,
    required this.total,
    required this.metode,
    required this.status,
    required this.dibuat,
    this.provider = 'manual',
    this.bukti,
    this.catatan,
    this.rekening = const {},
    this.otomatis = false,
    this.bayar = const {},
  });

  factory PermintaanTopup.fromJson(Map<String, dynamic> j) => PermintaanTopup(
        id: '${j['id']}',
        nominal: j['nominal'] ?? 0,
        kodeUnik: j['kode_unik'] ?? 0,
        total: j['total'] ?? (j['nominal'] ?? 0),
        metode: j['metode'] ?? 'transfer',
        status: j['status'] ?? 'menunggu',
        provider: '${j['provider'] ?? (j['otomatis'] == true ? 'gateway' : 'manual')}',
        bukti: (j['bukti'] as String?)?.isNotEmpty == true ? j['bukti'] : null,
        catatan: (j['catatan'] as String?)?.isNotEmpty == true ? j['catatan'] : null,
        dibuat: tanggalServer(j['dibuat']),
        rekening: _petaAman(j['rekening']),
        otomatis: j['otomatis'] == true,
        bayar: _petaAman(j['bayar']),
      );

  bool get selesai => status == 'disetujui' || status == 'ditolak';
}

/// Konfigurasi dari server: penyedia login aktif, nomor WhatsApp, rekening.
class KonfigurasiApp {
  final bool bayarOtomatis;
  final List<Map<String, dynamic>> metodeBayar;
  final bool googleAktif;
  final bool facebookAktif;
  final String whatsapp;
  final Map<String, dynamic> rekening;
  final int minTopup;

  /// Negara pengunjung (kode ISO-2 + nama Indonesia) — dideteksi server dari
  /// jaringan (Cloudflare) untuk baris persetujuan di layar login.
  final String negaraKode;
  final String negaraNama;

  /// Batch J: angka realtime untuk layar welcome & status unit.
  final int statistikPengguna;
  final int statistikUnitOnline;

  /// Batch M: server sedang mode pemeliharaan (dari /config, sehingga juga
  /// terbaca untuk perangkat yang belum login — selama pemeliharaan auth/*
  /// tetap terbuka dan 503 tidak pernah sampai ke klien tanpa token).
  final bool pemeliharaanAktif;
  final String pemeliharaanPesan;

  const KonfigurasiApp({
    this.bayarOtomatis = false,
    this.metodeBayar = const [],
    this.googleAktif = false,
    this.facebookAktif = false,
    this.whatsapp = '',
    this.rekening = const {},
    this.minTopup = 10000,
    this.negaraKode = '',
    this.negaraNama = '',
    this.statistikPengguna = 0,
    this.statistikUnitOnline = 0,
    this.pemeliharaanAktif = false,
    this.pemeliharaanPesan = '',
  });

  factory KonfigurasiApp.fromJson(Map<String, dynamic> j) {
    final p = _petaAman(j['providers']);
    final bayar = _petaAman(j['pembayaran']);
    final negara = _petaAman(j['negara']);
    return KonfigurasiApp(
      bayarOtomatis: bayar['otomatis'] == true,
      metodeBayar: ((bayar['metode'] as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      googleAktif: p['google'] == true,
      facebookAktif: p['facebook'] == true,
      whatsapp: '${j['whatsapp'] ?? ''}',
      rekening: _petaAman(j['rekening']),
      negaraKode: '${negara['kode'] ?? ''}',
      negaraNama: '${negara['nama'] ?? ''}',
      statistikPengguna: (_petaAman(j['statistik'])['pengguna'] as num?)?.toInt() ?? 0,
      statistikUnitOnline: (_petaAman(j['statistik'])['unitOnline'] as num?)?.toInt() ?? 0,
      minTopup: j['minTopup'] ?? 10000,
      pemeliharaanAktif: _petaAman(j['pemeliharaan'])['aktif'] == true,
      pemeliharaanPesan: '${_petaAman(j['pemeliharaan'])['pesan'] ?? ''}',
    );
  }
}

/// Satu diskusi di forum komunitas.
class ForumPost {
  final String id;
  final String userId;
  final String nama;
  final String? foto;
  final String kategori;
  final String judul;
  final String isi;
  final String? gambar;
  final String tier;
  final String? badge;
  /// Batch L: bingkai avatar & gaya nama penulis (dibaca semua orang).
  final String? bingkai;
  final String? gayaNama;
  final bool sensitif;
  int suka;
  int balasan;
  final bool disematkan;
  final DateTime dibuat;

  ForumPost({
    required this.id,
    required this.userId,
    required this.nama,
    required this.kategori,
    required this.judul,
    required this.isi,
    required this.dibuat,
    this.foto,
    this.gambar,
    this.tier = 'basic',
    this.badge,
    this.bingkai,
    this.gayaNama,
    this.sensitif = false,
    this.suka = 0,
    this.balasan = 0,
    this.disematkan = false,
  });

  factory ForumPost.fromJson(Map<String, dynamic> j) => ForumPost(
        id: '${j['id']}',
        userId: '${j['user_id'] ?? ''}',
        nama: j['nama'] ?? 'Pengguna',
        foto: (j['foto'] as String?)?.isNotEmpty == true ? j['foto'] : null,
        kategori: j['kategori'] ?? 'Umum',
        judul: j['judul'] ?? '',
        isi: j['isi'] ?? '',
        gambar: (j['gambar'] as String?)?.isNotEmpty == true ? j['gambar'] : null,
        tier: j['tier'] ?? 'basic',
        badge: (j['badge'] as String?)?.isNotEmpty == true ? j['badge'] : null,
        bingkai: (j['bingkai'] as String?)?.isNotEmpty == true ? j['bingkai'] : null,
        gayaNama: (j['gaya_nama'] as String?)?.isNotEmpty == true ? j['gaya_nama'] : null,
        sensitif: (j['sensitif'] ?? 0) == 1,
        suka: j['suka'] ?? 0,
        balasan: j['balasan'] ?? 0,
        disematkan: (j['disematkan'] ?? 0) == 1,
        dibuat: tanggalServer(j['dibuat']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'nama': nama,
        'foto': foto,
        'kategori': kategori,
        'judul': judul,
        'isi': isi,
        'gambar': gambar,
        'tier': tier,
        'suka': suka,
        'balasan': balasan,
        'disematkan': disematkan ? 1 : 0,
        'dibuat': dibuat.toIso8601String(),
      };
}

/// Balasan pada sebuah diskusi.
class ForumBalasan {
  final String id;
  final String postId;
  final String userId;
  final String? balasKe;
  final String nama;
  final String? foto;
  final String isi;
  final Stiker? stiker;
  final bool admin;
  final String tier;
  final String? badge;
  /// Batch L: bingkai & gaya nama penulis komentar.
  final String? bingkai;
  final String? gayaNama;
  int suka;
  final DateTime dibuat;

  ForumBalasan({
    required this.id,
    required this.postId,
    required this.nama,
    this.userId = '',
    this.balasKe,
    required this.isi,
    this.stiker,
    required this.dibuat,
    this.foto,
    this.admin = false,
    this.tier = 'basic',
    this.badge,
    this.bingkai,
    this.gayaNama,
    this.suka = 0,
  });

  factory ForumBalasan.fromJson(Map<String, dynamic> j) => ForumBalasan(
        id: '${j['id']}',
        postId: '${j['post_id'] ?? ''}',
        userId: '${j['user_id'] ?? ''}',
        balasKe: (j['balas_ke'] as String?)?.isNotEmpty == true ? j['balas_ke'] : null,
        nama: j['nama'] ?? 'Pengguna',
        foto: (j['foto'] as String?)?.isNotEmpty == true ? j['foto'] : null,
        isi: j['isi'] ?? '',
        stiker: Stiker.baca(j['stiker']),
        admin: (j['admin'] ?? 0) == 1,
        tier: j['tier'] ?? 'basic',
        badge: (j['badge'] as String?)?.isNotEmpty == true ? j['badge'] : null,
        bingkai: (j['bingkai'] as String?)?.isNotEmpty == true ? j['bingkai'] : null,
        gayaNama: (j['gaya_nama'] as String?)?.isNotEmpty == true ? j['gaya_nama'] : null,
        suka: j['suka'] ?? 0,
        dibuat: tanggalServer(j['dibuat']),
      );
}

/// Sesi bermain di PC sewaan.
class SesiMain {
  final String id;
  final String orderId;
  final String? agenId;
  final String status; // menyiapkan | siap | pairing | berjalan | selesai | gagal
  final String? host;
  final String? hostLan;
  final String? catatan;
  final int durasiMenit;
  final DateTime? mulai;
  final DateTime? berakhir;
  final String? clientState;
  final DateTime? clientLast;
  final String? clientRoute;
  final int? clientLatencyMs;
  final String? clientQuality;
  final int clientDisconnects;
  final int clientReconnectAttempt;
  final String? clientReason;

  SesiMain({
    required this.id,
    required this.orderId,
    required this.status,
    this.agenId,
    this.host,
    this.hostLan,
    this.catatan,
    this.durasiMenit = 60,
    this.mulai,
    this.berakhir,
    this.clientState,
    this.clientLast,
    this.clientRoute,
    this.clientLatencyMs,
    this.clientQuality,
    this.clientDisconnects = 0,
    this.clientReconnectAttempt = 0,
    this.clientReason,
  });

  factory SesiMain.fromJson(Map<String, dynamic> j) => SesiMain(
        id: '${j['id']}',
        orderId: '${j['order_id'] ?? ''}',
        agenId: j['agen_id'],
        status: j['status'] ?? 'menyiapkan',
        host: (j['host'] as String?)?.isNotEmpty == true ? j['host'] : null,
        hostLan:
            (j['host_lan'] as String?)?.isNotEmpty == true ? j['host_lan'] : null,
        catatan: (j['catatan'] as String?)?.isNotEmpty == true ? j['catatan'] : null,
        durasiMenit: j['durasi_menit'] ?? 60,
        mulai: DateTime.tryParse('${j['mulai']}'.replaceFirst(' ', 'T')),
        berakhir: DateTime.tryParse('${j['berakhir']}'.replaceFirst(' ', 'T')),
        clientState: j['client_state'] as String?,
        clientLast: j['client_last'] == null
            ? null
            : DateTime.tryParse('${j['client_last']}'.replaceFirst(' ', 'T')),
        clientRoute: j['client_route'] as String?,
        clientLatencyMs: (j['client_latency_ms'] as num?)?.toInt(),
        clientQuality: j['client_quality'] as String?,
        clientDisconnects: (j['client_disconnects'] as num?)?.toInt() ?? 0,
        clientReconnectAttempt:
            (j['client_reconnect_attempt'] as num?)?.toInt() ?? 0,
        clientReason: j['client_reason'] as String?,
      );
}

/// Satu baris pemberitahuan di pusat notifikasi.
class Notifikasi {
  final String id;
  final String jenis; // suka | balasan | komunitas | peringatan | sistem | order | wallet
  final String judul;
  final String pesan;
  final String? aktor;
  final String? refJenis;
  final String? refId;
  final bool dibaca;
  final DateTime dibuat;

  Notifikasi({
    required this.id,
    required this.jenis,
    required this.judul,
    required this.pesan,
    required this.dibuat,
    this.aktor,
    this.refJenis,
    this.refId,
    this.dibaca = false,
  });

  factory Notifikasi.fromJson(Map<String, dynamic> j) => Notifikasi(
        id: '${j['id']}',
        jenis: j['jenis'] ?? 'sistem',
        judul: j['judul'] ?? '',
        pesan: j['pesan'] ?? '',
        aktor: j['aktor'],
        refJenis: j['ref_jenis'],
        refId: j['ref_id'],
        dibaca: (j['dibaca'] ?? 0) == 1,
        dibuat: tanggalServer(j['dibuat']),
      );
}

/// ============================================================
///  Status pembekuan akun (layar Akun Dibekukan)
/// ============================================================
class PelanggaranItem {
  const PelanggaranItem({
    this.jenis = 'blokir',
    this.alasan = '',
    this.sampai,
    this.waktu = '',
  });
  final String jenis;
  final String alasan;
  final String? sampai;
  final String waktu;

  factory PelanggaranItem.fromJson(Map<String, dynamic> j) => PelanggaranItem(
        jenis: (j['jenis'] ?? 'blokir') as String,
        alasan: (j['alasan'] ?? '') as String,
        sampai: j['sampai'] as String?,
        waktu: (j['waktu'] ?? '') as String,
      );
}

class BandingItem {
  const BandingItem({
    this.id = '',
    this.pesan = '',
    this.status = 'baru',
    this.waktu = '',
    this.tanggapan,
  });
  final String id;
  final String pesan;
  final String status; // baru | diterima | ditolak
  final String waktu;
  final String? tanggapan;

  factory BandingItem.fromJson(Map<String, dynamic> j) => BandingItem(
        id: (j['id'] ?? '') as String,
        pesan: (j['pesan'] ?? '') as String,
        status: (j['status'] ?? 'baru') as String,
        waktu: (j['waktu'] ?? '') as String,
        tanggapan: j['tanggapan'] as String?,
      );
}

class InfoBlokir {
  const InfoBlokir({
    this.diblokir = false,
    this.sampai,
    this.alasan,
    this.pelanggaran = const [],
    this.banding = const [],
  });
  final bool diblokir;
  final String? sampai; // null = permanen
  final String? alasan;
  final List<PelanggaranItem> pelanggaran;
  final List<BandingItem> banding;

  bool get sementara => diblokir && sampai != null && sampai!.isNotEmpty;
  BandingItem? get bandingTerbuka =>
      banding.where((b) => b.status == 'baru').isEmpty
          ? null
          : banding.firstWhere((b) => b.status == 'baru');

  factory InfoBlokir.fromJson(Map<String, dynamic> j) => InfoBlokir(
        diblokir: (j['diblokir'] ?? false) == true,
        sampai: j['sampai'] as String?,
        alasan: j['alasan'] as String?,
        pelanggaran: (j['pelanggaran'] as List? ?? const [])
            .map((x) => PelanggaranItem.fromJson(Map<String, dynamic>.from(x)))
            .toList(),
        banding: (j['banding'] as List? ?? const [])
            .map((x) => BandingItem.fromJson(Map<String, dynamic>.from(x)))
            .toList(),
      );
}

/// Ubah penanda waktu server (ISO-8601 atau epoch ms) jadi epoch ms lokal.
int waktuMs(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toInt();
  final d = DateTime.tryParse('$v');
  return d?.millisecondsSinceEpoch ?? 0;
}

/// ============================================================
///  Sosial (Batch D): profil publik, ikutan, dan pesan DM
/// ============================================================
class ProfilPublik {
  final String id;
  final String nama;
  final String? username;
  final String? foto;
  final String? bio;
  final String? banner;
  final BannerMedia? bannerMedia;
  final String? bingkai;
  final String? tier;
  final String? badge;
  /// Batch L: identitas tambahan yang tampil ke semua orang.
  final String? slogan;
  final String? bioLink;
  final String? gayaNama;
  final String? createdAt;
  final int pengikut;
  final int mengikuti;
  final int posting;
  final bool sayaIkuti;
  final bool saya;

  const ProfilPublik({
    required this.id, required this.nama, this.username, this.foto, this.bio, this.banner,
    this.bannerMedia, this.bingkai, this.tier, this.badge,
    this.slogan, this.bioLink, this.gayaNama, this.createdAt,
    this.pengikut = 0, this.mengikuti = 0,
    this.posting = 0, this.sayaIkuti = false, this.saya = false,
  });

  factory ProfilPublik.fromJson(Map<String, dynamic> j) => ProfilPublik(
    id: j['id'] as String,
    nama: j['nama'] as String? ?? '',
    username: (j['username'] as String?)?.isNotEmpty == true ? j['username'] : null,
    foto: j['foto'] as String?,
    bio: j['bio'] as String?,
    banner: j['banner'] as String?,
    bannerMedia: BannerMedia.parse(j['banner_media']),
    bingkai: (j['bingkai'] as String?)?.isNotEmpty == true ? j['bingkai'] : null,
    tier: j['tier'] as String?,
    badge: j['badge'] as String?,
    slogan: (j['slogan'] as String?)?.isNotEmpty == true ? j['slogan'] : null,
    bioLink: (j['bio_link'] as String?)?.isNotEmpty == true ? j['bio_link'] : null,
    gayaNama: (j['gaya_nama'] as String?)?.isNotEmpty == true ? j['gaya_nama'] : null,
    createdAt: j['created_at'] as String?,
    pengikut: (j['pengikut'] as num?)?.toInt() ?? 0,
    mengikuti: (j['mengikuti'] as num?)?.toInt() ?? 0,
    posting: (j['posting'] as num?)?.toInt() ?? 0,
    // Server membalas kunci camelCase; terima juga varian snake_case.
    sayaIkuti: j['sayaIkuti'] == true || j['saya_ikuti'] == 1 || j['saya_ikuti'] == true,
    saya: j['saya'] == 1 || j['saya'] == true,
  );

  ProfilPublik copyWith({bool? sayaIkuti, int? pengikut}) => ProfilPublik(
        id: id, nama: nama, username: username, foto: foto, bio: bio,
        banner: banner, bannerMedia: bannerMedia, bingkai: bingkai,
        tier: tier, badge: badge, slogan: slogan, bioLink: bioLink,
        gayaNama: gayaNama, createdAt: createdAt,
        pengikut: pengikut ?? this.pengikut, mengikuti: mengikuti,
        posting: posting, sayaIkuti: sayaIkuti ?? this.sayaIkuti, saya: saya,
      );
}

/// Baris leaderboard nyata (Batch I) — poin = belanja bulan ini / total.
class PapanPeringkat {
  final int peringkat;
  final String id;
  final String nama;
  final String? username;
  final String? foto;
  final String? tier;
  final String? badge;
  final String? bingkai;
  final String? gayaNama;
  final String? slogan;
  final int poin;
  final bool saya;

  const PapanPeringkat({
    required this.peringkat, required this.id, required this.nama,
    this.username, this.foto, this.tier, this.badge, this.bingkai,
    this.gayaNama, this.slogan,
    this.poin = 0, this.saya = false,
  });

  factory PapanPeringkat.fromJson(Map<String, dynamic> j) => PapanPeringkat(
        peringkat: (j['peringkat'] as num?)?.toInt() ?? 0,
        id: '${j['id']}',
        nama: j['nama'] as String? ?? '',
        username: (j['username'] as String?)?.isNotEmpty == true ? j['username'] : null,
        foto: j['foto'] as String?,
        tier: j['tier'] as String?,
        badge: j['badge'] as String?,
        bingkai: (j['bingkai'] as String?)?.isNotEmpty == true ? j['bingkai'] : null,
        gayaNama: (j['gaya_nama'] as String?)?.isNotEmpty == true ? j['gaya_nama'] : null,
        slogan: (j['slogan'] as String?)?.isNotEmpty == true ? j['slogan'] : null,
        poin: (j['poin'] as num?)?.toInt() ?? 0,
        saya: j['saya'] == true || j['saya'] == 1,
      );
}

class DataLeaderboard {
  final String periode; // 'bulan' | 'total'
  final int? peringkatSaya;
  final int poinSaya;
  final List<PapanPeringkat> papan;

  const DataLeaderboard({
    required this.periode, this.peringkatSaya, this.poinSaya = 0,
    this.papan = const [],
  });

  factory DataLeaderboard.fromJson(Map<String, dynamic> j) {
    final saya = Map<String, dynamic>.from(j['saya'] as Map? ?? {});
    final papan = (j['papan'] as List? ?? [])
        .map((e) => PapanPeringkat.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    return DataLeaderboard(
      periode: j['periode'] as String? ?? 'bulan',
      peringkatSaya: (saya['peringkat'] as num?)?.toInt(),
      poinSaya: (saya['poin'] as num?)?.toInt() ?? 0,
      papan: papan,
    );
  }
}

class BisukanItem {
  final String thread;
  final int sampai;
  const BisukanItem({required this.thread, required this.sampai});
  factory BisukanItem.fromJson(Map<String, dynamic> j) => BisukanItem(
        thread: j['thread'] as String? ?? '',
        sampai: (j['sampai'] as num?)?.toInt() ?? 0,
      );
}

class IkutanItem {
  final String id;
  final String nama;
  final String? foto;
  const IkutanItem({required this.id, required this.nama, this.foto});
  factory IkutanItem.fromJson(Map<String, dynamic> j) => IkutanItem(
    id: j['id'] as String, nama: j['nama'] as String? ?? '', foto: j['foto'] as String?,
  );
}

class DmPesan {
  final String id;
  final String dariId;
  final String keId;
  final String? teks;
  final String? audio;
  final double? durasi;
  final String? gambar;
  final String tipe;
  final bool dibaca;
  final int waktu;
  final String? dariNama;
  final String? dariFoto;

  const DmPesan({
    required this.id, required this.dariId, required this.keId, this.teks,
    this.audio, this.durasi, this.gambar, this.tipe = 'text',
    this.dibaca = false, this.waktu = 0, this.dariNama, this.dariFoto,
  });

  factory DmPesan.fromJson(Map<String, dynamic> j) => DmPesan(
    id: j['id'] as String? ?? '',
    dariId: j['dari_id'] as String? ?? '',
    keId: j['ke_id'] as String? ?? '',
    teks: j['teks'] as String?,
    audio: j['audio'] as String?,
    durasi: (j['durasi'] as num?)?.toDouble(),
    gambar: j['gambar'] as String?,
    tipe: j['tipe'] as String? ?? 'text',
    dibaca: j['dibaca'] == 1 || j['dibaca'] == true,
    waktu: waktuMs(j['waktu']),
    dariNama: j['dari_nama'] as String?,
    dariFoto: j['dari_foto'] as String?,
  );

  bool dariSaya(String sayaId) => dariId == sayaId;
  DateTime get tanggal => DateTime.fromMillisecondsSinceEpoch(waktu);

  Map<String, dynamic> toJson() => {
    'id': id,
    'dari_id': dariId,
    'ke_id': keId,
    'teks': teks,
    'audio': audio,
    'durasi': durasi,
    'gambar': gambar,
    'tipe': tipe,
    'dibaca': dibaca ? 1 : 0,
    'waktu': waktu,
    'dari_nama': dariNama,
    'dari_foto': dariFoto,
  };
}


/// ============================================================
///  HUD streaming kustom (Batch P)
/// ============================================================
/// Posisi tombol disimpan relatif (0–1) terhadap kanvas landscape. Ukuran
/// disimpan dalam dp supaya editor Flutter dan overlay native Android memakai
/// bentuk yang sama pada perangkat dengan kepadatan layar berbeda.
class HudTombol {
  final String id;
  final String label;
  final int kode;
  final double x;
  final double y;
  final double lebar;
  final double tinggi;
  final double opacity;
  final String cara; // tahan | ketuk | toggle

  const HudTombol({
    required this.id,
    required this.label,
    required this.kode,
    this.x = .45,
    this.y = .45,
    this.lebar = 56,
    this.tinggi = 56,
    this.opacity = .86,
    this.cara = 'tahan',
  });

  factory HudTombol.fromJson(Map<String, dynamic> j) => HudTombol(
        id: '${j['id'] ?? 't_${DateTime.now().microsecondsSinceEpoch}'}',
        label: _labelHud(j['label']),
        kode: (j['kode'] as num?)?.toInt() ?? 0,
        x: _angkaHud(j['x'], .45).clamp(0, 1).toDouble(),
        y: _angkaHud(j['y'], .45).clamp(0, 1).toDouble(),
        lebar: _angkaHud(j['lebar'], 56).clamp(36, 160).toDouble(),
        tinggi: _angkaHud(j['tinggi'], 56).clamp(36, 100).toDouble(),
        opacity: _angkaHud(j['opacity'], .86).clamp(.25, 1).toDouble(),
        cara: const {'tahan', 'ketuk', 'toggle'}.contains(j['cara'])
            ? '${j['cara']}'
            : 'tahan',
      );

  HudTombol copyWith({
    String? id,
    String? label,
    int? kode,
    double? x,
    double? y,
    double? lebar,
    double? tinggi,
    double? opacity,
    String? cara,
  }) =>
      HudTombol(
        id: id ?? this.id,
        label: label ?? this.label,
        kode: kode ?? this.kode,
        x: x ?? this.x,
        y: y ?? this.y,
        lebar: lebar ?? this.lebar,
        tinggi: tinggi ?? this.tinggi,
        opacity: opacity ?? this.opacity,
        cara: cara ?? this.cara,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'kode': kode,
        'x': double.parse(x.toStringAsFixed(5)),
        'y': double.parse(y.toStringAsFixed(5)),
        'lebar': lebar.round(),
        'tinggi': tinggi.round(),
        'opacity': double.parse(opacity.toStringAsFixed(2)),
        'cara': cara,
      };
}

double _angkaHud(dynamic v, double fallback) =>
    v is num && v.isFinite ? v.toDouble() : fallback;

String _labelHud(dynamic v) {
  final s = '${v ?? '?'}'.trim();
  if (s.isEmpty) return '?';
  return String.fromCharCodes(s.runes.take(8));
}

class HudLayout {
  final String id;
  final String nama;
  final String deskripsi;
  final String game;
  final List<HudTombol> tombol;
  final bool bawaan;
  final String? sumberId;

  const HudLayout({
    required this.id,
    required this.nama,
    this.deskripsi = '',
    this.game = '',
    this.tombol = const [],
    this.bawaan = false,
    this.sumberId,
  });

  factory HudLayout.baru() => HudLayout(
        id: 'lokal_${DateTime.now().microsecondsSinceEpoch}',
        nama: 'HUD Baru',
      );

  factory HudLayout.fromJson(Map<String, dynamic> j) {
    dynamic raw = j['tombol'];
    if (j['data'] is Map) raw = (j['data'] as Map)['tombol'];
    return HudLayout(
      id: '${j['id'] ?? 'lokal_${DateTime.now().microsecondsSinceEpoch}'}',
      nama: '${j['nama'] ?? 'HUD Tanpa Nama'}',
      deskripsi: '${j['deskripsi'] ?? ''}',
      game: '${j['game'] ?? ''}',
      bawaan: j['bawaan'] == true,
      sumberId: j['sumber_id'] as String?,
      tombol: (raw as List? ?? const [])
          .whereType<Map>()
          .map((e) => HudTombol.fromJson(Map<String, dynamic>.from(e)))
          .take(48)
          .toList(),
    );
  }

  HudLayout copyWith({
    String? id,
    String? nama,
    String? deskripsi,
    String? game,
    List<HudTombol>? tombol,
    bool? bawaan,
    String? sumberId,
  }) =>
      HudLayout(
        id: id ?? this.id,
        nama: nama ?? this.nama,
        deskripsi: deskripsi ?? this.deskripsi,
        game: game ?? this.game,
        tombol: tombol ?? this.tombol,
        bawaan: bawaan ?? this.bawaan,
        sumberId: sumberId ?? this.sumberId,
      );

  /// Bentuk minimum yang dikirim ke Android dan server komunitas.
  Map<String, dynamic> toData() => {
        'versi': 1,
        'tombol': tombol.map((e) => e.toJson()).toList(),
      };

  Map<String, dynamic> toJson() => {
        'id': id,
        'nama': nama,
        'deskripsi': deskripsi,
        'game': game,
        'bawaan': bawaan,
        if (sumberId != null) 'sumber_id': sumberId,
        ...toData(),
      };
}

/// Metadata preset yang diterbitkan pengguna ke galeri komunitas.
class HudPresetPublik {
  final String id;
  final String userId;
  final String nama;
  final String deskripsi;
  final String game;
  final HudLayout layout;
  final bool publik;
  final int suka;
  final int dipakai;
  final bool sayaSuka;
  final bool saya;
  final String pembuatNama;
  final String? pembuatUsername;
  final String? pembuatFoto;
  final String? pembuatTier;
  final int dibuat;
  final int diubah;

  const HudPresetPublik({
    required this.id,
    required this.userId,
    required this.nama,
    required this.layout,
    this.deskripsi = '',
    this.game = '',
    this.publik = true,
    this.suka = 0,
    this.dipakai = 0,
    this.sayaSuka = false,
    this.saya = false,
    this.pembuatNama = '',
    this.pembuatUsername,
    this.pembuatFoto,
    this.pembuatTier,
    this.dibuat = 0,
    this.diubah = 0,
  });

  factory HudPresetPublik.fromJson(Map<String, dynamic> j) {
    Map<String, dynamic> data = {};
    final raw = j['data'];
    if (raw is Map) {
      data = Map<String, dynamic>.from(raw);
    } else if (raw is String && raw.isNotEmpty) {
      try {
        data = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      } catch (_) {}
    }
    final id = '${j['id'] ?? ''}';
    final nama = '${j['nama'] ?? 'Preset HUD'}';
    final deskripsi = '${j['deskripsi'] ?? ''}';
    final game = '${j['game'] ?? ''}';
    return HudPresetPublik(
      id: id,
      userId: '${j['user_id'] ?? ''}',
      nama: nama,
      deskripsi: deskripsi,
      game: game,
      layout: HudLayout.fromJson({
        'id': 'komunitas_$id',
        'nama': nama,
        'deskripsi': deskripsi,
        'game': game,
        'sumber_id': id,
        'data': data,
      }),
      publik: j['publik'] == true || j['publik'] == 1,
      suka: (j['suka'] as num?)?.toInt() ?? 0,
      dipakai: (j['dipakai'] as num?)?.toInt() ?? 0,
      sayaSuka: j['saya_suka'] == true || j['saya_suka'] == 1,
      saya: j['saya'] == true || j['saya'] == 1,
      pembuatNama: '${j['pembuat_nama'] ?? ''}',
      pembuatUsername: j['pembuat_username'] as String?,
      pembuatFoto: j['pembuat_foto'] as String?,
      pembuatTier: j['pembuat_tier'] as String?,
      dibuat: waktuMs(j['dibuat']),
      diubah: waktuMs(j['diubah']),
    );
  }

  HudPresetPublik copyWith({bool? sayaSuka, int? suka, int? dipakai}) =>
      HudPresetPublik(
        id: id,
        userId: userId,
        nama: nama,
        deskripsi: deskripsi,
        game: game,
        layout: layout,
        publik: publik,
        suka: suka ?? this.suka,
        dipakai: dipakai ?? this.dipakai,
        sayaSuka: sayaSuka ?? this.sayaSuka,
        saya: saya,
        pembuatNama: pembuatNama,
        pembuatUsername: pembuatUsername,
        pembuatFoto: pembuatFoto,
        pembuatTier: pembuatTier,
        dibuat: dibuat,
        diubah: diubah,
      );
}

/// Pilihan keycode Android yang aman dan berguna untuk dikirim ke host PC.
class HudAksi {
  final String label;
  final int kode;
  final String grup;
  final String cara;
  const HudAksi(this.label, this.kode, this.grup, [this.cara = 'tahan']);
}

const hudAksiTersedia = <HudAksi>[
  HudAksi('W', 51, 'Gerak'), HudAksi('A', 29, 'Gerak'),
  HudAksi('S', 47, 'Gerak'), HudAksi('D', 32, 'Gerak'),
  HudAksi('↑', 19, 'Gerak'), HudAksi('↓', 20, 'Gerak'),
  HudAksi('←', 21, 'Gerak'), HudAksi('→', 22, 'Gerak'),
  HudAksi('Space', 62, 'Aksi'), HudAksi('Shift', 59, 'Aksi'),
  HudAksi('Ctrl', 113, 'Aksi'), HudAksi('Alt', 57, 'Aksi'),
  HudAksi('Win', 117, 'Aksi', 'toggle'),
  HudAksi('B', 30, 'Huruf'), HudAksi('C', 31, 'Huruf'),
  HudAksi('E', 33, 'Huruf'), HudAksi('F', 34, 'Huruf'),
  HudAksi('G', 35, 'Huruf'), HudAksi('H', 36, 'Huruf'),
  HudAksi('I', 37, 'Huruf'), HudAksi('J', 38, 'Huruf'),
  HudAksi('K', 39, 'Huruf'), HudAksi('L', 40, 'Huruf'),
  HudAksi('M', 41, 'Huruf'), HudAksi('N', 42, 'Huruf'),
  HudAksi('O', 43, 'Huruf'), HudAksi('P', 44, 'Huruf'),
  HudAksi('Q', 45, 'Huruf'), HudAksi('R', 46, 'Huruf'),
  HudAksi('T', 48, 'Huruf'), HudAksi('U', 49, 'Huruf'),
  HudAksi('V', 50, 'Huruf'), HudAksi('X', 52, 'Huruf'),
  HudAksi('Y', 53, 'Huruf'), HudAksi('Z', 54, 'Huruf'),
  HudAksi('0', 7, 'Angka', 'ketuk'), HudAksi('1', 8, 'Angka', 'ketuk'),
  HudAksi('2', 9, 'Angka', 'ketuk'), HudAksi('3', 10, 'Angka', 'ketuk'),
  HudAksi('4', 11, 'Angka', 'ketuk'), HudAksi('5', 12, 'Angka', 'ketuk'),
  HudAksi('6', 13, 'Angka', 'ketuk'), HudAksi('7', 14, 'Angka', 'ketuk'),
  HudAksi('8', 15, 'Angka', 'ketuk'), HudAksi('9', 16, 'Angka', 'ketuk'),
  HudAksi('Esc', 111, 'Sistem', 'ketuk'), HudAksi('Tab', 61, 'Sistem', 'ketuk'),
  HudAksi('Enter', 66, 'Sistem', 'ketuk'), HudAksi('Back', 67, 'Sistem', 'ketuk'),
  HudAksi('Delete', 112, 'Sistem', 'ketuk'), HudAksi('Insert', 124, 'Sistem', 'ketuk'),
  HudAksi('Home', 122, 'Sistem', 'ketuk'), HudAksi('End', 123, 'Sistem', 'ketuk'),
  HudAksi('PgUp', 92, 'Sistem', 'ketuk'), HudAksi('PgDn', 93, 'Sistem', 'ketuk'),
  HudAksi('Caps', 115, 'Sistem', 'ketuk'),
  HudAksi('-', 69, 'Simbol', 'ketuk'), HudAksi('=', 70, 'Simbol', 'ketuk'),
  HudAksi('[', 71, 'Simbol', 'ketuk'), HudAksi(']', 72, 'Simbol', 'ketuk'),
  HudAksi('\\', 73, 'Simbol', 'ketuk'), HudAksi(';', 74, 'Simbol', 'ketuk'),
  HudAksi("'", 75, 'Simbol', 'ketuk'), HudAksi('/', 76, 'Simbol', 'ketuk'),
  HudAksi(',', 55, 'Simbol', 'ketuk'), HudAksi('.', 56, 'Simbol', 'ketuk'),
  HudAksi('F1', 131, 'F-Key', 'ketuk'), HudAksi('F2', 132, 'F-Key', 'ketuk'),
  HudAksi('F3', 133, 'F-Key', 'ketuk'), HudAksi('F4', 134, 'F-Key', 'ketuk'),
  HudAksi('F5', 135, 'F-Key', 'ketuk'), HudAksi('F6', 136, 'F-Key', 'ketuk'),
  HudAksi('F7', 137, 'F-Key', 'ketuk'), HudAksi('F8', 138, 'F-Key', 'ketuk'),
  HudAksi('F9', 139, 'F-Key', 'ketuk'), HudAksi('F10', 140, 'F-Key', 'ketuk'),
  HudAksi('F11', 141, 'F-Key', 'ketuk'), HudAksi('F12', 142, 'F-Key', 'ketuk'),
];

/// Agen live per paket PC (Batch J) — spek PC host terdeteksi otomatis oleh
/// agen di mesin host (heartbeat mengisi `agen.spec` di server).
class UnitLive {
  final String planId;
  final String status;
  final String versi;
  final String host;
  final String terakhir;
  final Map<String, dynamic> spec;

  const UnitLive({
    this.planId = '',
    this.status = 'offline',
    this.versi = '',
    this.host = '',
    this.terakhir = '',
    this.spec = const {},
  });

  factory UnitLive.fromJson(Map<String, dynamic> j) => UnitLive(
        planId: '${j['planId'] ?? ''}',
        status: '${j['status'] ?? 'offline'}',
        versi: '${j['versi'] ?? ''}',
        host: '${j['host'] ?? ''}',
        terakhir: '${j['terakhir'] ?? ''}',
        spec: _petaAman(j['spec']),
      );

  bool get online => status == 'online';
  String get hostname => '${spec['hostname'] ?? ''}';
  String get cpu => '${spec['cpu'] ?? ''}';
  String get ram => '${spec['ram_total_gb'] ?? ''}';
  String get gpu => '${spec['gpu'] ?? ''}';
  String get osVersi => '${spec['os_versi'] ?? ''}';
}
