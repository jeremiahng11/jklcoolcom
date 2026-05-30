import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/deployment.dart';
import 'instances_provider.dart';

/// Currently-running deployments across the team.
final runningDeploymentsProvider = FutureProvider<List<Deployment>>((
  ref,
) async {
  final client = ref.watch(coolifyClientProvider);
  if (client == null) return const [];
  return client.runningDeployments();
});

/// Deployment history for a single application.
final appDeploymentHistoryProvider =
    FutureProvider.family<List<Deployment>, String>((ref, appUuid) async {
      final client = ref.watch(coolifyClientProvider);
      if (client == null) return const [];
      return client.appDeploymentHistory(appUuid, take: 30);
    });

/// A single deployment (with logs), polled while it is still running.
final deploymentProvider = StreamProvider.family<Deployment, String>((
  ref,
  uuid,
) async* {
  final client = ref.watch(coolifyClientProvider);
  if (client == null) return;
  while (true) {
    final d = await client.deployment(uuid);
    yield d;
    if (!d.isRunning) break;
    await Future<void>.delayed(const Duration(seconds: 3));
  }
});
