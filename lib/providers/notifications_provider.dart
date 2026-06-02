import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_notification.dart';
import '../services/inbox_store.dart';

/// In-app inbox of alerts raised by the monitor (persisted in shared_prefs).
class NotificationsNotifier extends Notifier<List<AppNotification>> {
  @override
  List<AppNotification> build() {
    reload();
    return const [];
  }

  /// Re-read from storage (call when the app resumes — the background monitor
  /// may have added entries).
  Future<void> reload() async {
    state = await readInbox();
  }

  Future<void> markRead(String id) async {
    state = [for (final n in state) n.id == id ? n.copyWith(read: true) : n];
    await writeInbox(state);
  }

  Future<void> markAllRead() async {
    state = [for (final n in state) n.copyWith(read: true)];
    await writeInbox(state);
  }

  Future<void> remove(String id) async {
    state = state.where((n) => n.id != id).toList();
    await writeInbox(state);
  }

  Future<void> clear() async {
    state = const [];
    await writeInbox(const []);
  }
}

final notificationsProvider =
    NotifierProvider<NotificationsNotifier, List<AppNotification>>(
      NotificationsNotifier.new,
    );

final unreadCountProvider = Provider<int>(
  (ref) => ref.watch(notificationsProvider).where((n) => !n.read).length,
);
