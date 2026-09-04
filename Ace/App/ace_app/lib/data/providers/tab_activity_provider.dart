import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tracks, per device (SharedPreferences, not Firestore), the last time the
/// user opened the Annonces/Messages tabs — used to show a "new activity"
/// dot on the tab itself until they look at it.
class TabActivityState {
  final DateTime? lastSeenAnnouncements;
  final DateTime? lastSeenMessages;

  const TabActivityState({this.lastSeenAnnouncements, this.lastSeenMessages});
}

class TabActivityNotifier extends StateNotifier<TabActivityState> {
  TabActivityNotifier() : super(const TabActivityState()) {
    _load();
  }

  static const _announcementsKey = 'lastSeenAnnouncementsAt';
  static const _messagesKey = 'lastSeenMessagesAt';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final a = prefs.getString(_announcementsKey);
    final m = prefs.getString(_messagesKey);
    if (!mounted) return;
    state = TabActivityState(
      lastSeenAnnouncements: a != null ? DateTime.tryParse(a) : null,
      lastSeenMessages: m != null ? DateTime.tryParse(m) : null,
    );
  }

  Future<void> markAnnouncementsSeen() async {
    final now = DateTime.now();
    state = TabActivityState(
      lastSeenAnnouncements: now,
      lastSeenMessages: state.lastSeenMessages,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_announcementsKey, now.toIso8601String());
  }

  Future<void> markMessagesSeen() async {
    final now = DateTime.now();
    state = TabActivityState(
      lastSeenAnnouncements: state.lastSeenAnnouncements,
      lastSeenMessages: now,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_messagesKey, now.toIso8601String());
  }
}

final tabActivityProvider =
    StateNotifierProvider<TabActivityNotifier, TabActivityState>(
      (ref) => TabActivityNotifier(),
    );
