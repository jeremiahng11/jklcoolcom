import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_notification.dart';

/// Shared persistence for the notifications inbox, used by both the UI provider
/// and the monitor (which may run in a background isolate).
const _key = 'notifications_inbox';
const _max = 50;

Future<List<AppNotification>> readInbox() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_key);
  if (raw == null || raw.isEmpty) return [];
  try {
    final list = jsonDecode(raw) as List;
    return list
        .whereType<Map<String, dynamic>>()
        .map(AppNotification.fromJson)
        .toList();
  } catch (_) {
    return [];
  }
}

Future<void> writeInbox(List<AppNotification> items) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    _key,
    jsonEncode(items.map((e) => e.toJson()).toList()),
  );
}

/// Prepend [items] (skipping ids already present), capped to the most recent.
Future<void> appendInbox(List<AppNotification> items) async {
  if (items.isEmpty) return;
  final existing = await readInbox();
  final ids = existing.map((e) => e.id).toSet();
  final fresh = items.where((i) => !ids.contains(i.id)).toList();
  if (fresh.isEmpty) return;
  final next = [...fresh, ...existing];
  await writeInbox(next.length > _max ? next.sublist(0, _max) : next);
}
