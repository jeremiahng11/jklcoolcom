import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/deployment.dart';
import '../../providers/deployments_provider.dart';
import '../../providers/instances_provider.dart';
import '../../widgets/action_runner.dart';
import '../../widgets/async_value_view.dart';
import '../../widgets/log_console.dart';

/// Shows a single deployment with its (live-polled) logs and metadata.
class DeploymentDetailScreen extends ConsumerWidget {
  const DeploymentDetailScreen({super.key, required this.uuid});

  final String uuid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deployment = ref.watch(deploymentProvider(uuid));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Deployment'),
        actions: [
          if (deployment.value?.isRunning ?? false)
            TextButton.icon(
              onPressed: () async {
                final client = ref.read(coolifyClientProvider);
                if (client == null) return;
                final ok = await confirmAction(
                  context,
                  title: 'Cancel deployment',
                  message: 'Stop this running deployment?',
                  confirmLabel: 'Cancel deployment',
                  destructive: true,
                );
                if (ok && context.mounted) {
                  await runAction(
                    context,
                    action: () => client.cancelDeployment(uuid),
                    success: 'Deployment cancelled',
                  );
                }
              },
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Cancel'),
            ),
        ],
      ),
      body: AsyncValueView<Deployment>(
        value: deployment,
        onRetry: () => ref.invalidate(deploymentProvider(uuid)),
        data: (d) => Column(
          children: [
            _Meta(deployment: d),
            const Divider(height: 1),
            Expanded(child: LogConsole(text: _decodeLogs(d.logs))),
          ],
        ),
      ),
    );
  }

  /// Deployment logs come back as a JSON array string of `{output,...}` lines;
  /// fall back to raw text when it isn't JSON.
  String _decodeLogs(String logs) {
    if (logs.trim().isEmpty) return '';
    return logs;
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
                    '${d.shortCommit} · ${d.serverName}',
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
