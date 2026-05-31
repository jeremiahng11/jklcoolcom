import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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
  Duration get refreshInterval => const Duration(seconds: 10);

  @override
  void onAutoRefresh() {
    ref.invalidate(runningDeploymentsProvider);
    ref.invalidate(recentDeploymentsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final running = ref.watch(runningDeploymentsProvider);
    final recent = ref.watch(recentDeploymentsProvider);

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
        value: recent,
        loadingLabel: 'Loading deployments…',
        onRetry: () {
          ref.invalidate(recentDeploymentsProvider);
          ref.invalidate(runningDeploymentsProvider);
        },
        data: (recentList) {
          final runningList = running.value ?? const <Deployment>[];
          // Avoid showing the same deployment in both sections.
          final runningUuids = runningList.map((d) => d.deploymentUuid).toSet();
          final history = recentList
              .where((d) => !runningUuids.contains(d.deploymentUuid))
              .toList();

          if (runningList.isEmpty && history.isEmpty) {
            return const EmptyState(
              icon: Icons.rocket_launch_outlined,
              title: 'No deployments yet',
              message:
                  'Deploy an app and it will show here — live while running, '
                  'then in the history below.',
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(runningDeploymentsProvider);
              ref.invalidate(recentDeploymentsProvider);
              await ref.read(recentDeploymentsProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                if (runningList.isNotEmpty) ...[
                  const _SectionLabel('Running'),
                  const SizedBox(height: 8),
                  ...runningList.map(
                    (d) => _DeploymentTile(deployment: d, running: true),
                  ),
                  const SizedBox(height: 16),
                ],
                if (history.isNotEmpty) ...[
                  const _SectionLabel('Recent'),
                  const SizedBox(height: 8),
                  ...history.map((d) => _DeploymentTile(deployment: d)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      label.toUpperCase(),
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _DeploymentTile extends StatelessWidget {
  const _DeploymentTile({required this.deployment, this.running = false});

  final Deployment deployment;
  final bool running;

  @override
  Widget build(BuildContext context) {
    final d = deployment;
    final when = d.updatedAt ?? d.createdAt;
    final subtitle = [
      d.statusLabel,
      if (d.shortCommit.isNotEmpty) d.shortCommit,
      if (when != null) DateFormat.MMMd().add_jm().format(when.toLocal()),
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: ListTile(
          leading: running
              ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: d.statusColor,
                  ),
                )
              : Icon(Icons.circle, size: 14, color: d.statusColor),
          title: Text(d.applicationName),
          subtitle: Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => DeploymentDetailScreen(uuid: d.deploymentUuid),
            ),
          ),
        ),
      ),
    );
  }
}
