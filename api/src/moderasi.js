import { kataTerlarangDalam } from './kata.js';

/**
 * Moderasi teks ringan — filter kata kasar & pola spam link.
 * Dipakai di forum (post/balasan) dan bisa dipanggil dari jalur lain.
 * Bukan pengganti moderasi manual admin.
 */

/** Daftar dasar (ID + slang umum). Sengaja pendek; bisa ditambah lewat setelan nanti. */
const KATA_DASAR = [
  'anjing', 'bangsat', 'bego', 'goblok', 'tolol', 'kontol', 'memek', 'ngentot',
  'jancok', 'jancuk', 'asu', 'setan', 'tai', 'brengsek', 'kampret',
  'fuck', 'shit', 'bitch', 'asshole', 'dick', 'pussy', 'bastard',
  // SARA / ujaran kebencian (Batch E)
  'pki', 'teroris', 'jihadis', 'penistagama', 'antiagama', 'haramjadah',
  // pornografi (Batch E)
  'porno', 'porn', 'bokep', 'hentai', 'nsfw', 'coli', 'onani', 'masturbasi',
  'pelacur', 'lonte', 'jablay', 'sange', 'ngecrot', 'sperma', 'toket',
  'bugil', 'telanjang', 'onlyfans',
];

/** Domain yang sering dipakai spam phishing (bukan whitelist, hanya sinyal). */
const DOMAIN_CURIGA = [
  'bit.ly', 'tinyurl.com', 't.co', 'goo.gl', 'rb.gy', 'cutt.ly',
  'free-nitro', 'steamcommunity.ru', 'wa.me/spam',
];

function normalisasi(teks) {
  return String(teks || '')
    .toLowerCase()
    .normalize('NFKD')
    // hilangkan diakritik
    .replace(/[\u0300-\u036f]/g, '')
    // leetspeak ringan
    .replace(/0/g, 'o')
    .replace(/1/g, 'i')
    .replace(/3/g, 'e')
    .replace(/4/g, 'a')
    .replace(/@/g, 'a')
    .replace(/\$/g, 's')
    // buang pemisah di tengah kata: a.n.j.i.n.g / a n j i n g
    .replace(/[^a-z0-9\s]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function temukanKasar(teks) {
  const n = normalisasi(teks);
  if (!n) return [];
  const ketemu = [];
  for (const k of KATA_DASAR) {
    // word-ish boundary
    const re = new RegExp(`(?:^|\\s)${k}(?:$|\\s)`, 'i');
    if (re.test(` ${n} `) || n.includes(k)) {
      // hindari false positive sangat pendek di dalam kata lain kecuali exact
      if (k.length <= 3) {
        if (re.test(` ${n} `)) ketemu.push(k);
      } else if (n.includes(k)) {
        ketemu.push(k);
      }
    }
  }
  return [...new Set(ketemu)];
}

function hitungUrl(teks) {
  const s = String(teks || '');
  const http = s.match(/https?:\/\/[^\s]+/gi) || [];
  const www = s.match(/\bwww\.[^\s]+/gi) || [];
  return http.length + www.length;
}

function domainCuriga(teks) {
  const s = String(teks || '').toLowerCase();
  return DOMAIN_CURIGA.filter((d) => s.includes(d));
}

/**
 * @param {string} teks
 * @param {{ maksUrl?: number, wajibIsi?: boolean }} [opt]
 * @returns {{ ok: true } | { ok: false, alasan: string, kode: string }}
 */
export function periksaTeks(teks, opt = {}) {
  const maksUrl = opt.maksUrl ?? 3;
  const t = String(teks || '').trim();
  if (opt.wajibIsi && !t) {
    return { ok: false, alasan: 'Pesan kosong.', kode: 'KOSONG' };
  }
  if (!t) return { ok: true };

  const terlarang = kataTerlarangDalam(t);
  if (terlarang) {
    return {
      ok: false,
      alasan: 'Pesan mengandung kata yang tidak diperbolehkan. Mohon jaga bahasa di komunitas.',
      kode: 'KATA_KASAR',
    };
  }

  const kasar = temukanKasar(t);
  if (kasar.length) {
    return {
      ok: false,
      alasan: 'Pesan mengandung kata yang tidak diperbolehkan. Mohon jaga bahasa di komunitas.',
      kode: 'KATA_KASAR',
    };
  }

  const nUrl = hitungUrl(t);
  if (nUrl > maksUrl) {
    return {
      ok: false,
      alasan: `Terlalu banyak tautan (maks ${maksUrl}).`,
      kode: 'SPAM_LINK',
    };
  }

  const curiga = domainCuriga(t);
  if (curiga.length) {
    return {
      ok: false,
      alasan: 'Tautan tidak diizinkan atau terindikasi spam.',
      kode: 'LINK_CURIGA',
    };
  }

  // pola: banyak karakter berulang (SPAMMMMM)
  if (/(.)\1{7,}/.test(t)) {
    return { ok: false, alasan: 'Pola teks terindikasi spam.', kode: 'SPAM_POLA' };
  }

  return { ok: true };
}

/** Gabung beberapa field (judul + isi). */
export function periksaGabungan(...bagian) {
  return periksaTeks(bagian.filter(Boolean).join('\n'), { maksUrl: 3 });
}
