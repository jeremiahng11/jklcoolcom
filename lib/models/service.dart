import 'json_utils.dart';
import 'status.dart';

class CoolifyService {
  const CoolifyService({
    required this.uuid,
    required this.name,
    required this.description,
    required this.serviceType,
    required this.status,
    required this.raw,
  });

  final String uuid;
  final String name;
  final String description;
  final String serviceType;
  final ResourceStatus status;
  final Map<String, dynamic> raw;

  /// Services have no single `status` field on the model; Coolify aggregates
  /// per-container status. We read `status` when present and otherwise leave
  /// it unknown — the dashboard/resources list (from `/resources`) carries the
  /// authoritative aggregated status.
  factory CoolifyService.fromJson(Map<String, dynamic> json) {
    return CoolifyService(
      uuid: asStringOr(json['uuid']),
      name: asStringOr(json['name'], 'Service'),
      description: asStringOr(json['description']),
      serviceType: asStringOr(json['service_type'] ?? json['type']),
      status: ResourceStatus.parse(asString(json['status'])),
      raw: json,
    );
  }
}
