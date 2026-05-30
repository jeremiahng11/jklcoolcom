import 'json_utils.dart';

/// A persistent storage (volume / bind mount) attached to a resource.
class Storage {
  const Storage({
    required this.uuid,
    required this.name,
    required this.mountPath,
    required this.hostPath,
  });

  final String uuid;
  final String name;
  final String mountPath;
  final String hostPath;

  factory Storage.fromJson(Map<String, dynamic> json) {
    return Storage(
      uuid: asStringOr(json['uuid']),
      name: asStringOr(json['name'], 'volume'),
      mountPath: asStringOr(json['mount_path']),
      hostPath: asStringOr(json['host_path']),
    );
  }
}
