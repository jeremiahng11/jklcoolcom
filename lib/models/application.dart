import 'json_utils.dart';
import 'status.dart';

class Application {
  const Application({
    required this.uuid,
    required this.name,
    required this.description,
    required this.fqdn,
    required this.gitRepository,
    required this.gitBranch,
    required this.gitCommitSha,
    required this.buildPack,
    required this.status,
    required this.installCommand,
    required this.buildCommand,
    required this.startCommand,
    required this.portsExposes,
    required this.portsMappings,
    required this.dockerRegistryImageName,
    required this.dockerRegistryImageTag,
    required this.isAutoDeployEnabled,
    required this.isForceHttpsEnabled,
    required this.healthCheckEnabled,
    required this.healthCheckPath,
    required this.limitsMemory,
    required this.limitsCpus,
    required this.createdAt,
    required this.updatedAt,
    required this.raw,
  });

  final String uuid;
  final String name;
  final String description;
  final String fqdn;
  final String gitRepository;
  final String gitBranch;
  final String gitCommitSha;
  final String buildPack;
  final ResourceStatus status;
  final String installCommand;
  final String buildCommand;
  final String startCommand;
  final String portsExposes;
  final String portsMappings;
  final String dockerRegistryImageName;
  final String dockerRegistryImageTag;
  final bool isAutoDeployEnabled;
  final bool isForceHttpsEnabled;
  final bool healthCheckEnabled;
  final String healthCheckPath;
  final String limitsMemory;
  final String limitsCpus;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Full decoded payload — lets detail screens read rarely-used fields
  /// without bloating this class.
  final Map<String, dynamic> raw;

  /// Domains the app is served on, split from the comma-separated `fqdn`.
  List<String> get domains =>
      fqdn.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  factory Application.fromJson(Map<String, dynamic> json) {
    return Application(
      uuid: asStringOr(json['uuid']),
      name: asStringOr(json['name'], 'Application'),
      description: asStringOr(json['description']),
      fqdn: asStringOr(json['fqdn']),
      gitRepository: asStringOr(json['git_repository']),
      gitBranch: asStringOr(json['git_branch']),
      gitCommitSha: asStringOr(json['git_commit_sha']),
      buildPack: asStringOr(json['build_pack']),
      status: ResourceStatus.parse(asString(json['status'])),
      installCommand: asStringOr(json['install_command']),
      buildCommand: asStringOr(json['build_command']),
      startCommand: asStringOr(json['start_command']),
      portsExposes: asStringOr(json['ports_exposes']),
      portsMappings: asStringOr(json['ports_mappings']),
      dockerRegistryImageName: asStringOr(json['docker_registry_image_name']),
      dockerRegistryImageTag: asStringOr(json['docker_registry_image_tag']),
      isAutoDeployEnabled: asBool(json['is_auto_deploy_enabled'], true),
      isForceHttpsEnabled: asBool(json['is_force_https_enabled'], true),
      healthCheckEnabled: asBool(json['health_check_enabled']),
      healthCheckPath: asStringOr(json['health_check_path'], '/'),
      limitsMemory: asStringOr(json['limits_memory']),
      limitsCpus: asStringOr(json['limits_cpus']),
      createdAt: asDate(json['created_at']),
      updatedAt: asDate(json['updated_at']),
      raw: json,
    );
  }
}
