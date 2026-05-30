import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/server.dart';
import '../../models/status.dart';
import '../../providers/instances_provider.dart';
import '../../providers/resource_providers.dart';
import '../../widgets/action_runner.dart';
import '../../widgets/async_value_view.dart';
import '../../widgets/status_badge.dart';
import '../resources/detail_widgets.dart';

class ServerDetailScreen extends ConsumerWidget {
  const ServerDetailScreen({super.key, required this.uuid});

  final String uuid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final server = ref.watch(serverProvider(uuid));
    return Scaffold(
      appBar: AppBar(
        title: Text(server.value?.name ?? 'Server'),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(serverProvider(uuid)),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: AsyncValueView<Server>(
        value: server,
        onRetry: () => ref.invalidate(serverProvider(uuid)),
        data: (s) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DetailHeader(
              title: s.name,
              subtitle: s.connection,
              statusBadge: StatusBadge(
                ResourceStatus.parse(
                  s.isReachable ? 'running:healthy' : 'exited',
                ),
              ),
              actions: OutlinedButton.icon(
                onPressed: () async {
                  final client = ref.read(coolifyClientProvider);
                  if (client == null) return;
                  await runAction(
                    context,
                    action: () => client.validateServer(s.uuid),
                    success: 'Validation started',
                    running: 'Validating…',
                  );
                  ref.invalidate(serverProvider(uuid));
                },
                icon: const Icon(Icons.verified_outlined, size: 18),
                label: const Text('Validate'),
              ),
            ),
            const SizedBox(height: 16),
            DetailSection(
              title: 'Connection',
              children: [
                InfoRow('IP address', s.ip),
                InfoRow('User', s.user),
                InfoRow('Port', '${s.port}'),
                if (s.proxyType.isNotEmpty) InfoRow('Proxy', s.proxyType),
              ],
            ),
            DetailSection(
              title: 'Status',
              children: [
                InfoRow('Reachable', s.isReachable ? 'Yes' : 'No'),
                InfoRow('Usable', s.isUsable ? 'Yes' : 'No'),
                InfoRow('Build server', s.isBuildServer ? 'Yes' : 'No'),
                if (s.unreachableCount > 0)
                  InfoRow('Unreachable count', '${s.unreachableCount}'),
              ],
            ),
            if (s.description.isNotEmpty)
              DetailSection(
                title: 'Description',
                children: [Text(s.description)],
              ),
          ],
        ),
      ),
    );
  }
}
