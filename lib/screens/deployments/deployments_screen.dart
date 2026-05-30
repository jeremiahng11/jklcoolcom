import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/deployment.dart';
import '../../providers/deployments_provider.dart';
import '../../widgets/account_action.dart';
import '../../widgets/async_value_view.dart';
import '../../widgets/auto_refresh.dart';
import '../../widgets/empty_state.dart';
import 'deployment_detail_screen.dart';

class DeploymentsScreen extends ConsumerStatefulWidget {
  const DeploymentsScreen({super.key});

  @override
  ConsumerState<DeploymentsScreen> createState() => _DeploymentsScreenState();
}

class _DeploymentsScreenState extends ConsumerState<DeploymentsScreen>
    with AutoRefreshMixin {
  @override
  Duration get refreshInterval => const Duration(seconds: 8);

  @override
  void onAutoRefresh() => ref.invalidate(runningDeploymentsProvider);

  @override
  Widget build(BuildContext context) {
    final deployments = ref.watch(runningDeploymentsProvider);
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 56,
        leading: const AccountAction(),
        title: const Text('Deployments'),
        actions: [
          IconButton(onPressed: refreshNow, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: AsyncValueView<List<Deployment>>(
        value: deployments,
        onRetry: () => ref.invalidate(runningDeploymentsProvider),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.rocket_launch_outlined,
              title: 'No running deployments',
              message:
                  'Deployments you trigger appear here while they run. Pull to '
                  'refresh, or open an app to see its full history.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(runningDeploymentsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final d = list[i];
                return Card(
                  child: ListTile(
                    leading: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: d.statusColor,
                      ),
                    ),
                    title: Text(d.applicationName),
                    subtitle: Text(
                      [
                        d.statusLabel,
                        if (d.shortCommit.isNotEmpty) d.shortCommit,
                        if (d.serverName.isNotEmpty) d.serverName,
                      ].join(' · '),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            DeploymentDetailScreen(uuid: d.deploymentUuid),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
