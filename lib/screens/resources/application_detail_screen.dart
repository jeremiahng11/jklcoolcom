import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/application.dart';
import '../../providers/deployments_provider.dart';
import '../../providers/instances_provider.dart';
import '../../providers/logs_provider.dart';
import '../../providers/resource_providers.dart';
import '../../widgets/action_runner.dart';
import '../../widgets/async_value_view.dart';
import '../../widgets/env_var_editor.dart';
import '../../widgets/log_console.dart';
import '../../widgets/scheduled_tasks_editor.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/storage_editor.dart';
import '../deployments/deployment_detail_screen.dart';
import 'detail_widgets.dart';

class ApplicationDetailScreen extends ConsumerWidget {
  const ApplicationDetailScreen({super.key, required this.uuid});

  final String uuid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(applicationProvider(uuid));
    return DefaultTabController(
      length: 7,
      child: Scaffold(
        appBar: AppBar(
          title: Text(app.value?.name ?? 'Application'),
          actions: [
            IconButton(
              onPressed: () => ref.invalidate(applicationProvider(uuid)),
              icon: const Icon(Icons.refresh),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Overview'),
              Tab(text: 'Environment'),
              Tab(text: 'Deployments'),
              Tab(text: 'Logs'),
              Tab(text: 'Storage'),
              Tab(text: 'Tasks'),
              Tab(text: 'Settings'),
            ],
          ),
        ),
        body: AsyncValueView<Application>(
          value: app,
          onRetry: () => ref.invalidate(applicationProvider(uuid)),
          data: (a) => TabBarView(
            children: [
              _Overview(app: a),
              EnvVarEditor(kind: 'applications', uuid: uuid),
              _Deployments(uuid: uuid),
              _Logs(uuid: uuid),
              StorageEditor(kind: 'applications', uuid: uuid),
              ScheduledTasksEditor(kind: 'applications', uuid: uuid),
              _Settings(app: a),
            ],
          ),
        ),
      ),
    );
  }
}

class _Overview extends ConsumerWidget {
  const _Overview({required this.app});
  final Application app;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(applicationProvider(app.uuid)),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DetailHeader(
            title: app.name,
            statusBadge: StatusBadge(app.status),
            actions: _AppActions(app: app),
          ),
          const SizedBox(height: 16),
          if (app.domains.isNotEmpty)
            DetailSection(
              title: 'Domains',
              children: app.domains
                  .map(
                    (d) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.link),
                      title: Text(d),
                      trailing: const Icon(Icons.open_in_new, size: 18),
                      onTap: () => _open(d),
                    ),
                  )
                  .toList(),
            ),
          DetailSection(
            title: 'Source',
            children: [
              if (app.gitRepository.isNotEmpty)
                InfoRow('Repository', app.gitRepository),
              if (app.gitBranch.isNotEmpty) InfoRow('Branch', app.gitBranch),
              if (app.gitCommitSha.isNotEmpty)
                InfoRow('Commit', app.gitCommitSha),
              if (app.dockerRegistryImageName.isNotEmpty)
                InfoRow(
                  'Image',
                  '${app.dockerRegistryImageName}:${app.dockerRegistryImageTag}',
                ),
              InfoRow(
                'Build pack',
                app.buildPack.isEmpty ? '—' : app.buildPack,
              ),
            ],
          ),
          DetailSection(
            title: 'Build & run',
            children: [
              if (app.installCommand.isNotEmpty)
                InfoRow('Install', app.installCommand),
              if (app.buildCommand.isNotEmpty)
                InfoRow('Build', app.buildCommand),
              if (app.startCommand.isNotEmpty)
                InfoRow('Start', app.startCommand),
              if (app.portsExposes.isNotEmpty)
                InfoRow('Exposed ports', app.portsExposes),
              if (app.portsMappings.isNotEmpty)
                InfoRow('Port mappings', app.portsMappings),
            ],
          ),
          DetailSection(
            title: 'Configuration',
            children: [
              InfoRow('Auto deploy', app.isAutoDeployEnabled ? 'On' : 'Off'),
              InfoRow('Force HTTPS', app.isForceHttpsEnabled ? 'On' : 'Off'),
              InfoRow(
                'Health check',
                app.healthCheckEnabled ? app.healthCheckPath : 'Disabled',
              ),
              if (app.limitsMemory.isNotEmpty)
                InfoRow('Memory limit', app.limitsMemory),
              if (app.limitsCpus.isNotEmpty)
                InfoRow('CPU limit', app.limitsCpus),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _open(String domain) async {
    final url = domain.startsWith('http') ? domain : 'https://$domain';
    final uri = Uri.tryParse(url);
    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _AppActions extends ConsumerWidget {
  const _AppActions({required this.app});
  final Application app;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.read(coolifyClientProvider);
    if (client == null) return const SizedBox.shrink();

    Future<void> run(Future<void> Function() fn, String msg) async {
      final ok = await runAction(context, action: fn, success: msg);
      if (ok) {
        ref.invalidate(applicationProvider(app.uuid));
        ref.invalidate(resourcesProvider);
      }
    }

    return ResourceActionBar(
      actions: [
        ResourceAction(
          icon: Icons.rocket_launch,
          label: 'Deploy',
          primary: true,
          onPressed: () =>
              run(() => client.deploy(uuid: app.uuid), 'Deployment triggered'),
        ),
        ResourceAction(
          icon: Icons.restart_alt,
          label: 'Restart',
          onPressed: () =>
              run(() => client.restartApplication(app.uuid), 'Restarting'),
        ),
        if (app.status.isRunning)
          ResourceAction(
            icon: Icons.stop,
            label: 'Stop',
            onPressed: () async {
              final ok = await confirmAction(
                context,
                title: 'Stop application',
                message: 'Stop "${app.name}"?',
                confirmLabel: 'Stop',
              );
              if (ok && context.mounted) {
                run(() => client.stopApplication(app.uuid), 'Stopping');
              }
            },
          )
        else
          ResourceAction(
            icon: Icons.play_arrow,
            label: 'Start',
            onPressed: () =>
                run(() => client.startApplication(app.uuid), 'Starting'),
          ),
        ResourceAction(
          icon: Icons.build,
          label: 'Rebuild',
          onPressed: () => run(
            () => client.deploy(uuid: app.uuid, force: true),
            'Forced rebuild triggered',
          ),
        ),
      ],
    );
  }
}

class _Deployments extends ConsumerWidget {
  const _Deployments({required this.uuid});
  final String uuid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(appDeploymentHistoryProvider(uuid));
    return AsyncValueView(
      value: history,
      onRetry: () => ref.invalidate(appDeploymentHistoryProvider(uuid)),
      data: (list) {
        if (list.isEmpty) {
          return const Center(child: Text('No deployments yet'));
        }
        return RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(appDeploymentHistoryProvider(uuid)),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final d = list[i];
              return Card(
                child: ListTile(
                  leading: Icon(Icons.commit, color: d.statusColor),
                  title: Text(d.statusLabel),
                  subtitle: Text(
                    [
                      if (d.durationLabel.isNotEmpty) 'took ${d.durationLabel}',
                      if (d.finishedAt != null)
                        DateFormat.MMMd().add_jm().format(
                          d.finishedAt!.toLocal(),
                        ),
                      if (d.shortCommit.isNotEmpty) d.shortCommit,
                      if (d.commitMessage.isNotEmpty) d.commitMessage,
                    ].join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => DeploymentDetailScreen(deployment: d),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _Logs extends ConsumerWidget {
  const _Logs({required this.uuid});
  final String uuid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(appLogsProvider(uuid));
    final live = !ref.watch(pausedLogsProvider).contains(uuid);
    return logs.when(
      data: (text) => LogConsole(
        text: text,
        live: live,
        onToggleLive: () => ref.read(pausedLogsProvider.notifier).toggle(uuid),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => LogConsole(text: 'Could not load logs:\n$e'),
    );
  }
}

class _Settings extends ConsumerWidget {
  const _Settings({required this.app});
  final Application app;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.read(coolifyClientProvider);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        EditableField(
          label: 'Name',
          initialValue: app.name,
          onSave: (v) => _patch(context, ref, {'name': v}),
        ),
        EditableField(
          label: 'Domains (comma-separated)',
          initialValue: app.fqdn,
          onSave: (v) => _patch(context, ref, {'domains': v}),
        ),
        EditableField(
          label: 'Git branch',
          initialValue: app.gitBranch,
          onSave: (v) => _patch(context, ref, {'git_branch': v}),
        ),
        EditableField(
          label: 'Build command',
          initialValue: app.buildCommand,
          onSave: (v) => _patch(context, ref, {'build_command': v}),
        ),
        EditableField(
          label: 'Start command',
          initialValue: app.startCommand,
          onSave: (v) => _patch(context, ref, {'start_command': v}),
        ),
        EditableField(
          label: 'Custom Docker run options',
          initialValue: (app.raw['custom_docker_run_options'] ?? '').toString(),
          onSave: (v) => _patch(context, ref, {'custom_docker_run_options': v}),
        ),
        SwitchListTile(
          title: const Text('Auto deploy on push'),
          value: app.isAutoDeployEnabled,
          onChanged: client == null
              ? null
              : (v) => _patch(context, ref, {'is_auto_deploy_enabled': v}),
        ),
        SwitchListTile(
          title: const Text('Force HTTPS'),
          value: app.isForceHttpsEnabled,
          onChanged: client == null
              ? null
              : (v) => _patch(context, ref, {'is_force_https_enabled': v}),
        ),
        const SizedBox(height: 24),
        DangerZone(
          onDelete: () => _delete(context, ref),
          label: 'Delete application',
          description:
              'Permanently delete this application, its configuration and volumes.',
        ),
      ],
    );
  }

  Future<void> _patch(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> body,
  ) async {
    final client = ref.read(coolifyClientProvider);
    if (client == null) return;
    final ok = await runAction(
      context,
      action: () => client.updateApplication(app.uuid, body),
      success: 'Saved',
    );
    if (ok) ref.invalidate(applicationProvider(app.uuid));
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final client = ref.read(coolifyClientProvider);
    if (client == null) return;
    final ok = await confirmAction(
      context,
      title: 'Delete application',
      message: 'This permanently deletes "${app.name}". Continue?',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    final done = await runAction(
      context,
      action: () => client.deleteApplication(app.uuid),
      success: 'Application deleted',
    );
    if (done && context.mounted) {
      ref.invalidate(applicationsProvider);
      ref.invalidate(resourcesProvider);
      context.pop();
    }
  }
}
