import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/models/user.dart';
import '../../../features/auth/auth_provider.dart';
import '../../../shared/theme.dart';

class DriverPendingScreen extends ConsumerStatefulWidget {
  const DriverPendingScreen({super.key});

  @override
  ConsumerState<DriverPendingScreen> createState() => _DriverPendingScreenState();
}

class _DriverPendingScreenState extends ConsumerState<DriverPendingScreen> {
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    // Poll /auth/me/ every 30s so the router redirect fires the moment admin approves
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final resp = await ApiClient.dio.get(Endpoints.me);
      final user = User.fromJson(resp.data as Map<String, dynamic>);
      ref.read(authProvider.notifier).setUser(user);
      // GoRouter's refreshListenable fires automatically via _RouterNotifier
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0D0D0D) : TwamboColors.bg;
    final textColor = isDark ? Colors.white : TwamboColors.textPrimary;
    final user = ref.watch(authProvider).user;
    final status = user?.driverVerificationStatus ?? 'pending';
    final isRejected = status == 'rejected';

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),

              // Status pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                color: isRejected ? TwamboColors.error.withValues(alpha: 0.12) : TwamboColors.primary.withValues(alpha: 0.15),
                child: Text(
                  isRejected ? 'REJECTED' : 'PENDING REVIEW',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 10, fontWeight: FontWeight.w800,
                    color: isRejected ? TwamboColors.error : TwamboColors.accent,
                    letterSpacing: 1.6,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Container(
                decoration: const BoxDecoration(
                  border: Border(left: BorderSide(color: TwamboColors.primary, width: 4)),
                ),
                padding: const EdgeInsets.only(left: 16),
                child: Text(
                  isRejected ? 'Application\nRejected' : 'Under\nReview',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 32, fontWeight: FontWeight.w800,
                    color: textColor, height: 1.1,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              if (!isRejected) ...[
                _InfoCard(
                  icon: Icons.access_time_rounded,
                  title: 'What happens next?',
                  body: 'Our team reviews your ID, driver\'s licence, and vehicle registration. '
                      'This usually takes 1–2 business days.',
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                _InfoCard(
                  icon: Icons.notifications_outlined,
                  title: 'You\'ll be notified',
                  body: 'We\'ll send a push notification the moment your account is approved. '
                      'This screen checks automatically every 30 seconds.',
                  isDark: isDark,
                ),
              ] else ...[
                _InfoCard(
                  icon: Icons.cancel_outlined,
                  title: 'Your application was not approved',
                  body: 'Please check that your documents are clear and legible, '
                      'then resubmit. Contact support if you think this is a mistake.',
                  isDark: isDark,
                  accent: TwamboColors.error,
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Document re-upload coming soon'),
                    ));
                  },
                  child: Container(
                    height: 48,
                    color: TwamboColors.error,
                    alignment: Alignment.center,
                    child: Text('RESUBMIT DOCUMENTS',
                        style: GoogleFonts.spaceGrotesk(
                            fontSize: 11, fontWeight: FontWeight.w800,
                            color: Colors.white, letterSpacing: 1)),
                  ),
                ),
              ],

              const Spacer(),

              // Manual refresh
              GestureDetector(
                onTap: _refresh,
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.refresh, size: 16, color: TwamboColors.textSecondary),
                  const SizedBox(width: 6),
                  Text('Check status now',
                      style: GoogleFonts.manrope(fontSize: 13, color: TwamboColors.textSecondary)),
                ]),
              ),

              const SizedBox(height: 16),

              GestureDetector(
                onTap: () async {
                  await ref.read(authProvider.notifier).logout();
                  if (context.mounted) context.go('/login');
                },
                child: Center(
                  child: Text('Log out',
                      style: GoogleFonts.manrope(fontSize: 13, color: TwamboColors.textSecondary,
                          decoration: TextDecoration.underline)),
                ),
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final bool isDark;
  final Color accent;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.isDark,
    this.accent = TwamboColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final textColor = isDark ? Colors.white : TwamboColors.textPrimary;
    return Container(
      color: cardBg,
      padding: const EdgeInsets.all(16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 20, color: accent),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 13, fontWeight: FontWeight.w700, color: textColor)),
            const SizedBox(height: 4),
            Text(body,
                style: GoogleFonts.manrope(fontSize: 12, color: TwamboColors.textSecondary, height: 1.5)),
          ]),
        ),
      ]),
    );
  }
}
