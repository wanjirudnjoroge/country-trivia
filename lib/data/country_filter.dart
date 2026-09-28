import '../models/country.dart';

/// Filters the country pool down to sovereign states.
///
/// The API returns 222 entries, many of which are overseas territories or
/// dependencies rather than countries. Asking "which country is this flag?" about
/// a flag that belongs to Bermuda or Puerto Rico is ambiguous, so those ISO codes
/// are excluded before questions are generated.
class CountryFilter {
  const CountryFilter._();

  /// ISO 3166-1 alpha-2 codes that are not sovereign states.
  static const Set<String> nonSovereignIso2Codes = <String>{
    'AI', // Anguilla
    'AW', // Aruba
    'BM', // Bermuda
    'BV', // Bouvet Island
    'CC', // Cocos (Keeling) Islands
    'CK', // Cook Islands
    'CX', // Christmas Island
    'FK', // Falkland Islands
    'FO', // Faroe Islands
    'GG', // Guernsey
    'GI', // Gibraltar
    'GL', // Greenland
    'GP', // Guadeloupe
    'GU', // Guam
    'GS', // South Georgia and the South Sandwich Islands
    'HM', // Heard Island and McDonald Islands
    'HK', // Hong Kong
    'IM', // Isle of Man
    'IO', // British Indian Ocean Territory
    'JE', // Jersey
    'KY', // Cayman Islands
    'MO', // Macau
    'MP', // Northern Mariana Islands
    'MQ', // Martinique
    'NC', // New Caledonia
    'NF', // Norfolk Island
    'NU', // Niue
    'PF', // French Polynesia
    'PM', // Saint Pierre and Miquelon
    'PN', // Pitcairn
    'PR', // Puerto Rico
    'RE', // Reunion
    'TC', // Turks and Caicos Islands
    'TK', // Tokelau
    'UM', // United States Minor Outlying Islands
    'WF', // Wallis and Futuna
    'YT', // Mayotte
  };

  /// Notes on borderline entries that are deliberately kept:
  /// Taiwan is treated as a country, Czech Republic, Eswatini (listed as
  /// "Swaziland"), the Marshall Islands, Palau, Samoa and Tuvalu are all
  /// sovereign UN members. The API has no entry for Palestine or Kosovo, so
  /// those can never be asked.
  static bool isSovereign(Country country) =>
      !nonSovereignIso2Codes.contains(country.iso2.toUpperCase());

  /// Returns only the sovereign entries of [countries], order preserved.
  static List<Country> sovereignOnly(List<Country> countries) =>
      countries.where(isSovereign).toList(growable: false);
}
