import 'json_utils.dart';

/// An environment variable on an application, database, or service.
class EnvVar {
  const EnvVar({
    required this.uuid,
    required this.key,
    required this.value,
    required this.isPreview,
    required this.isBuildTime,
    required this.isLiteral,
    required this.isMultiline,
    required this.isShownOnce,
  });

  final String uuid;
  final String key;
  final String value;
  final bool isPreview;
  final bool isBuildTime;
  final bool isLiteral;
  final bool isMultiline;
  final bool isShownOnce;

  factory EnvVar.fromJson(Map<String, dynamic> json) {
    return EnvVar(
      uuid: asStringOr(json['uuid']),
      key: asStringOr(json['key']),
      // `real_value` carries the decrypted value when the token has
      // `read:sensitive`; otherwise fall back to `value`.
      value: asStringOr(json['real_value'] ?? json['value']),
      isPreview: asBool(json['is_preview']),
      isBuildTime: asBool(json['is_buildtime'] ?? json['is_build_time']),
      isLiteral: asBool(json['is_literal']),
      isMultiline: asBool(json['is_multiline']),
      isShownOnce: asBool(json['is_shown_once']),
    );
  }
}
