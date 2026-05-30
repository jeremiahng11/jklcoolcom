import 'json_utils.dart';

/// A scheduled backup configuration for a database.
class DatabaseBackup {
  const DatabaseBackup({
    required this.uuid,
    required this.enabled,
    required this.frequency,
    required this.saveLocally,
    required this.databasesToBackup,
    required this.numberOfBackupsToKeep,
  });

  final String uuid;
  final bool enabled;
  final String frequency;
  final bool saveLocally;
  final String databasesToBackup;
  final int numberOfBackupsToKeep;

  factory DatabaseBackup.fromJson(Map<String, dynamic> json) {
    return DatabaseBackup(
      uuid: asStringOr(json['uuid']),
      enabled: asBool(json['enabled'], true),
      frequency: asStringOr(json['frequency'], '0 0 * * *'),
      saveLocally: asBool(
        json['save_s3'] == null ? json['local'] : false,
        true,
      ),
      databasesToBackup: asStringOr(json['databases_to_backup']),
      numberOfBackupsToKeep: asIntOr(json['number_of_backups_locally'], 5),
    );
  }
}
