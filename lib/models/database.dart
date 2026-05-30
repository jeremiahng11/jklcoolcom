import 'json_utils.dart';
import 'status.dart';

/// The eight database engines Coolify can provision.
enum DbEngine {
  postgresql('postgresql', 'PostgreSQL'),
  mysql('mysql', 'MySQL'),
  mariadb('mariadb', 'MariaDB'),
  mongodb('mongodb', 'MongoDB'),
  redis('redis', 'Redis'),
  keydb('keydb', 'KeyDB'),
  dragonfly('dragonfly', 'Dragonfly'),
  clickhouse('clickhouse', 'ClickHouse');

  const DbEngine(this.slug, this.label);

  /// Path segment used by `POST /databases/{slug}`.
  final String slug;
  final String label;

  static DbEngine? fromType(String type) {
    final t = type.toLowerCase();
    for (final e in DbEngine.values) {
      if (t.contains(e.slug)) return e;
    }
    return null;
  }
}

class CoolifyDatabase {
  const CoolifyDatabase({
    required this.uuid,
    required this.name,
    required this.description,
    required this.image,
    required this.status,
    required this.engine,
    required this.isPublic,
    required this.publicPort,
    required this.internalUrl,
    required this.externalUrl,
    required this.raw,
  });

  final String uuid;
  final String name;
  final String description;
  final String image;
  final ResourceStatus status;
  final DbEngine? engine;
  final bool isPublic;
  final int? publicPort;
  final String internalUrl;
  final String externalUrl;
  final Map<String, dynamic> raw;

  String get engineLabel => engine?.label ?? 'Database';

  factory CoolifyDatabase.fromJson(Map<String, dynamic> json) {
    final type = asStringOr(
      json['type'] ?? json['database_type'] ?? json['image'] ?? '',
    );
    return CoolifyDatabase(
      uuid: asStringOr(json['uuid']),
      name: asStringOr(json['name'], 'Database'),
      description: asStringOr(json['description']),
      image: asStringOr(json['image']),
      status: ResourceStatus.parse(asString(json['status'])),
      engine: DbEngine.fromType('$type ${asStringOr(json['image'])}'),
      isPublic: asBool(json['is_public']),
      publicPort: asInt(json['public_port']),
      internalUrl: asStringOr(json['internal_db_url']),
      externalUrl: asStringOr(json['external_db_url']),
      raw: json,
    );
  }
}
