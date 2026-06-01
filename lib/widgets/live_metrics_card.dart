import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/instances_provider.dart';
import '../providers/metrics_provider.dart';
import '../theme/app_theme.dart';

/// Dashboard card showing live CPU / memory / disk / uptime from the metrics
/// agent, with per-core CPU bars and CPU/RAM sparklines (history kept while the
/// dashboard is open). Shows a setup hint when no agent is configured.
class LiveMetricsCard extends ConsumerStatefulWidget {
  const LiveMetricsCard({super.key});

  @override
  ConsumerState<LiveMetricsCard> createState() => _LiveMetricsCardState();
}

class _LiveMetricsCardState extends ConsumerState<LiveMetricsCard> {
  static const _maxSamples = 40;
  final List<double> _cpuHist = [];
  final List<double> _memHist = [];

  void _push(List<double> buf, double v) {
    buf.add(v);
    if (buf.length > _maxSamples) buf.removeAt(0);
  }

  @override
  Widget build(BuildContext context) {
    final instance = ref.watch(activeInstanceProvider);
    if (instance == null) return const SizedBox.shrink();

    if (!instance.hasMetrics) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.speed_outlined),
          title: const Text('Add live metrics'),
          subtitle: const Text(
            'See live CPU, memory, disk & uptime — tap for the quick setup guide',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/metrics-setup'),
        ),
      );
    }

    // Accumulate history as new samples arrive.
    ref.listen(liveMetricsProvider, (prev, next) {
      final d = next.value?.data;
      if (d != null) {
        setState(() {
          _push(_cpuHist, d.cpuPercent);
          _push(_memHist, d.memPercent);
        });
      }
    });

    final snap = ref.watch(liveMetricsProvider).value;
    final data = snap?.data;
    final error = snap?.error;
    final theme = Theme.of(context);

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
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
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
              if (_cpuHist.length > 1) ...[
                const SizedBox(height: 6),
                _Sparkline(
                  values: _cpuHist,
                  color: _levelColor(data.cpuPercent),
                ),
              ],
              if (data.cpuPerCore.isNotEmpty) ...[
                const SizedBox(height: 8),
                _CoreBars(cores: data.cpuPerCore),
              ],
              const SizedBox(height: 14),
              _MetricBar(
                icon: Icons.sd_card_outlined,
                label: 'Memory',
                percent: data.memPercent,
                detail: data.memLabel,
              ),
              if (_memHist.length > 1) ...[
                const SizedBox(height: 6),
                _Sparkline(
                  values: _memHist,
                  color: _levelColor(data.memPercent),
                ),
              ],
              const SizedBox(height: 14),
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
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ] else if (error != null) ...[
              Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 18,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(error)),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  children: [
                    TextButton.icon(
                      onPressed: () => ref.invalidate(liveMetricsProvider),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Retry'),
                    ),
                    TextButton.icon(
                      onPressed: () => context.push('/metrics-setup'),
                      icon: const Icon(Icons.help_outline, size: 18),
                      label: const Text('Setup help'),
                    ),
                  ],
                ),
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

Color _levelColor(double percent) {
  if (percent >= 90) return StatusColors.down;
  if (percent >= 70) return StatusColors.warning;
  return StatusColors.healthy;
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _levelColor(percent);
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

/// A compact equalizer-style row of per-core CPU bars.
class _CoreBars extends StatelessWidget {
  const _CoreBars({required this.cores});
  final List<double> cores;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        for (var i = 0; i < cores.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: Tooltip(
              message: 'Core $i: ${cores[i].toStringAsFixed(0)}%',
              child: Column(
                children: [
                  SizedBox(
                    height: 26,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: FractionallySizedBox(
                        heightFactor: (cores[i] / 100).clamp(0.04, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: _levelColor(cores[i]),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$i',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Simple sparkline of values (each 0..100) over a fixed height.
class _Sparkline extends StatelessWidget {
  const _Sparkline({required this.values, required this.color});
  final List<double> values;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      width: double.infinity,
      child: CustomPaint(painter: _SparkPainter(values, color)),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.values, this.color);
  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final n = values.length;
    Offset pt(int i) {
      final x = i / (n - 1) * size.width;
      final y = size.height - (values[i].clamp(0, 100) / 100) * size.height;
      return Offset(x, y);
    }

    final line = Path()..moveTo(pt(0).dx, pt(0).dy);
    for (var i = 1; i < n; i++) {
      line.lineTo(pt(i).dx, pt(i).dy);
    }

    // Soft fill under the line.
    final fill = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(fill, Paint()..color = color.withValues(alpha: 0.12));
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_SparkPainter old) =>
      old.values != values || old.color != color;
}
