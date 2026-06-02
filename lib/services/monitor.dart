import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_notification.dart';
import '../navigation.dart';
import 'inbox_store.dart';
import 'instance_store.dart';

const _channelId = 'alerts_channel';
const _stateKey = 'monitor_state';

final FlutterLocalNotificationsPlugin _fln = FlutterLocalNotificationsPlugin();
bool _flnReady = false;

Future<void> _ensureNotifications() async {
  if (_flnReady) return;
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  const ios = DarwinInitializationSettings();
  await _fln.initialize(
    const InitializationSettings(android: android, iOS: ios),
    onDidReceiveNotificationResponse: (resp) {
      final route = resp.payload;
      if (route != null && route.isNotEmpty) navigateFromNotification(route);
    },
  );
  await _fln
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          'Alerts',
          description: 'Deployment & resource health alerts',
          importance: Importance.high,
        ),
      );
  _flnReady = true;
}

/// Ask for notification permission (Android 13+ / iOS). Returns true if granted.
Future<bool> requestNotificationPermission() async {
  await _ensureNotifications();
  final android = _fln
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
  if (android != null) {
    return await android.requestNotificationsPermission() ?? false;
  }
  final ios = _fln
      .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin
      >();
  if (ios != null) {
    return await ios.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        ) ??
        false;
  }
  return true;
}

Future<void> _show(AppNotification n) async {
  await _ensureNotifications();
  await _fln.show(
    n.id.hashCode & 0x7fffffff,
    n.title,
    n.body,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        'Alerts',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    ),
    payload: n.route,
  );
}

Future<dynamic> _get(String url, String token) async {
  final res = await http
      .get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      )
      .timeout(const Duration(seconds: 10));
  if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
  return jsonDecode(res.body);
}

String _level(String status) {
  final s = status.toLowerCase();
  if (s == 'degraded' || s.contains('unhealthy')) return 'warning';
  if (s.startsWith('running')) return 'healthy';
  if (s.startsWith('exited') ||
      s == 'stopped' ||
      s == 'dead' ||
      s == 'paused') {
    return 'down';
  }
  return 'other';
}

String _kind(String type) {
  final t = type.toLowerCase();
  if (t.contains('application')) return 'application';
  if (t.contains('service')) return 'service';
  if (RegExp(
    'postgres|mysql|mariadb|mongodb|redis|keydb|dragonfly|clickhouse|database',
  ).hasMatch(t)) {
    return 'database';
  }
  return 'unknown';
}

/// Polls the active Coolify, diffs against the last seen state, fires local
/// notifications + inbox entries for resources going unhealthy and deployments
/// finishing/failing. Safe to call from a background isolate. The first run
/// seeds state silently.
Future<void> runMonitorCheck() async {
  final store = InstanceStore();
  final instances = await store.loadInstances();
  if (instances.isEmpty) return;
  final activeId = await store.activeInstanceId() ?? instances.first.id;
  final inst = instances.firstWhere(
    (i) => i.id == activeId,
    orElse: () => instances.first,
  );
  final token = await store.tokenFor(inst.id);
  if (token == null || token.isEmpty) return;
  final base = inst.baseUrl;

  final prefs = await SharedPreferences.getInstance();
  Map<String, dynamic> st = {};
  try {
    final raw = prefs.getString(_stateKey);
    if (raw != null) st = jsonDecode(raw) as Map<String, dynamic>;
  } catch (_) {}
  final initialized = st['initialized'] == true;
  final health = <String, String>{
    for (final e in (st['health'] as Map? ?? {}).entries)
      e.key.toString(): e.value.toString(),
  };
  final notified = <String>{
    ...((st['notified'] as List?) ?? []).map((e) => e.toString()),
  };

  final fresh = <AppNotification>[];

  // --- resource health ---
  try {
    final res = await _get('$base/resources', token);
    if (res is List) {
      final next = <String, String>{};
      for (final r in res.whereType<Map>()) {
        final uuid = (r['uuid'] ?? '').toString();
        if (uuid.isEmpty) continue;
        final lvl = _level((r['status'] ?? '').toString());
        next[uuid] = lvl;
        if (!initialized) continue;
        final was = health[uuid];
        final wasGood = was == null || was == 'healthy' || was == 'other';
        if (was != null && wasGood && (lvl == 'warning' || lvl == 'down')) {
          final name = (r['name'] ?? 'Resource').toString();
          fresh.add(
            AppNotification(
              id: 'h:$uuid:${DateTime.now().millisecondsSinceEpoch}',
              title: '$name ${lvl == 'down' ? 'is down' : 'is unhealthy'}',
              body: 'Status: ${r['status'] ?? 'unknown'}',
              route: AppNotification.routeFor(
                _kind((r['type'] ?? '').toString()),
                uuid,
              ),
              time: DateTime.now(),
              read: false,
            ),
          );
        }
      }
      st['health'] = next;
    }
  } catch (_) {}

  // --- deployments ---
  try {
    final apps = await _get('$base/applications', token);
    if (apps is List) {
      for (final a in apps.whereType<Map>()) {
        final uuid = (a['uuid'] ?? '').toString();
        if (uuid.isEmpty) continue;
        final name = (a['name'] ?? 'app').toString();
        dynamic hist;
        try {
          hist = await _get(
            '$base/deployments/applications/$uuid?take=3',
            token,
          );
        } catch (_) {
          continue;
        }
        final deps = hist is Map
            ? (hist['deployments'] as List? ?? [])
            : (hist is List ? hist : const []);
        for (final d in deps.whereType<Map>()) {
          final du = (d['deployment_uuid'] ?? '').toString();
          if (du.isEmpty) continue;
          final status = (d['status'] ?? '').toString().toLowerCase();
          final terminal =
              status == 'finished' ||
              status == 'failed' ||
              status == 'cancelled-by-user' ||
              status == 'cancelled';
          if (!terminal || notified.contains(du)) continue;
          notified.add(du);
          if (initialized) {
            final verb = status == 'finished'
                ? 'finished'
                : status == 'failed'
                ? 'failed'
                : 'cancelled';
            fresh.add(
              AppNotification(
                id: 'd:$du',
                title: 'Deploy $verb · $name',
                body: (d['commit_message'] ?? '').toString(),
                route: '/resources/app/$uuid',
                time: DateTime.now(),
                read: false,
              ),
            );
          }
        }
      }
      final notifiedList = notified.toList();
      st['notified'] = notifiedList.length > 500
          ? notifiedList.sublist(notifiedList.length - 500)
          : notifiedList;
    }
  } catch (_) {}

  st['initialized'] = true;
  await prefs.setString(_stateKey, jsonEncode(st));

  for (final n in fresh) {
    await _show(n);
  }
  await appendInbox(fresh);
}
