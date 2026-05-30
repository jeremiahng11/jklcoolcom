import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/scheduled_task.dart';
import '../providers/instances_provider.dart';
import '../providers/resource_providers.dart';
import 'action_runner.dart';
import 'async_value_view.dart';
import 'empty_state.dart';

/// Lists, creates and deletes scheduled (cron) tasks for a resource.
/// [kind] is the API segment: `applications` or `services`.
class ScheduledTasksEditor extends ConsumerWidget {
  const ScheduledTasksEditor({
    super.key,
    required this.kind,
    required this.uuid,
  });

  final String kind;
  final String uuid;

  EnvKey get _key => (kind: kind, uuid: uuid);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(scheduledTasksProvider(_key));
    return Scaffold(
      body: AsyncValueView<List<ScheduledTask>>(
        value: tasks,
        onRetry: () => ref.invalidate(scheduledTasksProvider(_key)),
        data: (list) {
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.schedule_outlined,
              title: 'No scheduled tasks',
              message: 'Run a command on a cron schedule inside the container.',
              action: FilledButton.icon(
                onPressed: () => _edit(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Add task'),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(scheduledTasksProvider(_key)),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final t = list[i];
                return Card(
                  child: ListTile(
                    leading: Icon(
                      t.enabled
                          ? Icons.timer_outlined
                          : Icons.timer_off_outlined,
                    ),
                    title: Text(t.name),
                    subtitle: Text(
                      [
                        if (t.frequency.isNotEmpty) t.frequency,
                        if (t.command.isNotEmpty) t.command,
                      ].join('  ·  '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _delete(context, ref, t),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: tasks.hasValue && tasks.value!.isNotEmpty
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
    ScheduledTask t,
  ) async {
    final ok = await confirmAction(
      context,
      title: 'Delete task',
      message: 'Remove "${t.name}"?',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    final client = ref.read(coolifyClientProvider);
    if (client == null) return;
    final done = await runAction(
      context,
      action: () => client.deleteScheduledTask(kind, uuid, t.uuid),
      success: 'Task deleted',
    );
    if (done) ref.invalidate(scheduledTasksProvider(_key));
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    final command = TextEditingController();
    final frequency = TextEditingController(text: '0 0 * * *');
    final container = TextEditingController();
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
                'New scheduled task',
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: command,
                decoration: const InputDecoration(
                  labelText: 'Command',
                  hintText: 'php artisan schedule:run',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: frequency,
                decoration: const InputDecoration(
                  labelText: 'Frequency (cron)',
                  hintText: '0 0 * * *',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: container,
                decoration: const InputDecoration(
                  labelText: 'Container (optional)',
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Add task'),
              ),
            ],
          ),
        );
      },
    );
    if (saved != true || !context.mounted) return;
    if (name.text.trim().isEmpty || command.text.trim().isEmpty) return;
    final client = ref.read(coolifyClientProvider);
    if (client == null) return;
    final ok = await runAction(
      context,
      action: () => client.createScheduledTask(kind, uuid, {
        'name': name.text.trim(),
        'command': command.text.trim(),
        'frequency': frequency.text.trim(),
        if (container.text.trim().isNotEmpty)
          'container': container.text.trim(),
        'enabled': true,
      }),
      success: 'Task added',
    );
    if (ok) ref.invalidate(scheduledTasksProvider(_key));
  }
}
