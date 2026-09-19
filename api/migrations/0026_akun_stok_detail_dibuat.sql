-- Migration 0026: Kolom detail dan dibuat pada tabel akun_stok
-- Supaya catatan lisensi/format akun dan stempel waktu pembuatan tersimpan aman.

ALTER TABLE akun_stok ADD COLUMN detail TEXT;
ALTER TABLE akun_stok ADD COLUMN dibuat TEXT;
