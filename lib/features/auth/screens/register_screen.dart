import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../auth_provider.dart';
import '../../../shared/theme.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  String _role = 'rider';
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      final err = await ref.read(authProvider.notifier).register(
            phone: '+26${_phoneCtrl.text.trim()}',
            fullName: _nameCtrl.text.trim(),
            password: _passCtrl.text,
            role: _role,
          );
      if (!mounted) return;
      if (err == null) {
        context.go(_role == 'driver' ? '/driver-pending' : '/search');
      } else {
        setState(() => _error = err);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TwamboColors.bg,
      appBar: AppBar(
        title: Text('Create Account', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w800)),
        leading: BackButton(onPressed: () => context.go('/login')),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: Container(
            height: 4,
            decoration: const BoxDecoration(
              gradient: twamboPrimaryGradient,
            ),
          ),
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
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  style: const TextStyle(color: TwamboColors.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Full name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  onChanged: (_) => setState(() => _error = null),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Enter your full name' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: TwamboColors.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Phone number',
                    prefixIcon: Icon(Icons.phone),
                    prefixText: '+26',
                    hintText: '097X XXX XXX',
                  ),
                  onChanged: (_) => setState(() => _error = null),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Enter your phone number' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passCtrl,
                  obscureText: _obscure,
                  style: const TextStyle(color: TwamboColors.textPrimary),
                  onChanged: (_) => setState(() => _error = null),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        color: TwamboColors.textSecondary,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) =>
                      v == null || v.length < 6 ? 'Minimum 6 characters' : null,
                ),
                const SizedBox(height: 24),
                Text(
                  'I am joining as a',
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w600,
                    color: TwamboColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _RoleCard(
                      label: 'Rider',
                      icon: Icons.person,
                      selected: _role == 'rider',
                      onTap: _loading ? null : () => setState(() => _role = 'rider'),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _RoleCard(
                      label: 'Driver',
                      icon: Icons.drive_eta,
                      selected: _role == 'driver',
                      onTap: _loading ? null : () => setState(() => _role = 'driver'),
                    )),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: TwamboColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: TwamboColors.error.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: TwamboColors.error, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
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
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: TwamboColors.primary,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'Create Account',
                              style: GoogleFonts.manrope(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: TwamboColors.textPrimary,
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('Already have an account? Log in'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  const _RoleCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: selected ? TwamboColors.primary.withValues(alpha: 0.15) : TwamboColors.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? TwamboColors.primary : TwamboColors.line,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: selected ? TwamboColors.primary : TwamboColors.textSecondary),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w600,
                color: selected ? TwamboColors.primary : TwamboColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
