import 'dart:convert';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'json_utils.dart';

enum DeployState { queued, inProgress, finished, failed, cancelled, unknown }

class Deployment {
  const Deployment({
    required this.deploymentUuid,
    required this.applicationName,
    required this.appUuid,
    required this.status,
    required this.commit,
    required this.commitMessage,
    required this.isWebhook,
    required this.isApi,
    required this.forceRebuild,
    required this.serverName,
    required this.logs,
    required this.createdAt,
    required this.updatedAt,
  });

  final String deploymentUuid;
  final String applicationName;

  /// The owning application's uuid. Not present on the API payload — injected
  /// by the aggregate provider so the UI can offer "Redeploy".
  final String appUuid;
  final DeployState status;
  final String commit;
  final String commitMessage;
  final bool isWebhook;
  final bool isApi;
  final bool forceRebuild;
  final String serverName;

  /// Raw deployment log payload (JSON-encoded line array) when fetched by uuid.
  final String logs;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get shortCommit => commit.length > 7 ? commit.substring(0, 7) : commit;

  bool get isRunning =>
      status == DeployState.queued || status == DeployState.inProgress;

  bool get isTerminal =>
      status == DeployState.finished ||
      status == DeployState.failed ||
      status == DeployState.cancelled;

  /// When the deployment ended (for terminal states), else null.
  DateTime? get finishedAt => isTerminal ? updatedAt : null;

  /// How long the deployment took (created → finished). Null while running or
  /// when timestamps are missing.
  Duration? get duration {
    final start = createdAt;
    final end = finishedAt;
    if (start == null || end == null) return null;
    final d = end.difference(start);
    return d.isNegative ? null : d;
  }

  /// Human duration, e.g. "23s", "1m 5s", "1h 2m". Empty when unavailable.
  String get durationLabel {
    final d = duration;
    if (d == null) return '';
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m';
    if (d.inMinutes > 0) return '${d.inMinutes}m ${d.inSeconds % 60}s';
    return '${d.inSeconds}s';
  }

  Deployment copyWith({String? applicationName, String? appUuid}) => Deployment(
    deploymentUuid: deploymentUuid,
    applicationName: applicationName ?? this.applicationName,
    appUuid: appUuid ?? this.appUuid,
    status: status,
    commit: commit,
    commitMessage: commitMessage,
    isWebhook: isWebhook,
    isApi: isApi,
    forceRebuild: forceRebuild,
    serverName: serverName,
    logs: logs,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  /// Coolify stores deployment logs as a JSON array of
  /// `{output, type, timestamp, hidden, ...}` entries. Decode it into readable
  /// lines, falling back to the raw string when it isn't JSON.
  String get logsText {
    final raw = logs.trim();
    if (raw.isEmpty) return '';
    if (!raw.startsWith('[')) return raw;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .where((e) => e['hidden'] != true)
            .map((e) => asStringOr(e['output']))
            .where((s) => s.isNotEmpty)
            .join('\n');
      }
    } catch (_) {}
    return raw;
  }

  factory Deployment.fromJson(Map<String, dynamic> json) {
    return Deployment(
      deploymentUuid: asStringOr(json['deployment_uuid'] ?? json['uuid']),
      applicationName: asStringOr(json['application_name'], 'Application'),
      appUuid: asStringOr(
        json['application_uuid'] ?? asMap(json['application'])['uuid'],
      ),
      status: _state(asStringOr(json['status'])),
      commit: asStringOr(json['commit']),
      commitMessage: asStringOr(json['commit_message']),
      isWebhook: asBool(json['is_webhook']),
      isApi: asBool(json['is_api']),
      forceRebuild: asBool(json['force_rebuild']),
      serverName: asStringOr(json['server_name']),
      logs: asStringOr(json['logs']),
      createdAt: asDate(json['created_at']),
      updatedAt: asDate(json['updated_at']),
    );
  }

  static DeployState _state(String s) {
    switch (s.toLowerCase()) {
      case 'queued':
        return DeployState.queued;
      case 'in_progress':
        return DeployState.inProgress;
      case 'finished':
        return DeployState.finished;
      case 'failed':
        return DeployState.failed;
      case 'cancelled-by-user':
      case 'cancelled':
        return DeployState.cancelled;
      default:
        return DeployState.unknown;
    }
  }

  String get statusLabel {
    switch (status) {
      case DeployState.queued:
        return 'Queued';
      case DeployState.inProgress:
        return 'In progress';
      case DeployState.finished:
        return 'Finished';
      case DeployState.failed:
        return 'Failed';
      case DeployState.cancelled:
        return 'Cancelled';
      case DeployState.unknown:
        return 'Unknown';
    }
  }

  Color get statusColor {
    switch (status) {
      case DeployState.finished:
        return StatusColors.healthy;
      case DeployState.failed:
        return StatusColors.down;
      case DeployState.cancelled:
        return StatusColors.neutral;
      case DeployState.queued:
      case DeployState.inProgress:
        return StatusColors.info;
      case DeployState.unknown:
        return StatusColors.neutral;
    }
  }
}
