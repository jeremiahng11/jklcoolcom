import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/application.dart';
import '../models/backup.dart';
import '../models/cloud.dart';
import '../models/database.dart';
import '../models/deployment.dart';
import '../models/env_var.dart';
import '../models/github_app.dart';
import '../models/instance.dart';
import '../models/json_utils.dart';
import '../models/private_key.dart';
import '../models/project.dart';
import '../models/resource.dart';
import '../models/scheduled_task.dart';
import '../models/server.dart';
import '../models/service.dart';
import '../models/storage.dart';
import '../models/team.dart';
import 'api_exception.dart';

/// A thin, typed wrapper over the Coolify v1 REST API, bound to a single
/// [CoolifyInstance] (base URL + bearer token).
///
/// Lifecycle endpoints (`/start`, `/stop`, `/restart`, `/deploy`, `/validate`)
/// accept GET per the OpenAPI spec, which keeps this client simple.
class CoolifyClient {
  CoolifyClient({
    required this.baseUrl,
    required this.token,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final String baseUrl;
  final String token;
  final http.Client _http;

  static const Duration _timeout = Duration(seconds: 20);

  void dispose() => _http.close();

  Map<String, String> get _headers => {
    'Authorization': 'Bearer $token',
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final clean = path.startsWith('/') ? path.substring(1) : path;
    final qp = query?.map((k, v) => MapEntry(k, v?.toString()))
      ?..removeWhere((_, v) => v == null);
    return Uri.parse('$baseUrl/$clean').replace(
      queryParameters: (qp != null && qp.isNotEmpty)
          ? qp.cast<String, String>()
          : null,
    );
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Object? body,
  }) async {
    final uri = _uri(path, query);
    try {
      late http.Response res;
      final encoded = body == null ? null : jsonEncode(body);
      switch (method) {
        case 'GET':
          res = await _http.get(uri, headers: _headers).timeout(_timeout);
          break;
        case 'POST':
          res = await _http
              .post(uri, headers: _headers, body: encoded)
              .timeout(_timeout);
          break;
        case 'PATCH':
          res = await _http
              .patch(uri, headers: _headers, body: encoded)
              .timeout(_timeout);
          break;
        case 'DELETE':
          res = await _http
              .delete(uri, headers: _headers, body: encoded)
              .timeout(_timeout);
          break;
        default:
          throw ArgumentError('Unsupported method $method');
      }

      if (res.statusCode >= 200 && res.statusCode < 300) {
        if (res.body.isEmpty) return null;
        try {
          return jsonDecode(res.body);
        } catch (_) {
          return res.body; // plain-text (e.g. /version, logs)
        }
      }
      throw ApiException.fromResponse(res.statusCode, res.body, res.headers);
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException(
        'The request timed out. Is the server reachable?',
        isNetwork: true,
      );
    } catch (e) {
      throw ApiException.network(e);
    }
  }

  List<Map<String, dynamic>> _list(dynamic data) {
    if (data is List) return data.whereType<Map<String, dynamic>>().toList();
    // Some endpoints wrap the array under `data`.
    if (data is Map && data['data'] is List) {
      return (data['data'] as List).whereType<Map<String, dynamic>>().toList();
    }
    return const [];
  }

  // ---------------------------------------------------------------------------
  // System / auth
  // ---------------------------------------------------------------------------

  Future<String> version() async {
    final data = await _send('GET', '/version');
    return data is String ? data.trim() : data.toString();
  }

  /// Validates the token by fetching the current team. Returns it on success.
  Future<Team> validateToken() => currentTeam();

  // ---------------------------------------------------------------------------
  // Teams
  // ---------------------------------------------------------------------------

  Future<List<Team>> teams() async =>
      _list(await _send('GET', '/teams')).map(Team.fromJson).toList();

  Future<Team> currentTeam() async =>
      Team.fromJson(asMap(await _send('GET', '/teams/current')));

  Future<List<TeamMember>> currentTeamMembers() async => _list(
    await _send('GET', '/teams/current/members'),
  ).map(TeamMember.fromJson).toList();

  // ---------------------------------------------------------------------------
  // Servers
  // ---------------------------------------------------------------------------

  Future<List<Server>> servers() async =>
      _list(await _send('GET', '/servers')).map(Server.fromJson).toList();

  Future<Server> server(String uuid) async =>
      Server.fromJson(asMap(await _send('GET', '/servers/$uuid')));

  Future<List<ResourceSummary>> serverResources(String uuid) async => _list(
    await _send('GET', '/servers/$uuid/resources'),
  ).map(ResourceSummary.fromJson).toList();

  Future<dynamic> validateServer(String uuid) =>
      _send('GET', '/servers/$uuid/validate');

  Future<String> createServer(Map<String, dynamic> body) async =>
      asStringOr(asMap(await _send('POST', '/servers', body: body))['uuid']);

  Future<void> updateServer(String uuid, Map<String, dynamic> body) =>
      _send('PATCH', '/servers/$uuid', body: body);

  Future<void> deleteServer(String uuid) => _send('DELETE', '/servers/$uuid');

  // ---------------------------------------------------------------------------
  // Projects & environments
  // ---------------------------------------------------------------------------

  Future<List<Project>> projects() async =>
      _list(await _send('GET', '/projects')).map(Project.fromJson).toList();

  Future<Project> project(String uuid) async =>
      Project.fromJson(asMap(await _send('GET', '/projects/$uuid')));

  Future<String> createProject(Map<String, dynamic> body) async =>
      asStringOr(asMap(await _send('POST', '/projects', body: body))['uuid']);

  Future<void> updateProject(String uuid, Map<String, dynamic> body) =>
      _send('PATCH', '/projects/$uuid', body: body);

  Future<void> deleteProject(String uuid) => _send('DELETE', '/projects/$uuid');

  Future<List<Environment>> environments(String projectUuid) async => _list(
    await _send('GET', '/projects/$projectUuid/environments'),
  ).map(Environment.fromJson).toList();

  Future<void> createEnvironment(String projectUuid, String name) => _send(
    'POST',
    '/projects/$projectUuid/environments',
    body: {'name': name},
  );

  Future<void> deleteEnvironment(String projectUuid, String envNameOrUuid) =>
      _send('DELETE', '/projects/$projectUuid/environments/$envNameOrUuid');

  // ---------------------------------------------------------------------------
  // Resources (unified)
  // ---------------------------------------------------------------------------

  Future<List<ResourceSummary>> resources() async => _list(
    await _send('GET', '/resources'),
  ).map(ResourceSummary.fromJson).toList();

  // ---------------------------------------------------------------------------
  // Applications
  // ---------------------------------------------------------------------------

  Future<List<Application>> applications({String? tag}) async => _list(
    await _send(
      'GET',
      '/applications',
      query: tag != null ? {'tag': tag} : null,
    ),
  ).map(Application.fromJson).toList();

  Future<Application> application(String uuid) async =>
      Application.fromJson(asMap(await _send('GET', '/applications/$uuid')));

  Future<void> updateApplication(String uuid, Map<String, dynamic> body) =>
      _send('PATCH', '/applications/$uuid', body: body);

  Future<void> deleteApplication(
    String uuid, {
    bool deleteConfigurations = true,
    bool deleteVolumes = true,
    bool dockerCleanup = true,
    bool deleteConnectedNetworks = false,
  }) => _send(
    'DELETE',
    '/applications/$uuid',
    query: {
      'delete_configurations': deleteConfigurations,
      'delete_volumes': deleteVolumes,
      'docker_cleanup': dockerCleanup,
      'delete_connected_networks': deleteConnectedNetworks,
    },
  );

  Future<String> appLogs(String uuid, {int lines = 200}) async {
    final data = await _send(
      'GET',
      '/applications/$uuid/logs',
      query: {'lines': lines},
    );
    return _extractLogs(data);
  }

  Future<void> startApplication(
    String uuid, {
    bool force = false,
    bool instantDeploy = false,
  }) => _send(
    'GET',
    '/applications/$uuid/start',
    query: {'force': force, 'instant_deploy': instantDeploy},
  );

  Future<void> stopApplication(String uuid) =>
      _send('GET', '/applications/$uuid/stop');

  Future<void> restartApplication(String uuid) =>
      _send('GET', '/applications/$uuid/restart');

  // App create variants.
  Future<String> createPublicApp(Map<String, dynamic> body) =>
      _createUuid('/applications/public', body);
  Future<String> createPrivateGithubApp(Map<String, dynamic> body) =>
      _createUuid('/applications/private-github-app', body);
  Future<String> createPrivateDeployKeyApp(Map<String, dynamic> body) =>
      _createUuid('/applications/private-deploy-key', body);
  Future<String> createDockerfileApp(Map<String, dynamic> body) =>
      _createUuid('/applications/dockerfile', body);
  Future<String> createDockerImageApp(Map<String, dynamic> body) =>
      _createUuid('/applications/dockerimage', body);

  // ---------------------------------------------------------------------------
  // Databases
  // ---------------------------------------------------------------------------

  Future<List<CoolifyDatabase>> databases() async => _list(
    await _send('GET', '/databases'),
  ).map(CoolifyDatabase.fromJson).toList();

  Future<CoolifyDatabase> database(String uuid) async =>
      CoolifyDatabase.fromJson(asMap(await _send('GET', '/databases/$uuid')));

  Future<void> updateDatabase(String uuid, Map<String, dynamic> body) =>
      _send('PATCH', '/databases/$uuid', body: body);

  Future<void> deleteDatabase(
    String uuid, {
    bool deleteConfigurations = true,
    bool deleteVolumes = true,
    bool dockerCleanup = true,
    bool deleteConnectedNetworks = false,
  }) => _send(
    'DELETE',
    '/databases/$uuid',
    query: {
      'delete_configurations': deleteConfigurations,
      'delete_volumes': deleteVolumes,
      'docker_cleanup': dockerCleanup,
      'delete_connected_networks': deleteConnectedNetworks,
    },
  );

  Future<void> startDatabase(String uuid) =>
      _send('GET', '/databases/$uuid/start');
  Future<void> stopDatabase(String uuid) =>
      _send('GET', '/databases/$uuid/stop');
  Future<void> restartDatabase(String uuid) =>
      _send('GET', '/databases/$uuid/restart');

  Future<String> createDatabase(DbEngine engine, Map<String, dynamic> body) =>
      _createUuid('/databases/${engine.slug}', body);

  // ---------------------------------------------------------------------------
  // Services
  // ---------------------------------------------------------------------------

  Future<List<CoolifyService>> services() async => _list(
    await _send('GET', '/services'),
  ).map(CoolifyService.fromJson).toList();

  Future<CoolifyService> service(String uuid) async =>
      CoolifyService.fromJson(asMap(await _send('GET', '/services/$uuid')));

  Future<String> createService(Map<String, dynamic> body) =>
      _createUuid('/services', body);

  Future<void> updateService(String uuid, Map<String, dynamic> body) =>
      _send('PATCH', '/services/$uuid', body: body);

  Future<void> deleteService(
    String uuid, {
    bool deleteConfigurations = true,
    bool deleteVolumes = true,
    bool dockerCleanup = true,
    bool deleteConnectedNetworks = false,
  }) => _send(
    'DELETE',
    '/services/$uuid',
    query: {
      'delete_configurations': deleteConfigurations,
      'delete_volumes': deleteVolumes,
      'docker_cleanup': dockerCleanup,
      'delete_connected_networks': deleteConnectedNetworks,
    },
  );

  Future<void> startService(String uuid) =>
      _send('GET', '/services/$uuid/start');
  Future<void> stopService(String uuid) => _send('GET', '/services/$uuid/stop');
  Future<void> restartService(String uuid) =>
      _send('GET', '/services/$uuid/restart');

  // ---------------------------------------------------------------------------
  // Environment variables (shared shape across apps/dbs/services)
  // ---------------------------------------------------------------------------

  Future<List<EnvVar>> envs(String kind, String uuid) async => _list(
    await _send('GET', '/$kind/$uuid/envs'),
  ).map(EnvVar.fromJson).toList();

  Future<void> createEnv(String kind, String uuid, Map<String, dynamic> body) =>
      _send('POST', '/$kind/$uuid/envs', body: body);

  Future<void> updateEnv(String kind, String uuid, Map<String, dynamic> body) =>
      _send('PATCH', '/$kind/$uuid/envs', body: body);

  Future<void> bulkUpdateEnvs(
    String kind,
    String uuid,
    List<Map<String, dynamic>> data,
  ) => _send('PATCH', '/$kind/$uuid/envs/bulk', body: {'data': data});

  Future<void> deleteEnv(String kind, String uuid, String envUuid) =>
      _send('DELETE', '/$kind/$uuid/envs/$envUuid');

  // ---------------------------------------------------------------------------
  // Deployments
  // ---------------------------------------------------------------------------

  Future<List<Deployment>> runningDeployments() async => _list(
    await _send('GET', '/deployments'),
  ).map(Deployment.fromJson).toList();

  Future<Deployment> deployment(String uuid) async =>
      Deployment.fromJson(asMap(await _send('GET', '/deployments/$uuid')));

  Future<void> cancelDeployment(String uuid) =>
      _send('POST', '/deployments/$uuid/cancel');

  Future<List<Deployment>> appDeploymentHistory(
    String appUuid, {
    int skip = 0,
    int take = 20,
  }) async {
    final data = await _send(
      'GET',
      '/deployments/applications/$appUuid',
      query: {'skip': skip, 'take': take},
    );
    // This endpoint wraps the list as {count, deployments: [...]}.
    final list = data is Map && data['deployments'] is List
        ? (data['deployments'] as List)
        : (data is List ? data : const []);
    return list
        .whereType<Map<String, dynamic>>()
        .map(Deployment.fromJson)
        .toList();
  }

  /// Triggers a deploy by resource uuid (or tag). Returns the deployment uuids.
  Future<List<String>> deploy({
    String? uuid,
    String? tag,
    bool force = false,
    int? pullRequestId,
  }) async {
    final data = await _send(
      'GET',
      '/deploy',
      query: {'uuid': ?uuid, 'tag': ?tag, 'force': force, 'pr': ?pullRequestId},
    );
    final deployments = asMap(data)['deployments'];
    if (deployments is List) {
      return deployments
          .whereType<Map<String, dynamic>>()
          .map((d) => asStringOr(d['deployment_uuid']))
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return const [];
  }

  // ---------------------------------------------------------------------------
  // Private keys
  // ---------------------------------------------------------------------------

  Future<List<PrivateKey>> privateKeys() async => _list(
    await _send('GET', '/security/keys'),
  ).map(PrivateKey.fromJson).toList();

  Future<String> createPrivateKey(Map<String, dynamic> body) =>
      _createUuid('/security/keys', body);

  Future<void> deletePrivateKey(String uuid) =>
      _send('DELETE', '/security/keys/$uuid');

  // ---------------------------------------------------------------------------
  // Persistent storages (shared across applications/databases/services)
  // ---------------------------------------------------------------------------

  Future<List<Storage>> storages(String kind, String uuid) async => _list(
    await _send('GET', '/$kind/$uuid/storages'),
  ).map(Storage.fromJson).toList();

  Future<void> createStorage(
    String kind,
    String uuid,
    Map<String, dynamic> body,
  ) => _send('POST', '/$kind/$uuid/storages', body: body);

  Future<void> updateStorage(
    String kind,
    String uuid,
    String storageUuid,
    Map<String, dynamic> body,
  ) => _send('PATCH', '/$kind/$uuid/storages/$storageUuid', body: body);

  Future<void> deleteStorage(String kind, String uuid, String storageUuid) =>
      _send('DELETE', '/$kind/$uuid/storages/$storageUuid');

  // ---------------------------------------------------------------------------
  // Scheduled tasks (applications & services)
  // ---------------------------------------------------------------------------

  Future<List<ScheduledTask>> scheduledTasks(String kind, String uuid) async =>
      _list(
        await _send('GET', '/$kind/$uuid/scheduled-tasks'),
      ).map(ScheduledTask.fromJson).toList();

  Future<void> createScheduledTask(
    String kind,
    String uuid,
    Map<String, dynamic> body,
  ) => _send('POST', '/$kind/$uuid/scheduled-tasks', body: body);

  Future<void> updateScheduledTask(
    String kind,
    String uuid,
    String taskUuid,
    Map<String, dynamic> body,
  ) => _send('PATCH', '/$kind/$uuid/scheduled-tasks/$taskUuid', body: body);

  Future<void> deleteScheduledTask(String kind, String uuid, String taskUuid) =>
      _send('DELETE', '/$kind/$uuid/scheduled-tasks/$taskUuid');

  Future<List<Map<String, dynamic>>> scheduledTaskExecutions(
    String kind,
    String uuid,
    String taskUuid,
  ) async => _list(
    await _send('GET', '/$kind/$uuid/scheduled-tasks/$taskUuid/executions'),
  );

  // ---------------------------------------------------------------------------
  // Database backups
  // ---------------------------------------------------------------------------

  Future<List<DatabaseBackup>> databaseBackups(String uuid) async => _list(
    await _send('GET', '/databases/$uuid/backups'),
  ).map(DatabaseBackup.fromJson).toList();

  Future<void> createDatabaseBackup(String uuid, Map<String, dynamic> body) =>
      _send('POST', '/databases/$uuid/backups', body: body);

  Future<void> updateDatabaseBackup(
    String uuid,
    String backupUuid,
    Map<String, dynamic> body,
  ) => _send('PATCH', '/databases/$uuid/backups/$backupUuid', body: body);

  Future<void> deleteDatabaseBackup(String uuid, String backupUuid) =>
      _send('DELETE', '/databases/$uuid/backups/$backupUuid');

  Future<List<Map<String, dynamic>>> backupExecutions(
    String uuid,
    String backupUuid,
  ) async => _list(
    await _send('GET', '/databases/$uuid/backups/$backupUuid/executions'),
  );

  // ---------------------------------------------------------------------------
  // GitHub apps (for private-GitHub-app deploys)
  // ---------------------------------------------------------------------------

  Future<List<GithubApp>> githubApps() async => _list(
    await _send('GET', '/github-apps'),
  ).map(GithubApp.fromJson).toList();

  Future<List<String>> githubAppRepositories(int appId) async {
    final data = await _send('GET', '/github-apps/$appId/repositories');
    final list = data is Map ? data['repositories'] : data;
    if (list is List) {
      return list
          .map((e) => e is Map ? asStringOr(e['name'] ?? e['full_name']) : '$e')
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return const [];
  }

  // ---------------------------------------------------------------------------
  // Cloud provider tokens & Hetzner provisioning (Cloud-oriented)
  // ---------------------------------------------------------------------------

  Future<List<CloudToken>> cloudTokens() async => _list(
    await _send('GET', '/cloud-tokens'),
  ).map(CloudToken.fromJson).toList();

  Future<String> createCloudToken(Map<String, dynamic> body) =>
      _createUuid('/cloud-tokens', body);

  Future<void> deleteCloudToken(String uuid) =>
      _send('DELETE', '/cloud-tokens/$uuid');

  Future<bool> validateCloudToken(String uuid) async {
    try {
      await _send('POST', '/cloud-tokens/$uuid/validate');
      return true;
    } on ApiException {
      return false;
    }
  }

  Future<List<HetznerOption>> hetznerOptions(String kind) async {
    // kind: locations | server-types | images | ssh-keys
    final data = await _send('GET', '/hetzner/$kind');
    final list = data is Map ? (data[kind] ?? data['data']) : data;
    if (list is List) {
      return list
          .whereType<Map<String, dynamic>>()
          .map(HetznerOption.fromJson)
          .toList();
    }
    return const [];
  }

  Future<String> provisionHetznerServer(Map<String, dynamic> body) =>
      _createUuid('/servers/hetzner', body);

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<String> _createUuid(String path, Map<String, dynamic> body) async =>
      asStringOr(asMap(await _send('POST', path, body: body))['uuid']);

  /// Coolify log endpoints sometimes return `{"logs": "..."}`, sometimes a raw
  /// string, sometimes a JSON array of `{output, ...}` lines.
  String _extractLogs(dynamic data) {
    if (data is String) return data;
    if (data is Map) {
      final logs = data['logs'];
      if (logs is String) return logs;
      if (logs is List) return _joinLogLines(logs);
      return data.values.join('\n');
    }
    if (data is List) return _joinLogLines(data);
    return data?.toString() ?? '';
  }

  String _joinLogLines(List<dynamic> lines) => lines
      .map((l) {
        if (l is Map) {
          return asStringOr(l['output'] ?? l['line'] ?? l['message']);
        }
        return l.toString();
      })
      .join('\n');
}
