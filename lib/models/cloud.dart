import 'json_utils.dart';

/// A stored cloud-provider API token (e.g. Hetzner) used for provisioning.
class CloudToken {
  const CloudToken({
    required this.uuid,
    required this.name,
    required this.provider,
  });

  final String uuid;
  final String name;
  final String provider;

  factory CloudToken.fromJson(Map<String, dynamic> json) {
    return CloudToken(
      uuid: asStringOr(json['uuid']),
      name: asStringOr(json['name'], 'Token'),
      provider: asStringOr(json['provider'] ?? json['type'], 'hetzner'),
    );
  }
}

/// A generic option returned by the Hetzner helper endpoints (locations,
/// server-types, images, ssh-keys).
class HetznerOption {
  const HetznerOption({required this.id, required this.label});

  final String id;
  final String label;

  factory HetznerOption.fromJson(Map<String, dynamic> json) {
    final id = asString(json['id'] ?? json['name']) ?? '';
    final label =
        asString(
          json['description'] ?? json['name'] ?? json['city'] ?? json['id'],
        ) ??
        id;
    return HetznerOption(id: id, label: label);
  }
}
