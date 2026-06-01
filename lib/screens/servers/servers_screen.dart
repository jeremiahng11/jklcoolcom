import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/server.dart';
import '../../models/status.dart';
import '../../providers/resource_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/async_value_view.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/status_badge.dart';

class ServersScreen extends ConsumerWidget {
  const ServersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servers = ref.watch(serversProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Servers')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/servers/add'),
        icon: const Icon(Icons.add),
        label: const Text('Add server'),
      ),
      body: AsyncValueView<List<Server>>(
        value: servers,
        onRetry: () => ref.invalidate(serversProvider),
        data: (list) {
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.dns_outlined,
              title: 'No servers',
              message:
                  'Servers connected to this Coolify instance appear here.',
              action: FilledButton.icon(
                onPressed: () => context.push('/servers/add'),
                icon: const Icon(Icons.add),
                label: const Text('Add server'),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(serversProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _ServerCard(server: list[i]),
            ),
          );
        },
      ),
    );
  }
}

class _ServerCard extends StatelessWidget {
  const _ServerCard({required this.server});
  final Server server;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(
          server.isReachable ? Icons.dns_rounded : Icons.cloud_off,
          color: server.isReachable ? StatusColors.healthy : StatusColors.down,
        ),
        title: Text(server.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(server.endpoint, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(
              [
                'Port ${server.port}',
                if (server.proxyType.isNotEmpty) 'proxy: ${server.proxyType}',
                if (server.isBuildServer) 'build server',
              ].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        trailing: StatusBadge(
          ResourceStatus.parse(
            server.isReachable ? 'running:healthy' : 'exited',
          ),
          compact: true,
        ),
        onTap: () => context.push('/servers/${server.uuid}'),
        isThreeLine: true,
      ),
    );
  }
}
