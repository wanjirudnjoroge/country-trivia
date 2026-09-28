import '../core/result.dart';
import '../models/country.dart';
import 'countries.dart' as fallback_data;
import 'country_repository.dart';

/// Serves the checked-in country list.
///
/// Used as the offline fallback and in tests, so it never fails and never
/// touches the network.
class StaticCountryRepository implements CountryRepository {
  StaticCountryRepository({List<Country>? countries})
    : _countries = List<Country>.unmodifiable(countries ?? fallback_data.countries);

  final List<Country> _countries;

  @override
  Future<Result<List<Country>>> getCountries({bool forceRefresh = false}) async =>
      Ok<List<Country>>(_countries);
}
