export async function infoHapusAkun(env, user) {
  const aktif = await env.DB.prepare("SELECT COUNT(*) n FROM orders WHERE user_id=? AND status IN ('pending','dibayar','provisioning','aktif')").bind(user.id).first();
  const sesi = await env.DB.prepare("SELECT COUNT(*) n FROM sesi WHERE user_id=? AND status NOT IN ('selesai','gagal')").bind(user.id).first();
  const topup = await env.DB.prepare("SELECT COUNT(*) n FROM topup WHERE user_id=? AND status IN ('menunggu','diperiksa')").bind(user.id).first();
  const penghalang = [];
  if (Number(user.saldo) > 0) penghalang.push('Saldo masih tersedia. Habiskan saldo atau hubungi CS untuk penyelesaian saldo.');
  if (aktif.n || sesi.n) penghalang.push('Selesaikan pesanan dan sesi PC yang masih aktif terlebih dahulu.');
  if (topup.n) penghalang.push('Masih ada top up yang menunggu penyelesaian. Hubungi CS.');
  return { perlu_otp: String(user.password || '').startsWith('sosial:'), boleh_hapus: !penghalang.length, penghalang, saldo: user.saldo || 0 };
}

/** Hanya dipanggil setelah konfirmasi eksplisit dan reautentikasi berhasil. */
export async function bersihkanAkun(env, user) {
  const id = user.id;
  const marker = `dihapus:${id}`;
  const labelTransfer = user.username ? `@${user.username}` : user.nama;
  const q = (sql, ...values) => env.DB.prepare(sql).bind(...values);
  await env.DB.batch([
    // Avatar OAuth yang sudah disalin ke folder privat layanan ikut masuk
    // antrean pemusnahan Cloudinary; URL penyedia lama tidak disentuh.
    q("INSERT OR IGNORE INTO media_hapus(url) SELECT foto FROM users WHERE id=? AND foto LIKE '%/xycloudstore/profil/sosial/%'", id),
    q('DELETE FROM follows WHERE ikut_id=? OR target_id=?', id, id),
    q('DELETE FROM dm WHERE dari_id=? OR ke_id=?', id, id),
    q('DELETE FROM simpan_post WHERE user_id=? OR post_id IN (SELECT id FROM forum_post WHERE user_id=?)', id, id),
    q('DELETE FROM forum_balasan_suka WHERE user_id=? OR balasan_id IN (SELECT id FROM forum_balasan WHERE user_id=? OR post_id IN (SELECT id FROM forum_post WHERE user_id=?))', id, id, id),
    q('UPDATE forum_balasan SET balas_ke=NULL WHERE balas_ke IN (SELECT id FROM forum_balasan WHERE user_id=?)', id),
    q('DELETE FROM forum_balasan WHERE user_id=? OR post_id IN (SELECT id FROM forum_post WHERE user_id=?)', id, id),
    q('DELETE FROM forum_suka WHERE user_id=? OR post_id IN (SELECT id FROM forum_post WHERE user_id=?)', id, id),
    q("DELETE FROM notifikasi WHERE user_id=? OR (ref_jenis='forum' AND ref_id IN (SELECT id FROM forum_post WHERE user_id=?))", id, id),
    q('DELETE FROM forum_post WHERE user_id=?', id),
    env.DB.prepare('UPDATE forum_post SET balasan=(SELECT COUNT(*) FROM forum_balasan b WHERE b.post_id=forum_post.id), suka=(SELECT COUNT(*) FROM forum_suka s WHERE s.post_id=forum_post.id)'),
    env.DB.prepare('UPDATE forum_balasan SET suka=(SELECT COUNT(*) FROM forum_balasan_suka s WHERE s.balasan_id=forum_balasan.id)'),
    q('DELETE FROM cs_messages WHERE user_id=? OR room=?', id, 'user:' + id),
    q('DELETE FROM favorit WHERE user_id=?', id),
    q('DELETE FROM ulasan WHERE user_id=?', id),
    q('DELETE FROM ulasan_pc WHERE user_id=?', id),
    q('DELETE FROM sesi WHERE user_id=?', id),
    q('DELETE FROM otp WHERE email=?', user.email),
    q('DELETE FROM social_identity WHERE user_id=?', id),
    q("UPDATE social_deletion_request SET user_id=NULL WHERE user_id=?", id),
    // referral_attribution memakai FK; hapus capability/audit personal sebelum user.
    q('DELETE FROM referral_attribution WHERE pengundang=? OR claimed_by=?', id, id),
    q("UPDATE users SET diundang_oleh=NULL WHERE diundang_oleh=?", id),
    q("UPDATE referral SET pengundang='dihapus' WHERE pengundang=?", id),
    // idx_referral_diundang_unique melarang semua akun diubah ke marker yang sama.
    q("UPDATE referral SET diundang=? WHERE diundang=?", marker, id),
    q("UPDATE voucher_pakai SET user_id='dihapus' WHERE user_id=?", id),
    q("UPDATE laporan SET pelapor='dihapus' WHERE pelapor=?", id),
    q('DELETE FROM galat WHERE user_id=?', id),
    q("UPDATE akun_stok SET user_id='dihapus' WHERE user_id=?", id),
    q("UPDATE orders SET user_id='dihapus',username=NULL,password=NULL,host=NULL WHERE user_id=?", id),
    // Catatan/notification transfer bisa berisi nama atau teks pribadi.
    q("DELETE FROM notifikasi WHERE ref_jenis='transfer' AND ref_id IN (SELECT id FROM transfer WHERE dari_id=? OR ke_id=?)", id, id),
    q("UPDATE transaksi SET judul='Transfer saldo' WHERE judul=? OR judul=?", `Transfer saldo ke ${labelTransfer}`, `Terima saldo dari ${labelTransfer}`),
    q('UPDATE transfer SET dari_id=CASE WHEN dari_id=? THEN ? ELSE dari_id END, ke_id=CASE WHEN ke_id=? THEN ? ELSE ke_id END, catatan=NULL WHERE dari_id=? OR ke_id=?', id, marker, id, marker, id, id),
    q("UPDATE transaksi SET user_id='dihapus' WHERE user_id=?", id),
    q("UPDATE topup SET user_id='dihapus',bukti=NULL WHERE user_id=?", id),
    q('DELETE FROM hud_preset_suka WHERE user_id=? OR preset_id IN (SELECT id FROM hud_preset WHERE user_id=?)', id, id),
    q('DELETE FROM hud_preset WHERE user_id=?', id),
    env.DB.prepare('UPDATE hud_preset SET suka=(SELECT COUNT(*) FROM hud_preset_suka s WHERE s.preset_id=hud_preset.id)'),
    q('DELETE FROM security_device_users WHERE user_id=?', id),
    q('DELETE FROM users WHERE id=?', id),
  ]);
}
