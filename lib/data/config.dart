/// Values injected at build time via `--dart-define-from-file=env/keys.json`.
class AppConfig {
  static const apiKey = String.fromEnvironment('MAPS_API_KEY');
  static const androidPackage = String.fromEnvironment('ANDROID_PACKAGE', defaultValue: 'com.anas.commute');

  /// SHA-1 of the signing cert, hex without colons (the X-Android-Cert header format).
  static final androidCert = const String.fromEnvironment('ANDROID_CERT_SHA1')
      .replaceAll(':', '')
      .toUpperCase();

  static bool get hasKey => apiKey.isNotEmpty;

  static Map<String, String> headers(String fieldMask) => {
    'Content-Type': 'application/json',
    'X-Goog-Api-Key': apiKey,
    'X-Goog-FieldMask': fieldMask,
    'X-Android-Package': androidPackage,
    if (androidCert.isNotEmpty) 'X-Android-Cert': androidCert,
  };
}

class ApiException implements Exception {
  final String message;
  final int? status;
  ApiException(this.message, {this.status});
  @override
  String toString() => message;

  static ApiException fromResponse(int code, String body) {
    final hint = switch (code) {
      403 => 'Key rejected (check API restrictions, package and SHA-1)',
      429 => 'Rate limited, try again shortly',
      400 => 'Bad request',
      _ => 'Server error $code',
    };
    final m = RegExp(r'"message":\s*"([^"]+)"').firstMatch(body)?.group(1);
    return ApiException(m == null ? hint : '$hint: $m', status: code);
  }
}
