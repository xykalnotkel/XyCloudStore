/**
 * ============================================================
 *  XyCloudStore - Halaman legal
 * ============================================================
 *  Syarat dan Ketentuan serta Kebijakan Privasi.
 *  Dipakai dua tempat: dibuka lewat browser (/legal/...) dan
 *  ditampilkan di dalam aplikasi pada menu Tentang.
 */

const PEMBARUAN = '16 September 2026';

const SYARAT = [
  ['Penerimaan Ketentuan',
   'Dengan mendaftar dan memakai aplikasi XyCloudStore, kamu setuju dengan seluruh ketentuan di halaman ini. ' +
   'Kalau tidak setuju, mohon berhenti memakai layanan.'],
  ['Layanan yang Kami Sediakan',
   'XyCloudStore menyewakan komputer awan (cloud PC) per jam atau per hari, serta menjual akun digital ' +
   'seperti layanan streaming dan langganan permainan. Ketersediaan unit dan stok akun ditampilkan secara realtime di aplikasi.'],
  ['Akun Pengguna',
   'Satu orang cukup memakai satu akun. Kamu bertanggung jawab menjaga kerahasiaan password dan seluruh aktivitas ' +
   'yang terjadi pada akunmu. Beri tahu kami segera lewat menu chat admin kalau ada aktivitas mencurigakan.'],
  ['Saldo dan Pembayaran',
   'Saldo dapat diisi melalui QRIS/virtual account Pakasir atau kanal manual yang tampil di aplikasi. Pembayaran otomatis diverifikasi ulang ke penyedia sebelum saldo dikreditkan; pembayaran manual memerlukan pemeriksaan bukti. ' +
   'Saldo hanya bisa dipakai untuk membeli layanan di dalam aplikasi, tidak dapat dicairkan kembali menjadi uang tunai, ' +
   'dan tidak memiliki masa kedaluwarsa selama akun aktif.'],
  ['Pengembalian Dana',
   'Sewa PC yang gagal dinyalakan karena kesalahan kami akan dikembalikan penuh ke saldo. ' +
   'Akun digital bergaransi diganti bila bermasalah dalam masa garansi yang tertulis pada produk. ' +
   'Pengembalian tidak berlaku bila kerusakan disebabkan pelanggaran ketentuan penyedia layanan asli.'],
  ['Larangan',
   'Dilarang memakai layanan untuk aktivitas melanggar hukum Republik Indonesia, termasuk peretasan, penambangan ' +
   'kripto tanpa izin, penyebaran perangkat perusak, penipuan, atau pelanggaran hak cipta. ' +
   'Akun yang melanggar dapat dinonaktifkan tanpa pengembalian saldo.'],
  ['Batas Tanggung Jawab',
   'Kami berusaha menjaga layanan tetap berjalan, namun tidak menjamin bebas gangguan sepenuhnya. ' +
   'Tanggung jawab kami maksimal sebesar nilai transaksi yang bersangkutan.'],
  ['Perubahan Ketentuan',
   'Ketentuan dapat diperbarui sewaktu-waktu. Perubahan penting akan diberitahukan lewat aplikasi atau email.'],
  ['Kontak',
   'Pertanyaan seputar ketentuan ini bisa disampaikan lewat menu Chat Admin di dalam aplikasi.'],
];

const PRIVASI = [
  ['Data yang Kami Kumpulkan',
   'Nama, alamat email, nomor WhatsApp, dan foto profil bila kamu masuk memakai Google atau Facebook. ' +
   'ID akun Google/Facebook disimpan sebagai HMAC app-scoped yang tidak dapat dibalik, bukan ID mentah. ' +
   'Kami juga menyimpan riwayat pesanan, transaksi saldo, bukti transfer, ulasan, dan percakapan dengan admin.'],
  ['Perangkat dan Anti-Penyalahgunaan',
   'Identitas perangkat Android yang dipseudonimkan atau identitas instalasi/browser, model perangkat, serta hash alamat jaringan dipakai untuk membatasi pendaftaran dan OTP. Untuk referral, kami mencatat hash tiket, tahap klik/unduh/buka, varian APK, dan waktu pemasangan paket Android guna memastikan bonus berasal dari pemasangan baru; tiket mentah tidak disimpan di basis data. Kami tidak mengumpulkan IMEI atau advertising ID untuk fitur ini. Penghitung pendaftaran dapat tetap disimpan tanpa email setelah akun dihapus untuk mencegah pendaftaran berulang. Catatan kejadian keamanan dan atribusi gagal dibersihkan sesuai masa audit yang berlaku.'],
  ['Cara Kami Memakainya',
   'Data dipakai untuk memproses pesanan, memverifikasi pembayaran, mengirim kredensial akun, menjawab pertanyaanmu, ' +
   'serta mengirim pemberitahuan penting mengenai pesanan. Kami tidak menjual data pribadi kepada siapa pun.'],
  ['Moderasi Konten Berbantuan AI',
   'Teks yang sengaja kamu publikasikan, seperti diskusi, komentar, ulasan, profil, atau preset HUD publik, dapat diperiksa oleh filter lokal dan layanan AI Grok melalui OpenRouter atau model keselamatan melalui GroqCloud bila provider tersebut dipilih dan Zero Data Retention telah dikonfirmasi, jika fitur diaktifkan. Pesan privat dan Chat Admin tidak dikirim untuk klasifikasi AI. Permintaan upstream mewajibkan zero-data-retention dan menolak penyedia yang mengumpulkan data. Basis data kami hanya menyimpan HMAC konten dan metadata verdict maksimal 90 hari, bukan prompt, teks, atau respons mentah. AI tidak menjatuhkan sanksi akun; keputusan dapat dilaporkan atau ditinjau moderator.'],
  ['Livestream dan Rekaman Gameplay',
   'Jika kamu memilih XyCloud Live, OBS pada PC rental menangkap Game Capture dan audio game; mic hanya ditangkap setelah persetujuan eksplisit. Kami memproses judul, game, waktu siaran, status scene/ingest, congestion, frame terlewat, jumlah penonton, dukungan, serta rekaman gameplay maksimal 30 hari untuk player, diagnostik, sengketa, dan moderasi. Stream key diambil agen langsung dari penyedia dan tidak disimpan di D1, command, ACK, atau log aplikasi. Pengikut yang mengizinkan dapat menerima notifikasi saat kreator mulai live.'],
  ['Layanan Pihak Ketiga',
   'Kami memakai Cloudflare (server, basis data, dan Stream untuk livestream/rekaman), Resend (pengiriman email), OneSignal (notifikasi), ' +
   'Cloudinary (penyimpanan gambar), Pakasir (pembayaran), Google Sign-In, Facebook Login (login opsional), serta OpenRouter/xAI atau GroqCloud (moderasi teks publik bila dipilih dan diaktifkan). ' +
   'Masing-masing hanya menerima data seperlunya untuk menjalankan fungsinya. Token akses sosial tidak disimpan oleh kami.'],
  ['Keamanan',
   'Password disimpan dalam bentuk hash SHA-256 dengan garam acak, tidak pernah dalam bentuk teks biasa. ' +
   'Komunikasi API memakai HTTPS. Streaming memakai protokol host tersendiri. Token login dan koleksi stiker disimpan di penyimpanan terenkripsi pada perangkatmu.'],
  ['Penyimpanan dan Penghapusan Data',
   'Data akun disimpan selama akun aktif; pesan CS yang lebih tua dari tujuh hari dihapus. Penghapusan akun dapat diminta melalui menu Profil > Pengaturan > Hapus Akun setelah saldo dan sesi aktif diselesaikan. Data pembukuan dianonimkan. ' +
   'Pengguna Facebook juga dapat menghapus XyCloudStore dari menu Apps and Websites di Facebook; permintaan bertanda tangan Meta diproses oleh callback https://api.xycloud.my.id/api/auth/facebook/data-deletion dan memberi kode/status konfirmasi. Status konfirmasi tanpa ID Facebook mentah disimpan maksimal 180 hari. ' +
   'Salinan yang sudah disimpan penerima dan retensi cadangan penyedia tidak dapat dihapus seketika melalui aplikasi.'],
  ['Hak Kamu',
   'Kamu berhak melihat, memperbaiki, memutus akun sosial, atau meminta penghapusan data pribadimu, serta menolak menerima notifikasi ' +
   'lewat pengaturan perangkat. Hubungi Chat Admin bila permintaan tertunda karena saldo atau sesi aktif.'],
  ['Anak di Bawah Umur',
   'Layanan ditujukan untuk pengguna berusia 13 tahun ke atas. Pengguna di bawah 17 tahun sebaiknya memakai ' +
   'layanan dengan pendampingan orang tua atau wali.'],
  ['Perubahan Kebijakan',
   'Kebijakan ini dapat diperbarui. Tanggal pembaruan terakhir selalu tertera di bagian atas halaman.'],
];

const LIVE = [
  ['Kelayakan dan Persetujuan',
   'Program kreator XyCloud Live hanya untuk pemilik akun berusia sekurang-kurangnya 18 tahun yang disetujui admin. Setiap siaran memerlukan sesi PC rental aktif, persetujuan perekaman, pengakuan scene aman, dan versi ketentuan siaran yang berlaku. Persetujuan kreator dapat ditolak atau ditangguhkan dengan alasan tertulis.'],
  ['Ruang Lingkup Tangkapan dan Mic',
   'Agen hanya diizinkan memakai OBS 30.1 atau lebih baru dengan Game Capture pada scene XyCloudLive. Audio game ditangkap terisolasi dari source Game Capture; Display Capture, Window Capture, Browser Capture, source asing, serta perangkat audio global dilarang dan memicu penghentian fail-closed. Mic mati secara default dan hanya boleh hidup setelah persetujuan eksplisit apabila source XyCloudMic aman sudah disiapkan operator. Kreator tetap wajib menutup notifikasi, kredensial, percakapan pribadi, dan data sensitif sebelum tayang.'],
  ['Konten, Hak, dan Moderasi',
   'Kreator hanya boleh menyiarkan game dan materi yang secara hukum boleh digunakan. Dilarang menampilkan kekerasan seksual, eksploitasi anak, perjudian ilegal, kebencian, doxxing, penipuan, pelanggaran hak cipta, cheat berbahaya, atau aktivitas melawan hukum. Judul, game, dan pesan publik diperiksa filter/moderasi; laporan penonton dapat ditinjau manusia. Sistem dapat langsung memutus ingest untuk melindungi pengguna atau platform.'],
  ['Player, Rekaman, dan Retensi',
   'Player diterbitkan melalui Cloudflare Stream dan memerlukan tiket pengguna XyCloudStore yang singkat serta terlacak. Kunjungan tautan publik hanya menampilkan teaser. Siaran dapat direkam untuk replay, keamanan, sengketa, dan moderasi lalu dihapus maksimal 30 hari setelah dibuat, kecuali salinan wajib dipertahankan lebih lama karena proses hukum atau investigasi. Jumlah penonton dan diagnostik teknis dicatat secara terbatas.'],
  ['Dukungan dan Bagian Kreator',
   'Penonton dapat mengirim dukungan dari saldo aplikasi dalam batas yang ditampilkan. Biaya platform dan bagian bersih kreator dihitung serta ditampilkan sebelum/di ledger; nilai awal biaya platform adalah 20 persen dan dapat berubah untuk siaran berikutnya setelah pemberitahuan. Kreator tidak boleh mendukung akun sendiri, mengatur transaksi palsu, membeli engagement, atau memaksa penonton membayar. Dukungan bukan investasi, taruhan, atau pembelian kepemilikan.'],
  ['Hold, Anti-Fraud, dan Payout',
   'Bagian kreator ditahan selama tujuh hari sebelum tersedia untuk menampung pemeriksaan fraud/refund. Payout hanya dapat diminta setelah metode penerima diverifikasi admin dan minimum payout terpenuhi. Permintaan direservasi, ditinjau pemilik, lalu ditandai dibayar hanya setelah transfer eksternal berhasil. Kreator bertanggung jawab atas pajak dan keakuratan identitas penerima sesuai hukum yang berlaku. Jangan mengirim nomor rekening lengkap melalui forum atau profil publik.'],
  ['Pembatalan dan Pengembalian Dukungan',
   'Dukungan yang sah pada umumnya final sebagai transfer saldo. Admin dapat membalik dukungan yang masih held/available bila terjadi transaksi duplikat, pengambilalihan akun, fraud, kesalahan sistem, atau pelanggaran; saldo penonton dikembalikan dan earning kreator dibatalkan dengan alasan audit. Earning yang sudah masuk payout memerlukan pemeriksaan manual dan tidak dibalik otomatis.'],
  ['Ketersediaan dan Batas Biaya',
   'Livestream adalah fitur rollout berbiaya dan dapat dimatikan, dibatasi durasi, dibatasi jumlah siaran bersamaan, atau dihentikan sewaktu-waktu untuk keamanan, pemeliharaan, dan kontrol biaya. Gangguan internet, OBS, PC rental, atau penyedia upstream dapat menurunkan kualitas atau mengakhiri siaran. Status diagnostik di aplikasi bersifat bantuan teknis, bukan jaminan kualitas tanpa putus.'],
  ['Notifikasi Pengikut dan Berbagi',
   'Saat siaran berhasil aktif, pengikut yang mengizinkan notifikasi XyCloud Live dapat menerima pemberitahuan. Kreator boleh membagikan tautan teaser resmi, tetapi dilarang membagikan stream key, credential OBS, tiket player, atau cara melewati autentikasi. Preferensi notifikasi dapat dimatikan dari aplikasi atau pengaturan channel Android.'],
  ['Pengakhiran Program dan Kontak',
   'Sesi rental berakhir, akun dibekukan, pelanggaran scene/konten, atau keputusan admin akan mengakhiri siaran dan menonaktifkan Live Input. Kewajiban payout yang sah tetap diselesaikan sesuai ledger, sedangkan transaksi bermasalah dapat ditahan selama investigasi. Banding dan pertanyaan disampaikan melalui Chat Admin dengan kode siaran, tanpa mengirim rahasia akun atau data rekening lengkap.'],
];

const REFUND = [
  ['Ringkasan',
   'Kebijakan ini menjelaskan kapan dan bagaimana pengembalian dana (refund) diberikan untuk sewa PC cloud, ' +
   'pembelian akun digital, dan pengisian saldo di XyCloudStore. Prinsip kami sederhana: kalau kesalahan ada ' +
   'di pihak kami, uangmu kembali.'],
  ['Sewa PC Cloud',
   'Bila unit gagal dinyalakan, tidak bisa diakses, atau spesifikasi tidak sesuai yang tertera karena kesalahan kami, ' +
   'biaya sewa dikembalikan penuh ke saldo. Bila sesi terputus di tengah karena gangguan server kami lebih dari ' +
   '15 menit, sisa waktu yang belum terpakai dikembalikan secara proporsional. Pengembalian tidak berlaku untuk ' +
   'gangguan akibat koneksi internet pengguna, perangkat pengguna, atau pelanggaran aturan pemakaian.'],
  ['Akun Digital dan Langganan',
   'Akun bergaransi diganti atau dananya dikembalikan bila bermasalah dalam masa garansi yang tertulis pada halaman ' +
   'produk (misalnya akun tidak bisa masuk, terkena banned tanpa pelanggaran dari pengguna, atau masa aktif lebih ' +
   'pendek dari yang dijanjikan). Garansi hangus bila pengguna mengubah data akun yang dilarang (email pemulihan, ' +
   'kata sandi bawaan penjual) atau melanggar ketentuan penyedia layanan asli.'],
  ['Pengisian Saldo',
   'Top up yang sudah berhasil dibayar tidak dapat dicairkan kembali menjadi uang tunai, sesuai ketentuan layanan. ' +
   'Bila kamu salah memasukkan nominal atau terjadi pemotongan ganda pada pembayaran otomatis (QRIS/e-wallet/VA), ' +
   'hubungi Chat Admin maksimal 3x24 jam dengan bukti mutasi — selisihnya kami kembalikan ke saldo setelah diverifikasi. ' +
   'Top up manual yang ditolak admin karena bukti tidak valid akan ditandai beserta alasannya.'],
  ['Cara Mengajukan',
   'Buka aplikasi → menu Chat Admin → jelaskan kendala dengan menyertakan kode pesanan atau kode top up (diawali t_ atau o_). ' +
   'Tim kami memverifikasi ke sistem dan penyedia pembayaran. Pengajuan juga bisa lewat email resmi yang tercantum di halaman ini.'],
  ['Lama Proses',
   'Verifikasi awal maksimal 1x24 jam pada hari kerja. Refund ke saldo diproses seketika setelah disetujui. ' +
   'Bila refund harus keluar melalui penyedia pembayaran (kasus khusus), proses mengikuti ketentuan penyedia, ' +
   'umumnya 2-7 hari kerja.'],
  ['Yang Tidak Termasuk',
   'Refund tidak diberikan untuk: perubahan pikiran setelah layanan dipakai normal, pelanggaran aturan (termasuk ' +
   'pemakaian untuk aktivitas ilegal), akun yang dinonaktifkan karena pelanggaran, voucher/promo yang sudah dipakai, ' +
   'dan kendala akibat force majeure di luar kendali kami yang diberitahukan melalui aplikasi.'],
  ['Dukungan XyCloud Live',
   'Dukungan saldo kepada kreator pada umumnya final. Pengembalian hanya dapat dilakukan sebelum earning masuk payout bila ada duplikasi, pengambilalihan akun, fraud, kegagalan sistem, atau pelanggaran yang terverifikasi. Admin mencatat alasan; saldo penonton dikembalikan dan earning kreator dibatalkan secara atomik. Gangguan player atau kualitas jaringan tanpa pemotongan saldo tidak menghasilkan refund dukungan.'],
  ['Kontak',
   'Pertanyaan soal pengembalian dana bisa disampaikan lewat Chat Admin di aplikasi. Keputusan refund selalu ' +
   'disertai alasan tertulis yang bisa kamu lihat di riwayat transaksi.'],
];

/** Daftar lisensi pihak ketiga yang dipakai server dan aplikasi. */
export const LISENSI = [
  ['Flutter dan Dart', 'Google', 'BSD-3-Clause'],
  ['provider', 'Remi Rousselet', 'MIT'],
  ['http', 'Dart team', 'BSD-3-Clause'],
  ['web_socket_channel', 'Dart team', 'BSD-3-Clause'],
  ['shared_preferences', 'Flutter team', 'BSD-3-Clause'],
  ['flutter_secure_storage', 'German Saprykin', 'BSD-3-Clause'],
  ['google_fonts', 'Flutter team', 'Apache-2.0'],
  ['Plus Jakarta Sans', 'Tokotype', 'SIL Open Font License 1.1'],
  ['intl', 'Dart team', 'BSD-3-Clause'],
  ['image_picker', 'Flutter team', 'Apache-2.0'],
  ['url_launcher', 'Flutter team', 'BSD-3-Clause'],
  ['google_sign_in', 'Flutter team', 'Apache-2.0'],
  ['flutter_web_auth_2', 'Linus Unnebäck', 'MIT'],
  ['onesignal_flutter', 'OneSignal', 'MIT'],
  ['package_info_plus', 'Flutter Community', 'BSD-3-Clause'],
  ['Cloudflare Workers, D1, Durable Objects', 'Cloudflare', 'layanan berlangganan'],
  ['Resend', 'Resend Inc.', 'layanan berlangganan'],
  ['Cloudinary', 'Cloudinary Ltd.', 'layanan berlangganan'],
  ['Pakasir', 'Pakasir', 'layanan pembayaran'],
  ['OpenRouter dan Grok', 'OpenRouter / xAI', 'layanan AI opsional'],
  ['GroqCloud', 'Groq, Inc.', 'layanan inferensi AI opsional dengan ZDR'],
  ['Material Symbols', 'Google', 'Apache-2.0'],
];

/** Halaman HTML bertema ungu untuk dibuka di browser. */
export function halamanLegal(jenis) {
  const judul = jenis === 'privasi' ? 'Kebijakan Privasi'
    : jenis === 'refund' ? 'Kebijakan Pengembalian Dana'
    : jenis === 'live' ? 'Ketentuan Kreator XyCloud Live'
    : 'Syarat dan Ketentuan';
  const isi = jenis === 'privasi' ? PRIVASI : jenis === 'refund' ? REFUND : jenis === 'live' ? LIVE : SYARAT;

  const bagian = isi
    .map(
      ([j, t], i) => `<section>
        <h2><span>${i + 1}</span>${j}</h2>
        <p>${t}</p>
      </section>`
    )
    .join('');

  const lisensi = jenis !== 'syarat'
    ? ''
    : `<section>
        <h2><span>${isi.length + 1}</span>Lisensi Pihak Ketiga</h2>
        <p>Aplikasi ini dibangun memakai perangkat lunak sumber terbuka berikut:</p>
        <table>
          <thead><tr><th>Komponen</th><th>Pembuat</th><th>Lisensi</th></tr></thead>
          <tbody>${LISENSI.map(([a, b, c]) => `<tr><td>${a}</td><td>${b}</td><td>${c}</td></tr>`).join('')}</tbody>
        </table>
      </section>`;

  return `<!DOCTYPE html><html lang="id"><head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>${judul} - XyCloudStore</title>
<style>
  *{box-sizing:border-box}
  body{margin:0;background:#FAF8FF;color:#1A1033;
    font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;line-height:1.7}
  header{background:linear-gradient(135deg,#6C2BE2,#4A12B8);color:#fff;padding:46px 22px 40px;text-align:center}
  header img{height:34px;background:#fff;padding:9px 15px;border-radius:12px}
  header h1{margin:20px 0 6px;font-size:26px;letter-spacing:-.8px}
  header p{margin:0;opacity:.75;font-size:13px}
  main{max-width:760px;margin:-22px auto 60px;padding:0 18px}
  .kartu{background:#fff;border:1px solid #EAE3F7;border-radius:22px;padding:28px 26px;
    box-shadow:0 14px 40px rgba(26,16,51,.07)}
  section{padding:16px 0;border-bottom:1px solid #F4F0FD}
  section:last-child{border-bottom:0}
  h2{font-size:16.5px;margin:0 0 8px;display:flex;align-items:center;gap:11px;letter-spacing:-.3px}
  h2 span{background:#F2ECFF;color:#6C2BE2;width:27px;height:27px;border-radius:50%;
    display:inline-flex;align-items:center;justify-content:center;font-size:12.5px;font-weight:800;flex:none}
  p{margin:0;color:#453B5E;font-size:14px}
  table{width:100%;border-collapse:collapse;margin-top:14px;font-size:13px}
  th,td{text-align:left;padding:9px 10px;border-bottom:1px solid #F4F0FD}
  th{color:#7C7391;font-weight:700;font-size:11.5px;text-transform:uppercase;letter-spacing:.6px}
  footer{text-align:center;color:#7C7391;font-size:12px;padding:0 18px 44px}
  a{color:#6C2BE2}
  .tautan{text-align:center;margin-top:22px}
  .tautan a{display:inline-block;margin:0 8px;font-weight:700;font-size:13.5px;text-decoration:none}
</style></head>
<body>
  <header>
    <img src="/brand/logo.png" alt="XyCloudStore">
    <h1>${judul}</h1>
    <p>Pembaruan terakhir: ${PEMBARUAN}</p>
  </header>
  <main>
    <div class="kartu">${bagian}${lisensi}</div>
    <div class="tautan">
      <a href="/legal/syarat">Syarat dan Ketentuan</a>
      <a href="/legal/privasi">Kebijakan Privasi</a>
      <a href="/legal/refund">Pengembalian Dana</a>
      <a href="/legal/live">Ketentuan XyCloud Live</a>
    </div>
  </main>
  <footer>XyCloudStore &middot; Sewa PC Cloud dan Akun Digital &middot; xycloud.my.id</footer>
</body></html>`;
}

/** Versi data mentah untuk ditampilkan di dalam aplikasi. */
export function isiLegal(jenis) {
  const isi = jenis === 'privasi' ? PRIVASI : jenis === 'refund' ? REFUND : jenis === 'live' ? LIVE : SYARAT;
  return {
    judul: jenis === 'privasi' ? 'Kebijakan Privasi'
      : jenis === 'refund' ? 'Kebijakan Pengembalian Dana'
      : jenis === 'live' ? 'Ketentuan Kreator XyCloud Live'
      : 'Syarat dan Ketentuan',
    pembaruan: PEMBARUAN,
    bagian: isi.map(([judul, teks]) => ({ judul, teks })),
    lisensi: LISENSI.map(([nama, pembuat, lisensi]) => ({ nama, pembuat, lisensi })),
  };
}
