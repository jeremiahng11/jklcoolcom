import 'json_utils.dart';

/// A notification raised by the in-app monitor, kept in the inbox.
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

  /// In-app route to open when tapped (e.g. `/resources/app/<uuid>`).
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

  /// In-app route for a resource of [kind] with [uuid].
  static String? routeFor(String kind, String uuid) {
    if (uuid.isEmpty) return null;
    switch (kind) {
      case 'application':
        return '/resources/app/$uuid';
      case 'database':
        return '/resources/db/$uuid';
      case 'service':
        return '/resources/service/$uuid';
    }
    return null;
  }
}
