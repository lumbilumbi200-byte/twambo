import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_providers.dart';
import 'theme.dart';

class RiderNavBar extends ConsumerWidget {
  final int currentIndex;
  const RiderNavBar({required this.currentIndex, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unreadCount = ref.watch(unreadNotificationsProvider).whenData((v) => v).value ?? 0;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF2E2E2E) : TwamboColors.line,
            width: 1.5,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              _NavItem(icon: Icons.home_rounded, label: 'Home', active: currentIndex == 0, onTap: () => context.go('/search')),
              _NavItem(icon: Icons.bookmark_outline_rounded, label: 'Bookings', active: currentIndex == 1, onTap: () => context.go('/bookings')),
              _NavItem(icon: Icons.notifications_outlined, label: 'Alerts', active: currentIndex == 2, onTap: () => context.go('/notifications'), badge: unreadCount),
              _NavItem(icon: Icons.person_outline_rounded, label: 'Profile', active: currentIndex == 3, onTap: () => context.go('/profile')),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final int badge;

  const _NavItem({required this.icon, required this.label, required this.active, required this.onTap, this.badge = 0});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 20,
              height: 2,
              margin: const EdgeInsets.only(bottom: 4),
              color: active ? TwamboColors.primary : Colors.transparent,
            ),
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, size: 22, color: active ? TwamboColors.primary : TwamboColors.textSecondary),
                if (badge > 0)
                  Positioned(
                    right: -6,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                      decoration: const BoxDecoration(
                        color: TwamboColors.error,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        badge > 9 ? '9+' : '$badge',
                        style: GoogleFonts.spaceGrotesk(
                            fontSize: 8, fontWeight: FontWeight.w800, color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 10,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? TwamboColors.primary : TwamboColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
