import 'json_utils.dart';

class Project {
  const Project({
    required this.uuid,
    required this.name,
    required this.description,
    required this.environments,
  });

  final String uuid;
  final String name;
  final String description;
  final List<Environment> environments;

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      uuid: asStringOr(json['uuid']),
      name: asStringOr(json['name'], 'Project'),
      description: asStringOr(json['description']),
      environments: asMapList(
        json['environments'],
      ).map(Environment.fromJson).toList(),
    );
  }
}

class Environment {
  const Environment({
    required this.id,
    required this.uuid,
    required this.name,
    required this.description,
  });

  final int id;
  final String uuid;
  final String name;
  final String description;

  factory Environment.fromJson(Map<String, dynamic> json) {
    return Environment(
      id: asIntOr(json['id']),
      uuid: asStringOr(json['uuid']),
      name: asStringOr(json['name'], 'production'),
      description: asStringOr(json['description']),
    );
  }
}
