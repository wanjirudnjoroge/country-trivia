import 'package:country_trivia/core/result.dart';
import 'package:country_trivia/data/country_repository.dart';
import 'package:country_trivia/models/country.dart';

/// A pool with predictable names, so tests can reason about options.
List<Country> buildTestPool({int size = 30}) => <Country>[
  for (int i = 0; i < size; i++)
    Country(name: 'Country $i', iso2: 'C${i.toString().padLeft(2, '0')}'),
];

/// Serves a fixed list, or a fixed failure, without touching the network.
class FakeCountryRepository implements CountryRepository {
  FakeCountryRepository({List<Country>? countries, this.failure})
    : countries = countries ?? buildTestPool();

  final List<Country> countries;
  Failure? failure;
  int calls = 0;
  int forceRefreshCalls = 0;

  @override
  Future<Result<List<Country>>> getCountries({bool forceRefresh = false}) async {
    calls++;
    if (forceRefresh) forceRefreshCalls++;
    final Failure? failure = this.failure;
    if (failure != null) return Err<List<Country>>(failure);
    return Ok<List<Country>>(countries);
  }

}
