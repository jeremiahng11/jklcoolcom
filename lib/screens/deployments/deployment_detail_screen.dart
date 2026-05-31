import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/deployment.dart';
import '../../providers/deployments_provider.dart';
import '../../providers/instances_provider.dart';
import '../../widgets/action_runner.dart';
import '../../widgets/log_console.dart';

/// Shows a single deployment with its logs and metadata.
///
/// Important: `GET /deployments/{uuid}` does NOT return logs, but the history
/// endpoint (`/deployments/applications/{uuid}`) does. So we render the logs
/// from the [deployment] we were handed (which came from the history list) and,
/// while it is still running, poll the history endpoint for live updates.
class DeploymentDetailScreen extends ConsumerStatefulWidget {
  const DeploymentDetailScreen({super.key, required this.deployment});

  final Deployment deployment;

  @override
  ConsumerState<DeploymentDetailScreen> createState() =>
      _DeploymentDetailScreenState();
}

class _DeploymentDetailScreenState
    extends ConsumerState<DeploymentDetailScreen> {
  late Deployment _d = widget.deployment;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // Resolve the owning app uuid if we weren't given it (needed to fetch logs).
    if (_d.appUuid.isEmpty) {
      final client = ref.read(coolifyClientProvider);
      if (client != null) {
        try {
          final full = await client.deployment(_d.deploymentUuid);
          if (full.appUuid.isNotEmpty) {
            _d = _d.copyWith(appUuid: full.appUuid);
          }
        } catch (_) {}
      }
    }
    // Fetch logs once if we don't have them yet, then poll while running.
    if (_d.logsText.isEmpty) await _refresh();
    if (_d.isRunning) {
      _timer = Timer.periodic(const Duration(seconds: 3), (_) => _refresh());
    }
  }

  Future<void> _refresh() async {
    final client = ref.read(coolifyClientProvider);
    if (client == null || _d.appUuid.isEmpty) return;
    try {
      final history = await client.appDeploymentHistory(_d.appUuid, take: 20);
      Deployment? match;
      for (final h in history) {
        if (h.deploymentUuid == _d.deploymentUuid) {
          match = h;
          break;
        }
      }
      if (match != null && mounted) {
        setState(() => _d = match!.copyWith(appUuid: _d.appUuid));
        if (!match.isRunning) _timer?.cancel();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Deployment'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
          if (_d.isRunning)
            TextButton.icon(
              onPressed: _cancel,
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Cancel'),
            ),
        ],
      ),
      body: Column(
        children: [
          _Meta(deployment: _d),
          const Divider(height: 1),
          Expanded(child: LogConsole(text: _d.logsText)),
        ],
      ),
    );
  }

  Future<void> _cancel() async {
    final client = ref.read(coolifyClientProvider);
    if (client == null) return;
    final ok = await confirmAction(
      context,
      title: 'Cancel deployment',
      message: 'Stop this running deployment?',
      confirmLabel: 'Cancel deployment',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final done = await runAction(
      context,
      action: () => client.cancelDeployment(_d.deploymentUuid),
      success: 'Deployment cancelled',
    );
    if (done) {
      ref.invalidate(runningDeploymentsProvider);
      ref.invalidate(recentDeploymentsProvider);
      await _refresh();
    }
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.deployment});
  final Deployment deployment;

  @override
  Widget build(BuildContext context) {
    final d = deployment;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: d.statusColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (d.isRunning)
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: d.statusColor,
                    ),
                  )
                else
                  Icon(Icons.circle, size: 10, color: d.statusColor),
                const SizedBox(width: 8),
                Text(
                  d.statusLabel,
                  style: TextStyle(
                    color: d.statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  d.applicationName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (d.shortCommit.isNotEmpty)
                  Text(
                    '${d.shortCommit}'
                    '${d.serverName.isNotEmpty ? ' · ${d.serverName}' : ''}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                if (d.finishedAt != null)
                  Text(
                    'Finished ${DateFormat.MMMd().add_jm().format(d.finishedAt!.toLocal())}'
                    '${d.durationLabel.isNotEmpty ? ' · took ${d.durationLabel}' : ''}',
                    style: Theme.of(context).textTheme.bodySmall,
                  )
                else if (d.durationLabel.isNotEmpty)
                  Text(
                    'Took ${d.durationLabel}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
