import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../auth_provider.dart';
import '../../../shared/theme.dart';

class OtpScreen extends ConsumerStatefulWidget {
  final String phone;
  final String role;
  const OtpScreen({super.key, required this.phone, required this.role});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _otpCtrl = TextEditingController();
  String? _verificationId;
  bool _codeSent = false;
  bool _loading = false;
  bool _sending = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _sendCode();
  }

  @override
  void dispose() {
    _otpCtrl.dispose();
    super.dispose();
  }

  String get _e164Phone {
    var p = widget.phone.trim();
    if (p.startsWith('0')) p = '+260${p.substring(1)}';
    if (!p.startsWith('+')) p = '+$p';
    return p;
  }

  Future<void> _sendCode() async {
    setState(() { _sending = true; _error = null; });
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: _e164Phone,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Auto-verified on Android (SMS auto-fill)
        await _signInAndVerify(credential);
      },
      verificationFailed: (FirebaseAuthException e) {
        setState(() {
          _sending = false;
          _error = e.message ?? 'Verification failed';
        });
      },
      codeSent: (String verificationId, int? resendToken) {
        setState(() {
          _verificationId = verificationId;
          _codeSent = true;
          _sending = false;
        });
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
      },
    );
  }

  Future<void> _signInAndVerify(PhoneAuthCredential credential) async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await FirebaseAuth.instance.signInWithCredential(credential);
      final idToken = await result.user?.getIdToken();
      if (idToken == null) throw Exception('No ID token');
      await ApiClient.dio.post(Endpoints.verifyPhone, data: {'id_token': idToken});
      if (!mounted) return;
      // Persist tokens and set auth state — registration is now complete
      await ref.read(authProvider.notifier).completeRegistration();
      if (!mounted) return;
      context.go(widget.role == 'driver' ? '/driver-pending' : '/search');
    } catch (e) {
      setState(() => _error = 'Verification failed. Check the code and try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirm() async {
    final code = _otpCtrl.text.trim();
    if (code.length != 6 || _verificationId == null) return;
    final credential = PhoneAuthProvider.credential(
      verificationId: _verificationId!,
      smsCode: code,
    );
    await _signInAndVerify(credential);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TwamboColors.bg,
      appBar: AppBar(
        title: Text('Verify Phone', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w800)),
        leading: BackButton(onPressed: () => context.go('/register')),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Text('Enter the code', style: GoogleFonts.spaceGrotesk(fontSize: 26, fontWeight: FontWeight.w800, color: TwamboColors.textPrimary)),
              const SizedBox(height: 8),
              Text(
                _sending
                    ? 'Sending SMS to ${widget.phone}...'
                    : 'We sent a 6-digit code to ${widget.phone}',
                style: GoogleFonts.manrope(fontSize: 14, color: TwamboColors.textSecondary),
              ),
              const SizedBox(height: 32),
              if (_sending)
                const Center(child: CircularProgressIndicator())
              else ...[
                TextFormField(
                  controller: _otpCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: GoogleFonts.spaceGrotesk(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: 12, color: TwamboColors.textPrimary),
                  decoration: const InputDecoration(counterText: '', hintText: '------'),
                  onChanged: (v) {
                    setState(() => _error = null);
                    if (v.length == 6) _confirm();
                  },
                ),
                const SizedBox(height: 24),
                if (_error != null) ...[
                  Text(_error!, style: GoogleFonts.manrope(fontSize: 13, color: TwamboColors.error)),
                  const SizedBox(height: 16),
                ],
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _confirm,
                    style: ElevatedButton.styleFrom(backgroundColor: TwamboColors.primary),
                    child: _loading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text('VERIFY', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: _sending ? null : _sendCode,
                    child: Text('Resend code', style: GoogleFonts.manrope(color: TwamboColors.accent)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
