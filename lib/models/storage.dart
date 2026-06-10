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
    // Persistent storages use mount_path/host_path; file storages use fs_path.
    final mount = asStringOr(json['mount_path']).isNotEmpty
        ? asStringOr(json['mount_path'])
        : asStringOr(json['fs_path']);
    final name = asStringOr(json['name']).isNotEmpty
        ? asStringOr(json['name'])
        : (mount.isNotEmpty ? mount.split('/').last : 'volume');
    return Storage(
      uuid: asStringOr(json['uuid']),
      name: name,
      mountPath: mount,
      hostPath: asStringOr(json['host_path']),
    );
  }
}
