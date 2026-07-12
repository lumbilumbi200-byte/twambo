import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/api/api_client.dart';
import '../core/api/endpoints.dart';
import 'theme.dart';

/// Shows the post-trip rating dialog.
/// Returns true if a rating was submitted, false/null otherwise.
Future<bool> showRatingDialog(
  BuildContext context, {
  required int bookingId,
  required String ratedUserName,
  required bool ratingAsDriver, // true = driver rating rider, false = rider rating driver
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _RatingDialog(
      bookingId: bookingId,
      ratedUserName: ratedUserName,
      ratingAsDriver: ratingAsDriver,
    ),
  );
  return result == true;
}

class _RatingDialog extends StatefulWidget {
  final int bookingId;
  final String ratedUserName;
  final bool ratingAsDriver;
  const _RatingDialog({
    required this.bookingId,
    required this.ratedUserName,
    required this.ratingAsDriver,
  });

  @override
  State<_RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<_RatingDialog> {
  int _stars = 0;
  final _commentCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_stars == 0) {
      setState(() => _error = 'Please select a star rating');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await ApiClient.dio.post(
        Endpoints.submitRating(widget.bookingId),
        data: {'stars': _stars, 'comment': _commentCtrl.text.trim()},
      );
      if (mounted) { Navigator.pop(context, true); }
    } catch (e) {
      if (mounted) {
        String msg = 'Could not submit — try again';
        try {
          final data = (e as dynamic).response?.data;
          if (data is Map && data['detail'] != null) msg = data['detail'].toString();
        } catch (_) {}
        setState(() { _loading = false; _error = msg; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final textColor = isDark ? Colors.white : TwamboColors.textPrimary;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.78),
        decoration: BoxDecoration(
          color: cardBg,
          border: const Border(left: BorderSide(color: TwamboColors.primary, width: 5)),
        ),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            widget.ratingAsDriver ? 'RATE YOUR RIDER' : 'RATE YOUR DRIVER',
            style: GoogleFonts.spaceGrotesk(
                fontSize: 10, fontWeight: FontWeight.w800,
                color: TwamboColors.primary, letterSpacing: 1.8),
          ),
          const SizedBox(height: 8),
          Text(widget.ratedUserName,
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 16, fontWeight: FontWeight.w800, color: textColor)),
          const SizedBox(height: 4),
          Text(
            widget.ratingAsDriver
                ? 'How was this rider on your trip?'
                : 'How was your ride experience?',
            style: GoogleFonts.manrope(fontSize: 12, color: TwamboColors.textSecondary),
          ),
          const SizedBox(height: 20),

          // Star selector — 5 × (30 + 8 pad) = 190px, fits 204px dialog width
          Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (i) {
            final filled = i < _stars;
            return GestureDetector(
              onTap: () => setState(() => _stars = i + 1),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  filled ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 30,
                  color: filled ? TwamboColors.primary : TwamboColors.line,
                ),
              ),
            );
          })),
          const SizedBox(height: 6),
          Center(child: Text(
            _stars == 0 ? 'Tap to rate' : _starLabel(_stars),
            style: GoogleFonts.spaceGrotesk(
                fontSize: 10, fontWeight: FontWeight.w700,
                color: _stars > 0 ? TwamboColors.primary : TwamboColors.textSecondary,
                letterSpacing: 1),
          )),

          const SizedBox(height: 16),

          // Comment field
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: TwamboColors.line, width: 1),
            ),
            child: TextField(
              controller: _commentCtrl,
              maxLines: 2,
              style: GoogleFonts.manrope(fontSize: 13, color: textColor),
              decoration: InputDecoration(
                hintText: 'Add a comment (optional)',
                hintStyle: GoogleFonts.manrope(fontSize: 12, color: TwamboColors.textSecondary),
                contentPadding: const EdgeInsets.all(10),
                border: InputBorder.none,
              ),
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: GoogleFonts.manrope(fontSize: 11, color: TwamboColors.error)),
          ],

          const SizedBox(height: 16),

          // Submit
          GestureDetector(
            onTap: _loading ? null : _submit,
            child: Container(
              height: 48, width: double.infinity,
              color: _stars == 0 ? TwamboColors.line : TwamboColors.primary,
              alignment: Alignment.center,
              child: _loading
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: TwamboColors.textPrimary))
                  : Text('SUBMIT RATING', style: GoogleFonts.spaceGrotesk(
                      fontSize: 11, fontWeight: FontWeight.w800,
                      color: TwamboColors.textPrimary, letterSpacing: 1)),
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => Navigator.pop(context, false),
            child: Center(child: Text('Skip for now',
                style: GoogleFonts.manrope(fontSize: 12, color: TwamboColors.textSecondary))),
          ),
        ]),
        ),
      ),
    );
  }

  String _starLabel(int s) {
    const labels = ['', 'Poor', 'Fair', 'Good', 'Great', 'Excellent!'];
    return labels[s];
  }
}
