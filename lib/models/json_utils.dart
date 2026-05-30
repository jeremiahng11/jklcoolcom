/// Lenient JSON field accessors. The Coolify API occasionally returns numbers
/// as strings, booleans as 0/1, and nulls where a default reads better, so we
/// coerce defensively rather than trust types.
String? asString(dynamic v) {
  if (v == null) return null;
  if (v is String) return v;
  return v.toString();
}

String asStringOr(dynamic v, [String fallback = '']) => asString(v) ?? fallback;

int? asInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is double) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

int asIntOr(dynamic v, [int fallback = 0]) => asInt(v) ?? fallback;

bool asBool(dynamic v, [bool fallback = false]) {
  if (v == null) return fallback;
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) {
    final s = v.toLowerCase();
    return s == 'true' || s == '1' || s == 'yes';
  }
  return fallback;
}

DateTime? asDate(dynamic v) {
  final s = asString(v);
  if (s == null || s.isEmpty) return null;
  return DateTime.tryParse(s);
}

Map<String, dynamic> asMap(dynamic v) =>
    v is Map<String, dynamic> ? v : <String, dynamic>{};

List<Map<String, dynamic>> asMapList(dynamic v) {
  if (v is List) {
    return v.whereType<Map<String, dynamic>>().toList();
  }
  return const <Map<String, dynamic>>[];
}
