export const kanalPush = tipe => ['cs'].includes(tipe) ? 'xy_cs_v1' : ['order','sesi','wallet','akun'].includes(tipe) ? 'xy_orders_v1' : ['forum','balasan','suka','komunitas'].includes(tipe) ? 'xy_forum_v1' : ['promo','banner'].includes(tipe) ? 'xy_promo_v1' : 'xy_system_v1';
/**
 * ============================================================
 *  XyCloudStore - Push notification (OneSignal)
 *  Dipakai supaya notifikasi tetap masuk walau aplikasi ditutup.
 * ============================================================
 *  Catatan: push Android baru benar-benar terkirim setelah
 *  kredensial Firebase (FCM v1 Service Account JSON) diunggah
 *  ke dashboard OneSignal. Tanpa itu OneSignal menolak kiriman.
 */

const UNGU = '6C2BE2';

/**
 * Kirim push ke satu pengguna berdasarkan external_id (= id user di D1).
 * Aman dipanggil kapan saja; kalau kredensial belum ada, fungsi diam saja.
 *
 * `tombol` (opsional): deretan aksi yang tampil di notifikasi Android,
 * maksimal 3, bentuknya [{ id, text }] misalnya [{ id: 'buka', text: 'Buka' }].
 * Saat diketuk, aplikasi menerima data.tipe seperti biasa (id tombol juga
 * disertakan di data.aksi bila perangkat mendukungnya).
 */
export async function kirimPush(env, { userId, judul, pesan, data, url, tombol, gambar }) {
  if (!env.ONESIGNAL_APP_ID || !env.ONESIGNAL_API_KEY || !userId) {
    return { ok: false, alasan: 'kredensial OneSignal belum diatur' };
  }

  const body = {
    app_id: env.ONESIGNAL_APP_ID,
    include_aliases: { external_id: [String(userId)] },
    target_channel: 'push',
    headings: { en: judul, id: judul },
    contents: { en: pesan, id: pesan },
    android_accent_color: `FF${UNGU}`,
    existing_android_channel_id: kanalPush(data?.tipe),
    small_icon: 'ic_stat_onesignal_default',
    // Gambar besar di notifikasi (foto pengirim) supaya push chat/balasan
    // langsung terasa personal (permintaan Batch D, 2026-09-13).
    ...(gambar ? { image: String(gambar) } : {}),
    data: data || {},
    ...(Array.isArray(tombol) && tombol.length
      ? { buttons: tombol.slice(0, 3).map((t) => ({ id: String(t.id), text: String(t.text), icon: 'ic_stat_onesignal_default' })) }
      : {}),
    ...(url ? { url } : {}),
  };

  try {
    const r = await fetch('https://api.onesignal.com/notifications', {
      method: 'POST',
      headers: {
        Authorization: `Key ${env.ONESIGNAL_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(body),
    });
    const j = await r.json().catch(() => ({}));
    return r.ok && !j.errors ? { ok: true, id: j.id } : { ok: false, alasan: JSON.stringify(j.errors || j) };
  } catch (e) {
    return { ok: false, alasan: String(e) };
  }
}

/** Kirim push ke semua pelanggan yang berlangganan (dipakai untuk promo/banner). */
export async function siarkanPush(env, { judul, pesan, data }) {
  if (!env.ONESIGNAL_APP_ID || !env.ONESIGNAL_API_KEY) {
    return { ok: false, alasan: 'kredensial OneSignal belum diatur' };
  }
  try {
    const r = await fetch('https://api.onesignal.com/notifications', {
      method: 'POST',
      headers: {
        Authorization: `Key ${env.ONESIGNAL_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        app_id: env.ONESIGNAL_APP_ID,
        included_segments: ['Total Subscriptions'],
        headings: { en: judul, id: judul },
        contents: { en: pesan, id: pesan },
        android_accent_color: `FF${UNGU}`,
        // Ikon di-override di build ke logo XyCloudStore (tools/siapkan_ikon_push.py).
        small_icon: 'ic_stat_onesignal_default',
        existing_android_channel_id: kanalPush(data?.tipe),
        data: data || {},
      }),
    });
    const j = await r.json().catch(() => ({}));
    return r.ok && !j.errors ? { ok: true, id: j.id } : { ok: false, alasan: JSON.stringify(j.errors || j) };
  } catch (e) {
    return { ok: false, alasan: String(e) };
  }
}
