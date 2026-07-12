import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../shared/theme.dart';

class NewPasswordScreen extends StatefulWidget {
  final String phone;
  final String idToken;

  const NewPasswordScreen({
    super.key,
    required this.phone,
    required this.idToken,
  });

  @override
  State<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends State<NewPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passCtrl    = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _loading  = false;
  String? _error;

  @override
  void dispose() {
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    try {
      await ApiClient.dio.post(
        Endpoints.resetPassword,
        data: {
          'phone_number': widget.phone,
          'id_token':     widget.idToken,
          'new_password': _passCtrl.text,
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset! Please log in.'),
          backgroundColor: TwamboColors.success,
        ),
      );
      context.go('/login');
    } on DioException catch (e) {
      setState(() => _error = e.response?.data['detail'] ?? 'Something went wrong.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TwamboColors.bg,
      appBar: AppBar(
        title: Text('New Password',
            style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w800)),
        automaticallyImplyLeading: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: Container(height: 4, decoration: const BoxDecoration(gradient: twamboPrimaryGradient)),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: TwamboColors.success.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_outline_rounded,
                      size: 48, color: TwamboColors.success),
                ),
                const SizedBox(height: 24),
                Text('Set a new password',
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 22, fontWeight: FontWeight.w800,
                        color: TwamboColors.textPrimary),
                    textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text('Phone verified. Choose a strong password.',
                    style: GoogleFonts.manrope(
                        fontSize: 13, color: TwamboColors.textSecondary),
                    textAlign: TextAlign.center),
                const SizedBox(height: 36),
                TextFormField(
                  controller: _passCtrl,
                  obscureText: _obscure1,
                  style: const TextStyle(color: TwamboColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'New password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure1
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                          color: TwamboColors.textSecondary),
                      onPressed: () => setState(() => _obscure1 = !_obscure1),
                    ),
                  ),
                  onChanged: (_) => setState(() => _error = null),
                  validator: (v) =>
                      v == null || v.length < 6 ? 'Minimum 6 characters' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmCtrl,
                  obscureText: _obscure2,
                  style: const TextStyle(color: TwamboColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Confirm password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure2
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                          color: TwamboColors.textSecondary),
                      onPressed: () => setState(() => _obscure2 = !_obscure2),
                    ),
                  ),
                  onChanged: (_) => setState(() => _error = null),
                  validator: (v) =>
                      v != _passCtrl.text ? 'Passwords do not match' : null,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: TwamboColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: TwamboColors.error.withValues(alpha: 0.3)),
                    ),
                    child: Text(_error!,
                        style: const TextStyle(color: TwamboColors.error, fontSize: 13),
                        textAlign: TextAlign.center),
                  ),
                ],
                const SizedBox(height: 28),
                InkWell(
                  onTap: _loading ? null : _submit,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: !_loading ? twamboPrimaryGradient : null,
                      color: _loading ? TwamboColors.surfaceAlt : null,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: _loading
                          ? const SizedBox(height: 20, width: 20,
                              child: CircularProgressIndicator(
                                  color: TwamboColors.primary, strokeWidth: 2))
                          : Text('Reset Password',
                              style: GoogleFonts.manrope(
                                  fontWeight: FontWeight.w800, fontSize: 15,
                                  color: TwamboColors.textPrimary)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
