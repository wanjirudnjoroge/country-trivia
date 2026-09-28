import 'dart:convert';
import 'dart:math';

import 'package:country_trivia/core/app_config.dart';
import 'package:country_trivia/core/quiz_config.dart';
import 'package:country_trivia/core/result.dart';
import 'package:country_trivia/data/api_client.dart';
import 'package:country_trivia/data/country_dto.dart';
import 'package:country_trivia/data/country_filter.dart';
import 'package:country_trivia/data/country_remote_data_source.dart';
import 'package:country_trivia/data/fallback_country_repository.dart';
import 'package:country_trivia/data/question_generator.dart';
import 'package:country_trivia/data/remote_country_repository.dart';
import 'package:country_trivia/data/static_country_repository.dart';
import 'package:country_trivia/models/country.dart';
import 'package:country_trivia/models/question.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A trimmed copy of the real countriesnow.space payload.
const String _realEnvelope = '''
{
  "error": false,
  "msg": "flags images retrieved",
  "data": [
    {"name":"Afghanistan","flag":"https://upload.wikimedia.org/a.svg","iso2":"AF","iso3":"AFG"},
    {"name":"Albania","flag":"https://upload.wikimedia.org/b.svg","iso2":"AL","iso3":"ALB"},
    {"name":"Bermuda","flag":"https://upload.wikimedia.org/bm.svg","iso2":"BM","iso3":"BMU"},
    {"name":"Japan","flag":"https://upload.wikimedia.org/j.svg","iso2":"JP","iso3":"JPN"},
    {"name":"Peru","flag":"https://upload.wikimedia.org/pe.svg","iso2":"PE","iso3":"PER"},
    {"name":"","iso2":"XX","iso3":"XXX"},
    {"name":"Namibia","iso2":"TOOLONG","iso3":"NAM"}
  ]
}
''';

http.Client _clientReturning(
  Object? body, {
  int status = 200,
  Duration? delay,
}) {
  return MockClient((http.Request request) async {
    if (delay != null) await Future<void>.delayed(delay);
    return http.Response(
      body is String ? body : jsonEncode(body),
      status,
      headers: const <String, String>{'content-type': 'application/json'},
    );
  });
}

ApiClient _api(http.Client client) => ApiClient(client);

CountryRemoteDataSource _source(http.Client client) =>
    CountryRemoteDataSource(_api(client), path: AppConfig.countriesPath);

void main() {
  group('CountryDto', () {
    test('parses a well-formed entry and uppercases the code', () {
      final CountryDto? dto = CountryDto.tryParse(<String, Object?>{
        'name': ' Japan ',
        'iso2': 'jp',
        'iso3': 'jpn',
      });

      expect(dto, isNotNull);
      expect(dto!.name, 'Japan');
      expect(dto.iso2, 'JP');
      expect(dto.iso3, 'JPN');
      expect(dto.toCountry().flagUrl, 'https://flagcdn.com/w320/jp.png');
    });

    test('accepts the Iso2 spelling used by the sibling /iso endpoint', () {
      final CountryDto? dto = CountryDto.tryParse(<String, Object?>{
        'name': 'Nigeria',
        'Iso2': 'NG',
        'Iso3': 'NGA',
      });

      expect(dto?.iso2, 'NG');
    });

    test('rejects entries with a missing name, code or wrong code length', () {
      expect(CountryDto.tryParse(<String, Object?>{'iso2': 'JP'}), isNull);
      expect(CountryDto.tryParse(<String, Object?>{'name': 'Japan'}), isNull);
      expect(CountryDto.tryParse(<String, Object?>{'name': '  ', 'iso2': 'JP'}), isNull);
      expect(
        CountryDto.tryParse(<String, Object?>{'name': 'Namibia', 'iso2': 'NAM'}),
        isNull,
      );
      expect(CountryDto.tryParse('not a map'), isNull);
    });
  });

  group('parseCountryList', () {
    test('unwraps the envelope and drops unusable entries', () {
      final List<Country> countries = parseCountryList(jsonDecode(_realEnvelope));
      final List<String> names = countries
          .map((Country c) => c.name)
          .toList();

      expect(names, <String>['Afghanistan', 'Albania', 'Bermuda', 'Japan', 'Peru']);
    });

    test('accepts a bare list too', () {
      final List<Country> countries = parseCountryList(<Object?>[
        <String, Object?>{'name': 'Japan', 'iso2': 'JP'},
      ]);

      expect(countries.single.name, 'Japan');
    });

    test('throws when the payload has no data field or is empty', () {
      expect(
        () => parseCountryList(<String, Object?>{'error': true}),
        throwsFormatException,
      );
      expect(
        () => parseCountryList(<String, Object?>{'data': <Object?>[]}),
        throwsFormatException,
      );
      expect(() => parseCountryList(42), throwsFormatException);
    });
  });

  group('ApiClient', () {
    test('returns the decoded body on 200', () async {
      final ApiClient client = _api(_clientReturning(_realEnvelope));
      final Result<Object?> result = await client.getJson('/x');

      expect(result.isOk, isTrue);
      expect(result.valueOrNull, isA<Map<String, dynamic>>());
    });

    test('maps a non-200 status to a server failure', () async {
      final ApiClient client = _api(
        _clientReturning('{"error":true}', status: 503),
      );
      final Result<Object?> result = await client.getJson('/x');

      expect(result.failureOrNull?.kind, FailureKind.server);
      expect(result.failureOrNull?.statusCode, 503);
      expect(result.failureOrNull?.isRetryable, isTrue);
    });

    test('maps a slow response to a timeout failure', () async {
      final ApiClient client = ApiClient(
        _clientReturning(_realEnvelope, delay: const Duration(seconds: 2)),
        timeout: const Duration(milliseconds: 50),
      );

      final Result<Object?> result = await client.getJson('/x');
      expect(result.failureOrNull?.kind, FailureKind.timeout);
    });

    test('maps invalid JSON to a parsing failure', () async {
      final ApiClient client = _api(_clientReturning('not json'));
      final Result<Object?> result = await client.getJson('/x');

      expect(result.failureOrNull?.kind, FailureKind.parsing);
    });

    test('maps a connection error to a network failure', () async {
      final ApiClient client = _api(
        MockClient((http.Request request) async {
          throw http.ClientException('Connection closed', request.url);
        }),
      );

      final Result<Object?> result = await client.getJson('/x');
      expect(result.failureOrNull?.kind, FailureKind.network);
    });
  });

  group('CountryRemoteDataSource', () {
    test('maps the real payload to models', () async {
      final Result<List<Country>> result =
          await _source(_clientReturning(_realEnvelope)).fetchCountries();

      expect(result.isOk, isTrue);
      expect(result.valueOrNull, hasLength(5));
    });

    test('propagates a server failure unchanged', () async {
      final Result<List<Country>> result =
          await _source(_clientReturning('{}', status: 500)).fetchCountries();

      expect(result.failureOrNull?.kind, FailureKind.server);
    });
  });

  group('CountryFilter', () {
    test('excludes territories but keeps sovereign states', () {
      expect(
        CountryFilter.isSovereign(const Country(name: 'Bermuda', iso2: 'BM')),
        isFalse,
      );
      expect(
        CountryFilter.isSovereign(const Country(name: 'Puerto Rico', iso2: 'PR')),
        isFalse,
      );
      expect(
        CountryFilter.isSovereign(const Country(name: 'Japan', iso2: 'JP')),
        isTrue,
      );
      expect(
        CountryFilter.isSovereign(const Country(name: 'Vatican City', iso2: 'VA')),
        isTrue,
      );
    });

    test('denylist is uppercase alpha-2 codes only', () {
      for (final String code in CountryFilter.nonSovereignIso2Codes) {
        expect(code, matches(RegExp(r'^[A-Z]{2}$')));
      }
    });

    test('sovereignOnly preserves the input order', () {
      final List<Country> filtered = CountryFilter.sovereignOnly(<Country>[
        const Country(name: 'Japan', iso2: 'JP'),
        const Country(name: 'Aruba', iso2: 'AW'),
        const Country(name: 'Peru', iso2: 'PE'),
      ]);

      expect(filtered.map((Country c) => c.iso2), <String>['JP', 'PE']);
    });
  });

  group('RemoteCountryRepository', () {
    test('caches after the first successful fetch', () async {
      int calls = 0;
      final RemoteCountryRepository repository = RemoteCountryRepository(
        CountryRemoteDataSource(
          _api(
            MockClient((http.Request request) async {
              calls++;
              return http.Response(_realEnvelope, 200);
            }),
          ),
          path: AppConfig.countriesPath,
        ),
      );

      await repository.getCountries();
      await repository.getCountries();
      expect(calls, 1);

      await repository.getCountries(forceRefresh: true);
      expect(calls, 2);
    });

    test('does not cache a failure', () async {
      int calls = 0;
      final RemoteCountryRepository repository = RemoteCountryRepository(
        CountryRemoteDataSource(
          _api(
            MockClient((http.Request request) async {
              calls++;
              return http.Response('nope', 500);
            }),
          ),
          path: AppConfig.countriesPath,
        ),
      );

      expect((await repository.getCountries()).isErr, isTrue);
      expect((await repository.getCountries()).isErr, isTrue);
      expect(calls, 2);
    });
  });

  group('FallbackCountryRepository', () {
    FallbackCountryRepository build({
      required http.Client remote,
    }) => FallbackCountryRepository(
      RemoteCountryRepository(_source(remote)),
      StaticCountryRepository(),
    );

    test('uses the API when it answers', () async {
      final FallbackCountryRepository repository = build(
        remote: _clientReturning(_realEnvelope),
      );

      final Result<List<Country>> result = await repository.getCountries();

      expect(result.isOk, isTrue);
      expect(repository.isUsingOfflineData, isFalse);
      expect(repository.lastRemoteFailure, isNull);
    });

    test('drops territories from the remote pool', () async {
      final FallbackCountryRepository repository = build(
        remote: _clientReturning(_realEnvelope),
      );

      final List<Country> countries = (await repository.getCountries()).valueOrNull!;
      expect(
        countries.map((Country c) => c.iso2),
        isNot(contains('BM')),
      );
    });

    test('falls back to the offline list when the API fails', () async {
      final FallbackCountryRepository repository = build(
        remote: _clientReturning('boom', status: 500),
      );

      final Result<List<Country>> result = await repository.getCountries();

      expect(result.isOk, isTrue);
      expect(repository.isUsingOfflineData, isTrue);
      expect(repository.lastRemoteFailure?.kind, FailureKind.server);
      expect(result.valueOrNull!.length, greaterThan(100));
    });

    test('falls back on a timeout too', () async {
      final FallbackCountryRepository repository = FallbackCountryRepository(
        RemoteCountryRepository(
          CountryRemoteDataSource(
            ApiClient(
              _clientReturning(
                _realEnvelope,
                delay: const Duration(seconds: 2),
              ),
              timeout: const Duration(milliseconds: 50),
            ),
            path: AppConfig.countriesPath,
          ),
        ),
        StaticCountryRepository(),
      );

      final Result<List<Country>> result = await repository.getCountries();

      expect(result.isOk, isTrue);
      expect(repository.isUsingOfflineData, isTrue);
      expect(repository.lastRemoteFailure?.kind, FailureKind.timeout);
    });

    test('fails when even the offline pool is too small', () async {
      final FallbackCountryRepository repository = FallbackCountryRepository(
        RemoteCountryRepository(
          CountryRemoteDataSource(
            _api(_clientReturning('{"data":[]}')),
            path: AppConfig.countriesPath,
          ),
        ),
        StaticCountryRepository(
          countries: <Country>[
            const Country(name: 'Japan', iso2: 'JP'),
            const Country(name: 'Peru', iso2: 'PE'),
          ],
        ),
      );

      final Result<List<Country>> result = await repository.getCountries();
      expect(result.failureOrNull?.kind, FailureKind.parsing);
    });
  });

  group('StaticCountryRepository', () {
    test('always resolves with the offline list', () async {
      final Result<List<Country>> result =
          await StaticCountryRepository().getCountries();

      expect(result.isOk, isTrue);
      expect(result.valueOrNull, isNotEmpty);
    });
  });

  group('QuestionGenerator', () {
    final List<Country> pool = <Country>[
      for (int i = 0; i < 30; i++)
        Country(name: 'Country $i', iso2: 'C${i.toString().padLeft(1, '0')}'),
    ];

    test('builds the configured number of valid questions', () {
      final List<Question> questions = QuestionGenerator(random: Random(1))
          .generate(pool);

      expect(questions, hasLength(QuizConfig.questionCount));
      for (final Question question in questions) {
        expect(question.isValid, isTrue);
        expect(question.optionCount, QuizConfig.optionCount);
      }
    });

    test('never repeats a country within a run', () {
      final List<Question> questions = QuestionGenerator(random: Random(2))
          .generate(pool, count: 10);

      final Set<String> codes = questions
          .map((Question q) => q.country.iso2)
          .toSet();
      expect(codes, hasLength(10));
    });

    test('distractors come from the same pool and differ from the answer', () {
      final List<Question> questions = QuestionGenerator(random: Random(3))
          .generate(pool, count: 5);

      for (final Question question in questions) {
        for (final Country option in question.options) {
          expect(pool, contains(option), reason: 'option must come from the pool');
        }

        expect(question.options[question.correctIndex], question.country);

        final List<Country> distractors = question.options
            .where((Country option) => option != question.country)
            .toList();
        expect(distractors, hasLength(QuizConfig.optionCount - 1));
        for (final Country option in distractors) {
          expect(option, isNot(question.country));
        }
      }
    });

    test('spreads the correct answer across all four positions', () {
      final Set<int> positions = <int>{
        for (int seed = 0; seed < 200; seed++)
          ...QuestionGenerator(random: Random(seed))
              .generate(pool, count: 1)
              .map((Question q) => q.correctIndex),
      };

      expect(positions.toSet(), <int>{0, 1, 2, 3});
    });

    test('caps the run at the pool size', () {
      final List<Question> questions = QuestionGenerator(random: Random(4))
          .generate(pool, count: 99);

      expect(questions, hasLength(pool.length));
    });

    test('refuses a pool smaller than the option count', () {
      expect(
        () => QuestionGenerator(random: Random(5)).generate(
          <Country>[
            const Country(name: 'Japan', iso2: 'JP'),
            const Country(name: 'Peru', iso2: 'PE'),
          ],
        ),
        throwsArgumentError,
      );
    });
  });
}
