import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/app_state.dart';
import '../widgets/common.dart';

/// Layar memasukkan kode verifikasi 6 digit yang dikirim ke email.
/// Dipakai untuk dua hal: mengaktifkan akun baru dan mereset password.
class OtpScreen extends StatefulWidget {
  const OtpScreen({
    super.key,
    required this.email,
    this.nama = '',
    this.mode = 'verifikasi', // verifikasi | reset
    this.pesanAwal,
  });

  final String email;
  final String nama;
  final String mode;
  final String? pesanAwal;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> _kotak = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _fokus = List.generate(6, (_) => FocusNode());
  final _pass = TextEditingController();

  String? _galat;
  bool _lihatPass = false;
  int _hitungMundur = 60;
  Timer? _timer;

  bool get _reset => widget.mode == 'reset';
  String get _kode => _kotak.map((c) => c.text).join();

  @override
  void initState() {
    super.initState();
    _mulaiHitung();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.pesanAwal != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.pesanAwal!)));
      }
      _fokus.first.requestFocus();
    });
  }

  void _mulaiHitung() {
    _timer?.cancel();
    setState(() => _hitungMundur = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _hitungMundur--);
      if (_hitungMundur <= 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _kotak) {
      c.dispose();
    }
    for (final f in _fokus) {
      f.dispose();
    }
    _pass.dispose();
    super.dispose();
  }

  void _isiDariTempel(String teks) {
    final angka = teks.replaceAll(RegExp(r'[^0-9]'), '');
    for (var i = 0; i < 6; i++) {
      _kotak[i].text = i < angka.length ? angka[i] : '';
    }
    setState(() {});
    if (angka.length >= 6) {
      FocusScope.of(context).unfocus();
      _kirim();
    }
  }

  Future<void> _kirim() async {
    if (_kode.length < 6) {
      setState(() => _galat = 'Kode belum lengkap');
      return;
    }
    if (_reset && (_pass.text.length < 8 || _pass.text.length > 128)) {
      setState(() => _galat = 'Password baru harus 8–128 karakter');
      return;
    }

    setState(() => _galat = null);
    final s = context.read<AppState>();
    final ok = _reset
        ? await s.resetPassword(email: widget.email, kode: _kode, password: _pass.text)
        : await s.verifikasiEmail(widget.email, _kode);

    if (!mounted) return;
    if (ok) {
      Navigator.of(context).popUntil((r) => r.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_reset ? 'Password baru tersimpan. Selamat datang kembali.' : 'Akun berhasil diaktifkan. Selamat datang.')),
      );
    } else {
      setState(() => _galat = s.error ?? 'Kode salah, coba lagi.');
    }
  }

  Future<void> _kirimUlang() async {
    if (_hitungMundur > 0) return;
    final s = context.read<AppState>();
    final pesan = await s.kirimUlangKode(widget.email, tipe: widget.mode);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(pesan ?? s.error ?? 'Gagal mengirim kode.')),
    );
    if (pesan != null) _mulaiHitung();
  }

  @override
  Widget build(BuildContext context) {
    final loading = context.watch<AppState>().loading;

    return Scaffold(
      body: AuroraBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(26, 8, 26, 32),
            children: [
              if (Navigator.canPop(context))
                Pressable(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: XyTheme.of(context).surface,
                      borderRadius: BorderRadius.circular(XyRadius.sm),
                      border: Border.all(color: XyTheme.of(context).line),
                    ),
                    child: const Icon(Icons.arrow_back_rounded, size: 20),
                  ),
                ),

              const SizedBox(height: 22),
              const Center(child: XyIlustrasi('sukses', tinggi: 150)),
              const SizedBox(height: 16),

              Text(
                _reset ? 'Buat password baru' : 'Cek email kamu',
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -1, height: 1.2),
              ),
              const SizedBox(height: 8),
              Text.rich(
                TextSpan(children: [
                  const TextSpan(text: 'Kami mengirim kode 6 digit ke '),
                  TextSpan(
                    text: widget.email,
                    style: const TextStyle(fontWeight: FontWeight.w700, color: XyTheme.primary),
                  ),
                  const TextSpan(text: '. Kode berlaku 15 menit.'),
                ]),
                style:  TextStyle(color: XyTheme.of(context).muted, fontSize: 13.8, height: 1.6),
              ),

              const SizedBox(height: 26),

              // ---- kotak kode ----
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (i) {
                  return SizedBox(
                    width: 48,
                    child: TextField(
                      controller: _kotak[i],
                      focusNode: _fokus[i],
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      maxLength: 1,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: 0),
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        counterText: '',
                        contentPadding: EdgeInsets.symmetric(vertical: 16),
                      ),
                      onChanged: (v) {
                        if (v.length > 1) return _isiDariTempel(v);
                        if (v.isNotEmpty && i < 5) _fokus[i + 1].requestFocus();
                        if (v.isEmpty && i > 0) _fokus[i - 1].requestFocus();
                        setState(() {});
                        if (_kode.length == 6 && !_reset) _kirim();
                      },
                    ),
                  );
                }),
              ),

              if (_reset) ...[
                const SizedBox(height: 22),
                const Text('Password Baru',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, letterSpacing: -.1)),
                const SizedBox(height: 9),
                TextField(
                  controller: _pass,
                  obscureText: !_lihatPass,
                  decoration: InputDecoration(
                    hintText: '8–128 karakter',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(_lihatPass ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                      onPressed: () => setState(() => _lihatPass = !_lihatPass),
                    ),
                  ),
                ),
              ],

              if (_galat != null) ...[
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
                  decoration: BoxDecoration(
                    color: XyTheme.danger.withOpacity(.07),
                    borderRadius: BorderRadius.circular(XyRadius.sm),
                    border: Border.all(color: XyTheme.danger.withOpacity(.22)),
                  ),
                  child: Row(children: [
                    Icon(Icons.error_outline_rounded, color: XyTheme.danger, size: 19),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(_galat!,
                          style: const TextStyle(
                              color: XyTheme.danger, fontSize: 12.8, fontWeight: FontWeight.w600, height: 1.4)),
                    ),
                  ]),
                ),
              ],

              const SizedBox(height: 24),
              GradientButton(
                label: _reset ? 'Simpan Password Baru' : 'Verifikasi Sekarang',
                icon: Icons.verified_rounded,
                loading: loading,
                onPressed: _kirim,
              ),

              const SizedBox(height: 18),
              Center(
                child: _hitungMundur > 0
                    ? Text('Kirim ulang kode dalam $_hitungMundur detik',
                        style:  TextStyle(color: XyTheme.of(context).muted, fontSize: 13, fontWeight: FontWeight.w600))
                    : Pressable(
                        onTap: _kirimUlang,
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Text('Kirim ulang kode',
                              style: TextStyle(color: XyTheme.primary, fontWeight: FontWeight.w700, fontSize: 13.5)),
                        ),
                      ),
              ),

              const SizedBox(height: 10),
               Center(
                child: Text('Tidak ada emailnya? Cek folder spam atau promosi.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: XyTheme.of(context).muted, fontSize: 12, height: 1.5)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
