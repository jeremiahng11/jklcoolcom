import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/resource.dart';
import '../models/status.dart';
import 'resource_providers.dart';

/// Aggregated health counts for the dashboard header.
class DashboardSummary {
  const DashboardSummary({
    required this.total,
    required this.healthy,
    required this.warning,
    required this.down,
    required this.other,
    required this.applications,
    required this.databases,
    required this.services,
    required this.attention,
  });

  final int total;
  final int healthy;
  final int warning;
  final int down;
  final int other;
  final int applications;
  final int databases;
  final int services;

  /// Resources that need attention (warning or down), worst first.
  final List<ResourceSummary> attention;

  factory DashboardSummary.from(List<ResourceSummary> resources) {
    var healthy = 0, warning = 0, down = 0, other = 0;
    var apps = 0, dbs = 0, svcs = 0;
    final attention = <ResourceSummary>[];

    for (final r in resources) {
      switch (r.status.level) {
        case HealthLevel.healthy:
          healthy++;
          break;
        case HealthLevel.warning:
          warning++;
          attention.add(r);
          break;
        case HealthLevel.down:
          down++;
          attention.add(r);
          break;
        case HealthLevel.transitioning:
        case HealthLevel.unknown:
          other++;
          break;
      }
      switch (r.kind) {
        case ResourceKind.application:
          apps++;
          break;
        case ResourceKind.database:
          dbs++;
          break;
        case ResourceKind.service:
          svcs++;
          break;
        case ResourceKind.unknown:
          break;
      }
    }

    // Down before warning.
    attention.sort(
      (a, b) => a.status.level.index.compareTo(b.status.level.index),
    );

    return DashboardSummary(
      total: resources.length,
      healthy: healthy,
      warning: warning,
      down: down,
      other: other,
      applications: apps,
      databases: dbs,
      services: svcs,
      attention: attention,
    );
  }
}

final dashboardSummaryProvider = Provider<AsyncValue<DashboardSummary>>((ref) {
  return ref.watch(resourcesProvider).whenData(DashboardSummary.from);
});
