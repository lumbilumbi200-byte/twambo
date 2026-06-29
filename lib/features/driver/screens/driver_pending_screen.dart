import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
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
    } catch (_) {}
  }

  Future<void> _logout() async {
    await ref.read(authProvider.notifier).logout();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0D0D0D) : TwamboColors.bg;
    final user = ref.watch(authProvider).user;
    final status = user?.driverVerificationStatus ?? 'pending';
    final isRejected = status == 'rejected';

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: isRejected
            ? _RejectedView(onRefresh: _refresh, onLogout: _logout, isDark: isDark)
            : _PendingView(onRefresh: _refresh, onLogout: _logout, isDark: isDark),
      ),
    );
  }
}

// ── Pending view — upload docs + waiting state ────────────────────────────────

class _PendingView extends StatelessWidget {
  final VoidCallback onRefresh;
  final VoidCallback onLogout;
  final bool isDark;
  const _PendingView({required this.onRefresh, required this.onLogout, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : TwamboColors.textPrimary;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            color: TwamboColors.primary.withValues(alpha: 0.15),
            child: Text('PENDING REVIEW',
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 10, fontWeight: FontWeight.w800,
                    color: TwamboColors.accent, letterSpacing: 1.6)),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: const BoxDecoration(
                border: Border(left: BorderSide(color: TwamboColors.primary, width: 4))),
            padding: const EdgeInsets.only(left: 16),
            child: Text('Driver\nOnboarding',
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 28, fontWeight: FontWeight.w800,
                    color: textColor, height: 1.1)),
          ),
          const SizedBox(height: 8),
          Text('Upload all documents below. Once submitted, our team will review and approve your account.',
              style: GoogleFonts.manrope(
                  fontSize: 13, color: TwamboColors.textSecondary, height: 1.5)),
          const SizedBox(height: 28),
          _DocumentUploadCard(isDark: isDark),
          const SizedBox(height: 28),
          GestureDetector(
            onTap: onRefresh,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.refresh, size: 16, color: TwamboColors.textSecondary),
              const SizedBox(width: 6),
              Text('Check approval status',
                  style: GoogleFonts.manrope(fontSize: 13, color: TwamboColors.textSecondary)),
            ]),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: onLogout,
              child: Text('Log out',
                  style: GoogleFonts.manrope(
                      fontSize: 13, color: TwamboColors.textSecondary,
                      decoration: TextDecoration.underline)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Document upload card ──────────────────────────────────────────────────────

class _DocumentUploadCard extends ConsumerStatefulWidget {
  final bool isDark;
  const _DocumentUploadCard({required this.isDark});

  @override
  ConsumerState<_DocumentUploadCard> createState() => _DocumentUploadCardState();
}

class _DocumentUploadCardState extends ConsumerState<_DocumentUploadCard> {
  final _picker = ImagePicker();
  final Map<String, File?> _files = {
    'national_id': null,
    'drivers_license': null,
    'vehicle_registration': null,
    'plate_photo': null,
    'fitness_certificate': null,
    'insurance_certificate': null,
  };

  bool _loading = false;
  bool _submitted = false;
  String? _error;

  static const _labels = {
    'national_id':            'NRC (National ID)',
    'drivers_license':        "Driver's Licence",
    'vehicle_registration':   'Vehicle Registration',
    'plate_photo':            'Number Plate Photo',
    'fitness_certificate':    'Fitness Certificate',
    'insurance_certificate':  'Insurance Certificate',
  };

  static const _icons = {
    'national_id':            Icons.badge_outlined,
    'drivers_license':        Icons.credit_card_outlined,
    'vehicle_registration':   Icons.description_outlined,
    'plate_photo':            Icons.directions_car_outlined,
    'fitness_certificate':    Icons.verified_outlined,
    'insurance_certificate':  Icons.shield_outlined,
  };

  Future<void> _pick(String field) async {
    final xf = await _picker.pickImage(
        source: ImageSource.gallery, imageQuality: 80);
    if (xf == null) return;
    setState(() => _files[field] = File(xf.path));
  }

  bool get _allSelected => _files.values.every((f) => f != null);

  Future<void> _submit() async {
    if (!_allSelected) {
      setState(() => _error = 'Please select all 6 documents before submitting.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final formData = FormData.fromMap({
        for (final entry in _files.entries)
          entry.key: await MultipartFile.fromFile(
              entry.value!.path, filename: '${entry.key}.jpg'),
      });
      await ApiClient.dio.patch(Endpoints.driverDocuments, data: formData);
      setState(() => _submitted = true);
    } catch (_) {
      setState(() => _error = 'Upload failed. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardBg = widget.isDark ? const Color(0xFF1A1A1A) : Colors.white;

    if (_submitted) {
      return Container(
        padding: const EdgeInsets.all(20),
        color: TwamboColors.success.withValues(alpha: 0.08),
        child: Row(children: [
          const Icon(Icons.check_circle_rounded, color: TwamboColors.success, size: 28),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Documents Submitted',
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 14, fontWeight: FontWeight.w800, color: TwamboColors.success)),
            const SizedBox(height: 4),
            Text('Our team is reviewing your application. You\'ll be notified when approved.',
                style: GoogleFonts.manrope(fontSize: 12, color: TwamboColors.textSecondary, height: 1.4)),
          ])),
        ]),
      );
    }

    return Container(
      color: cardBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE)))),
            child: Row(children: [
              Container(width: 4, height: 20, color: TwamboColors.primary),
              const SizedBox(width: 10),
              Text('Required Documents',
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 13, fontWeight: FontWeight.w800,
                      color: widget.isDark ? Colors.white : TwamboColors.textPrimary)),
              const Spacer(),
              Text('${_files.values.where((f) => f != null).length}/6',
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 12, fontWeight: FontWeight.w700,
                      color: _allSelected ? TwamboColors.success : TwamboColors.textSecondary)),
            ]),
          ),
          ..._files.keys.map((field) => _DocTile(
            label: _labels[field]!,
            icon: _icons[field]!,
            file: _files[field],
            isDark: widget.isDark,
            onTap: () => _pick(field),
          )),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(_error!,
                  style: GoogleFonts.manrope(fontSize: 12, color: TwamboColors.error)),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: GestureDetector(
              onTap: _loading ? null : _submit,
              child: Container(
                height: 48,
                color: _allSelected
                    ? TwamboColors.primary
                    : TwamboColors.primary.withValues(alpha: 0.4),
                alignment: Alignment.center,
                child: _loading
                    ? const SizedBox(height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('SUBMIT DOCUMENTS',
                        style: GoogleFonts.spaceGrotesk(
                            fontSize: 11, fontWeight: FontWeight.w800,
                            color: Colors.white, letterSpacing: 1.2)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Single document tile ──────────────────────────────────────────────────────

class _DocTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final File? file;
  final bool isDark;
  final VoidCallback onTap;
  const _DocTile({
    required this.label, required this.icon,
    required this.file, required this.isDark, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selected = file != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(
              color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F0F0))),
        ),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            color: selected
                ? TwamboColors.success.withValues(alpha: 0.1)
                : (isDark ? const Color(0xFF252525) : const Color(0xFFF5F5F5)),
            child: Icon(
              selected ? Icons.check_circle_rounded : icon,
              size: 20,
              color: selected ? TwamboColors.success : TwamboColors.textSecondary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 13, fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : TwamboColors.textPrimary)),
              Text(selected ? 'Ready to upload' : 'Tap to select photo',
                  style: GoogleFonts.manrope(
                      fontSize: 11,
                      color: selected ? TwamboColors.success : TwamboColors.textSecondary)),
            ]),
          ),
          if (selected)
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.file(file!, width: 44, height: 44, fit: BoxFit.cover),
            )
          else
            const Icon(Icons.chevron_right, size: 18, color: TwamboColors.textSecondary),
        ]),
      ),
    );
  }
}

// ── Rejected view ─────────────────────────────────────────────────────────────

class _RejectedView extends StatelessWidget {
  final VoidCallback onRefresh;
  final VoidCallback onLogout;
  final bool isDark;
  const _RejectedView({required this.onRefresh, required this.onLogout, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            color: TwamboColors.error.withValues(alpha: 0.12),
            child: Text('APPLICATION REJECTED',
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 10, fontWeight: FontWeight.w800,
                    color: TwamboColors.error, letterSpacing: 1.6)),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: const BoxDecoration(
                border: Border(left: BorderSide(color: TwamboColors.error, width: 4))),
            padding: const EdgeInsets.only(left: 16),
            child: Text('Documents\nRejected',
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 28, fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : TwamboColors.textPrimary,
                    height: 1.1)),
          ),
          const SizedBox(height: 12),
          Text('Make sure all photos are clear and legible, then resubmit.',
              style: GoogleFonts.manrope(
                  fontSize: 13, color: TwamboColors.textSecondary, height: 1.5)),
          const SizedBox(height: 28),
          _DocumentUploadCard(isDark: isDark),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: onRefresh,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.refresh, size: 16, color: TwamboColors.textSecondary),
              const SizedBox(width: 6),
              Text('Check status',
                  style: GoogleFonts.manrope(fontSize: 13, color: TwamboColors.textSecondary)),
            ]),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: onLogout,
              child: Text('Log out',
                  style: GoogleFonts.manrope(
                      fontSize: 13, color: TwamboColors.textSecondary,
                      decoration: TextDecoration.underline)),
            ),
          ),
        ],
      ),
    );
  }
}
