import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/version_check_service.dart';
import '../theme.dart';

// ── Gate overlay (placed in MaterialApp.builder) ──────────────────────────────

class UpdateGate extends StatefulWidget {
  final Widget child;
  final VersionResult? softUpdate;
  const UpdateGate({super.key, required this.child, this.softUpdate});

  @override
  State<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends State<UpdateGate> {
  bool _dialogShown = false;

  @override
  void initState() {
    super.initState();
    if (widget.softUpdate != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShow());
    }
  }

  void _maybeShow() {
    if (_dialogShown || !mounted) return;
    _dialogShown = true;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => _SoftUpdateDialog(result: widget.softUpdate!),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

// ── Soft update dialog ────────────────────────────────────────────────────────

class _SoftUpdateDialog extends StatelessWidget {
  final VersionResult result;
  const _SoftUpdateDialog({required this.result});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Dialog(
      shape: const RoundedRectangleBorder(),
      backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            color: TwamboColors.primary,
            child: Text('UPDATE AVAILABLE',
              style: GoogleFonts.spaceGrotesk(fontSize: 9, fontWeight: FontWeight.w800,
                color: TwamboColors.textPrimary, letterSpacing: 1.5)),
          ),
          const SizedBox(height: 14),
          Text('v${result.latestVersion} is out',
            style: GoogleFonts.spaceGrotesk(fontSize: 20, fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : TwamboColors.textPrimary)),
          Text('You have v${result.currentVersion}',
            style: GoogleFonts.manrope(fontSize: 12, color: TwamboColors.textSecondary)),
          if (result.releaseNotes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(result.releaseNotes,
              style: GoogleFonts.manrope(fontSize: 13,
                color: isDark ? Colors.white70 : TwamboColors.textSecondary)),
          ],
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                color: isDark ? const Color(0xFF2A2A2A) : TwamboColors.bg,
                child: Center(child: Text('Later',
                  style: GoogleFonts.spaceGrotesk(fontSize: 13, fontWeight: FontWeight.w700,
                    color: TwamboColors.textSecondary))),
              ),
            )),
            const SizedBox(width: 8),
            Expanded(child: GestureDetector(
              onTap: () async {
                Navigator.pop(context);
                final uri = Uri.parse(result.downloadUrl);
                if (await canLaunchUrl(uri)) launchUrl(uri, mode: LaunchMode.externalApplication);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                color: TwamboColors.primary,
                child: Center(child: Text('Download',
                  style: GoogleFonts.spaceGrotesk(fontSize: 13, fontWeight: FontWeight.w800,
                    color: TwamboColors.textPrimary))),
              ),
            )),
          ]),
        ]),
      ),
    );
  }
}

// ── Force update screen (standalone, blocks the app) ─────────────────────────

class ForceUpdateScreen extends StatelessWidget {
  final VersionResult result;
  const ForceUpdateScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF0A0A0A),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                // Logo wordmark
                Text('TWMB',
                  style: GoogleFonts.spaceGrotesk(fontSize: 36, fontWeight: FontWeight.w900,
                    color: TwamboColors.primary, letterSpacing: 2)),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  color: TwamboColors.error,
                  child: Text('UPDATE REQUIRED',
                    style: GoogleFonts.spaceGrotesk(fontSize: 9, fontWeight: FontWeight.w800,
                      color: Colors.white, letterSpacing: 1.5)),
                ),
                const SizedBox(height: 16),
                Text('Your app is out of date',
                  style: GoogleFonts.spaceGrotesk(fontSize: 24, fontWeight: FontWeight.w800,
                    color: Colors.white)),
                const SizedBox(height: 10),
                Text(
                  'Version ${result.minRequiredVersion} or higher is required to use Twambo. '
                  'Please download the latest version to continue.',
                  style: GoogleFonts.manrope(fontSize: 14, color: Colors.white60, height: 1.6),
                ),
                if (result.releaseNotes.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(result.releaseNotes,
                    style: GoogleFonts.manrope(fontSize: 13, color: Colors.white38)),
                ],
                const SizedBox(height: 32),
                GestureDetector(
                  onTap: () async {
                    final uri = Uri.parse(result.downloadUrl);
                    if (await canLaunchUrl(uri)) launchUrl(uri, mode: LaunchMode.externalApplication);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    color: TwamboColors.primary,
                    child: Center(child: Text('Download v${result.latestVersion}',
                      style: GoogleFonts.spaceGrotesk(fontSize: 15, fontWeight: FontWeight.w800,
                        color: TwamboColors.textPrimary))),
                  ),
                ),
                const SizedBox(height: 12),
                Center(child: Text('v${result.currentVersion} installed — v${result.minRequiredVersion} required',
                  style: GoogleFonts.manrope(fontSize: 10, color: Colors.white24))),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
