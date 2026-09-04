import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../presentation/screens/announcement_detail/announcement_detail_screen.dart';
import '../../presentation/screens/auth/auth_view_model.dart';
import '../../presentation/screens/booking_detail/booking_detail_screen.dart';
import '../../presentation/screens/community/chat_screen.dart';
import '../../presentation/screens/community/community_view_model.dart';
import '../../presentation/screens/courts/club_event_providers.dart';
import '../../presentation/screens/courts/courts_view_model.dart';
import '../router/app_router.dart';

/// Routes a tapped push notification to the screen it's about, using the
/// `type` + id fields the Cloud Functions attach as the message's `data`
/// payload (see `functions/index.js`). Called from three places that all
/// end up with that same map: a background push opened via
/// `FirebaseMessaging.onMessageOpenedApp`, a terminated-app cold start via
/// `getInitialMessage()`, and a foreground push shown as a local
/// notification (Android only) via its tap payload.
Future<void> handleNotificationTap(WidgetRef ref, Map<String, dynamic> data) async {
  final context = rootNavigatorKey.currentContext;
  debugPrint('NotificationNav: handleNotificationTap data=$data context=$context');
  if (context == null) return;

  switch (data['type']) {
    case 'message':
      await _openConversation(ref, context, data['conversationId'] as String?);
    case 'broadcast':
      await _openBroadcast(ref, context, data['broadcastId'] as String?);
    case 'club_event':
      await _openClubEvent(ref, context, data['eventId'] as String?);
    case 'booking_created':
    case 'booking_cancelled':
    case 'booking_reminder':
      await _openBooking(ref, context, data['bookingId'] as String?);
  }
}

Future<void> _openConversation(
  WidgetRef ref,
  BuildContext context,
  String? conversationId,
) async {
  if (conversationId == null) return;
  final currentUserId = ref.read(currentUserProvider).valueOrNull?.id;
  if (currentUserId == null) {
    debugPrint('NotificationNav: _openConversation aborted, no current user yet');
    return;
  }

  final participantIds = await ref
      .read(messageRepositoryProvider)
      .participantIdsForConversation(conversationId);
  debugPrint('NotificationNav: _openConversation participantIds=$participantIds');
  if (participantIds == null || !context.mounted) return;

  final otherIds = participantIds.where((id) => id != currentUserId).toList();
  final users = ref.read(allUsersProvider).valueOrNull ?? const [];
  final otherNames = otherIds
      .map((id) => users.where((u) => u.id == id).firstOrNull?.name ?? 'Joueur')
      .toList();
  final isGroup = otherIds.length > 1;

  Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute(
      builder: (_) => ChatScreen(
        conversationId: conversationId,
        otherParticipantIds: otherIds,
        title: otherNames.isEmpty ? 'Conversation' : otherNames.join(', '),
        avatarInitials: isGroup || otherNames.isEmpty ? null : _initialsOf(otherNames.first),
      ),
    ),
  );
}

Future<void> _openBroadcast(
  WidgetRef ref,
  BuildContext context,
  String? broadcastId,
) async {
  if (broadcastId == null) return;
  final currentUserId = ref.read(currentUserProvider).valueOrNull?.id;
  if (currentUserId == null) {
    debugPrint('NotificationNav: _openBroadcast aborted, no current user yet');
    return;
  }

  final announcement = await ref.read(broadcastRepositoryProvider).getById(broadcastId);
  debugPrint('NotificationNav: _openBroadcast announcement=$announcement');
  if (announcement == null || !context.mounted) return;

  Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute(
      builder: (_) => AnnouncementDetailScreen(
        announcement: announcement,
        currentUserId: currentUserId,
      ),
    ),
  );
}

Future<void> _openClubEvent(
  WidgetRef ref,
  BuildContext context,
  String? eventId,
) async {
  if (eventId == null) return;
  final event = await ref.read(clubEventRepositoryProvider).getById(eventId);
  debugPrint('NotificationNav: _openClubEvent event=$event');
  if (event == null || !context.mounted) return;
  context.push('/event/${event.id}', extra: event);
}

Future<void> _openBooking(
  WidgetRef ref,
  BuildContext context,
  String? bookingId,
) async {
  if (bookingId == null) return;
  final booking = await ref.read(bookingRepositoryProvider).getById(bookingId);
  debugPrint('NotificationNav: _openBooking booking=$booking');
  if (booking == null || !context.mounted) return;

  Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute(builder: (_) => BookingDetailScreen(booking: booking)),
  );
}

String _initialsOf(String name) {
  final parts = name.trim().split(' ');
  if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  return parts.isEmpty || parts[0].isEmpty ? '?' : parts[0][0].toUpperCase();
}
