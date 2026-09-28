import '../models/country.dart';

/// Parses the countriesnow.space response into [Country] values.
///
/// The endpoint answers with an envelope, not a bare array:
/// `{ "error": false, "msg": "...", "data": [ { "name": ..., "iso2": ... } ] }`.
/// A sibling endpoint in the same collection returns `Iso2`/`Iso3` with a
/// capital I, so both spellings are accepted, and malformed entries are dropped
/// rather than failing the whole response.
class CountryDto {
  const CountryDto({required this.name, required this.iso2, this.iso3});

  /// Returns `null` when [raw] is not a country object with a usable name and
  /// ISO 3166-1 alpha-2 code.
  static CountryDto? tryParse(Object? raw) {
    if (raw is! Map) return null;

    final Object? name = raw['name'] ?? raw['country'];
    final Object? iso2 = raw['iso2'] ?? raw['Iso2'] ?? raw['code'];
    final Object? iso3 = raw['iso3'] ?? raw['Iso3'];

    if (name is! String || iso2 is! String) return null;

    final String trimmedName = name.trim();
    final String trimmedIso2 = iso2.trim();
    if (trimmedName.isEmpty || !_isAlpha2(trimmedIso2)) return null;

    final String? trimmedIso3 = iso3 is String && iso3.trim().length == 3
        ? iso3.trim().toUpperCase()
        : null;

    return CountryDto(
      name: trimmedName,
      iso2: trimmedIso2.toUpperCase(),
      iso3: trimmedIso3,
    );
  }

  static bool _isAlpha2(String value) =>
      value.length == 2 && RegExp(r'^[A-Za-z]{2}$').hasMatch(value);

  final String name;
  final String iso2;
  final String? iso3;

  /// Converts to the domain model, normalising the code to uppercase.
  Country toCountry() => Country(name: name, iso2: iso2, iso3: iso3);
}

/// Extracts the country list from [json].
///
/// Throws [FormatException] when the payload is not the expected shape; the
/// caller turns that into a `Failure.parsing`.
List<Country> parseCountryList(Object? json) {
  Object? rawList = json;

  if (json is Map) {
    final Object? data = json['data'] ?? json['Data'];
    if (data == null) {
      throw const FormatException('Response contains no "data" field');
    }
    rawList = data;
  }

  if (rawList is! List) {
    throw const FormatException('Expected a list of countries');
  }

  final List<Country> countries = <Country>[];
  for (final Object? entry in rawList) {
    final CountryDto? dto = CountryDto.tryParse(entry);
    if (dto != null) countries.add(dto.toCountry());
  }

  if (countries.isEmpty) {
    throw const FormatException('No usable countries in response');
  }

  return countries;
}
