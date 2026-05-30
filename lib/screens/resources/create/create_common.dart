import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/project.dart';
import '../../../models/server.dart';
import '../../../providers/resource_providers.dart';

/// The deployment target chosen by the user: which server, project and
/// environment a new resource is created in.
class DeploymentTarget {
  const DeploymentTarget({
    this.serverUuid,
    this.projectUuid,
    this.environmentName,
    this.environmentUuid,
  });

  final String? serverUuid;
  final String? projectUuid;
  final String? environmentName;
  final String? environmentUuid;

  bool get isComplete =>
      serverUuid != null &&
      projectUuid != null &&
      (environmentName != null || environmentUuid != null);

  DeploymentTarget copyWith({
    String? serverUuid,
    String? projectUuid,
    String? environmentName,
    String? environmentUuid,
    bool clearEnv = false,
  }) {
    return DeploymentTarget(
      serverUuid: serverUuid ?? this.serverUuid,
      projectUuid: projectUuid ?? this.projectUuid,
      environmentName: clearEnv
          ? null
          : (environmentName ?? this.environmentName),
      environmentUuid: clearEnv
          ? null
          : (environmentUuid ?? this.environmentUuid),
    );
  }

  Map<String, dynamic> toBody() => {
    if (serverUuid != null) 'server_uuid': serverUuid,
    if (projectUuid != null) 'project_uuid': projectUuid,
    if (environmentName != null) 'environment_name': environmentName,
    if (environmentUuid != null) 'environment_uuid': environmentUuid,
  };
}

/// Lets the user pick a server, project and environment. Reports changes via
/// [onChanged].
class TargetSelector extends ConsumerWidget {
  const TargetSelector({
    super.key,
    required this.target,
    required this.onChanged,
  });

  final DeploymentTarget target;
  final ValueChanged<DeploymentTarget> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servers = ref.watch(serversProvider);
    final projects = ref.watch(projectsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        servers.when(
          data: (list) => DropdownButtonFormField<String>(
            initialValue: target.serverUuid,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Server',
              prefixIcon: Icon(Icons.dns_outlined),
            ),
            items: list
                .map(
                  (Server s) => DropdownMenuItem(
                    value: s.uuid,
                    child: Text(s.name, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: (v) => onChanged(target.copyWith(serverUuid: v)),
          ),
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('Failed to load servers: $e'),
        ),
        const SizedBox(height: 12),
        projects.when(
          data: (list) => DropdownButtonFormField<String>(
            initialValue: target.projectUuid,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Project',
              prefixIcon: Icon(Icons.folder_outlined),
            ),
            items: list
                .map(
                  (Project p) => DropdownMenuItem(
                    value: p.uuid,
                    child: Text(p.name, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: (v) {
              onChanged(target.copyWith(projectUuid: v, clearEnv: true));
            },
          ),
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('Failed to load projects: $e'),
        ),
        const SizedBox(height: 12),
        if (target.projectUuid != null)
          _EnvironmentDropdown(
            projectUuid: target.projectUuid!,
            selectedUuid: target.environmentUuid,
            onChanged: (env) => onChanged(
              target.copyWith(
                environmentName: env.name,
                environmentUuid: env.uuid,
              ),
            ),
          ),
      ],
    );
  }
}

class _EnvironmentDropdown extends ConsumerWidget {
  const _EnvironmentDropdown({
    required this.projectUuid,
    required this.selectedUuid,
    required this.onChanged,
  });

  final String projectUuid;
  final String? selectedUuid;
  final ValueChanged<Environment> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(projectProvider(projectUuid));
    return project.when(
      data: (p) {
        final envs = p.environments;
        if (envs.isEmpty) {
          return const Text('This project has no environments.');
        }
        return DropdownButtonFormField<String>(
          initialValue: selectedUuid,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Environment',
            prefixIcon: Icon(Icons.layers_outlined),
          ),
          items: envs
              .map((e) => DropdownMenuItem(value: e.uuid, child: Text(e.name)))
              .toList(),
          onChanged: (v) {
            final env = envs.firstWhere((e) => e.uuid == v);
            onChanged(env);
          },
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('Failed to load environments: $e'),
    );
  }
}
