import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../dev/kitwe_places.dart';
import '../../../features/auth/auth_provider.dart';
import '../../../shared/app_providers.dart';
import '../../../shared/rider_nav_bar.dart';
import '../../../shared/theme.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;
    final saved = ref.watch(savedLocationsProvider);
    final initials = _initials(user?.fullName ?? '');

    final bg = isDark ? const Color(0xFF0D0D0D) : TwamboColors.bg;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Scaffold(
      backgroundColor: bg,
      bottomNavigationBar: const RiderNavBar(currentIndex: 3),
      body: Column(
        children: [
          // ── Header ───────────────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [const Color(0xFF0D1B2A), const Color(0xFF1A2F4A)]
                    : [const Color(0xFF1565C0), const Color(0xFF1E88E5)],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                child: Row(
                  children: [
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        color: TwamboColors.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Center(
                        child: Text(initials,
                            style: GoogleFonts.spaceGrotesk(
                                fontSize: 22, fontWeight: FontWeight.w800,
                                color: TwamboColors.textPrimary)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user?.fullName ?? '—',
                              style: GoogleFonts.spaceGrotesk(
                                  fontSize: 18, fontWeight: FontWeight.w800,
                                  color: Colors.white)),
                          const SizedBox(height: 2),
                          Text(user?.phoneNumber ?? '—',
                              style: GoogleFonts.manrope(
                                  fontSize: 13,
                                  color: Colors.white.withValues(alpha: 0.7))),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            color: TwamboColors.primary,
                            child: Text(
                              (user?.role ?? 'rider').toUpperCase(),
                              style: GoogleFonts.spaceGrotesk(
                                  fontSize: 9, fontWeight: FontWeight.w800,
                                  color: TwamboColors.textPrimary, letterSpacing: 1.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Edit button
                    GestureDetector(
                      onTap: () => _editProfile(context, ref, user?.fullName, user?.phoneNumber),
                      child: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(Icons.edit_outlined, size: 18, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Body ─────────────────────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
              children: [
                // ── Preferences ────────────────────────────────────────────
                _SectionLabel('PREFERENCES', isDark),
                const SizedBox(height: 8),
                _SettingsTile(
                  icon: isDark ? Icons.dark_mode_rounded : Icons.wb_sunny_rounded,
                  label: 'Dark Mode',
                  isDark: isDark,
                  trailing: Switch(
                    value: isDark,
                    onChanged: (_) => ref.read(themeModeProvider.notifier).toggle(),
                    activeColor: TwamboColors.primary,
                  ),
                ),

                // ── Saved Locations ────────────────────────────────────────
                const SizedBox(height: 20),
                _SectionLabel('SAVED LOCATIONS', isDark),
                const SizedBox(height: 8),
                _SavedLocationTile(
                  icon: Icons.home_outlined,
                  label: 'Home',
                  place: saved['home'],
                  isDark: isDark,
                  onTap: () async {
                    final p = await _pickPlace(context, 'Set home location');
                    if (p != null) { ref.read(savedLocationsProvider.notifier).set('home', p); }
                  },
                  onClear: () => ref.read(savedLocationsProvider.notifier).clear('home'),
                ),
                _SavedLocationTile(
                  icon: Icons.work_outline_rounded,
                  label: 'Work',
                  place: saved['work'],
                  isDark: isDark,
                  onTap: () async {
                    final p = await _pickPlace(context, 'Set work location');
                    if (p != null) { ref.read(savedLocationsProvider.notifier).set('work', p); }
                  },
                  onClear: () => ref.read(savedLocationsProvider.notifier).clear('work'),
                ),

                // ── Account ────────────────────────────────────────────────
                const SizedBox(height: 20),
                _SectionLabel('ACCOUNT', isDark),
                const SizedBox(height: 8),
                _SettingsTile(
                  icon: Icons.notifications_outlined,
                  label: 'Notifications',
                  isDark: isDark,
                  onTap: () => context.go('/notifications'),
                ),
                _SettingsTile(
                  icon: Icons.bookmark_outline_rounded,
                  label: 'My Bookings',
                  isDark: isDark,
                  onTap: () => context.go('/bookings'),
                ),

                // ── About ──────────────────────────────────────────────────
                const SizedBox(height: 20),
                _SectionLabel('ABOUT', isDark),
                const SizedBox(height: 8),
                _SettingsTile(
                  icon: Icons.info_outline_rounded,
                  label: 'About TWMB',
                  subtitle: 'Zambia\'s seat marketplace',
                  isDark: isDark,
                  onTap: () => _showAbout(context),
                ),

                const SizedBox(height: 32),

                // ── Logout ─────────────────────────────────────────────────
                GestureDetector(
                  onTap: () async {
                    await ref.read(authProvider.notifier).logout();
                    if (context.mounted) { context.go('/login'); }
                  },
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: cardBg,
                      border: const Border(left: BorderSide(color: TwamboColors.error, width: 4)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.logout_rounded, size: 18, color: TwamboColors.error),
                        const SizedBox(width: 10),
                        Text('LOG OUT',
                            style: GoogleFonts.spaceGrotesk(
                                fontSize: 13, fontWeight: FontWeight.w800,
                                color: TwamboColors.error, letterSpacing: 1.5)),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                Center(
                  child: Text('TWMB v1.0.0',
                      style: GoogleFonts.spaceGrotesk(
                          fontSize: 10, color: TwamboColors.textSecondary,
                          letterSpacing: 2)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty || parts[0].isEmpty) { return '?'; }
    if (parts.length == 1) { return parts[0][0].toUpperCase(); }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  Future<void> _editProfile(BuildContext context, WidgetRef ref,
      String? currentName, String? currentPhone) async {
    final nameCtrl  = TextEditingController(text: currentName);
    final phoneCtrl = TextEditingController(text: currentPhone);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text('Edit Profile',
            style: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : TwamboColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _EditField(ctrl: nameCtrl, label: 'Full Name', icon: Icons.person_outline, isDark: isDark),
            const SizedBox(height: 12),
            _EditField(ctrl: phoneCtrl, label: 'Phone Number', icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone, isDark: isDark),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: TwamboColors.textSecondary)),
          ),
          GestureDetector(
            onTap: () {
              final name  = nameCtrl.text.trim();
              final phone = phoneCtrl.text.trim();
              if (name.isNotEmpty || phone.isNotEmpty) {
                ref.read(authProvider.notifier).updateProfile(
                  fullName: name.isNotEmpty ? name : null,
                  phoneNumber: phone.isNotEmpty ? phone : null,
                );
              }
              Navigator.pop(ctx);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              color: TwamboColors.primary,
              child: Text('SAVE',
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 12, fontWeight: FontWeight.w800,
                      color: TwamboColors.textPrimary, letterSpacing: 1)),
            ),
          ),
        ],
      ),
    );
  }

  Future<KitwePlace?> _pickPlace(BuildContext context, String title) async {
    final query = await showModalBottomSheet<KitwePlace>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _QuickPlacePicker(title: title),
    );
    return query;
  }

  void _showAbout(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Row(
          children: [
            Container(width: 4, height: 24, color: TwamboColors.primary),
            const SizedBox(width: 10),
            Text('About TWMB',
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 16, fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : TwamboColors.textPrimary)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AboutLine(Icons.emoji_transportation_rounded,
                'TWMB (Twambo) is Zambia\'s first seat-sharing marketplace — book individual seats on planned routes instead of paying for the whole car.'),
            const SizedBox(height: 12),
            _AboutLine(Icons.people_outline_rounded,
                'Dynamic rides let multiple riders share a car and split the fare. Private rides book the entire vehicle for your group.'),
            const SizedBox(height: 12),
            _AboutLine(Icons.location_on_outlined,
                'Currently serving Kitwe, Copperbelt Province.'),
            const SizedBox(height: 12),
            _AboutLine(Icons.shield_outlined,
                'All fares are agreed upfront — no surge surprises, no cash haggling.'),
          ],
        ),
        actions: [
          GestureDetector(
            onTap: () => Navigator.pop(ctx),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              color: TwamboColors.primary,
              child: Text('GOT IT',
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 12, fontWeight: FontWeight.w800,
                      color: TwamboColors.textPrimary, letterSpacing: 1)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Quick place picker sheet (name search only, no map) ───────────────────────

class _QuickPlacePicker extends StatefulWidget {
  final String title;
  const _QuickPlacePicker({required this.title});

  @override
  State<_QuickPlacePicker> createState() => _QuickPlacePickerState();
}

class _QuickPlacePickerState extends State<_QuickPlacePicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final results = searchPlaces(_q);

    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(children: [
        Container(
          color: bg,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Column(children: [
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF3E3E3E) : TwamboColors.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Text(widget.title,
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 11, fontWeight: FontWeight.w800,
                    color: TwamboColors.textSecondary, letterSpacing: 1.5)),
            const SizedBox(height: 12),
            TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _q = v),
              decoration: InputDecoration(
                hintText: 'Search Kitwe places…',
                prefixIcon: const Icon(Icons.search, size: 18, color: TwamboColors.textSecondary),
                filled: true,
                fillColor: isDark ? const Color(0xFF2A2A2A) : TwamboColors.surfaceAlt,
                border: OutlineInputBorder(
                  borderSide: BorderSide.none,
                  borderRadius: BorderRadius.circular(4),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              style: GoogleFonts.manrope(
                  fontSize: 14,
                  color: isDark ? Colors.white : TwamboColors.textPrimary),
            ),
          ]),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: results.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              color: isDark ? const Color(0xFF2E2E2E) : TwamboColors.line,
            ),
            itemBuilder: (_, i) {
              final p = results[i];
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.pop(context, p),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(children: [
                    Icon(Icons.location_on_outlined,
                        size: 16, color: TwamboColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(p.name,
                          style: GoogleFonts.manrope(
                              fontSize: 14, fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : TwamboColors.textPrimary)),
                    ),
                    if (p.tag != null)
                      Text(p.tag!,
                          style: GoogleFonts.manrope(
                              fontSize: 11, color: TwamboColors.textSecondary)),
                  ]),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  final bool isDark;
  const _SectionLabel(this.text, this.isDark);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: GoogleFonts.spaceGrotesk(
            fontSize: 10, fontWeight: FontWeight.w800,
            color: TwamboColors.textSecondary, letterSpacing: 2));
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool isDark;

  const _SettingsTile({
    required this.icon, required this.label, required this.isDark,
    this.subtitle, this.trailing, this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : TwamboColors.textPrimary;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 1),
        decoration: BoxDecoration(
          color: bg,
          border: const Border(left: BorderSide(color: TwamboColors.primary, width: 3)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(children: [
          Icon(icon, size: 20, color: TwamboColors.secondary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.manrope(
                        fontSize: 14, fontWeight: FontWeight.w600, color: textColor)),
                if (subtitle != null)
                  Text(subtitle!,
                      style: GoogleFonts.manrope(
                          fontSize: 11, color: TwamboColors.textSecondary)),
              ],
            ),
          ),
          if (trailing != null) trailing!
          else if (onTap != null)
            const Icon(Icons.chevron_right, size: 18, color: TwamboColors.textSecondary),
        ]),
      ),
    );
  }
}

class _SavedLocationTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final KitwePlace? place;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const _SavedLocationTile({
    required this.icon, required this.label, required this.place,
    required this.isDark, required this.onTap, required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : TwamboColors.textPrimary;
    final hasPlace = place != null;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 1),
        decoration: BoxDecoration(
          color: bg,
          border: Border(
            left: BorderSide(
              color: hasPlace ? TwamboColors.success : TwamboColors.primary,
              width: 3,
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(children: [
          Icon(icon, size: 20,
              color: hasPlace ? TwamboColors.success : TwamboColors.secondary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.manrope(
                        fontSize: 14, fontWeight: FontWeight.w600, color: textColor)),
                Text(
                  hasPlace ? place!.name : 'Tap to set',
                  style: GoogleFonts.manrope(
                      fontSize: 11,
                      color: hasPlace
                          ? TwamboColors.success
                          : TwamboColors.textSecondary),
                ),
              ],
            ),
          ),
          if (hasPlace)
            GestureDetector(
              onTap: onClear,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.close, size: 16, color: TwamboColors.textSecondary),
              ),
            )
          else
            const Icon(Icons.add, size: 18, color: TwamboColors.textSecondary),
        ]),
      ),
    );
  }
}

class _EditField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final TextInputType keyboardType;
  final bool isDark;

  const _EditField({
    required this.ctrl, required this.label, required this.icon,
    this.keyboardType = TextInputType.text, required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      style: GoogleFonts.manrope(
          fontSize: 14,
          color: isDark ? Colors.white : TwamboColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.manrope(
            fontSize: 12, color: TwamboColors.textSecondary),
        prefixIcon: Icon(icon, size: 18, color: TwamboColors.textSecondary),
        filled: true,
        fillColor: isDark ? const Color(0xFF2A2A2A) : TwamboColors.surfaceAlt,
        border: OutlineInputBorder(
          borderSide: BorderSide(color: TwamboColors.line),
          borderRadius: BorderRadius.circular(4),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: TwamboColors.line),
          borderRadius: BorderRadius.circular(4),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: TwamboColors.primary, width: 2),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}

class _AboutLine extends StatelessWidget {
  final IconData icon;
  final String text;
  const _AboutLine(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: TwamboColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
              style: GoogleFonts.manrope(
                  fontSize: 13,
                  color: isDark ? Colors.white70 : TwamboColors.textSecondary,
                  height: 1.5)),
        ),
      ],
    );
  }
}
