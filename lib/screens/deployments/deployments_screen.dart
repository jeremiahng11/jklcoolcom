import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/deployment.dart';
import '../../providers/deployments_provider.dart';
import '../../providers/instances_provider.dart';
import '../../widgets/account_action.dart';
import '../../widgets/action_runner.dart';
import '../../widgets/async_value_view.dart';
import '../../widgets/auto_refresh.dart';
import '../../widgets/empty_state.dart';
import 'deployment_detail_screen.dart';

enum DeployFilter { all, running, finished, failed }

extension on DeployFilter {
  String get label => switch (this) {
    DeployFilter.all => 'All',
    DeployFilter.running => 'Running',
    DeployFilter.finished => 'Finished',
    DeployFilter.failed => 'Failed',
  };
}

class DeploymentsScreen extends ConsumerStatefulWidget {
  const DeploymentsScreen({super.key});

  @override
  ConsumerState<DeploymentsScreen> createState() => _DeploymentsScreenState();
}

class _DeploymentsScreenState extends ConsumerState<DeploymentsScreen>
    with AutoRefreshMixin {
  DeployFilter _filter = DeployFilter.all;

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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final f in DeployFilter.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(f.label),
                        selected: _filter == f,
                        onSelected: (_) => setState(() => _filter = f),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
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
          final runningUuids = runningList.map((d) => d.deploymentUuid).toSet();
          final history = recentList
              .where((d) => !runningUuids.contains(d.deploymentUuid))
              .toList();

          final showRunning =
              _filter == DeployFilter.all || _filter == DeployFilter.running;
          final filteredHistory = switch (_filter) {
            DeployFilter.all => history,
            DeployFilter.running => const <Deployment>[],
            DeployFilter.finished =>
              history.where((d) => d.status == DeployState.finished).toList(),
            DeployFilter.failed =>
              history
                  .where(
                    (d) =>
                        d.status == DeployState.failed ||
                        d.status == DeployState.cancelled,
                  )
                  .toList(),
          };

          if ((!showRunning || runningList.isEmpty) &&
              filteredHistory.isEmpty) {
            return EmptyState(
              icon: Icons.rocket_launch_outlined,
              title: _filter == DeployFilter.all
                  ? 'No deployments yet'
                  : 'Nothing matches “${_filter.label}”',
              message: _filter == DeployFilter.all
                  ? 'Deploy an app and it will show here — live while running, '
                        'then in the history below.'
                  : 'Try a different filter.',
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
                if (showRunning && runningList.isNotEmpty) ...[
                  const _SectionLabel('Running'),
                  const SizedBox(height: 8),
                  ...runningList.map(
                    (d) => _DeploymentTile(deployment: d, running: true),
                  ),
                  const SizedBox(height: 16),
                ],
                if (filteredHistory.isNotEmpty) ...[
                  if (_filter == DeployFilter.all)
                    const _SectionLabel('Recent'),
                  if (_filter == DeployFilter.all) const SizedBox(height: 8),
                  ...filteredHistory.map((d) => _DeploymentTile(deployment: d)),
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

class _DeploymentTile extends ConsumerWidget {
  const _DeploymentTile({required this.deployment, this.running = false});

  final Deployment deployment;
  final bool running;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = deployment;
    final theme = Theme.of(context);

    // Line 1: status + commit (+ trigger source).
    final line1 = [
      d.statusLabel,
      if (d.shortCommit.isNotEmpty) d.shortCommit,
      if (d.isWebhook) 'webhook' else if (d.isApi) 'api',
    ].join(' · ');

    // Line 2: finished time + duration (the requested info), always visible.
    final String line2;
    if (running) {
      line2 = 'Started ${_fmt(d.createdAt)}';
    } else if (d.finishedAt != null) {
      line2 = d.durationLabel.isNotEmpty
          ? 'Finished ${_fmt(d.finishedAt)} · took ${d.durationLabel}'
          : 'Finished ${_fmt(d.finishedAt)}';
    } else {
      line2 = _fmt(d.updatedAt ?? d.createdAt);
    }

    final canRedeploy = !running && d.appUuid.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: ListTile(
          isThreeLine: true,
          leading: running
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: d.statusColor,
                  ),
                )
              : Icon(Icons.circle, size: 14, color: d.statusColor),
          title: Text(
            d.applicationName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 2),
              Text(line1, maxLines: 1, overflow: TextOverflow.ellipsis),
              Row(
                children: [
                  Icon(
                    running ? Icons.timelapse : Icons.schedule,
                    size: 13,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      line2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          trailing: PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'logs') _openLogs(context);
              if (v == 'redeploy') _redeploy(context, ref);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'logs', child: Text('View logs')),
              if (canRedeploy)
                const PopupMenuItem(value: 'redeploy', child: Text('Redeploy')),
            ],
          ),
          onTap: () => _openLogs(context),
        ),
      ),
    );
  }

  void _openLogs(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DeploymentDetailScreen(uuid: deployment.deploymentUuid),
      ),
    );
  }

  Future<void> _redeploy(BuildContext context, WidgetRef ref) async {
    final client = ref.read(coolifyClientProvider);
    if (client == null) return;
    final ok = await confirmAction(
      context,
      title: 'Redeploy',
      message: 'Trigger a new deployment of ${deployment.applicationName}?',
      confirmLabel: 'Redeploy',
    );
    if (!ok || !context.mounted) return;
    final done = await runAction(
      context,
      action: () => client.deploy(uuid: deployment.appUuid),
      success: 'Deployment triggered',
    );
    if (done) {
      ref.invalidate(runningDeploymentsProvider);
      ref.invalidate(recentDeploymentsProvider);
    }
  }

  static String _fmt(DateTime? t) =>
      t == null ? '—' : DateFormat.MMMd().add_jm().format(t.toLocal());
}
