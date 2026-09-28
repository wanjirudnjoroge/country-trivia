import '../core/result.dart';
import '../models/country.dart';
import 'country_remote_data_source.dart';
import 'country_repository.dart';

/// Fetches countries from the API and caches them for the session.
///
/// The endpoint sends `cache-control: max-age=86400`, so a second fetch within
/// a run is pointless.
class RemoteCountryRepository implements CountryRepository {
  RemoteCountryRepository(this._dataSource);

  final CountryRemoteDataSource _dataSource;
  List<Country>? _cache;

  @override
  Future<Result<List<Country>>> getCountries({bool forceRefresh = false}) async {
    final List<Country>? cached = _cache;
    if (!forceRefresh && cached != null) return Ok<List<Country>>(cached);

    final Result<List<Country>> result = await _dataSource.fetchCountries();
    if (result case Ok<List<Country>>(:final List<Country> value)) {
      _cache = value;
    }
    return result;
  }
}
