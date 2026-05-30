import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/storage.dart';
import '../providers/instances_provider.dart';
import '../providers/resource_providers.dart';
import 'action_runner.dart';
import 'async_value_view.dart';
import 'empty_state.dart';

/// Lists, creates and deletes persistent storages for a resource.
/// [kind] is the API segment: `applications`, `databases`, `services`.
class StorageEditor extends ConsumerWidget {
  const StorageEditor({super.key, required this.kind, required this.uuid});

  final String kind;
  final String uuid;

  EnvKey get _key => (kind: kind, uuid: uuid);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storages = ref.watch(storagesProvider(_key));
    return Scaffold(
      body: AsyncValueView<List<Storage>>(
        value: storages,
        onRetry: () => ref.invalidate(storagesProvider(_key)),
        data: (list) {
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.folder_special_outlined,
              title: 'No persistent storage',
              message: 'Add a volume to persist data across deployments.',
              action: FilledButton.icon(
                onPressed: () => _edit(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Add storage'),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(storagesProvider(_key)),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final s = list[i];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.folder_special_outlined),
                    title: Text(s.name),
                    subtitle: Text(
                      [
                        if (s.hostPath.isNotEmpty) s.hostPath,
                        if (s.mountPath.isNotEmpty) '→ ${s.mountPath}',
                      ].join('  '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _delete(context, ref, s),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: storages.hasValue && storages.value!.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () => _edit(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            )
          : null,
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Storage s) async {
    final ok = await confirmAction(
      context,
      title: 'Delete storage',
      message: 'Remove "${s.name}"? Data on the volume may be lost.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    final client = ref.read(coolifyClientProvider);
    if (client == null) return;
    final done = await runAction(
      context,
      action: () => client.deleteStorage(kind, uuid, s.uuid),
      success: 'Storage deleted',
    );
    if (done) ref.invalidate(storagesProvider(_key));
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    final mount = TextEditingController();
    final host = TextEditingController();
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
              Text('Add storage', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: mount,
                decoration: const InputDecoration(
                  labelText: 'Mount path (in container)',
                  hintText: '/data',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: host,
                decoration: const InputDecoration(
                  labelText: 'Host path (optional)',
                  hintText: 'leave blank for a managed volume',
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Add storage'),
              ),
            ],
          ),
        );
      },
    );
    if (saved != true || !context.mounted) return;
    if (mount.text.trim().isEmpty) return;
    final client = ref.read(coolifyClientProvider);
    if (client == null) return;
    final ok = await runAction(
      context,
      action: () => client.createStorage(kind, uuid, {
        'name': name.text.trim(),
        'mount_path': mount.text.trim(),
        if (host.text.trim().isNotEmpty) 'host_path': host.text.trim(),
      }),
      success: 'Storage added',
    );
    if (ok) ref.invalidate(storagesProvider(_key));
  }
}
