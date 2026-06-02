import 'json_utils.dart';

/// A received push notification stored in the in-app inbox.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.route,
    required this.time,
    required this.read,
  });

  final String id;
  final String title;
  final String body;

  /// In-app route to open when tapped (from the message's data payload).
  final String? route;
  final DateTime time;
  final bool read;

  AppNotification copyWith({bool? read}) => AppNotification(
    id: id,
    title: title,
    body: body,
    route: route,
    time: time,
    read: read ?? this.read,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'route': route,
    'time': time.toIso8601String(),
    'read': read,
  };

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
    id: asStringOr(j['id']),
    title: asStringOr(j['title'], 'Notification'),
    body: asStringOr(j['body']),
    route: j['route'] as String?,
    time: asDate(j['time']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    read: asBool(j['read']),
  );

  /// Maps an FCM data payload to an in-app route. Supports an explicit `route`
  /// key, or `type` + `uuid` (e.g. type=application, uuid=…).
  static String? routeFromData(Map<String, dynamic> data) {
    final explicit = data['route'];
    if (explicit is String && explicit.trim().isNotEmpty) {
      return explicit.trim();
    }

    final type = asStringOr(data['type'] ?? data['kind']).toLowerCase();
    final uuid = asStringOr(data['uuid']);
    if (uuid.isNotEmpty) {
      if (type.contains('application') || type == 'app') {
        return '/resources/app/$uuid';
      }
      if (type.contains('database') || type == 'db') {
        return '/resources/db/$uuid';
      }
      if (type.contains('service')) return '/resources/service/$uuid';
      if (type.contains('server')) return '/servers/$uuid';
      if (type.contains('project')) return '/projects/$uuid';
    }
    if (type.contains('deploy')) return '/deployments';
    if (type.contains('server')) return '/servers';
    return null;
  }
}
