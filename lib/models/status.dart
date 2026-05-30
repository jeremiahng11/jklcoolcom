import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// High-level health bucket derived from a Coolify status string.
enum HealthLevel { healthy, warning, down, transitioning, unknown }

/// Parsed representation of Coolify's `"<state>:<health>"` status strings.
///
/// Coolify reports things like `running:healthy`, `running:unhealthy`,
/// `exited:unhealthy`, `degraded`, `restarting`, or simply `stopped`. We split
/// on `:` — index 0 is the container lifecycle state, index 1 (if present) is
/// the health-check result.
@immutable
class ResourceStatus {
  const ResourceStatus({
    required this.raw,
    required this.state,
    required this.health,
    required this.level,
  });

  /// The original, untouched status string.
  final String raw;

  /// Lifecycle state, e.g. `running`, `exited`, `restarting`, `stopped`.
  final String state;

  /// Health portion, e.g. `healthy`, `unhealthy`, or empty when absent.
  final String health;

  final HealthLevel level;

  factory ResourceStatus.parse(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) {
      return const ResourceStatus(
        raw: '',
        state: 'unknown',
        health: '',
        level: HealthLevel.unknown,
      );
    }

    final lower = raw.toLowerCase();
    final parts = lower.split(':');
    final state = parts.first.trim();
    final health = parts.length > 1 ? parts[1].trim() : '';

    HealthLevel level;
    if (state == 'degraded') {
      level = HealthLevel.warning;
    } else if (state.startsWith('running')) {
      if (health == 'healthy') {
        level = HealthLevel.healthy;
      } else if (health == 'unhealthy') {
        level = HealthLevel.warning;
      } else if (health == 'starting') {
        level = HealthLevel.transitioning;
      } else {
        level = HealthLevel.healthy; // running, health unknown
      }
    } else if (state == 'restarting' ||
        state == 'created' ||
        state == 'starting') {
      level = HealthLevel.transitioning;
    } else if (state == 'exited' ||
        state == 'stopped' ||
        state == 'dead' ||
        state == 'removing' ||
        state == 'paused') {
      level = HealthLevel.down;
    } else {
      level = HealthLevel.unknown;
    }

    return ResourceStatus(raw: raw, state: state, health: health, level: level);
  }

  bool get isRunning => state.startsWith('running');
  bool get isStopped =>
      state == 'exited' || state == 'stopped' || state == 'dead';

  /// Short human label, e.g. "Healthy", "Unhealthy", "Stopped".
  String get label {
    switch (level) {
      case HealthLevel.healthy:
        return 'Healthy';
      case HealthLevel.warning:
        if (state == 'degraded') return 'Degraded';
        return health == 'unhealthy' ? 'Unhealthy' : 'Warning';
      case HealthLevel.down:
        return state == 'exited' ? 'Stopped' : _titleCase(state);
      case HealthLevel.transitioning:
        return health == 'starting' ? 'Starting' : _titleCase(state);
      case HealthLevel.unknown:
        return raw.isEmpty ? 'Unknown' : _titleCase(state);
    }
  }

  Color get color {
    switch (level) {
      case HealthLevel.healthy:
        return StatusColors.healthy;
      case HealthLevel.warning:
        return StatusColors.warning;
      case HealthLevel.down:
        return StatusColors.down;
      case HealthLevel.transitioning:
        return StatusColors.info;
      case HealthLevel.unknown:
        return StatusColors.neutral;
    }
  }

  IconData get icon {
    switch (level) {
      case HealthLevel.healthy:
        return Icons.check_circle_rounded;
      case HealthLevel.warning:
        return Icons.warning_amber_rounded;
      case HealthLevel.down:
        return Icons.stop_circle_rounded;
      case HealthLevel.transitioning:
        return Icons.hourglass_top_rounded;
      case HealthLevel.unknown:
        return Icons.help_outline_rounded;
    }
  }

  static String _titleCase(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
