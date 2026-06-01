import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/resource.dart';
import '../models/status.dart';
import '../providers/dashboard_provider.dart';
import '../providers/instances_provider.dart';
import '../providers/resource_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/account_action.dart';
import '../widgets/async_value_view.dart';
import '../widgets/auto_refresh.dart';
import '../widgets/live_metrics_card.dart';
import '../widgets/resource_card.dart';
import '../widgets/status_badge.dart';
import 'resources/resources_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with AutoRefreshMixin {
  @override
  void onAutoRefresh() {
    ref.invalidate(resourcesProvider);
    ref.invalidate(dashboardServersProvider);
  }

  @override
  Widget build(BuildContext context) {
    final active = ref.watch(activeInstanceProvider);
    final summary = ref.watch(dashboardSummaryProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 56,
        leading: const AccountAction(),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Dashboard', style: TextStyle(fontSize: 18)),
            if (active != null)
              Text(
                active.label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: refreshNow,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(resourcesProvider);
          ref.invalidate(dashboardServersProvider);
          await ref.read(resourcesProvider.future);
        },
        child: AsyncValueView<DashboardSummary>(
          value: summary,
          onRetry: () => ref.invalidate(resourcesProvider),
          loadingLabel: 'Loading your resources…',
          data: (s) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _HealthHeader(summary: s),
              const SizedBox(height: 16),
              const LiveMetricsCard(),
              const SizedBox(height: 16),
              _CountRow(summary: s),
              const SizedBox(height: 20),
              if (s.attention.isNotEmpty) ...[
                _SectionTitle('Needs attention', count: s.attention.length),
                const SizedBox(height: 8),
                ...s.attention.map(
                  (r) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ResourceCard(
                      icon: iconForKind(r.kind),
                      title: r.name,
                      subtitle: r.typeLabel,
                      status: r.status,
                      onTap: () => _openResource(context, r),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              const _ServersSection(),
              const SizedBox(height: 12),
              _QuickLinks(),
            ],
          ),
        ),
      ),
    );
  }

  void _openResource(BuildContext context, ResourceSummary r) {
    switch (r.kind) {
      case ResourceKind.application:
        context.push('/resources/app/${r.uuid}');
        break;
      case ResourceKind.database:
        context.push('/resources/db/${r.uuid}');
        break;
      case ResourceKind.service:
        context.push('/resources/service/${r.uuid}');
        break;
      case ResourceKind.unknown:
        break;
    }
  }
}

class _HealthHeader extends StatelessWidget {
  const _HealthHeader({required this.summary});
  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = summary.total;
    final healthyPct = total == 0 ? 0.0 : summary.healthy / total;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            SizedBox(
              width: 88,
              height: 88,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 88,
                    height: 88,
                    child: CircularProgressIndicator(
                      value: total == 0 ? 0 : healthyPct,
                      strokeWidth: 9,
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation(
                        summary.down > 0
                            ? StatusColors.warning
                            : StatusColors.healthy,
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${(healthyPct * 100).round()}%',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text('healthy', style: theme.textTheme.bodySmall),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$total resources',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _Pill('${summary.healthy} healthy', StatusColors.healthy),
                      if (summary.warning > 0)
                        _Pill(
                          '${summary.warning} warning',
                          StatusColors.warning,
                        ),
                      if (summary.down > 0)
                        _Pill('${summary.down} down', StatusColors.down),
                      if (summary.other > 0)
                        _Pill('${summary.other} other', StatusColors.neutral),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CountRow extends ConsumerWidget {
  const _CountRow({required this.summary});
  final DashboardSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void openTab(int tab) {
      ref.read(resourcesTabProvider.notifier).set(tab);
      context.go('/resources');
    }

    return Row(
      children: [
        Expanded(
          child: _CountTile(
            icon: Icons.rocket_launch_outlined,
            label: 'Apps',
            count: summary.applications,
            onTap: () => openTab(0),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _CountTile(
            icon: Icons.storage_rounded,
            label: 'Databases',
            count: summary.databases,
            onTap: () => openTab(1),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _CountTile(
            icon: Icons.widgets_outlined,
            label: 'Services',
            count: summary.services,
            onTap: () => openTab(2),
          ),
        ),
      ],
    );
  }
}

class _CountTile extends StatelessWidget {
  const _CountTile({
    required this.icon,
    required this.label,
    required this.count,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(height: 8),
              Text(
                '$count',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.count});
  final String title;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        if (count != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                color: theme.colorScheme.onErrorContainer,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ServersSection extends ConsumerWidget {
  const _ServersSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servers = ref.watch(dashboardServersProvider);
    return servers.maybeWhen(
      data: (list) {
        if (list.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle('Servers'),
            const SizedBox(height: 8),
            ...list.map(
              (s) => Card(
                child: ListTile(
                  isThreeLine: s.hasHardwareInfo,
                  leading: Icon(
                    s.isReachable ? Icons.dns_rounded : Icons.cloud_off,
                    color: s.isReachable
                        ? StatusColors.healthy
                        : StatusColors.down,
                  ),
                  title: Text(s.name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.connection,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (s.hasHardwareInfo)
                        Text(
                          s.hardwareSummary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                    ],
                  ),
                  trailing: StatusBadge(
                    ResourceStatus.parse(
                      s.isReachable ? 'running:healthy' : 'exited',
                    ),
                    compact: true,
                  ),
                  onTap: () => context.push('/servers/${s.uuid}'),
                ),
              ),
            ),
            const SizedBox(height: 4),
          ],
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _QuickLinks extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.dns_outlined),
            title: const Text('Servers'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/servers'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: const Text('Projects'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/projects'),
          ),
        ],
      ),
    );
  }
}
