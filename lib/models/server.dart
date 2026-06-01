import 'json_utils.dart';

class Server {
  const Server({
    required this.uuid,
    required this.name,
    required this.description,
    required this.ip,
    required this.user,
    required this.port,
    required this.proxyType,
    required this.isReachable,
    required this.isUsable,
    required this.isBuildServer,
    required this.unreachableCount,
    required this.os,
    required this.arch,
    required this.cpus,
    required this.memoryBytes,
    required this.uptimeSince,
    required this.metricsCollectedAt,
  });

  final String uuid;
  final String name;
  final String description;
  final String ip;
  final String user;
  final int port;
  final String proxyType;
  final bool isReachable;
  final bool isUsable;
  final bool isBuildServer;
  final int unreachableCount;

  // From `server_metadata` (hardware capacity, not realtime load).
  final String os;
  final String arch;
  final int cpus;
  final int memoryBytes;
  final DateTime? uptimeSince;
  final DateTime? metricsCollectedAt;

  String get connection => '$user@$ip:$port';

  /// `user@ip` without the port — for showing the port on a separate line.
  String get endpoint => '$user@$ip';

  bool get hasHardwareInfo => cpus > 0 || memoryBytes > 0 || os.isNotEmpty;

  /// Total RAM as a friendly label, e.g. "8.0 GB".
  String get memoryLabel {
    if (memoryBytes <= 0) return '—';
    final gb = memoryBytes / (1024 * 1024 * 1024);
    if (gb >= 1) return '${gb.toStringAsFixed(gb >= 10 ? 0 : 1)} GB';
    final mb = memoryBytes / (1024 * 1024);
    return '${mb.toStringAsFixed(0)} MB';
  }

  /// Compact capacity summary, e.g. "4 cores · 8.0 GB · Debian 12".
  String get hardwareSummary {
    final parts = <String>[
      if (cpus > 0) '$cpus core${cpus == 1 ? '' : 's'}',
      if (memoryBytes > 0) memoryLabel,
      if (os.isNotEmpty) os,
    ];
    return parts.join(' · ');
  }

  /// Uptime as a friendly duration relative to [now] (passed in to stay pure).
  String uptimeLabel(DateTime now) {
    final since = uptimeSince;
    if (since == null) return '—';
    final d = now.difference(since);
    if (d.isNegative) return '—';
    if (d.inDays > 0) return '${d.inDays}d ${d.inHours % 24}h';
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m';
    return '${d.inMinutes}m';
  }

  factory Server.fromJson(Map<String, dynamic> json) {
    final settings = asMap(json['settings']);
    final meta = asMap(json['server_metadata']);
    return Server(
      uuid: asStringOr(json['uuid']),
      name: asStringOr(json['name'], 'Server'),
      description: asStringOr(json['description']),
      ip: asStringOr(json['ip']),
      user: asStringOr(json['user'], 'root'),
      port: asIntOr(json['port'], 22),
      proxyType: asStringOr(json['proxy_type'] ?? asMap(json['proxy'])['type']),
      isReachable: asBool(settings['is_reachable'], true),
      isUsable: asBool(settings['is_usable'], true),
      isBuildServer: asBool(settings['is_build_server']),
      unreachableCount: asIntOr(json['unreachable_count']),
      os: asStringOr(meta['os']),
      arch: asStringOr(meta['arch']),
      cpus: asIntOr(meta['cpus']),
      memoryBytes: asIntOr(meta['memory_bytes']),
      uptimeSince: asDate(meta['uptime_since']),
      metricsCollectedAt: asDate(meta['collected_at']),
    );
  }
}
