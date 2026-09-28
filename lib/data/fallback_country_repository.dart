import '../core/quiz_config.dart';
import '../core/result.dart';
import '../models/country.dart';
import 'country_filter.dart';
import 'country_repository.dart';

/// Tries the API first and falls back to the checked-in country list.
///
/// Whichever source answers, the pool is filtered down to sovereign states and
/// checked for a minimum viable size, so the quiz either gets a usable pool or a
/// [Failure] it can show.
class FallbackCountryRepository implements CountryRepository {
  FallbackCountryRepository(this._primary, this._fallback);

  final CountryRepository _primary;
  final CountryRepository _fallback;

  List<Country>? _cache;
  bool _usingOfflineData = false;
  Failure? _lastRemoteFailure;

  /// True when the last successful load came from the offline list, which the
  /// UI surfaces as a non-blocking banner.
  bool get isUsingOfflineData => _usingOfflineData;

  /// Why the remote source was not used, if it was not.
  Failure? get lastRemoteFailure => _lastRemoteFailure;

  @override
  Future<Result<List<Country>>> getCountries({bool forceRefresh = false}) async {
    final List<Country>? cached = _cache;
    if (!forceRefresh && cached != null) return Ok<List<Country>>(cached);

    final Result<List<Country>> remote = await _primary.getCountries(
      forceRefresh: forceRefresh,
    );

    if (remote case Ok<List<Country>>(:final List<Country> value)) {
      _lastRemoteFailure = null;
      return _finish(value);
    }

    _lastRemoteFailure = remote.failureOrNull;
    final Result<List<Country>> offline = await _fallback.getCountries(
      forceRefresh: forceRefresh,
    );

    return switch (offline) {
      Ok<List<Country>>(:final List<Country> value) => _finish(
        value,
        usingOfflineData: true,
      ),
      Err<List<Country>>(:final Failure failure) => Err<List<Country>>(failure),
    };
  }

  Result<List<Country>> _finish(
    List<Country> raw, {
    bool usingOfflineData = false,
  }) {
    final List<Country> filtered = CountryFilter.sovereignOnly(raw);

    if (filtered.length < QuizConfig.optionCount) {
      return Err<List<Country>>(
        const Failure(
          FailureKind.parsing,
          'Not enough countries to build a question.',
        ),
      );
    }

    _cache = filtered;
    _usingOfflineData = usingOfflineData;
    return Ok<List<Country>>(filtered);
  }
}
