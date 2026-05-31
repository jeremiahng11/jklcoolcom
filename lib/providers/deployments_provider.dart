import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/deployment.dart';
import 'instances_provider.dart';
import 'resource_providers.dart';

/// Currently-running deployments across the team.
final runningDeploymentsProvider = FutureProvider<List<Deployment>>((
  ref,
) async {
  final client = ref.watch(coolifyClientProvider);
  if (client == null) return const [];
  return client.runningDeployments();
});

/// Recent deployments aggregated across every application, newest first.
///
/// Coolify has no global deployment-history endpoint, so we fan out over each
/// application's history and merge. Used by the Deployments tab so it shows
/// past deployments even when nothing is currently running.
final recentDeploymentsProvider = FutureProvider<List<Deployment>>((ref) async {
  final client = ref.watch(coolifyClientProvider);
  if (client == null) return const [];
  final apps = await ref.watch(applicationsProvider.future);

  final results = await Future.wait(
    apps.map((a) async {
      try {
        final history = await client.appDeploymentHistory(a.uuid, take: 5);
        // History items carry no app name/uuid — inject them so the UI can
        // label and redeploy.
        return history
            .map((d) => d.copyWith(applicationName: a.name, appUuid: a.uuid))
            .toList();
      } catch (_) {
        return const <Deployment>[];
      }
    }),
  );

  final all = results.expand((e) => e).toList()
    ..sort((a, b) {
      final at = a.updatedAt ?? a.createdAt;
      final bt = b.updatedAt ?? b.createdAt;
      if (at == null && bt == null) return 0;
      if (at == null) return 1;
      if (bt == null) return -1;
      return bt.compareTo(at);
    });
  return all.take(40).toList();
});

/// Deployment history for a single application. Injects the app uuid so the
/// detail screen can fetch logs / offer redeploy.
final appDeploymentHistoryProvider =
    FutureProvider.family<List<Deployment>, String>((ref, appUuid) async {
      final client = ref.watch(coolifyClientProvider);
      if (client == null) return const [];
      final history = await client.appDeploymentHistory(appUuid, take: 30);
      return history.map((d) => d.copyWith(appUuid: appUuid)).toList();
    });
