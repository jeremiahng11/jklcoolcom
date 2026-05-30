import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/cloud.dart';
import '../../providers/instances_provider.dart';
import '../../providers/resource_providers.dart';
import '../../widgets/action_runner.dart';
import '../../widgets/async_value_view.dart';
import '../../widgets/empty_state.dart';

/// Manage stored cloud-provider API tokens (e.g. Hetzner) used to provision
/// new servers.
class CloudTokensScreen extends ConsumerWidget {
  const CloudTokensScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(cloudTokensProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cloud tokens'),
        actions: [
          IconButton(
            tooltip: 'Provision on Hetzner',
            onPressed: () => context.push('/servers/hetzner'),
            icon: const Icon(Icons.rocket_launch_outlined),
          ),
        ],
      ),
      body: AsyncValueView<List<CloudToken>>(
        value: tokens,
        onRetry: () => ref.invalidate(cloudTokensProvider),
        data: (list) {
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.cloud_outlined,
              title: 'No cloud tokens',
              message:
                  'Add a provider API token (e.g. Hetzner) to provision new '
                  'servers directly from the app.',
              action: FilledButton.icon(
                onPressed: () => _add(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Add token'),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(cloudTokensProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final t = list[i];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.vpn_lock_outlined),
                    title: Text(t.name),
                    subtitle: Text(t.provider),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Validate',
                          icon: const Icon(Icons.check_circle_outline),
                          onPressed: () => _validate(context, ref, t),
                        ),
                        IconButton(
                          tooltip: 'Delete',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _delete(context, ref, t),
                        ),
                      ],
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
        label: const Text('Add token'),
      ),
    );
  }

  Future<void> _validate(
    BuildContext context,
    WidgetRef ref,
    CloudToken t,
  ) async {
    final client = ref.read(coolifyClientProvider);
    if (client == null) return;
    await runAction(
      context,
      action: () async {
        final ok = await client.validateCloudToken(t.uuid);
        if (!ok) throw Exception('Token is invalid');
      },
      success: 'Token is valid',
      running: 'Validating…',
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    CloudToken t,
  ) async {
    final ok = await confirmAction(
      context,
      title: 'Delete token',
      message: 'Remove "${t.name}"?',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    final client = ref.read(coolifyClientProvider);
    if (client == null) return;
    final done = await runAction(
      context,
      action: () => client.deleteCloudToken(t.uuid),
      success: 'Token deleted',
    );
    if (done) ref.invalidate(cloudTokensProvider);
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    final token = TextEditingController();
    var provider = 'hetzner';
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final insets = MediaQuery.of(ctx).viewInsets.bottom;
        return StatefulBuilder(
          builder: (ctx, setLocal) => Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, insets + 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Add cloud token',
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: provider,
                  decoration: const InputDecoration(labelText: 'Provider'),
                  items: const [
                    DropdownMenuItem(value: 'hetzner', child: Text('Hetzner')),
                  ],
                  onChanged: (v) => setLocal(() => provider = v ?? 'hetzner'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: token,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'API token'),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Add token'),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (saved != true || !context.mounted) return;
    if (name.text.trim().isEmpty || token.text.trim().isEmpty) return;
    final client = ref.read(coolifyClientProvider);
    if (client == null) return;
    final ok = await runAction(
      context,
      action: () => client.createCloudToken({
        'name': name.text.trim(),
        'provider': provider,
        'token': token.text.trim(),
      }),
      success: 'Token added',
    );
    if (ok) ref.invalidate(cloudTokensProvider);
  }
}
