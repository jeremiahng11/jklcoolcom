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

  String get connection => '$user@$ip:$port';

  factory Server.fromJson(Map<String, dynamic> json) {
    final settings = asMap(json['settings']);
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
    );
  }
}
