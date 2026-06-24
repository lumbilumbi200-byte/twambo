import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'theme.dart';

class DriverNavBar extends StatelessWidget {
  final int currentIndex;
  final int requestsBadge;
  const DriverNavBar({required this.currentIndex, this.requestsBadge = 0, super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
              _NavItem(icon: Icons.directions_car_rounded, label: 'Home',
                  active: currentIndex == 0, onTap: () => context.go('/driver')),
              _NavItem(
                icon: Icons.inbox_rounded,
                label: 'Requests',
                active: currentIndex == 1,
                badge: requestsBadge,
                onTap: () => context.go('/driver/requests'),
              ),
              _NavItem(icon: Icons.route_rounded, label: 'Trips',
                  active: currentIndex == 2, onTap: () => context.go('/driver/trips')),
              _NavItem(icon: Icons.account_balance_wallet_rounded, label: 'Earnings',
                  active: currentIndex == 3, onTap: () => context.go('/driver/earnings')),
              _NavItem(icon: Icons.person_outline_rounded, label: 'Profile',
                  active: currentIndex == 4, onTap: () => context.go('/driver/profile')),
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
  final int badge;
  final VoidCallback onTap;
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 20, height: 2,
              margin: const EdgeInsets.only(bottom: 4),
              color: active ? TwamboColors.primary : Colors.transparent,
            ),
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, size: 22,
                    color: active ? TwamboColors.primary : TwamboColors.textSecondary),
                if (badge > 0)
                  Positioned(
                    top: -4, right: -6,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      decoration: const BoxDecoration(
                        color: TwamboColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Text('$badge',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.spaceGrotesk(
                              fontSize: 9, fontWeight: FontWeight.w800,
                              color: Colors.black)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(label,
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
