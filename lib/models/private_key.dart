import 'json_utils.dart';

class PrivateKey {
  const PrivateKey({
    required this.uuid,
    required this.name,
    required this.description,
    required this.publicKey,
    required this.fingerprint,
    required this.isGitRelated,
  });

  final String uuid;
  final String name;
  final String description;
  final String publicKey;
  final String fingerprint;
  final bool isGitRelated;

  factory PrivateKey.fromJson(Map<String, dynamic> json) {
    return PrivateKey(
      uuid: asStringOr(json['uuid']),
      name: asStringOr(json['name'], 'Key'),
      description: asStringOr(json['description']),
      publicKey: asStringOr(json['public_key']),
      fingerprint: asStringOr(json['fingerprint']),
      isGitRelated: asBool(json['is_git_related']),
    );
  }
}
