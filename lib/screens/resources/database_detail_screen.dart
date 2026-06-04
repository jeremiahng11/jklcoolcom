import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/database.dart';
import '../../providers/instances_provider.dart';
import '../../providers/resource_providers.dart';
import '../../widgets/action_runner.dart';
import '../../widgets/async_value_view.dart';
import '../../widgets/backups_editor.dart';
import '../../widgets/env_var_editor.dart';
import '../../widgets/open_terminal_button.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/storage_editor.dart';
import 'detail_widgets.dart';

class DatabaseDetailScreen extends ConsumerWidget {
  const DatabaseDetailScreen({super.key, required this.uuid});

  final String uuid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider(uuid));
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: Text(db.value?.name ?? 'Database'),
          actions: [
            const OpenTerminalButton(),
            IconButton(
              onPressed: () => ref.invalidate(databaseProvider(uuid)),
              icon: const Icon(Icons.refresh),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Overview'),
              Tab(text: 'Environment'),
              Tab(text: 'Backups'),
              Tab(text: 'Storage'),
              Tab(text: 'Settings'),
            ],
          ),
        ),
        body: AsyncValueView<CoolifyDatabase>(
          value: db,
          onRetry: () => ref.invalidate(databaseProvider(uuid)),
          data: (d) => TabBarView(
            children: [
              _Overview(db: d),
              EnvVarEditor(kind: 'databases', uuid: uuid),
              BackupsEditor(uuid: uuid),
              StorageEditor(kind: 'databases', uuid: uuid),
              _Settings(db: d),
            ],
          ),
        ),
      ),
    );
  }
}

class _Overview extends ConsumerWidget {
  const _Overview({required this.db});
  final CoolifyDatabase db;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.read(coolifyClientProvider);

    Future<void> run(Future<void> Function() fn, String msg) async {
      final ok = await runAction(context, action: fn, success: msg);
      if (ok) {
        ref.invalidate(databaseProvider(db.uuid));
        ref.invalidate(resourcesProvider);
      }
    }

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(databaseProvider(db.uuid)),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DetailHeader(
            title: db.name,
            subtitle: db.engineLabel,
            statusBadge: StatusBadge(db.status),
            actions: client == null
                ? const SizedBox.shrink()
                : ResourceActionBar(
                    actions: [
                      if (db.status.isRunning)
                        ResourceAction(
                          icon: Icons.stop,
                          label: 'Stop',
                          onPressed: () async {
                            final ok = await confirmAction(
                              context,
                              title: 'Stop database',
                              message: 'Stop "${db.name}"?',
                              confirmLabel: 'Stop',
                            );
                            if (ok && context.mounted) {
                              run(
                                () => client.stopDatabase(db.uuid),
                                'Stopping',
                              );
                            }
                          },
                        )
                      else
                        ResourceAction(
                          icon: Icons.play_arrow,
                          label: 'Start',
                          primary: true,
                          onPressed: () => run(
                            () => client.startDatabase(db.uuid),
                            'Starting',
                          ),
                        ),
                      ResourceAction(
                        icon: Icons.restart_alt,
                        label: 'Restart',
                        onPressed: () => run(
                          () => client.restartDatabase(db.uuid),
                          'Restarting',
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          DetailSection(
            title: 'Details',
            children: [
              InfoRow('Engine', db.engineLabel),
              if (db.image.isNotEmpty) InfoRow('Image', db.image),
              InfoRow('Public', db.isPublic ? 'Yes' : 'No'),
              if (db.publicPort != null)
                InfoRow('Public port', '${db.publicPort}'),
            ],
          ),
          DetailSection(
            title: 'Connection',
            children: [
              if (db.internalUrl.isNotEmpty)
                InfoRow('Internal URL', db.internalUrl),
              if (db.externalUrl.isNotEmpty)
                InfoRow('External URL', db.externalUrl),
              if (db.internalUrl.isEmpty && db.externalUrl.isEmpty)
                const Text(
                  'Connection strings require a token with read:sensitive scope.',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Settings extends ConsumerWidget {
  const _Settings({required this.db});
  final CoolifyDatabase db;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        EditableField(
          label: 'Name',
          initialValue: db.name,
          onSave: (v) => _patch(context, ref, {'name': v}),
        ),
        EditableField(
          label: 'Description',
          initialValue: db.description,
          onSave: (v) => _patch(context, ref, {'description': v}),
        ),
        SwitchListTile(
          title: const Text('Publicly accessible'),
          subtitle: const Text('Expose this database on a public port'),
          value: db.isPublic,
          onChanged: (v) => _patch(context, ref, {'is_public': v}),
        ),
        const Divider(height: 32),
        Text('Health check', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Health check enabled'),
          subtitle: const Text('Probe the database container for liveness'),
          value: db.healthCheckEnabled,
          onChanged: (v) => _patch(context, ref, {'health_check_enabled': v}),
        ),
        const SizedBox(height: 8),
        EditableField(
          label: 'Interval (seconds)',
          initialValue: '${db.healthCheckInterval}',
          onSave: (v) => _patchInt(context, ref, 'health_check_interval', v),
        ),
        EditableField(
          label: 'Timeout (seconds)',
          initialValue: '${db.healthCheckTimeout}',
          onSave: (v) => _patchInt(context, ref, 'health_check_timeout', v),
        ),
        EditableField(
          label: 'Retries',
          initialValue: '${db.healthCheckRetries}',
          onSave: (v) => _patchInt(context, ref, 'health_check_retries', v),
        ),
        EditableField(
          label: 'Start period (seconds)',
          initialValue: '${db.healthCheckStartPeriod}',
          onSave: (v) =>
              _patchInt(context, ref, 'health_check_start_period', v),
        ),
        const SizedBox(height: 24),
        DangerZone(
          label: 'Delete database',
          description: 'Permanently delete this database and its data volumes.',
          onDelete: () => _delete(context, ref),
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
      action: () => client.updateDatabase(db.uuid, body),
      success: 'Saved',
    );
    if (ok) ref.invalidate(databaseProvider(db.uuid));
  }

  Future<void> _patchInt(
    BuildContext context,
    WidgetRef ref,
    String key,
    String value,
  ) async {
    final n = int.tryParse(value.trim());
    if (n == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter a whole number.')));
      return;
    }
    await _patch(context, ref, {key: n});
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final client = ref.read(coolifyClientProvider);
    if (client == null) return;
    final ok = await confirmAction(
      context,
      title: 'Delete database',
      message: 'This permanently deletes "${db.name}" and its data. Continue?',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    final done = await runAction(
      context,
      action: () => client.deleteDatabase(db.uuid),
      success: 'Database deleted',
    );
    if (done && context.mounted) {
      ref.invalidate(databasesProvider);
      ref.invalidate(resourcesProvider);
      context.pop();
    }
  }
}
