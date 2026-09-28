import '../core/result.dart';
import '../models/country.dart';

/// Supplies the countries the quiz is built from.
///
/// The ViewModel depends on this interface only, so tests can substitute a fake
/// without any network.
abstract class CountryRepository {
  /// Returns the country pool, or a [Failure].
  ///
  /// [forceRefresh] bypasses any in-memory cache.
  Future<Result<List<Country>>> getCountries({bool forceRefresh = false});
}
