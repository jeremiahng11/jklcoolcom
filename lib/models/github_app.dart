import 'json_utils.dart';

/// A connected GitHub App, usable as a source for private-repo apps.
class GithubApp {
  const GithubApp({
    required this.id,
    required this.uuid,
    required this.name,
    required this.organization,
  });

  final int id;
  final String uuid;
  final String name;
  final String organization;

  factory GithubApp.fromJson(Map<String, dynamic> json) {
    return GithubApp(
      id: asIntOr(json['id']),
      uuid: asStringOr(json['uuid']),
      name: asStringOr(json['name'], 'GitHub App'),
      organization: asStringOr(json['organization']),
    );
  }
}
