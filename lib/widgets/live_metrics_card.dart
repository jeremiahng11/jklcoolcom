import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/instances_provider.dart';
import '../providers/metrics_provider.dart';
import '../theme/app_theme.dart';

/// Dashboard card showing live CPU / memory / disk / uptime from the metrics
/// agent. Shows a setup hint when no agent is configured for the active account.
class LiveMetricsCard extends ConsumerWidget {
  const LiveMetricsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final instance = ref.watch(activeInstanceProvider);
    if (instance == null) return const SizedBox.shrink();

    if (!instance.hasMetrics) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.speed_outlined),
          title: const Text('Add live metrics'),
          subtitle: const Text(
            'Run the agent on your server to see live CPU, memory, disk & uptime',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/edit-instance/${instance.id}'),
        ),
      );
    }

    final snap = ref.watch(liveMetricsProvider).value;
    final data = snap?.data;
    final error = snap?.error;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.speed_rounded, size: 18),
                const SizedBox(width: 8),
                Text(
                  data != null && data.hostname.isNotEmpty
                      ? 'Live · ${data.hostname}'
                      : 'Live metrics',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                if (data != null)
                  Text(
                    'up ${data.uptimeLabel}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (data != null) ...[
              _MetricBar(
                icon: Icons.memory,
                label: 'CPU',
                percent: data.cpuPercent,
                detail: data.cores > 0 ? '${data.cores} cores' : '',
              ),
              const SizedBox(height: 12),
              _MetricBar(
                icon: Icons.sd_card_outlined,
                label: 'Memory',
                percent: data.memPercent,
                detail: data.memLabel,
              ),
              const SizedBox(height: 12),
              _MetricBar(
                icon: Icons.storage_rounded,
                label: 'Disk',
                percent: data.diskPercent,
                detail: data.diskLabel,
              ),
              if (data.load.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Load avg  ${data.load.map((l) => l.toStringAsFixed(2)).join('  ')}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ] else if (error != null) ...[
              Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 18,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(error)),
                ],
              ),
            ] else
              const Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('Connecting to agent…'),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _MetricBar extends StatelessWidget {
  const _MetricBar({
    required this.icon,
    required this.label,
    required this.percent,
    required this.detail,
  });

  final IconData icon;
  final String label;
  final double percent;
  final String detail;

  Color _color() {
    if (percent >= 90) return StatusColors.down;
    if (percent >= 70) return StatusColors.warning;
    return StatusColors.healthy;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _color();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            if (detail.isNotEmpty)
              Text(
                detail,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            const SizedBox(width: 8),
            Text(
              '${percent.toStringAsFixed(0)}%',
              style: TextStyle(fontWeight: FontWeight.w700, color: color),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: (percent / 100).clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}
