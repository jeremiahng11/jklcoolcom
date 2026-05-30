import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/private_key.dart';
import '../../providers/instances_provider.dart';
import '../../providers/resource_providers.dart';
import '../../widgets/action_runner.dart';
import '../../widgets/async_value_view.dart';
import '../../widgets/empty_state.dart';

class PrivateKeysScreen extends ConsumerWidget {
  const PrivateKeysScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final keys = ref.watch(privateKeysProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('SSH keys')),
      body: AsyncValueView<List<PrivateKey>>(
        value: keys,
        onRetry: () => ref.invalidate(privateKeysProvider),
        data: (list) {
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.key_outlined,
              title: 'No SSH keys',
              message: 'Add a private key to connect servers or private repos.',
              action: FilledButton.icon(
                onPressed: () => _add(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Add key'),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(privateKeysProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final k = list[i];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.vpn_key_outlined),
                    title: Text(k.name),
                    subtitle: Text(
                      k.fingerprint.isNotEmpty ? k.fingerprint : k.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _delete(context, ref, k),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add key'),
      ),
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    PrivateKey k,
  ) async {
    final ok = await confirmAction(
      context,
      title: 'Delete key',
      message: 'Remove "${k.name}"?',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    final client = ref.read(coolifyClientProvider);
    if (client == null) return;
    final done = await runAction(
      context,
      action: () => client.deletePrivateKey(k.uuid),
      success: 'Key deleted',
    );
    if (done) ref.invalidate(privateKeysProvider);
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    final key = TextEditingController();
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
              Text('Add SSH key', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: key,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Private key',
                  alignLabelWithHint: true,
                  hintText: '-----BEGIN OPENSSH PRIVATE KEY-----',
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Add key'),
              ),
            ],
          ),
        );
      },
    );
    if (saved != true || !context.mounted) return;
    if (name.text.trim().isEmpty || key.text.trim().isEmpty) return;
    final client = ref.read(coolifyClientProvider);
    if (client == null) return;
    final ok = await runAction(
      context,
      action: () => client.createPrivateKey({
        'name': name.text.trim(),
        'private_key': key.text,
      }),
      success: 'Key added',
    );
    if (ok) ref.invalidate(privateKeysProvider);
  }
}
