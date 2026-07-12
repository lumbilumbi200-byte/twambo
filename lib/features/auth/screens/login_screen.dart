import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../auth_provider.dart';
import '../../../shared/theme.dart';

// Afrofuturism accent colours
const _techPurple  = Color(0xFFCE93D8);
const _techCyan    = Color(0xFF00E5FF);
const _techGold    = Color(0xFFFFD54F);
const _skinDark    = Color(0xFF3D1A00);
const _hairDark    = Color(0xFF1A0800);

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      final phone = '+26${_phoneCtrl.text.trim()}';
      final err = await ref
          .read(authProvider.notifier)
          .login(phone, _passCtrl.text);
      if (!mounted) return;
      if (err == null) {
        final user = ref.read(authProvider).user!;
        context.go(user.isDriver ? '/driver' : '/search');
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
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // ── Full-screen scene ─────────────────────────────────────────
          const Positioned.fill(child: _MarketScene()),

          // ── TWMB brand — left-aligned, level with the sun ─────────────
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 14, 80, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TWMB',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 50,
                        fontWeight: FontWeight.w800,
                        color: TwamboColors.primary,
                        letterSpacing: 8,
                        shadows: [
                          const Shadow(color: _techPurple, offset: Offset(3, 4), blurRadius: 0),
                          Shadow(color: _techPurple.withValues(alpha: 0.4), offset: const Offset(0, 0), blurRadius: 12),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    const _QuoteTyper(),
                  ],
                ),
              ),
            ),
          ),

          // ── Login dialog anchored at bottom ───────────────────────────
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: _LoginDialog(
                  formKey: _formKey,
                  phoneCtrl: _phoneCtrl,
                  passCtrl: _passCtrl,
                  obscure: _obscure,
                  onToggleObscure: () => setState(() => _obscure = !_obscure),
                  onSubmit: _loading ? null : _submit,
                  loading: _loading,
                  error: _error,
                  onChanged: (_) => setState(() => _error = null),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Login dialog ──────────────────────────────────────────────────────────────

class _LoginDialog extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController phoneCtrl;
  final TextEditingController passCtrl;
  final bool obscure;
  final VoidCallback onToggleObscure;
  final VoidCallback? onSubmit;
  final bool loading;
  final String? error;
  final ValueChanged<String> onChanged;

  const _LoginDialog({
    required this.formKey, required this.phoneCtrl, required this.passCtrl,
    required this.obscure, required this.onToggleObscure, required this.onSubmit,
    required this.loading, required this.error, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.52),
              border: Border(
                left: const BorderSide(color: TwamboColors.primary, width: 4),
                top: BorderSide(color: _techPurple.withValues(alpha: 0.5), width: 1),
                right: BorderSide(color: TwamboColors.line, width: 1),
                bottom: BorderSide(color: TwamboColors.line, width: 1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Thin header label
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 9, 14, 9),
                  decoration: BoxDecoration(
                    color: TwamboColors.primary.withValues(alpha: 0.07),
                    border: Border(bottom: BorderSide(color: _techPurple.withValues(alpha: 0.3), width: 1)),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'A-les-go',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 10, fontWeight: FontWeight.w700,
                          color: TwamboColors.primary, letterSpacing: 2,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(
                          border: Border.all(color: _techPurple, width: 1.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'RIDER · DRIVER',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 9, fontWeight: FontWeight.w700,
                            color: _techPurple, letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Form
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                  child: Form(
                    key: formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _RetroField(
                          controller: phoneCtrl, label: 'PHONE NUMBER',
                          icon: Icons.phone_outlined, keyboardType: TextInputType.phone,
                          prefix: '+26',
                          onChanged: onChanged,
                          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 10),
                        _RetroField(
                          controller: passCtrl, label: 'PASSWORD',
                          icon: Icons.lock_outline, obscure: obscure,
                          onToggleObscure: onToggleObscure, onChanged: onChanged,
                          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                        ),
                        if (error != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            color: TwamboColors.error.withValues(alpha: 0.07),
                            child: Text(error!,
                              style: GoogleFonts.spaceGrotesk(fontSize: 11, color: TwamboColors.error),
                              textAlign: TextAlign.center),
                          ),
                        ],
                        const SizedBox(height: 14),
                        InkWell(
                          onTap: onSubmit,
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              color: onSubmit != null ? TwamboColors.primary : TwamboColors.line,
                              boxShadow: onSubmit != null ? [
                                BoxShadow(color: _techPurple.withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 3)),
                              ] : null,
                            ),
                            child: Center(
                              child: loading
                                  ? const SizedBox(width: 18, height: 18,
                                      child: CircularProgressIndicator(color: TwamboColors.textPrimary, strokeWidth: 2.5))
                                  : Text('LOG IN',
                                      style: GoogleFonts.spaceGrotesk(
                                        fontSize: 13, fontWeight: FontWeight.w800,
                                        letterSpacing: 3, color: TwamboColors.textPrimary)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Center(
                          child: TextButton(
                            onPressed: () => context.push('/forgot-password'),
                            child: Text('Forgot password?',
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                color: TwamboColors.accent,
                                fontWeight: FontWeight.w600,
                              )),
                          ),
                        ),
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: () => context.go('/register'),
                          child: Container(
                            height: 42,
                            decoration: BoxDecoration(
                              border: Border.all(color: TwamboColors.secondary.withValues(alpha: 0.6)),
                            ),
                            child: Center(
                              child: Text('CREATE AN ACCOUNT',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 11, fontWeight: FontWeight.w700,
                                  color: TwamboColors.secondary, letterSpacing: 1.5)),
                            ),
                          ),
                        ),
                      ],
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

// ── Field ─────────────────────────────────────────────────────────────────────

class _RetroField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType keyboardType;
  final bool obscure;
  final String? prefix;
  final VoidCallback? onToggleObscure;
  final ValueChanged<String> onChanged;
  final FormFieldValidator<String> validator;

  const _RetroField({
    required this.controller, required this.label, required this.icon,
    this.keyboardType = TextInputType.text, this.obscure = false,
    this.prefix, this.onToggleObscure, required this.onChanged, required this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      style: GoogleFonts.spaceGrotesk(fontSize: 14, fontWeight: FontWeight.w600, color: TwamboColors.textPrimary),
      onChanged: onChanged,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.spaceGrotesk(fontSize: 10, letterSpacing: 1.4, color: TwamboColors.textSecondary),
        prefixIcon: Icon(icon, size: 17, color: TwamboColors.textSecondary),
        prefixText: prefix,
        prefixStyle: GoogleFonts.spaceGrotesk(fontSize: 14, fontWeight: FontWeight.w600, color: TwamboColors.textPrimary),
        suffixIcon: onToggleObscure != null
            ? IconButton(
                icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    size: 17, color: TwamboColors.textSecondary),
                onPressed: onToggleObscure)
            : null,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.72),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        border: InputBorder.none,
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: TwamboColors.line),
          borderRadius: BorderRadius.circular(10),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: TwamboColors.primary, width: 2),
          borderRadius: BorderRadius.circular(10),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: TwamboColors.error),
          borderRadius: BorderRadius.circular(10),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: TwamboColors.error, width: 2),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}

// ── Rotating quote typewriter ─────────────────────────────────────────────────

class _QuoteTyper extends StatefulWidget {
  const _QuoteTyper();

  @override
  State<_QuoteTyper> createState() => _QuoteTyperState();
}

class _QuoteTyperState extends State<_QuoteTyper> {
  static const _quotes = [
    '"The refrigerator knows what you did in 2014.\nIt blinks in code when the kitchen lights die,\nand the lettuce is actively taking notes."',
    '"Never glue your shoes to the spinning ceiling fan.\nThe gravity gods will demand a heavy tax,\nand your ankles will pay the ultimate price."',
    '"If a tomato is classified as a fruit by science,\nthen a bottle of ketchup is just a thick smoothie.\nPlease do not put a straw in the squeeze bottle."',
    '"The alphabet should officially begin with the number seven.\nLetters have had it too easy for far too long,\nand the vowels are getting dangerously comfortable."',
    '"Yesterday becomes tomorrow if you walk backward fast enough.\nJust mind the fire hydrant near the corner store,\nor the temporal loop will claim your shins."',
    '"The toaster is actively plotting against the living room curtains.\nI can hear them whispering through the drywall fabric,\nand the blender has already chosen a side."',
    '"Pigeons are just highly weaponized government street chickens.\nThey suffer from severe collective existential anxiety\nand refuse to pay rent for occupying our statues."',
    '"Your left sock has negotiated a total escape plan.\nIt is currently living a much better life in Ohio,\nhidden deep inside a stranger\'s heavy-duty dryer."',
    '"Math is just a collection of insecure numbers\nscreaming at each other over basic logical fallacies.\nX needs to find its own therapist and leave us alone."',
    '"Gravity is not a fundamental law of physics.\nIt is just the earth hugging your shoes too tightly\nbecause the soil is incredibly lonely down there."',
    '"The moon is a giant glowing space cheese wheel.\nThe astronauts lied about the dust to protect the flavor,\nand the mice are building rockets as we speak."',
    '"Mirrors are just multi-dimensional travel portals\nthat completely gave up trying to do their actual job.\nNow they just mock our haircuts for minimum wage."',
    '"Why do we park our vehicles on driveways\nyet constantly drive them on the parkways?\nThe civil engineers are playing a dangerous game."',
    '"Do the ocean fish ever get genuinely thirsty down there?\nOr is the constant drowning sensation just a lifestyle choice\nthat they refuse to discuss with terrestrial mammals?"',
    '"Is a bowl of tomato soup just a hot savory mug of tea\nthat happens to feature large floating cracker chunks?\nThe tea lobby refuses to comment on this matter."',
    '"Sleep is just a free nightly preview clip of death.\nBut with much weirder plotlines and subscription ads\nfeaturing flying teeth and public speaking naked."',
    '"The ceiling has thousands of tiny invisible eyes.\nBut they only open on the third Tuesday of the month,\nso feel free to dance unbothered until then."',
  ];

  int _idx = 0;
  String _displayed = '';
  bool _cursorOn = true;

  Timer? _typeTimer;
  Timer? _holdTimer;
  Timer? _cursorTimer;

  @override
  void initState() {
    super.initState();
    _startCursorBlink();
    _startTyping();
  }

  void _startCursorBlink() {
    _cursorTimer = Timer.periodic(const Duration(milliseconds: 530), (_) {
      if (mounted) setState(() => _cursorOn = !_cursorOn);
    });
  }

  void _startTyping() {
    final target = _quotes[_idx];
    int charIdx = 0;
    _typeTimer?.cancel();
    _holdTimer?.cancel();
    if (mounted) setState(() => _displayed = '');

    _typeTimer = Timer.periodic(const Duration(milliseconds: 38), (t) {
      if (!mounted) { t.cancel(); return; }
      if (charIdx >= target.length) {
        t.cancel();
        // Hold 3.5s then move to next quote
        _holdTimer = Timer(const Duration(milliseconds: 3500), () {
          if (!mounted) return;
          _idx = (_idx + 1) % _quotes.length;
          _startTyping();
        });
        return;
      }
      setState(() => _displayed = target.substring(0, ++charIdx));
    });
  }

  @override
  void dispose() {
    _typeTimer?.cancel();
    _holdTimer?.cancel();
    _cursorTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cursor = _cursorOn ? '_' : ' ';
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 10, 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.38),
        border: Border(
          left: BorderSide(color: _techCyan, width: 2.5),
          top: BorderSide(color: _techCyan.withValues(alpha: 0.25), width: 0.5),
          bottom: BorderSide(color: _techCyan.withValues(alpha: 0.25), width: 0.5),
        ),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '> ',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: _techCyan,
                shadows: [Shadow(color: _techCyan.withValues(alpha: 0.8), blurRadius: 6)],
              ),
            ),
            TextSpan(
              text: _displayed,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Colors.white,
                height: 1.45,
                shadows: const [Shadow(color: Colors.black54, blurRadius: 4)],
              ),
            ),
            TextSpan(
              text: cursor,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: _techCyan,
                shadows: [Shadow(color: _techCyan.withValues(alpha: 0.9), blurRadius: 8)],
              ),
            ),
          ],
        ),
        maxLines: 3,
        overflow: TextOverflow.clip,
      ),
        ),
      ),
    );
  }
}



// ── Market scene ──────────────────────────────────────────────────────────────

class _MarketScene extends StatelessWidget {
  const _MarketScene();

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _MarketPainter(), child: const SizedBox.expand());
}

class _MarketPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final groundY    = size.height * 0.32;
    final roadTop    = size.height * 0.35;
    final roadBottom = size.height * 0.58;

    _drawSky(canvas, size);
    _drawSunGlow(canvas, size);
    _drawClouds(canvas, size);
    _drawBuildings(canvas, size, groundY);
    _drawRoad(canvas, size, roadTop, roadBottom);
    _drawTaxisAndMandem(canvas, size, roadTop, roadBottom);
    _drawForeground(canvas, size, roadBottom);
  }

  // ── Sky ────────────────────────────────────────────────────────────────────

  void _drawSky(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF6EC6E8), Color(0xFFAEDEF5), Color(0xFFFFF8DC)],
          stops: [0.0, 0.55, 1.0],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );
    // Subtle tech-grid overlay in sky (very faint)
    final gridP = Paint()
      ..color = _techCyan.withValues(alpha: 0.05)
      ..strokeWidth = 0.5;
    for (double x = 0; x < size.width; x += size.width / 8) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height * 0.32), gridP);
    }
    for (double y = 0; y < size.height * 0.32; y += size.height * 0.06) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridP);
    }
  }

  // ── Sun ────────────────────────────────────────────────────────────────────

  void _drawSunGlow(Canvas canvas, Size size) {
    final cx = size.width * 0.80;
    final cy = size.height * 0.10;
    canvas.drawCircle(Offset(cx, cy), 115,
        Paint()
          ..shader = RadialGradient(colors: [
            const Color(0xFFFFD700).withValues(alpha: 0.55),
            const Color(0xFFFFC300).withValues(alpha: 0.18),
            Colors.transparent,
          ], stops: const [0.0, 0.45, 1.0])
              .createShader(Rect.fromCenter(center: Offset(cx, cy), width: 230, height: 230)));
    // Sun disc
    canvas.drawCircle(Offset(cx, cy), 28, Paint()..color = const Color(0xFFFFD700));
    // Tech ring around sun
    canvas.drawCircle(
        Offset(cx, cy), 38,
        Paint()
          ..color = _techGold.withValues(alpha: 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
  }

  // ── Clouds ─────────────────────────────────────────────────────────────────

  void _drawClouds(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white.withValues(alpha: 0.88);
    _cloud(canvas, size.width * 0.14, size.height * 0.10, 56, p);
    _cloud(canvas, size.width * 0.52, size.height * 0.06, 40, p);
  }

  void _cloud(Canvas canvas, double cx, double cy, double r, Paint p) {
    canvas.drawCircle(Offset(cx, cy), r * 0.6, p);
    canvas.drawCircle(Offset(cx + r * 0.52, cy + r * 0.1), r * 0.5, p);
    canvas.drawCircle(Offset(cx - r * 0.44, cy + r * 0.1), r * 0.44, p);
    canvas.drawCircle(Offset(cx + r * 0.14, cy + r * 0.3), r * 0.54, p);
  }

  // ── Buildings ──────────────────────────────────────────────────────────────

  void _drawBuildings(Canvas canvas, Size size, double groundY) {
    final defs = [
      // [relX, relW, h, wallColor]
      [0.00, 0.21, 78.0, 0xFFE8845A], // terracotta
      [0.19, 0.22, 60.0, 0xFF3DB6A0], // teal
      [0.39, 0.23, 94.0, 0xFFFFC300], // yellow
      [0.60, 0.20, 66.0, 0xFFEEEEEE], // white
      [0.78, 0.24, 80.0, 0xFF4A7FBF], // blue
    ];

    for (int i = 0; i < defs.length; i++) {
      final d = defs[i];
      final x = size.width * (d[0] as double);
      final w = size.width * (d[1] as double);
      final h = d[2] as double;
      final color = Color(d[3] as int);

      // Wall
      canvas.drawRect(Rect.fromLTWH(x, groundY - h, w, h), Paint()..color = color);
      // Parapet
      canvas.drawRect(Rect.fromLTWH(x, groundY - h - 9, w, 9),
          Paint()..color = color.withValues(alpha: 0.72));
      // Outline
      canvas.drawRect(Rect.fromLTWH(x, groundY - h - 9, w, h + 9),
          Paint()
            ..color = Colors.black.withValues(alpha: 0.1)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1);
      // Windows
      final winP = Paint()..color = const Color(0xFF87CEEB).withValues(alpha: 0.85);
      final winW = w * 0.17;
      for (int row = 0; row < 2; row++) {
        for (int col = 0; col < 2; col++) {
          canvas.drawRect(
            Rect.fromLTWH(x + w * 0.14 + col * w * 0.36,
                groundY - h + 12 + row * 24, winW, 13),
            winP,
          );
        }
      }
    }

    // Awning on teal building
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.18, groundY - 28)
        ..lineTo(size.width * 0.41, groundY - 28)
        ..lineTo(size.width * 0.42, groundY - 17)
        ..lineTo(size.width * 0.17, groundY - 17)
        ..close(),
      Paint()..color = TwamboColors.primary,
    );

    // Shop signs
    _signPlain(canvas, size.width * 0.02, groundY - 38, 48, 14, Colors.white);
    _signPlain(canvas, size.width * 0.21, groundY - 32, 46, 13, TwamboColors.primary);
    _signPlain(canvas, size.width * 0.42, groundY - 42, 50, 14, const Color(0xFFE8845A));
    _signPlain(canvas, size.width * 0.62, groundY - 32, 44, 13, const Color(0xFF3DB6A0));

    // Wakanda-tech neon sign on yellow building
    _glowRect(canvas,
        Rect.fromLTWH(size.width * 0.42, groundY - 56, 48, 12),
        _techCyan, 0.7, 6);

    // Solar panel on blue building (top)
    final spX = size.width * 0.80;
    final spY = groundY - (defs[4][2] as double) - 9 - 16;
    canvas.drawRect(Rect.fromLTWH(spX, spY, size.width * 0.20, 14),
        Paint()..color = const Color(0xFF1565C0).withValues(alpha: 0.8));
    canvas.drawRect(Rect.fromLTWH(spX, spY, size.width * 0.20, 14),
        Paint()..color = _techCyan.withValues(alpha: 0.4)..style = PaintingStyle.stroke..strokeWidth = 1);
    for (int g = 1; g < 5; g++) {
      canvas.drawLine(
        Offset(spX + g * size.width * 0.04, spY),
        Offset(spX + g * size.width * 0.04, spY + 14),
        Paint()..color = _techCyan.withValues(alpha: 0.4)..strokeWidth = 0.8,
      );
    }
  }

  void _signPlain(Canvas canvas, double x, double y, double w, double h, Color c) {
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), const Radius.circular(3)),
        Paint()..color = c);
    canvas.drawRect(Rect.fromLTWH(x + 5, y + h * 0.35, w - 10, 2.5),
        Paint()..color = Colors.black.withValues(alpha: 0.28));
  }

  // Glowing rectangle (neon sign effect)
  void _glowRect(Canvas canvas, Rect rect, Color color, double opacity, double blur) {
    canvas.drawRect(rect,
        Paint()
          ..color = color.withValues(alpha: opacity * 0.25)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur));
    canvas.drawRect(rect, Paint()..color = color.withValues(alpha: opacity * 0.7));
    canvas.drawRect(rect,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);
  }

  // ── Perspective road ───────────────────────────────────────────────────────

  void _drawRoad(Canvas canvas, Size size, double rt, double rb) {
    // Trapezoid: narrow at top (horizon), wide at bottom (foreground)
    final roadPath = Path()
      ..moveTo(0, rb)
      ..lineTo(size.width * 0.07, rt)
      ..lineTo(size.width * 0.93, rt)
      ..lineTo(size.width, rb)
      ..close();

    // Asphalt gradient (darker at horizon = depth)
    canvas.drawPath(roadPath,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [const Color(0xFF1A1A1A), const Color(0xFF606060)],
          ).createShader(Rect.fromLTWH(0, rt, size.width, rb - rt)));

    // Glowing purple/cyan edge lines (Wakanda road tech)
    _glowLine(canvas, Offset(0, rb), Offset(size.width * 0.07, rt), _techPurple, 2.5, 5);
    _glowLine(canvas, Offset(size.width, rb), Offset(size.width * 0.93, rt), _techPurple, 2.5, 5);

    // White centre dashes converging to vanishing point
    final vpX = size.width * 0.5;
    const dashes = 7;
    for (int i = 0; i < dashes; i++) {
      final t1 = i / dashes.toDouble();
      final t2 = (i + 0.52) / dashes.toDouble();
      final y1 = rb + (rt - rb) * t1;
      final y2 = rb + (rt - rb) * t2;
      canvas.drawLine(Offset(vpX, y1), Offset(vpX, y2),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.7)
            ..strokeWidth = 2.0 - 1.0 * t1);
    }

    // Sidewalk strip above road
    canvas.drawRect(Rect.fromLTWH(0, rt - 11, size.width, 11),
        Paint()..color = const Color(0xFFCFAE86));
    // Yellow curb
    canvas.drawLine(Offset(0, rt), Offset(size.width, rt),
        Paint()..color = TwamboColors.primary..strokeWidth = 2.5);

    // Depth shadow at horizon
    canvas.drawRect(
      Rect.fromLTWH(0, rt, size.width, 18),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withValues(alpha: 0.3), Colors.transparent],
        ).createShader(Rect.fromLTWH(0, rt, size.width, 18)),
    );
  }

  void _glowLine(Canvas canvas, Offset a, Offset b, Color color, double sw, double blur) {
    canvas.drawLine(a, b,
        Paint()
          ..color = color.withValues(alpha: 0.35)
          ..strokeWidth = sw + blur
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur));
    canvas.drawLine(a, b, Paint()..color = color..strokeWidth = sw);
  }

  // ── Taxis + the mandem ─────────────────────────────────────────────────────

  void _drawTaxisAndMandem(Canvas canvas, Size size, double rt, double rb) {
    final rh = rb - rt;

    // Perspective helpers
    double scaleAt(double t) => 0.36 + 0.64 * t;
    double roadCx(double t, double laneFrac) {
      final lx = size.width * 0.07 * (1 - t);
      final rx = size.width * (1 - 0.07 * (1 - t));
      return lx + (rx - lx) * laneFrac;
    }

    // ── Taxi A — far, left lane ───────────────────────────────────────
    const tAt = 0.20;
    final tAscale = scaleAt(tAt);
    final tAw = 155.0 * tAscale;
    final tAyWheel = rt + rh * tAt;
    final tAcx = roadCx(tAt, 0.26);
    _drawTaxi(canvas, tAcx - tAw / 2, tAyWheel - tAw * 0.42, tAw, true);

    // Person A1 — afro guy leaning on far taxi (right side), red dashiki
    final pAs = 42.0 * tAscale;
    _personLeaning(
      canvas,
      tAcx - tAw / 2 + tAw + pAs * 0.5,
      tAyWheel,
      pAs,
      const Color(0xFFE53935),
      true, // leaning left toward taxi
      hair: _HairStyle.afro,
    );

    // ── Taxi B — near, right lane ─────────────────────────────────────
    const tBt = 0.58;
    final tBscale = scaleAt(tBt);
    final tBw = 155.0 * tBscale;
    final tByWheel = rt + rh * tBt;
    final tBcx = roadCx(tBt, 0.70);
    _drawTaxi(canvas, tBcx - tBw / 2, tByWheel - tBw * 0.42, tBw, false);

    // People around near taxi
    final pBs = 42.0 * tBscale;

    // Person B1 — locs, leaning on left side of taxi, green print shirt
    _personLeaning(
      canvas,
      tBcx - tBw / 2 - pBs * 0.5,
      tByWheel,
      pBs,
      const Color(0xFF2E7D32),
      false, // leaning right toward taxi
      hair: _HairStyle.locs,
    );

    // Person B2 — flat-top afro, squatting by front wheel, orange
    _personSquatting(
      canvas,
      tBcx - tBw / 2 + tBw * 0.18,
      tByWheel,
      pBs,
      const Color(0xFFFF6F00),
      hair: _HairStyle.flatTop,
    );

    // Person B3 — afro+cap, standing right of taxi, looking at holographic phone
    _personWithPhone(
      canvas,
      tBcx - tBw / 2 + tBw + pBs * 0.7,
      tByWheel,
      pBs,
      const Color(0xFF1565C0),
    );
  }

  // ── Draw a Mark-II boxy taxi ───────────────────────────────────────────────

  void _drawTaxi(Canvas canvas, double x, double y, double w, bool facingRight) {
    final h  = w * 0.42;
    final rh = h * 0.38;
    final by = y + rh;
    final bh = h * 0.62;

    // Shadow
    canvas.drawOval(
        Rect.fromCenter(center: Offset(x + w / 2, by + bh + 4), width: w * 0.88, height: 6),
        Paint()..color = Colors.black.withValues(alpha: 0.22));

    // Body
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, by, w, bh), const Radius.circular(4)),
        Paint()..color = TwamboColors.primary);

    // Roof
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(x + w * 0.10, y, w * 0.80, rh + 5), const Radius.circular(5)),
        Paint()..color = TwamboColors.primaryDark);

    // TAXI sign
    canvas.drawRect(Rect.fromLTWH(x + w * 0.30, y - 8, w * 0.40, 8),
        Paint()..color = Colors.black);
    canvas.drawRect(Rect.fromLTWH(x + w * 0.31, y - 7, w * 0.38, 6),
        Paint()..color = TwamboColors.primary);

    // Windshield
    final wsX = facingRight ? x + w * 0.54 : x + w * 0.10;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(wsX, by + 2, w * 0.30, rh - 2), const Radius.circular(3)),
        Paint()..color = const Color(0xFF5B9BD5).withValues(alpha: 0.88));

    // Rear window
    final rwX = facingRight ? x + w * 0.10 : x + w * 0.60;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(rwX, by + 3, w * 0.22, rh - 4), const Radius.circular(2)),
        Paint()..color = const Color(0xFF5B9BD5).withValues(alpha: 0.60));

    // Bumper chrome
    canvas.drawLine(Offset(x + 3, by + bh - 5), Offset(x + w - 3, by + bh - 5),
        Paint()
          ..color = const Color(0xFFCCCCCC)
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke);

    // Door line
    canvas.drawLine(Offset(x + w * 0.50, by + 4), Offset(x + w * 0.50, by + bh - 8),
        Paint()..color = Colors.black.withValues(alpha: 0.18)..strokeWidth = 1);

    // Purple LED underglow (Wakanda tech)
    _glowLine(canvas,
        Offset(x + 4, by + bh - 1), Offset(x + w - 4, by + bh - 1),
        _techPurple, 1.5, 5);

    // Wheels
    _wheel(canvas, x + w * 0.18, by + bh, w * 0.12);
    _wheel(canvas, x + w * 0.80, by + bh, w * 0.12);
  }

  void _wheel(Canvas canvas, double cx, double cy, double r) {
    canvas.drawCircle(Offset(cx, cy), r, Paint()..color = const Color(0xFF1A1A1A));
    canvas.drawCircle(Offset(cx, cy), r * 0.55, Paint()..color = const Color(0xFF777777));
    canvas.drawCircle(Offset(cx, cy), r * 0.24, Paint()..color = const Color(0xFF333333));
  }

  // ── People ─────────────────────────────────────────────────────────────────

  void _personLeaning(Canvas canvas, double cx, double fy, double s, Color shirt,
      bool leanLeft, {_HairStyle hair = _HairStyle.afro}) {
    final ox = leanLeft ? -s * 0.14 : s * 0.14;
    final headCx = cx + ox;

    _drawHead(canvas, headCx, fy - s * 2.15, s * 0.32, hair);
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(cx + ox - s * 0.22, fy - s * 1.82, s * 0.44, s * 0.82),
            const Radius.circular(3)),
        Paint()..color = shirt);
    _drawLegs(canvas, cx + ox * 0.5, fy, s);

    // Arm resting on taxi side
    final armEndX = leanLeft ? cx - s * 1.0 : cx + s * 1.0;
    canvas.drawLine(
      Offset(cx + ox + (leanLeft ? -s * 0.22 : s * 0.22), fy - s * 1.56),
      Offset(armEndX, fy - s * 1.62),
      Paint()..color = _skinDark..strokeWidth = s * 0.14..strokeCap = StrokeCap.round,
    );
    // Other arm hangs
    canvas.drawLine(
      Offset(cx + ox + (leanLeft ? s * 0.22 : -s * 0.22), fy - s * 1.70),
      Offset(cx + ox + (leanLeft ? s * 0.46 : -s * 0.46), fy - s * 1.08),
      Paint()..color = _skinDark..strokeWidth = s * 0.13..strokeCap = StrokeCap.round,
    );
  }

  void _personSquatting(Canvas canvas, double cx, double fy, double s, Color shirt,
      {_HairStyle hair = _HairStyle.afro}) {
    _drawHead(canvas, cx, fy - s * 1.55, s * 0.30, hair);
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(cx - s * 0.22, fy - s * 1.22, s * 0.44, s * 0.58),
            const Radius.circular(3)),
        Paint()..color = shirt);
    // Bent legs
    final legP = Paint()..color = const Color(0xFF1A1A1A)..strokeWidth = s * 0.22..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx - s * 0.16, fy - s * 0.62), Offset(cx - s * 0.36, fy), legP);
    canvas.drawLine(Offset(cx + s * 0.16, fy - s * 0.62), Offset(cx + s * 0.36, fy), legP);
    // Arms resting on knees
    canvas.drawLine(Offset(cx - s * 0.22, fy - s * 1.05), Offset(cx - s * 0.38, fy - s * 0.68),
        Paint()..color = _skinDark..strokeWidth = s * 0.13..strokeCap = StrokeCap.round);
    canvas.drawLine(Offset(cx + s * 0.22, fy - s * 1.05), Offset(cx + s * 0.38, fy - s * 0.68),
        Paint()..color = _skinDark..strokeWidth = s * 0.13..strokeCap = StrokeCap.round);
  }

  // Guy holding holographic phone
  void _personWithPhone(Canvas canvas, double cx, double fy, double s, Color shirt) {
    _drawHead(canvas, cx, fy - s * 2.2, s * 0.32, _HairStyle.afroWithCap);
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(cx - s * 0.22, fy - s * 1.85, s * 0.44, s * 0.85),
            const Radius.circular(3)),
        Paint()..color = shirt);
    _drawLegs(canvas, cx, fy, s);
    // Arm holding phone out (right arm up)
    canvas.drawLine(Offset(cx + s * 0.22, fy - s * 1.70), Offset(cx + s * 0.5, fy - s * 1.5),
        Paint()..color = _skinDark..strokeWidth = s * 0.13..strokeCap = StrokeCap.round);
    // Phone body
    final ph = Rect.fromLTWH(cx + s * 0.42, fy - s * 1.75, s * 0.28, s * 0.44);
    canvas.drawRRect(RRect.fromRectAndRadius(ph, const Radius.circular(3)),
        Paint()..color = const Color(0xFF1A1A2E));
    // Holographic glow on phone screen
    canvas.drawRRect(
        RRect.fromRectAndRadius(ph.deflate(2), const Radius.circular(2)),
        Paint()
          ..color = _techCyan.withValues(alpha: 0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    canvas.drawRRect(RRect.fromRectAndRadius(ph.deflate(2), const Radius.circular(2)),
        Paint()..color = _techCyan.withValues(alpha: 0.7));
    // Left arm hanging
    canvas.drawLine(Offset(cx - s * 0.22, fy - s * 1.70), Offset(cx - s * 0.42, fy - s * 1.08),
        Paint()..color = _skinDark..strokeWidth = s * 0.13..strokeCap = StrokeCap.round);
  }

  void _drawLegs(Canvas canvas, double cx, double fy, double s) {
    final p = Paint()..color = const Color(0xFF1A1A1A)..strokeWidth = s * 0.20..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx - s * 0.14, fy - s * 0.88), Offset(cx - s * 0.16, fy), p);
    canvas.drawLine(Offset(cx + s * 0.14, fy - s * 0.88), Offset(cx + s * 0.16, fy - s * 0.1), p);
    // Foot shadow
    canvas.drawOval(Rect.fromCenter(center: Offset(cx, fy + 2), width: s * 0.5, height: s * 0.12),
        Paint()..color = Colors.black.withValues(alpha: 0.18));
  }

  void _drawHead(Canvas canvas, double cx, double cy, double r, _HairStyle hair) {
    switch (hair) {
      case _HairStyle.afro:
        // Large afro circle behind face
        canvas.drawCircle(Offset(cx, cy - r * 0.2), r * 1.55,
            Paint()..color = _hairDark);
        canvas.drawCircle(Offset(cx, cy), r, Paint()..color = _skinDark);
        break;
      case _HairStyle.locs:
        // Head + hanging locs
        canvas.drawCircle(Offset(cx, cy), r, Paint()..color = _skinDark);
        final locP = Paint()..color = const Color(0xFF3D1C00)..strokeWidth = r * 0.22..strokeCap = StrokeCap.round;
        for (int i = -2; i <= 2; i++) {
          canvas.drawLine(
            Offset(cx + i * r * 0.28, cy + r * 0.6),
            Offset(cx + i * r * 0.30, cy + r * 1.9),
            locP,
          );
        }
        break;
      case _HairStyle.flatTop:
        // Flat-top afro: rectangle on top of head
        canvas.drawCircle(Offset(cx, cy), r, Paint()..color = _skinDark);
        canvas.drawRect(
            Rect.fromLTWH(cx - r * 1.3, cy - r * 1.4, r * 2.6, r * 1.2),
            Paint()..color = _hairDark);
        break;
      case _HairStyle.afroWithCap:
        // Small afro + backwards cap
        canvas.drawCircle(Offset(cx, cy - r * 0.15), r * 1.3, Paint()..color = _hairDark);
        canvas.drawCircle(Offset(cx, cy), r, Paint()..color = _skinDark);
        // Cap brim (backwards — extends behind head)
        canvas.drawRect(
            Rect.fromLTWH(cx - r * 1.5, cy - r * 0.1, r * 0.7, r * 0.2),
            Paint()..color = const Color(0xFF1A1A1A));
        // Cap body (rounded on top)
        canvas.drawArc(
            Rect.fromCenter(center: Offset(cx, cy), width: r * 2.0, height: r * 1.4),
            math.pi, math.pi, true,
            Paint()..color = const Color(0xFF1A1A1A));
        break;
    }
  }

  // ── Foreground dust fade ───────────────────────────────────────────────────

  void _drawForeground(Canvas canvas, Size size, double roadBottom) {
    canvas.drawRect(
      Rect.fromLTWH(0, roadBottom * 0.9, size.width, size.height - roadBottom * 0.9),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [const Color(0xFFD4B896).withValues(alpha: 0.32), Colors.transparent],
        ).createShader(Rect.fromLTWH(0, roadBottom * 0.9, size.width, size.height - roadBottom * 0.9)),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

enum _HairStyle { afro, locs, flatTop, afroWithCap }
