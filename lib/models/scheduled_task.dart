import 'json_utils.dart';

/// A scheduled (cron) task on an application or service.
class ScheduledTask {
  const ScheduledTask({
    required this.uuid,
    required this.name,
    required this.command,
    required this.frequency,
    required this.container,
    required this.enabled,
  });

  final String uuid;
  final String name;
  final String command;
  final String frequency;
  final String container;
  final bool enabled;

  factory ScheduledTask.fromJson(Map<String, dynamic> json) {
    return ScheduledTask(
      uuid: asStringOr(json['uuid']),
      name: asStringOr(json['name'], 'task'),
      command: asStringOr(json['command']),
      frequency: asStringOr(json['frequency']),
      container: asStringOr(json['container']),
      enabled: asBool(json['enabled'], true),
    );
  }
}
