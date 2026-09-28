/// Build-time configuration.
///
/// Values come from `--dart-define` at build time, e.g.
/// `flutter run --dart-define=API_BASE_URL=https://example.com`.
class AppConfig {
  const AppConfig._();

  /// Base URL of the countries API (see docs/master_plan.md §2.1).
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://countriesnow.space',
  );

  /// Path appended to [apiBaseUrl] to list every country with its ISO codes.
  static const String countriesPath = '/api/v0.1/countries/flag/images';

  /// Base URL for flag images. HTTPS is required: the http:// URL 301-redirects
  /// here, and a web build served over HTTPS would fail as mixed content.
  static const String flagBaseUrl = 'https://flagcdn.com/w320/';

  /// Full flag URL for a lowercase ISO 3166-1 alpha-2 code.
  static String flagUrl(String iso2Lowercase) => '$flagBaseUrl$iso2Lowercase.png';

  /// Timeout applied to every network request.
  static const Duration requestTimeout = Duration(seconds: 10);
}
