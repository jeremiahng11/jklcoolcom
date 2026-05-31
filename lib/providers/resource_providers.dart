import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/application.dart';
import '../models/backup.dart';
import '../models/cloud.dart';
import '../models/database.dart';
import '../models/env_var.dart';
import '../models/github_app.dart';
import '../models/private_key.dart';
import '../models/project.dart';
import '../models/resource.dart';
import '../models/scheduled_task.dart';
import '../models/server.dart';
import '../models/service.dart';
import '../models/storage.dart';
import '../models/team.dart';
import 'instances_provider.dart';

/// Unified resource list (apps + dbs + services) used by the dashboard.
final resourcesProvider = FutureProvider<List<ResourceSummary>>((ref) async {
  final client = ref.watch(coolifyClientProvider);
  if (client == null) return const [];
  return client.resources();
});

final applicationsProvider = FutureProvider<List<Application>>((ref) async {
  final client = ref.watch(coolifyClientProvider);
  if (client == null) return const [];
  return client.applications();
});

final databasesProvider = FutureProvider<List<CoolifyDatabase>>((ref) async {
  final client = ref.watch(coolifyClientProvider);
  if (client == null) return const [];
  return client.databases();
});

final servicesProvider = FutureProvider<List<CoolifyService>>((ref) async {
  final client = ref.watch(coolifyClientProvider);
  if (client == null) return const [];
  return client.services();
});

final serversProvider = FutureProvider<List<Server>>((ref) async {
  final client = ref.watch(coolifyClientProvider);
  if (client == null) return const [];
  return client.servers();
});

/// Resources (apps/dbs/services) running on a given server.
final serverResourcesProvider =
    FutureProvider.family<List<ResourceSummary>, String>((ref, uuid) async {
      final client = ref.watch(coolifyClientProvider);
      if (client == null) return const [];
      return client.serverResources(uuid);
    });

final projectsProvider = FutureProvider<List<Project>>((ref) async {
  final client = ref.watch(coolifyClientProvider);
  if (client == null) return const [];
  return client.projects();
});

final privateKeysProvider = FutureProvider<List<PrivateKey>>((ref) async {
  final client = ref.watch(coolifyClientProvider);
  if (client == null) return const [];
  return client.privateKeys();
});

final currentTeamProvider = FutureProvider<Team?>((ref) async {
  final client = ref.watch(coolifyClientProvider);
  if (client == null) return null;
  return client.currentTeam();
});

final versionProvider = FutureProvider<String>((ref) async {
  final client = ref.watch(coolifyClientProvider);
  if (client == null) return '';
  return client.version();
});

/// Environment variables for any resource. `kind` is the API segment:
/// `applications`, `databases`, or `services`.
typedef EnvKey = ({String kind, String uuid});

final envsProvider = FutureProvider.family<List<EnvVar>, EnvKey>((
  ref,
  key,
) async {
  final client = ref.watch(coolifyClientProvider);
  if (client == null) return const [];
  return client.envs(key.kind, key.uuid);
});

final storagesProvider = FutureProvider.family<List<Storage>, EnvKey>((
  ref,
  key,
) async {
  final client = ref.watch(coolifyClientProvider);
  if (client == null) return const [];
  return client.storages(key.kind, key.uuid);
});

final scheduledTasksProvider =
    FutureProvider.family<List<ScheduledTask>, EnvKey>((ref, key) async {
      final client = ref.watch(coolifyClientProvider);
      if (client == null) return const [];
      return client.scheduledTasks(key.kind, key.uuid);
    });

final databaseBackupsProvider =
    FutureProvider.family<List<DatabaseBackup>, String>((ref, uuid) async {
      final client = ref.watch(coolifyClientProvider);
      if (client == null) return const [];
      return client.databaseBackups(uuid);
    });

final githubAppsProvider = FutureProvider<List<GithubApp>>((ref) async {
  final client = ref.watch(coolifyClientProvider);
  if (client == null) return const [];
  return client.githubApps();
});

final cloudTokensProvider = FutureProvider<List<CloudToken>>((ref) async {
  final client = ref.watch(coolifyClientProvider);
  if (client == null) return const [];
  return client.cloudTokens();
});

/// Hetzner option lists, keyed by kind: `locations`, `server-types`,
/// `images`, `ssh-keys`.
final hetznerOptionsProvider =
    FutureProvider.family<List<HetznerOption>, String>((ref, kind) async {
      final client = ref.watch(coolifyClientProvider);
      if (client == null) return const [];
      return client.hetznerOptions(kind);
    });

// Per-resource detail providers (keyed by uuid).

final applicationProvider = FutureProvider.family<Application, String>((
  ref,
  uuid,
) async {
  final client = ref.watch(coolifyClientProvider);
  if (client == null) throw StateError('No active account');
  return client.application(uuid);
});

final databaseProvider = FutureProvider.family<CoolifyDatabase, String>((
  ref,
  uuid,
) async {
  final client = ref.watch(coolifyClientProvider);
  if (client == null) throw StateError('No active account');
  return client.database(uuid);
});

final serviceProvider = FutureProvider.family<CoolifyService, String>((
  ref,
  uuid,
) async {
  final client = ref.watch(coolifyClientProvider);
  if (client == null) throw StateError('No active account');
  return client.service(uuid);
});

final serverProvider = FutureProvider.family<Server, String>((ref, uuid) async {
  final client = ref.watch(coolifyClientProvider);
  if (client == null) throw StateError('No active account');
  return client.server(uuid);
});

final projectProvider = FutureProvider.family<Project, String>((
  ref,
  uuid,
) async {
  final client = ref.watch(coolifyClientProvider);
  if (client == null) throw StateError('No active account');
  return client.project(uuid);
});
