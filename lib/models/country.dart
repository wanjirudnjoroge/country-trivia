import '../core/app_config.dart';

/// A country shown in the quiz.
///
/// Immutable value type: two countries with the same ISO code are equal, so a
/// country survives a round trip through the data layer unchanged.
class Country {
  const Country({required this.name, required this.iso2, this.iso3});

  /// Builds a country from an ISO 3166-1 alpha-2 code, deriving a readable name
  /// from it. Used by the offline fallback list.
  factory Country.fromCode(String iso2, {String? name}) => Country(
    name: name ?? iso2.toUpperCase(),
    iso2: iso2.toUpperCase(),
  );

  /// English display name, e.g. `Japan`.
  final String name;

  /// ISO 3166-1 alpha-2 code, always stored uppercase, e.g. `JP`.
  final String iso2;

  /// ISO 3166-1 alpha-3 code when known, e.g. `JPN`.
  final String? iso3;

  /// [iso2] lowercased, the form flagcdn.com expects.
  String get iso2Lowercase => iso2.toLowerCase();

  /// Flag image URL, always HTTPS.
  String get flagUrl => AppConfig.flagUrl(iso2Lowercase);

  /// Whether this country has enough data to appear in a question.
  bool get isUsable => name.trim().isNotEmpty && iso2.trim().isNotEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Country && other.iso2 == iso2;

  @override
  int get hashCode => iso2.hashCode;

  @override
  String toString() => 'Country($name, $iso2)';
}
