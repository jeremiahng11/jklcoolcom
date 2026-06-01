import 'json_utils.dart';

/// A single Coolify endpoint the user manages (one "account").
///
/// The API token is a secret and is **not** stored here — it lives in
/// [FlutterSecureStorage] keyed by [id]. This object only carries the
/// non-secret metadata that is persisted to shared_preferences as JSON.
class CoolifyInstance {
  const CoolifyInstance({
    required this.id,
    required this.label,
    required this.baseUrl,
    required this.accentColor,
    this.metricsUrl = '',
  });

  /// Stable local identifier (also the secure-storage key for the token).
  final String id;

  /// User-facing name, e.g. "Home server" or "Coolify Cloud".
  final String label;

  /// Normalised base URL ending in `/api/v1`, e.g. `https://app.coolify.io/api/v1`.
  final String baseUrl;

  /// ARGB value of the per-instance accent colour.
  final int accentColor;

  /// Optional base URL of the metrics agent on the host (e.g.
  /// `http://192.168.0.147:8088`). Empty when not configured. The agent token
  /// is a secret stored separately in secure storage.
  final String metricsUrl;

  bool get hasMetrics => metricsUrl.trim().isNotEmpty;

  /// The origin without the `/api/v1` suffix — useful for opening the
  /// dashboard in a browser.
  String get dashboardUrl {
    final uri = Uri.tryParse(baseUrl);
    if (uri == null) return baseUrl;
    return '${uri.scheme}://${uri.authority}';
  }

  String get host => Uri.tryParse(baseUrl)?.host ?? baseUrl;

  CoolifyInstance copyWith({
    String? label,
    String? baseUrl,
    int? accentColor,
    String? metricsUrl,
  }) {
    return CoolifyInstance(
      id: id,
      label: label ?? this.label,
      baseUrl: baseUrl ?? this.baseUrl,
      accentColor: accentColor ?? this.accentColor,
      metricsUrl: metricsUrl ?? this.metricsUrl,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'baseUrl': baseUrl,
    'accentColor': accentColor,
    'metricsUrl': metricsUrl,
  };

  factory CoolifyInstance.fromJson(Map<String, dynamic> json) {
    return CoolifyInstance(
      id: asStringOr(json['id']),
      label: asStringOr(json['label'], 'Coolify'),
      baseUrl: asStringOr(json['baseUrl']),
      accentColor: asIntOr(json['accentColor'], 0xFF8B5CF6),
      metricsUrl: asStringOr(json['metricsUrl']),
    );
  }

  /// Normalises a metrics-agent URL: adds a scheme (http for LAN hosts) and
  /// strips any trailing slash. Empty input stays empty.
  static String normaliseMetricsUrl(String input) {
    var raw = input.trim();
    if (raw.isEmpty) return '';
    if (!raw.startsWith('http://') && !raw.startsWith('https://')) {
      raw = 'http://$raw';
    }
    return raw.replaceAll(RegExp(r'/+$'), '');
  }

  /// Normalises raw user input into a base URL ending in `/api/v1`.
  ///
  /// Accepts `localhost:8000`, `http://192.168.1.10:8000`,
  /// `https://coolify.example.com`, or a full `.../api/v1` URL.
  static String normaliseBaseUrl(String input) {
    var raw = input.trim();
    if (raw.isEmpty) return raw;
    if (!raw.startsWith('http://') && !raw.startsWith('https://')) {
      // Local hosts default to http; everything else to https.
      final isLocal =
          raw.startsWith('localhost') ||
          raw.startsWith('127.0.0.1') ||
          raw.startsWith('192.168.') ||
          raw.startsWith('10.') ||
          raw.startsWith('0.0.0.0');
      raw = '${isLocal ? 'http' : 'https'}://$raw';
    }
    // Strip trailing slashes.
    raw = raw.replaceAll(RegExp(r'/+$'), '');
    // Ensure exactly one /api/v1 suffix.
    raw = raw.replaceAll(RegExp(r'/api/v1/?$'), '');
    return '$raw/api/v1';
  }
}
