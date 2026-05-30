import 'dart:convert';

/// A typed error surfaced from the Coolify API, with a user-friendly message
/// and (where useful) the per-field validation errors from a 422 response.
class ApiException implements Exception {
  ApiException(
    this.message, {
    this.statusCode,
    this.fieldErrors,
    this.retryAfter,
    this.isNetwork = false,
  });

  final String message;
  final int? statusCode;
  final Map<String, List<String>>? fieldErrors;

  /// Seconds to wait before retrying, from the `Retry-After` header on a 429.
  final int? retryAfter;
  final bool isNetwork;

  /// True when the failure is most likely a missing token scope (403).
  bool get isScopeError => statusCode == 403;

  /// True when the token is invalid or expired (401).
  bool get isAuthError => statusCode == 401;

  @override
  String toString() => message;

  factory ApiException.network(Object error) {
    return ApiException(
      'Could not reach the server. Check the URL and your connection.',
      isNetwork: true,
    );
  }

  factory ApiException.fromResponse(
    int statusCode,
    String body,
    Map<String, String> headers,
  ) {
    String message;
    Map<String, List<String>>? fieldErrors;

    final parsed = _tryDecode(body);
    final apiMessage = parsed?['message']?.toString();

    switch (statusCode) {
      case 400:
        message = apiMessage ?? 'Invalid request or token.';
        break;
      case 401:
        message =
            'Authentication failed — the API token is invalid or expired.';
        break;
      case 403:
        message =
            'Permission denied. This token is missing a required scope (write / deploy / read:sensitive).';
        break;
      case 404:
        message = apiMessage ?? 'Not found.';
        break;
      case 422:
        message = apiMessage ?? 'Validation error.';
        final errors = parsed?['errors'];
        if (errors is Map) {
          fieldErrors = errors.map(
            (k, v) => MapEntry(
              k.toString(),
              (v is List)
                  ? v.map((e) => e.toString()).toList()
                  : <String>[v.toString()],
            ),
          );
        }
        break;
      case 429:
        message = 'Rate limit exceeded. Please wait a moment and try again.';
        break;
      default:
        message =
            apiMessage ??
            'Request failed (HTTP $statusCode). Please try again.';
    }

    final retryAfter = int.tryParse(headers['retry-after'] ?? '');
    return ApiException(
      message,
      statusCode: statusCode,
      fieldErrors: fieldErrors,
      retryAfter: retryAfter,
    );
  }

  static Map<String, dynamic>? _tryDecode(String body) {
    try {
      if (body.isEmpty) return null;
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }
}
