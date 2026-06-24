import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../dev/mock_trips.dart';
import '../../../features/auth/auth_provider.dart';
import '../../../shared/driver_nav_bar.dart';
import '../../../shared/theme.dart';

class _DriverProfileData {
  final String verificationStatus;
  final bool isOnline;
  final double rating;
  final int totalTrips;
  final String? vehicleMake;
  final String? vehicleModel;
  final int? vehicleYear;
  final String? vehicleColor;
  final String? vehiclePlate;
  final String? vehicleType;

  const _DriverProfileData({
    required this.verificationStatus,
    required this.isOnline,
    required this.rating,
    required this.totalTrips,
    this.vehicleMake,
    this.vehicleModel,
    this.vehicleYear,
    this.vehicleColor,
    this.vehiclePlate,
    this.vehicleType,
  });
}

final _driverProfileDataProvider = FutureProvider<_DriverProfileData>((ref) async {
  if (kUseMockData) {
    await Future.delayed(const Duration(milliseconds: 200));
    return _DriverProfileData(
      verificationStatus: 'approved',
      isOnline: mockDriverProfile['is_online'] as bool? ?? false,
      rating: 4.8,
      totalTrips: 47,
      vehicleMake: mockVehicle['make'] as String?,
      vehicleModel: mockVehicle['model'] as String?,
      vehicleYear: 2019,
      vehicleColor: 'White',
      vehiclePlate: 'ABZ 1234',
      vehicleType: 'sedan',
    );
  }
  final profileResp = await ApiClient.dio.get(Endpoints.driverProfile);
  final profile = profileResp.data as Map<String, dynamic>;

  Map<String, dynamic>? vehicle;
  try {
    final vehicleResp = await ApiClient.dio.get(Endpoints.driverVehicle);
    vehicle = vehicleResp.data as Map<String, dynamic>?;
  } catch (_) {}

  return _DriverProfileData(
    verificationStatus: profile['verification_status'] as String? ?? 'pending',
    isOnline: profile['is_online'] as bool? ?? false,
    rating: double.parse((profile['rating'] ?? '0').toString()),
    totalTrips: profile['total_trips'] as int? ?? 0,
    vehicleMake: vehicle?['make'] as String?,
    vehicleModel: vehicle?['model'] as String?,
    vehicleYear: vehicle?['year'] as int?,
    vehicleColor: vehicle?['color'] as String?,
    vehiclePlate: vehicle?['plate_number'] as String?,
    vehicleType: vehicle?['vehicle_type'] as String?,
  );
});

class DriverProfileScreen extends ConsumerWidget {
  const DriverProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final profileAsync = ref.watch(_driverProfileDataProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0D0D0D) : TwamboColors.bg;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : TwamboColors.textPrimary;

    final initial = user?.fullName.isNotEmpty == true ? user!.fullName[0].toUpperCase() : 'D';

    return Scaffold(
      backgroundColor: bg,
      bottomNavigationBar: const DriverNavBar(currentIndex: 4),
      body: SafeArea(
        bottom: false,
        child: profileAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: TwamboColors.primary)),
          error: (e, _) => _ProfileBody(user: user, profile: null, isDark: isDark,
              initial: initial, cardBg: cardBg, textColor: textColor, bg: bg),
          data: (profile) => _ProfileBody(user: user, profile: profile, isDark: isDark,
              initial: initial, cardBg: cardBg, textColor: textColor, bg: bg),
        ),
      ),
    );
  }
}

class _ProfileBody extends ConsumerWidget {
  final dynamic user;
  final _DriverProfileData? profile;
  final bool isDark;
  final String initial;
  final Color cardBg;
  final Color textColor;
  final Color bg;

  const _ProfileBody({
    required this.user, required this.profile, required this.isDark,
    required this.initial, required this.cardBg, required this.textColor, required this.bg,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusColor = _statusColor(profile?.verificationStatus ?? 'pending');
    final statusLabel = _statusLabel(profile?.verificationStatus ?? 'pending');

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // ── Hero header ─────────────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
          decoration: BoxDecoration(
            color: cardBg,
            border: const Border(left: BorderSide(color: TwamboColors.primary, width: 4)),
          ),
          child: Row(children: [
            Container(
              width: 64, height: 64,
              color: TwamboColors.primary,
              child: Center(child: Text(initial,
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 28, fontWeight: FontWeight.w800, color: TwamboColors.textPrimary))),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(user?.fullName ?? 'Driver',
                  style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.w800, color: textColor)),
              const SizedBox(height: 3),
              Text(user?.phoneNumber ?? '',
                  style: GoogleFonts.manrope(fontSize: 13, color: TwamboColors.textSecondary)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                color: statusColor.withValues(alpha: 0.12),
                child: Text(statusLabel,
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 9, fontWeight: FontWeight.w800, color: statusColor, letterSpacing: 1.5)),
              ),
            ])),
          ]),
        ),

        const SizedBox(height: 12),

        // ── Stats row ────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Expanded(child: _StatBox(
              label: 'RATING',
              value: profile != null ? profile!.rating.toStringAsFixed(1) : '—',
              icon: Icons.star_rounded,
              iconColor: TwamboColors.primary,
              cardBg: cardBg, textColor: textColor,
            )),
            const SizedBox(width: 10),
            Expanded(child: _StatBox(
              label: 'TRIPS',
              value: profile != null ? '${profile!.totalTrips}' : '—',
              icon: Icons.route_rounded,
              iconColor: TwamboColors.secondary,
              cardBg: cardBg, textColor: textColor,
            )),
            const SizedBox(width: 10),
            Expanded(child: _StatBox(
              label: 'STATUS',
              value: profile?.isOnline == true ? 'ONLINE' : 'OFFLINE',
              icon: Icons.radio_button_checked_rounded,
              iconColor: profile?.isOnline == true ? TwamboColors.success : TwamboColors.textSecondary,
              cardBg: cardBg, textColor: textColor,
            )),
          ]),
        ),

        const SizedBox(height: 12),

        // ── Vehicle card ─────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            decoration: BoxDecoration(
              color: cardBg,
              border: Border(left: BorderSide(
                  color: profile?.vehicleMake != null ? TwamboColors.secondary : TwamboColors.line,
                  width: 4)),
            ),
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('VEHICLE', style: GoogleFonts.spaceGrotesk(
                    fontSize: 9, fontWeight: FontWeight.w800,
                    color: TwamboColors.textSecondary, letterSpacing: 2)),
                const Spacer(),
                GestureDetector(
                  onTap: () async {
                    final changed = await showModalBottomSheet<bool>(
                      context: context, isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => _VehicleEditSheet(existing: profile),
                    );
                    if (changed == true && context.mounted) {
                      ref.invalidate(_driverProfileDataProvider);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    color: TwamboColors.secondary.withValues(alpha: 0.12),
                    child: Text(
                      profile?.vehicleMake != null ? 'EDIT' : 'ADD VEHICLE',
                      style: GoogleFonts.spaceGrotesk(
                          fontSize: 9, fontWeight: FontWeight.w800,
                          color: TwamboColors.secondary, letterSpacing: 1),
                    ),
                  ),
                ),
              ]),
              if (profile?.vehicleMake != null) ...[
                const SizedBox(height: 10),
                _VehicleRow(
                  icon: Icons.directions_car_rounded,
                  label: '${profile!.vehicleMake} ${profile!.vehicleModel}'
                      '${profile!.vehicleYear != null ? ' (${profile!.vehicleYear})' : ''}',
                  textColor: textColor,
                ),
                if (profile!.vehiclePlate != null) ...[
                  const SizedBox(height: 8),
                  _VehicleRow(icon: Icons.tag_rounded, label: profile!.vehiclePlate!, textColor: textColor),
                ],
                if (profile!.vehicleColor != null) ...[
                  const SizedBox(height: 8),
                  _VehicleRow(icon: Icons.palette_outlined, label: profile!.vehicleColor!, textColor: textColor),
                ],
                if (profile!.vehicleType != null) ...[
                  const SizedBox(height: 8),
                  _VehicleRow(icon: Icons.category_outlined,
                      label: _capitalise(profile!.vehicleType!), textColor: textColor),
                ],
              ] else ...[
                const SizedBox(height: 10),
                Row(children: [
                  const Icon(Icons.directions_car_outlined, color: TwamboColors.textSecondary, size: 20),
                  const SizedBox(width: 10),
                  Text('No vehicle registered',
                      style: GoogleFonts.manrope(fontSize: 13, color: TwamboColors.textSecondary)),
                ]),
              ],
            ]),
          ),
        ),

        const SizedBox(height: 32),

        // ── Logout ────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
          child: GestureDetector(
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: cardBg,
                  title: Text('Log out', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w800, color: textColor)),
                  content: Text('Are you sure you want to log out?',
                      style: GoogleFonts.manrope(color: TwamboColors.textSecondary)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text('CANCEL', style: GoogleFonts.spaceGrotesk(
                          fontSize: 11, fontWeight: FontWeight.w700, color: TwamboColors.secondary)),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text('LOG OUT', style: GoogleFonts.spaceGrotesk(
                          fontSize: 11, fontWeight: FontWeight.w700, color: TwamboColors.error)),
                    ),
                  ],
                ),
              );
              if (confirmed == true && context.mounted) {
                await ref.read(authProvider.notifier).logout();
                if (context.mounted) context.go('/login');
              }
            },
            child: Container(
              height: 52, width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: TwamboColors.error, width: 1.5),
              ),
              child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.logout_rounded, size: 16, color: TwamboColors.error),
                const SizedBox(width: 8),
                Text('LOG OUT', style: GoogleFonts.spaceGrotesk(
                    fontSize: 12, fontWeight: FontWeight.w800,
                    color: TwamboColors.error, letterSpacing: 1)),
              ])),
            ),
          ),
        ),
      ],
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved': return TwamboColors.success;
      case 'rejected': return TwamboColors.error;
      case 'suspended': return TwamboColors.accent;
      default: return TwamboColors.secondary;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'approved': return 'APPROVED';
      case 'rejected': return 'REJECTED';
      case 'suspended': return 'SUSPENDED';
      default: return 'PENDING REVIEW';
    }
  }

  String _capitalise(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).replaceAll('_', ' ');
}

// ── Stat box ────────────────────────────────────────────────────────────────

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color cardBg;
  final Color textColor;
  const _StatBox({
    required this.label, required this.value, required this.icon,
    required this.iconColor, required this.cardBg, required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      color: cardBg,
      child: Column(children: [
        Icon(icon, size: 20, color: iconColor),
        const SizedBox(height: 6),
        Text(value, style: GoogleFonts.spaceGrotesk(
            fontSize: 16, fontWeight: FontWeight.w800, color: textColor)),
        const SizedBox(height: 3),
        Text(label, style: GoogleFonts.spaceGrotesk(
            fontSize: 8, fontWeight: FontWeight.w700,
            color: TwamboColors.textSecondary, letterSpacing: 1.5)),
      ]),
    );
  }
}

// ── Vehicle row ─────────────────────────────────────────────────────────────

class _VehicleRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color textColor;
  const _VehicleRow({required this.icon, required this.label, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 16, color: TwamboColors.secondary),
      const SizedBox(width: 10),
      Expanded(child: Text(label,
          style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w600, color: textColor))),
    ]);
  }
}

// ── Vehicle edit sheet ────────────────────────────────────────────────────────

class _VehicleEditSheet extends StatefulWidget {
  final _DriverProfileData? existing;
  const _VehicleEditSheet({this.existing});
  @override
  State<_VehicleEditSheet> createState() => _VehicleEditSheetState();
}

class _VehicleEditSheetState extends State<_VehicleEditSheet> {
  final _makeCtrl    = TextEditingController();
  final _modelCtrl   = TextEditingController();
  final _yearCtrl    = TextEditingController();
  final _colorCtrl   = TextEditingController();
  final _plateCtrl   = TextEditingController();
  final _seatsCtrl   = TextEditingController();
  String _type       = 'sedan';
  String _fuel       = 'petrol';
  bool _loading      = false;
  String? _error;

  static const _types = ['sedan', 'suv', 'minibus'];
  static const _fuels = ['petrol', 'diesel', 'electric'];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _makeCtrl.text  = e.vehicleMake  ?? '';
      _modelCtrl.text = e.vehicleModel ?? '';
      _yearCtrl.text  = e.vehicleYear?.toString() ?? '';
      _colorCtrl.text = e.vehicleColor ?? '';
      _plateCtrl.text = e.vehiclePlate ?? '';
      _type           = e.vehicleType  ?? 'sedan';
    }
  }

  @override
  void dispose() {
    for (final c in [_makeCtrl, _modelCtrl, _yearCtrl, _colorCtrl, _plateCtrl, _seatsCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_makeCtrl.text.trim().isEmpty || _modelCtrl.text.trim().isEmpty ||
        _plateCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Make, model and plate are required');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final body = <String, dynamic>{
        'vehicle_type': _type,
        'make': _makeCtrl.text.trim(),
        'model': _modelCtrl.text.trim(),
        'color': _colorCtrl.text.trim(),
        'plate_number': _plateCtrl.text.trim().toUpperCase(),
        'fuel_type': _fuel,
      };
      if (_yearCtrl.text.trim().isNotEmpty) {
        body['year'] = int.tryParse(_yearCtrl.text.trim());
      }
      if (_seatsCtrl.text.trim().isNotEmpty) {
        body['total_seats'] = int.tryParse(_seatsCtrl.text.trim());
      }
      await ApiClient.dio.patch(Endpoints.driverVehicle, data: body);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() { _loading = false; _error = 'Save failed — check your details'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final textColor = isDark ? Colors.white : TwamboColors.textPrimary;

    return Container(
      color: bg,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('VEHICLE DETAILS', style: GoogleFonts.spaceGrotesk(
                  fontSize: 14, fontWeight: FontWeight.w800, color: textColor, letterSpacing: 1)),
              const Spacer(),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ]),
            const SizedBox(height: 16),

            // Type dropdown
            Text('TYPE', style: _labelStyle),
            const SizedBox(height: 6),
            Row(children: _types.map((t) => Expanded(child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: GestureDetector(
                onTap: () => setState(() => _type = t),
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: _type == t ? TwamboColors.secondary : Colors.transparent,
                    border: Border.all(color: _type == t ? TwamboColors.secondary : TwamboColors.line),
                  ),
                  child: Center(child: Text(t.toUpperCase(), style: GoogleFonts.spaceGrotesk(
                      fontSize: 10, fontWeight: FontWeight.w800,
                      color: _type == t ? Colors.black : TwamboColors.textSecondary, letterSpacing: 1))),
                ),
              ),
            ))).toList()),
            const SizedBox(height: 14),

            _Field(label: 'MAKE (e.g. Toyota)', ctrl: _makeCtrl),
            const SizedBox(height: 12),
            _Field(label: 'MODEL (e.g. Corolla)', ctrl: _modelCtrl),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _Field(label: 'YEAR', ctrl: _yearCtrl, numeric: true)),
              const SizedBox(width: 12),
              Expanded(child: _Field(label: 'SEATS', ctrl: _seatsCtrl, numeric: true)),
            ]),
            const SizedBox(height: 12),
            _Field(label: 'COLOR', ctrl: _colorCtrl),
            const SizedBox(height: 12),
            _Field(label: 'PLATE NUMBER', ctrl: _plateCtrl),
            const SizedBox(height: 14),

            // Fuel dropdown
            Text('FUEL TYPE', style: _labelStyle),
            const SizedBox(height: 6),
            Row(children: _fuels.map((f) => Expanded(child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: GestureDetector(
                onTap: () => setState(() => _fuel = f),
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: _fuel == f ? TwamboColors.primary.withValues(alpha: 0.15) : Colors.transparent,
                    border: Border.all(color: _fuel == f ? TwamboColors.primary : TwamboColors.line),
                  ),
                  child: Center(child: Text(f.toUpperCase(), style: GoogleFonts.spaceGrotesk(
                      fontSize: 9, fontWeight: FontWeight.w800,
                      color: _fuel == f ? TwamboColors.primary : TwamboColors.textSecondary, letterSpacing: 1))),
                ),
              ),
            ))).toList()),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: GoogleFonts.manrope(fontSize: 12, color: TwamboColors.error)),
            ],

            const SizedBox(height: 20),
            GestureDetector(
              onTap: _loading ? null : _save,
              child: Container(
                height: 52, width: double.infinity,
                color: _loading ? TwamboColors.line : TwamboColors.primary,
                child: Center(child: _loading
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                    : Text('SAVE VEHICLE', style: GoogleFonts.spaceGrotesk(
                        fontSize: 13, fontWeight: FontWeight.w800,
                        color: Colors.black, letterSpacing: 1))),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  TextStyle get _labelStyle => GoogleFonts.spaceGrotesk(
      fontSize: 9, fontWeight: FontWeight.w800,
      color: TwamboColors.textSecondary, letterSpacing: 1.5);
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final bool numeric;
  const _Field({required this.label, required this.ctrl, this.numeric = false});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: GoogleFonts.spaceGrotesk(
          fontSize: 9, fontWeight: FontWeight.w800,
          color: TwamboColors.textSecondary, letterSpacing: 1.5)),
      const SizedBox(height: 6),
      TextField(
        controller: ctrl,
        keyboardType: numeric ? TextInputType.number : TextInputType.text,
        style: GoogleFonts.manrope(fontSize: 13,
            color: isDark ? Colors.white : TwamboColors.textPrimary),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.zero,
              borderSide: const BorderSide(color: TwamboColors.line)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.zero,
              borderSide: const BorderSide(color: TwamboColors.line)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.zero,
              borderSide: const BorderSide(color: TwamboColors.primary, width: 1.5)),
        ),
      ),
    ]);
  }
}
