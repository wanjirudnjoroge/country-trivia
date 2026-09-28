import '../core/result.dart';
import '../models/country.dart';
import 'api_client.dart';
import 'country_dto.dart';

/// Fetches the country list from the remote API.
class CountryRemoteDataSource {
  const CountryRemoteDataSource(this._apiClient, {required this.path});

  final ApiClient _apiClient;

  /// Path appended to the base URL, see `AppConfig.countriesPath`.
  final String path;

  /// Returns every country the API knows about, or a [Failure].
  Future<Result<List<Country>>> fetchCountries() async {
    final Result<Object?> body = await _apiClient.getJson(path);

    return switch (body) {
      Ok<Object?>(:final Object? value) => _parse(value),
      Err<Object?>(:final Failure failure) => Err<List<Country>>(failure),
    };
  }

  Result<List<Country>> _parse(Object? json) {
    try {
      return Ok<List<Country>>(parseCountryList(json));
    } on FormatException catch (error) {
      return Err<List<Country>>(
        Failure(FailureKind.parsing, error.message, cause: error),
      );
    }
  }
}
