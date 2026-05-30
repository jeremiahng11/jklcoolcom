import 'json_utils.dart';
import 'status.dart';

/// Coarse category of a Coolify resource, used for routing + iconography.
enum ResourceKind { application, database, service, unknown }

/// A unified entry from `GET /resources` (apps + databases + services across
/// the team). Just enough to render the dashboard and route into a detail
/// screen; full data is fetched per-resource on demand.
class ResourceSummary {
  const ResourceSummary({
    required this.uuid,
    required this.name,
    required this.rawType,
    required this.kind,
    required this.status,
  });

  final String uuid;
  final String name;
  final String rawType;
  final ResourceKind kind;
  final ResourceStatus status;

  factory ResourceSummary.fromJson(Map<String, dynamic> json) {
    final rawType = asStringOr(
      json['type'] ?? json['resource_type'] ?? json['__model_type'] ?? '',
    );
    return ResourceSummary(
      uuid: asStringOr(json['uuid']),
      name: asStringOr(json['name'], 'Unnamed'),
      rawType: rawType,
      kind: kindFromType(rawType),
      status: ResourceStatus.parse(asString(json['status'])),
    );
  }

  static ResourceKind kindFromType(String type) {
    final t = type.toLowerCase();
    if (t.contains('application')) return ResourceKind.application;
    if (t.contains('service')) return ResourceKind.service;
    if (t.contains('postgresql') ||
        t.contains('mysql') ||
        t.contains('mariadb') ||
        t.contains('mongodb') ||
        t.contains('redis') ||
        t.contains('keydb') ||
        t.contains('dragonfly') ||
        t.contains('clickhouse') ||
        t.contains('database')) {
      return ResourceKind.database;
    }
    return ResourceKind.unknown;
  }

  /// A friendly engine/type label, e.g. "PostgreSQL", "Application".
  String get typeLabel {
    final t = rawType.toLowerCase();
    if (t.contains('postgresql')) return 'PostgreSQL';
    if (t.contains('mysql')) return 'MySQL';
    if (t.contains('mariadb')) return 'MariaDB';
    if (t.contains('mongodb')) return 'MongoDB';
    if (t.contains('redis')) return 'Redis';
    if (t.contains('keydb')) return 'KeyDB';
    if (t.contains('dragonfly')) return 'Dragonfly';
    if (t.contains('clickhouse')) return 'ClickHouse';
    if (kind == ResourceKind.application) return 'Application';
    if (kind == ResourceKind.service) return 'Service';
    return rawType.isEmpty ? 'Resource' : rawType;
  }
}
