import 'json_utils.dart';

/// Live host metrics from the Coolify Companion agent.
class ServerMetrics {
  const ServerMetrics({
    required this.hostname,
    required this.cores,
    required this.cpuPercent,
    required this.memUsed,
    required this.memTotal,
    required this.memPercent,
    required this.diskUsed,
    required this.diskTotal,
    required this.diskPercent,
    required this.uptimeSeconds,
    required this.load,
  });

  final String hostname;
  final int cores;
  final double cpuPercent;
  final int memUsed;
  final int memTotal;
  final double memPercent;
  final int diskUsed;
  final int diskTotal;
  final double diskPercent;
  final int uptimeSeconds;
  final List<double> load;

  static String bytes(int b) {
    if (b <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var v = b.toDouble();
    var i = 0;
    while (v >= 1024 && i < units.length - 1) {
      v /= 1024;
      i++;
    }
    return '${v.toStringAsFixed(v >= 100 || i == 0 ? 0 : 1)} ${units[i]}';
  }

  String get memLabel => '${bytes(memUsed)} / ${bytes(memTotal)}';
  String get diskLabel => '${bytes(diskUsed)} / ${bytes(diskTotal)}';

  String get uptimeLabel {
    final d = Duration(seconds: uptimeSeconds);
    if (d.inDays > 0) return '${d.inDays}d ${d.inHours % 24}h';
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m';
    return '${d.inMinutes}m';
  }

  factory ServerMetrics.fromJson(Map<String, dynamic> json) {
    final mem = asMap(json['mem']);
    final disk = asMap(json['disk']);
    final loadRaw = json['load'];
    return ServerMetrics(
      hostname: asStringOr(json['hostname']),
      cores: asIntOr(json['cores']),
      cpuPercent: _d(json['cpu_percent']).clamp(0, 100).toDouble(),
      memUsed: asIntOr(mem['used']),
      memTotal: asIntOr(mem['total']),
      memPercent: _d(mem['percent']),
      diskUsed: asIntOr(disk['used']),
      diskTotal: asIntOr(disk['total']),
      diskPercent: _d(disk['percent']),
      uptimeSeconds: asIntOr(json['uptime_seconds']),
      load: loadRaw is List
          ? loadRaw.map((e) => _d(e)).toList()
          : const <double>[],
    );
  }

  static double _d(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }
}
