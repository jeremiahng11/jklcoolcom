import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/backup.dart';
import '../providers/instances_provider.dart';
import '../providers/resource_providers.dart';
import 'action_runner.dart';
import 'async_value_view.dart';
import 'empty_state.dart';

/// Lists, creates and deletes scheduled backup configs for a database.
class BackupsEditor extends ConsumerWidget {
  const BackupsEditor({super.key, required this.uuid});

  final String uuid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backups = ref.watch(databaseBackupsProvider(uuid));
    return Scaffold(
      body: AsyncValueView<List<DatabaseBackup>>(
        value: backups,
        onRetry: () => ref.invalidate(databaseBackupsProvider(uuid)),
        data: (list) {
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.backup_outlined,
              title: 'No scheduled backups',
              message: 'Schedule automatic backups of this database.',
              action: FilledButton.icon(
                onPressed: () => _edit(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Add backup'),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(databaseBackupsProvider(uuid)),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final b = list[i];
                return Card(
                  child: ListTile(
                    leading: Icon(
                      b.enabled ? Icons.backup : Icons.backup_outlined,
                    ),
                    title: Text(b.frequency),
                    subtitle: Text(
                      'Keep ${b.numberOfBackupsToKeep} · '
                      '${b.enabled ? 'enabled' : 'disabled'}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _delete(context, ref, b),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: backups.hasValue && backups.value!.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () => _edit(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            )
          : null,
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    DatabaseBackup b,
  ) async {
    final ok = await confirmAction(
      context,
      title: 'Delete backup schedule',
      message: 'Remove this backup configuration?',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    final client = ref.read(coolifyClientProvider);
    if (client == null) return;
    final done = await runAction(
      context,
      action: () => client.deleteDatabaseBackup(uuid, b.uuid),
      success: 'Backup schedule deleted',
    );
    if (done) ref.invalidate(databaseBackupsProvider(uuid));
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final frequency = TextEditingController(text: '0 0 * * *');
    final keep = TextEditingController(text: '5');
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final insets = MediaQuery.of(ctx).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, insets + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'New backup schedule',
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: frequency,
                decoration: const InputDecoration(
                  labelText: 'Frequency (cron)',
                  hintText: '0 0 * * *',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: keep,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Number of backups to keep',
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Add backup'),
              ),
            ],
          ),
        );
      },
    );
    if (saved != true || !context.mounted) return;
    final client = ref.read(coolifyClientProvider);
    if (client == null) return;
    final ok = await runAction(
      context,
      action: () => client.createDatabaseBackup(uuid, {
        'enabled': true,
        'frequency': frequency.text.trim(),
        'number_of_backups_locally': int.tryParse(keep.text.trim()) ?? 5,
        'save_s3': false,
      }),
      success: 'Backup schedule added',
    );
    if (ok) ref.invalidate(databaseBackupsProvider(uuid));
  }
}
