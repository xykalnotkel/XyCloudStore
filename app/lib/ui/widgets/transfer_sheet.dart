import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import 'bingkai_profil.dart';
import '../../data/api_client.dart';
import '../../providers/app_state.dart';
import 'common.dart';

/// ============================================================
///  Kirim Saldo antar pengguna (Batch I)
/// ============================================================
///  Alur: cari penerima (@username/email) → nominal → PIN transfer.
///  Bila PIN belum dipasang (HTTP 428), panel pemasangan PIN muncul
///  di tempat: konfirmasi password, atau kode email untuk akun sosial.
Future<void> bukaTransfer(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _SheetTransfer(),
  );
}

/// Panel pasang/ganti PIN transfer — juga dipakai dari layar Keamanan.
Future<void> bukaSetPin(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _PanelPin(mandiri: true),
  );
}

class _SheetTransfer extends StatefulWidget {
  const _SheetTransfer();

  @override
  State<_SheetTransfer> createState() => _SheetTransferState();
}

class _SheetTransferState extends State<_SheetTransfer> {
  final _q = TextEditingController();
  final _nominal = TextEditingController();
  final _pin = TextEditingController();
  final _catatan = TextEditingController();
  Timer? _debounce;

  Map<String, dynamic>? _target;
  bool _cariSibuk = false;
  String? _cariGalat;
  bool _kirimSibuk = false;
  String? _galat;
  bool _perluPin = false; // 428 → tampilkan panel PIN
  Map<String, dynamic>? _hasil;

  @override
  void dispose() {
    _q.dispose();
    _nominal.dispose();
    _pin.dispose();
    _catatan.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _jadwalCari() {
    _debounce?.cancel();
    final q = _q.text.trim();
    if (q.length < 3) {
      setState(() {
        _target = null;
        _cariGalat = null;
      });
      return;
    }
    setState(() {
      _cariSibuk = true;
      _cariGalat = null;
    });
    _debounce = Timer(const Duration(milliseconds: 600), () async {
      try {
        final t = await context.read<AppState>().cariPenerimaTransfer(q);
        if (!mounted) return;
        setState(() {
          _target = t;
          _cariSibuk = false;
        });
      } on ApiException catch (e) {
        if (!mounted) return;
        setState(() {
          _target = null;
          _cariSibuk = false;
          _cariGalat = e.pesan;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _target = null;
          _cariSibuk = false;
        });
      }
    });
  }

  int get _nominalInt {
    final angka = _nominal.text.replaceAll(RegExp(r'[^0-9]'), '');
    return angka.isEmpty ? 0 : int.parse(angka);
  }

  Future<void> _kirim() async {
    final target = _target;
    if (target == null) {
      setState(() => _galat = 'Pilih penerima dulu.');
      return;
    }
    final n = _nominalInt;
    if (n < 10000) {
      setState(() => _galat = 'Transfer minimal Rp10.000.');
      return;
    }
    if (_pin.text.length != 6) {
      setState(() => _galat = 'Masukkan PIN transfer 6 digit.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _kirimSibuk = true;
      _galat = null;
    });
    try {
      final hasil = await context.read<AppState>().kirimTransfer(
            ke: '${target['id']}',
            nominal: n,
            pin: _pin.text,
            catatan: _catatan.text.trim(),
          );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() {
        _kirimSibuk = false;
        _hasil = hasil;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _kirimSibuk = false;
        if (e.status == 428) {
          _perluPin = true;
          _galat = null;
        } else {
          _galat = e.pesan;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _kirimSibuk = false;
        _galat = 'Tidak bisa terhubung ke server. Coba lagi.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = XyTheme.of(context);
    final u = context.watch<AppState>().user;
    final kb = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: kb),
      child: Container(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * .88),
        margin: const EdgeInsets.fromLTRB(10, 18, 10, 10),
        decoration: BoxDecoration(
          color: t.surfaceHigh,
          borderRadius: BorderRadius.circular(XyRadius.xxl),
          border: Border.all(color: t.line),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 10),
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: t.line,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          Flexible(
            child: _hasil != null
                ? _sukses(_hasil!)
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
                    child: _perluPin
                        ? _PanelPin(
                            mandiri: false,
                            setelahTerpasang: () {
                              if (mounted) {
                                setState(() => _perluPin = false);
                              }
                            },
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: XyTheme.violet.withOpacity(.14),
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                  child: const Icon(
                                      Icons.swap_horiz_rounded,
                                      color: XyTheme.violet,
                                      size: 22),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Kirim Saldo',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 16.5,
                                              letterSpacing: -.3)),
                                      SizedBox(height: 2),
                                      Text(
                                          'Ke sesama pengguna XyCloud — instan, tanpa admin.',
                                          style: TextStyle(
                                              fontSize: 11.5,
                                              color: XyTheme.muted)),
                                    ],
                                  ),
                                ),
                              ]),
                              const SizedBox(height: 18),
                              const XyLabel('Penerima (@username atau email)'),
                              TextField(
                                controller: _q,
                                onChanged: (_) => _jadwalCari(),
                                autocorrect: false,
                                decoration: InputDecoration(
                                  hintText: 'contoh: @budi atau budi@email.com',
                                  prefixIcon:
                                      const Icon(Icons.person_search_rounded),
                                  suffixIcon: _cariSibuk
                                      ? const Padding(
                                          padding: EdgeInsets.all(14),
                                          child: SizedBox(
                                              width: 16,
                                              height: 16,
                                              child:
                                                  CircularProgressIndicator(
                                                      strokeWidth: 2)),
                                        )
                                      : null,
                                ),
                              ),
                              if (_cariGalat != null) ...[
                                const SizedBox(height: 8),
                                Text(_cariGalat!,
                                    style: const TextStyle(
                                        color: XyTheme.dangerBright,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600)),
                              ],
                              if (_target != null) ...[
                                const SizedBox(height: 12),
                                XyCard(
                                  padding: const EdgeInsets.all(13),
                                  child: Row(children: [
                                    AvatarBingkai(
                                      bingkai: _target!['bingkai'] as String?,
                                      size: 42,
                                      child: _AvatarKecil(
                                          _target!['foto'] as String?,
                                          '${_target!['nama'] ?? ''}'),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text('${_target!['nama'] ?? ''}',
                                              maxLines: 1,
                                              overflow:
                                                  TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 14)),
                                          if ((_target!['username'] ?? '')
                                              .toString()
                                              .isNotEmpty)
                                            Text(
                                                '@${_target!['username']}',
                                                style: TextStyle(
                                                    color: t.accent,
                                                    fontWeight:
                                                        FontWeight.w700,
                                                    fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                    Icon(Icons.check_circle_rounded,
                                        color: XyTheme.okBright, size: 20),
                                  ]),
                                ),
                              ],
                              const SizedBox(height: 18),
                              const XyLabel('Nominal'),
                              TextField(
                                controller: _nominal,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  TextInputFormatter.withFunction((v, n) {
                                    final angka =
                                        n.text.replaceAll(RegExp(r'[^0-9]'), '');
                                    if (angka.isEmpty) {
                                      return n.copyWith(text: '');
                                    }
                                    final nilai = int.parse(angka);
                                    return n.copyWith(
                                      text: rupiah(nilai),
                                      selection: TextSelection.collapsed(
                                          offset:
                                              rupiah(nilai).length),
                                    );
                                  }),
                                ],
                                decoration: const InputDecoration(
                                  hintText: 'Rp0',
                                  prefixIcon:
                                      Icon(Icons.payments_outlined),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(spacing: 8, runSpacing: 8, children: [
                                for (final n in [10000, 25000, 50000, 100000, 500000])
                                  Pressable(
                                    onTap: () => setState(() =>
                                        _nominal.text = rupiah(n)),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 13, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: _nominalInt == n
                                            ? XyTheme.violet.withOpacity(.16)
                                            : t.lineSoft,
                                        borderRadius:
                                            BorderRadius.circular(XyRadius.pill),
                                        border: Border.all(
                                          color: _nominalInt == n
                                              ? XyTheme.violet
                                              : t.line,
                                        ),
                                      ),
                                      child: Text(
                                        n >= 1000000
                                            ? 'Rp${n ~/ 1000000}jt'
                                            : 'Rp${n ~/ 1000}rb',
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: _nominalInt == n
                                                ? XyTheme.violet
                                                : t.inkSoft),
                                      ),
                                    ),
                                  ),
                              ]),
                              if (u != null) ...[
                                const SizedBox(height: 8),
                                Text('Saldo kamu: ${rupiah(u.saldo)}',
                                    style: TextStyle(
                                        fontSize: 11.5, color: t.muted)),
                              ],
                              const SizedBox(height: 18),
                              const XyLabel('PIN Transfer (6 digit)'),
                              TextField(
                                controller: _pin,
                                obscureText: true,
                                keyboardType: TextInputType.number,
                                maxLength: 6,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                decoration: const InputDecoration(
                                  counterText: '',
                                  hintText: '••••••',
                                  prefixIcon: Icon(Icons.pin_rounded),
                                ),
                              ),
                              if (u != null && !u.pinTransferAktif) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'Belum punya PIN? Akan muncul panduan memasangnya saat mengirim.',
                                  style: TextStyle(
                                      fontSize: 11, color: t.muted),
                                ),
                              ],
                              const SizedBox(height: 14),
                              const XyLabel('Catatan (opsional)'),
                              TextField(
                                controller: _catatan,
                                maxLength: 120,
                                decoration: const InputDecoration(
                                  hintText: 'contoh: traktir kopi kemarin',
                                  counterText: '',
                                ),
                              ),
                              if (_galat != null) ...[
                                const SizedBox(height: 10),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: XyTheme.danger.withOpacity(.08),
                                    borderRadius:
                                        BorderRadius.circular(XyRadius.sm),
                                    border: Border.all(
                                        color:
                                            XyTheme.danger.withOpacity(.25)),
                                  ),
                                  child: Text(_galat!,
                                      style: const TextStyle(
                                          color: XyTheme.dangerBright,
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600)),
                                ),
                              ],
                              const SizedBox(height: 16),
                              GradientButton(
                                label: _nominalInt >= 10000 && _target != null
                                    ? 'Kirim ${rupiah(_nominalInt)}'
                                    : 'Kirim Saldo',
                                icon: Icons.send_rounded,
                                loading: _kirimSibuk,
                                onPressed: _kirimSibuk ? null : _kirim,
                              ),
                              const SizedBox(height: 10),
                              Row(children: [
                                Icon(Icons.shield_outlined,
                                    size: 14, color: t.muted),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Min Rp10.000 · maks Rp5.000.000/transaksi · Rp10.000.000/hari. Transfer tidak bisa dibatalkan.',
                                    style: TextStyle(
                                        fontSize: 10.5,
                                        height: 1.4,
                                        color: t.muted),
                                  ),
                                ),
                              ]),
                            ],
                          ),
                  ),
          ),
        ]),
      ),
    );
  }

  Widget _sukses(Map<String, dynamic> h) {
    final t = XyTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 30),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 74,
          height: 74,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: XyTheme.okBright.withOpacity(.12),
            border: Border.all(color: XyTheme.okBright.withOpacity(.4)),
          ),
          child: const Icon(Icons.check_rounded,
              size: 40, color: XyTheme.okBright),
        ),
        const SizedBox(height: 16),
        const Text('Transfer berhasil! 🎉',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        const SizedBox(height: 8),
        Text(
          '${rupiah(_nominalInt)} dikirim ke ${h['ke'] ?? 'penerima'}.',
          textAlign: TextAlign.center,
          style: TextStyle(color: t.muted, fontSize: 13, height: 1.5),
        ),
        const SizedBox(height: 20),
        GradientButton(
          label: 'Tutup',
          onPressed: () => Navigator.pop(context),
        ),
      ]),
    );
  }
}

class _AvatarKecil extends StatelessWidget {
  const _AvatarKecil(this.foto, this.nama);
  final String? foto;
  final String nama;

  @override
  Widget build(BuildContext context) {
    if ((foto ?? '').isNotEmpty) {
      return AppImage(foto!);
    }
    return Container(
      color: XyTheme.of(context).primarySoft,
      alignment: Alignment.center,
      child: Text(
        nama.isEmpty ? '?' : nama[0].toUpperCase(),
        style: TextStyle(
            fontWeight: FontWeight.w800, color: XyTheme.of(context).accent),
      ),
    );
  }
}

/// Panel pasang/ganti PIN transfer.
/// `mandiri=true` → dibuka dari Keamanan (punya judul & tombol tutup sendiri).
class _PanelPin extends StatefulWidget {
  const _PanelPin({required this.mandiri, this.setelahTerpasang});
  final bool mandiri;
  final VoidCallback? setelahTerpasang;

  @override
  State<_PanelPin> createState() => _PanelPinState();
}

class _PanelPinState extends State<_PanelPin> {
  final _pin = TextEditingController();
  final _konfirmasi = TextEditingController();
  final _kode = TextEditingController();
  bool _sibuk = false;
  String? _galat;

  /// True setelah pengguna memilih jalur kode email (akun sosial).
  bool _sosialDiteksi = false;

  @override
  void dispose() {
    _pin.dispose();
    _konfirmasi.dispose();
    _kode.dispose();
    super.dispose();
  }

  Future<void> _mintaKode() async {
    setState(() => _sibuk = true);
    try {
      final pesan = await context.read<AppState>().mintaKodePinTransfer();
      if (!mounted) return;
      setState(() {
        _sibuk = false;
        _sosialDiteksi = true;
        _galat = null;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(pesan)));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _sibuk = false;
        // 400 = akun ini punya password → konfirmasi pakai password.
        _galat = e.status == 400
            ? 'Akun ini memakai password untuk konfirmasi.'
            : e.pesan;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sibuk = false;
        _galat = 'Gagal mengirim kode. Coba lagi.';
      });
    }
  }

  Future<void> _simpan() async {
    if (_pin.text.length != 6) {
      setState(() => _galat = 'PIN harus 6 digit angka.');
      return;
    }
    final konfirmasi = _sosialDiteksi ? _kode.text.trim() : _konfirmasi.text;
    if (konfirmasi.isEmpty) {
      setState(() =>
          _galat = _sosialDiteksi ? 'Masukkan kode dari email.' : 'Masukkan password akunmu.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _sibuk = true;
      _galat = null;
    });
    try {
      await context
          .read<AppState>()
          .setPinTransfer(_pin.text, konfirmasi);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN transfer tersimpan.')));
      if (widget.mandiri) {
        Navigator.pop(context);
      } else {
        widget.setelahTerpasang?.call();
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _sibuk = false;
        _galat = e.pesan;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sibuk = false;
        _galat = 'Tidak bisa terhubung ke server.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = XyTheme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (widget.mandiri) ...[
        Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: XyTheme.goldSoft.withOpacity(.16),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Icons.pin_rounded,
                color: XyTheme.goldMid, size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PIN Transfer',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16.5,
                        letterSpacing: -.3)),
                SizedBox(height: 2),
                Text('6 digit, dipakai setiap kali mengirim saldo.',
                    style: TextStyle(fontSize: 11.5, color: XyTheme.muted)),
              ],
            ),
          ),
        ]),
        const SizedBox(height: 18),
      ] else ...[
        const Text('Pasang PIN Transfer dulu',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 6),
        Text(
          'PIN 6 digit menjaga saldo kamu saat transfer antar pengguna. Konfirmasi dengan password akun (atau kode email untuk akun Google).',
          style: TextStyle(color: t.muted, fontSize: 12.5, height: 1.55),
        ),
        const SizedBox(height: 16),
      ],
      const XyLabel('PIN baru (6 digit)'),
      TextField(
        controller: _pin,
        obscureText: true,
        keyboardType: TextInputType.number,
        maxLength: 6,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(
            counterText: '', hintText: '••••••', prefixIcon: Icon(Icons.pin_rounded)),
      ),
      const SizedBox(height: 14),
      if (!_sosialDiteksi) ...[
        const XyLabel('Password akun'),
        TextField(
          controller: _konfirmasi,
          obscureText: true,
          decoration: const InputDecoration(
              hintText: 'Password kamu',
              prefixIcon: Icon(Icons.lock_outline_rounded)),
        ),
        const SizedBox(height: 6),
        TextButton.icon(
          onPressed: _sibuk ? null : _mintaKode,
          icon: const Icon(Icons.mail_outline_rounded, size: 16),
          label: const Text('Akun Google tanpa password? Kirim kode email'),
        ),
      ] else ...[
        const XyLabel('Kode dari email'),
        TextField(
          controller: _kode,
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
              counterText: '',
              hintText: '••••••',
              prefixIcon: const Icon(Icons.mark_email_unread_rounded),
              suffixIcon: TextButton(
                onPressed: _sibuk ? null : _mintaKode,
                child: const Text('Kirim ulang', style: TextStyle(fontSize: 11.5)),
              )),
        ),
      ],
      if (_galat != null) ...[
        const SizedBox(height: 8),
        Text(_galat!,
            style: const TextStyle(
                color: XyTheme.dangerBright,
                fontSize: 12.5,
                fontWeight: FontWeight.w600)),
      ],
      const SizedBox(height: 16),
      GradientButton(
        label: 'Simpan PIN',
        icon: Icons.check_rounded,
        loading: _sibuk,
        onPressed: _sibuk ? null : _simpan,
      ),
    ]);
  }
}
