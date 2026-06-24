import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../features/auth/auth_provider.dart';
import '../../shared/theme.dart';

// ── Model + provider ──────────────────────────────────────────────────────────

class AppNotification {
  final int id;
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;
  final Map<String, dynamic> data;

  const AppNotification({
    required this.id, required this.title, required this.body,
    required this.isRead, required this.createdAt, required this.data,
  });

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['id'] as int,
        title: j['title'] as String,
        body: j['body'] as String,
        isRead: j['is_read'] as bool,
        createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
        data: (j['data'] as Map<String, dynamic>?) ?? {},
      );
}

final notificationsProvider = FutureProvider<List<AppNotification>>((ref) async {
  final resp = await ApiClient.dio.get(Endpoints.notifications);
  final raw = resp.data is List ? resp.data as List : (resp.data['results'] as List? ?? []);
  return raw.map<AppNotification>((j) => AppNotification.fromJson(j as Map<String, dynamic>)).toList();
});

// ── Screen ────────────────────────────────────────────────────────────────────

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) { return 'Just now'; }
    if (diff.inMinutes < 60) { return '${diff.inMinutes}m ago'; }
    if (diff.inHours < 24) { return '${diff.inHours}h ago'; }
    return '${diff.inDays}d ago';
  }

  IconData _iconForType(String? type) {
    switch (type) {
      case 'trip_starting': return Icons.directions_car;
      case 'trip_completed': return Icons.check_circle_outline;
      case 'ride_request_accepted': return Icons.hail_rounded;
      case 'ride_request_rejected': return Icons.cancel_outlined;
      case 'booking_confirmed': return Icons.bookmark_added_outlined;
      default: return Icons.notifications_outlined;
    }
  }

  Color _colorForType(String? type) {
    switch (type) {
      case 'trip_starting':
      case 'trip_completed':
      case 'ride_request_accepted':
      case 'booking_confirmed': return TwamboColors.success;
      case 'ride_request_rejected': return TwamboColors.error;
      default: return TwamboColors.secondary;
    }
  }

  void _onTap(BuildContext context, WidgetRef ref, AppNotification notif) async {
    if (!notif.isRead) {
      await ApiClient.dio.post(Endpoints.markRead(notif.id));
      ref.invalidate(notificationsProvider);
    }
    if (!context.mounted) { return; }
    // Deep-link based on notification type
    final type = notif.data['type'] as String?;
    final tripId = notif.data['trip_id'] as String?;
    if (tripId == null) { return; }
    final auth = ref.read(authProvider);
    if (auth.user?.isDriver == true) {
      if (type == 'trip_starting' || type == null) {
        context.go('/driver/trip/$tripId');
      }
    } else {
      if (type == 'ride_request_accepted' || type == 'booking_confirmed') {
        context.go('/bookings');
      } else if (type == 'trip_starting' || type == 'trip_completed') {
        context.go('/bookings');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifAsync = ref.watch(notificationsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0D0D0D) : TwamboColors.bg;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final auth = ref.watch(authProvider);
    final isDriver = auth.user?.isDriver == true;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          // ── Header ──────────────────────────────────────────────────────
          Container(
            color: cardBg,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Row(children: [
              GestureDetector(
                onTap: () => context.canPop() ? context.pop() : context.go(isDriver ? '/driver' : '/search'),
                child: Container(
                  width: 36, height: 36,
                  color: isDark ? const Color(0xFF2A2A2A) : TwamboColors.bg,
                  child: const Icon(Icons.arrow_back, size: 18, color: TwamboColors.textSecondary),
                ),
              ),
              const SizedBox(width: 12),
              Container(width: 4, height: 22, color: TwamboColors.primary),
              const SizedBox(width: 10),
              Expanded(child: Text('NOTIFICATIONS',
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 16, fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : TwamboColors.textPrimary))),
              notifAsync.maybeWhen(
                data: (list) {
                  final unread = list.where((n) => !n.isRead).length;
                  return Row(children: [
                    if (unread > 0)
                      Container(
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        color: TwamboColors.error,
                        child: Text('$unread NEW',
                            style: GoogleFonts.spaceGrotesk(
                                fontSize: 8, fontWeight: FontWeight.w800,
                                color: Colors.white, letterSpacing: 1)),
                      ),
                    GestureDetector(
                      onTap: () async {
                        await ApiClient.dio.post(Endpoints.markAllRead);
                        ref.invalidate(notificationsProvider);
                      },
                      child: Text('MARK ALL READ',
                          style: GoogleFonts.spaceGrotesk(
                              fontSize: 9, fontWeight: FontWeight.w700,
                              color: TwamboColors.secondary, letterSpacing: 1)),
                    ),
                  ]);
                },
                orElse: () => const SizedBox.shrink(),
              ),
            ]),
          ),

          // ── List ────────────────────────────────────────────────────────
          Expanded(
            child: notifAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: TwamboColors.primary)),
              error: (e, _) => Center(child: Text('Error: $e',
                  style: GoogleFonts.manrope(color: TwamboColors.error))),
              data: (notifications) => notifications.isEmpty
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        width: 64, height: 64,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E1E1E) : TwamboColors.surfaceAlt,
                          border: const Border(left: BorderSide(color: TwamboColors.primary, width: 3)),
                        ),
                        child: const Icon(Icons.notifications_none, size: 32, color: TwamboColors.textSecondary),
                      ),
                      const SizedBox(height: 14),
                      Text('NO NOTIFICATIONS', style: GoogleFonts.spaceGrotesk(
                          fontSize: 11, fontWeight: FontWeight.w700,
                          color: TwamboColors.textSecondary, letterSpacing: 2)),
                      const SizedBox(height: 4),
                      Text("You're all caught up",
                          style: GoogleFonts.manrope(fontSize: 12, color: TwamboColors.textSecondary)),
                    ]))
                  : RefreshIndicator(
                      color: TwamboColors.primary,
                      onRefresh: () => ref.refresh(notificationsProvider.future),
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(0, 0, 0, 80),
                        itemCount: notifications.length,
                        separatorBuilder: (_, __) => Container(
                            height: 1,
                            color: isDark ? const Color(0xFF2E2E2E) : TwamboColors.line),
                        itemBuilder: (_, i) {
                          final n = notifications[i];
                          final type = n.data['type'] as String?;
                          final accentColor = _colorForType(type);
                          return GestureDetector(
                            onTap: () => _onTap(context, ref, n),
                            child: Container(
                              color: n.isRead
                                  ? (isDark ? const Color(0xFF0D0D0D) : TwamboColors.bg)
                                  : (isDark ? const Color(0xFF1A1A1A) : Colors.white),
                              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                // Icon badge
                                Container(
                                  width: 40, height: 40,
                                  color: accentColor.withValues(alpha: 0.1),
                                  child: Icon(_iconForType(type), size: 20, color: accentColor),
                                ),
                                const SizedBox(width: 12),
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Row(children: [
                                    Expanded(child: Text(n.title,
                                        style: GoogleFonts.spaceGrotesk(
                                            fontSize: 12,
                                            fontWeight: n.isRead ? FontWeight.w600 : FontWeight.w800,
                                            color: isDark ? Colors.white : TwamboColors.textPrimary))),
                                    if (!n.isRead)
                                      Container(width: 8, height: 8,
                                          decoration: const BoxDecoration(
                                              shape: BoxShape.circle, color: TwamboColors.primary)),
                                  ]),
                                  const SizedBox(height: 3),
                                  Text(n.body,
                                      style: GoogleFonts.manrope(
                                          fontSize: 12, color: TwamboColors.textSecondary)),
                                  const SizedBox(height: 5),
                                  Text(_relativeTime(n.createdAt),
                                      style: GoogleFonts.manrope(
                                          fontSize: 10, color: TwamboColors.textSecondary,
                                          letterSpacing: 0.3)),
                                ])),
                              ]),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ),
        ]),
      ),
    );
  }
}
