import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_notification.dart';

/// In-app inbox of received notifications, persisted locally (capped).
class NotificationsNotifier extends Notifier<List<AppNotification>> {
  static const _key = 'notifications_inbox';
  static const _max = 50;

  @override
  List<AppNotification> build() {
    _load();
    return const [];
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return;
    try {
      final list = jsonDecode(raw) as List;
      state = list
          .whereType<Map<String, dynamic>>()
          .map(AppNotification.fromJson)
          .toList();
    } catch (_) {}
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(state.map((n) => n.toJson()).toList()),
    );
  }

  void add(AppNotification n) {
    // Avoid duplicates (same id, e.g. foreground + opened of the same message).
    if (state.any((e) => e.id == n.id)) return;
    final next = [n, ...state];
    state = next.length > _max ? next.sublist(0, _max) : next;
    _persist();
  }

  void markRead(String id) {
    state = [for (final n in state) n.id == id ? n.copyWith(read: true) : n];
    _persist();
  }

  void markAllRead() {
    state = [for (final n in state) n.copyWith(read: true)];
    _persist();
  }

  void remove(String id) {
    state = state.where((n) => n.id != id).toList();
    _persist();
  }

  void clear() {
    state = const [];
    _persist();
  }
}

final notificationsProvider =
    NotifierProvider<NotificationsNotifier, List<AppNotification>>(
      NotificationsNotifier.new,
    );

final unreadCountProvider = Provider<int>(
  (ref) => ref.watch(notificationsProvider).where((n) => !n.read).length,
);
