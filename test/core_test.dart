import 'package:country_trivia/core/app_config.dart';
import 'package:country_trivia/core/quiz_config.dart';
import 'package:country_trivia/core/result.dart';
import 'package:country_trivia/data/countries.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QuizConfig', () {
    test('awards 10, 8 then 5 for the first three attempts', () {
      expect(QuizConfig.pointsForAttempt(0), 10);
      expect(QuizConfig.pointsForAttempt(1), 8);
      expect(QuizConfig.pointsForAttempt(2), 5);
    });

    test('awards nothing once the ladder is exhausted', () {
      expect(QuizConfig.pointsForAttempt(3), 0);
      expect(QuizConfig.pointsForAttempt(99), 0);
    });

    test('offers three attempts so a fourth tap reveals', () {
      expect(QuizConfig.attemptsPerQuestion, 3);
    });

    test('maximum score assumes a first-try answer every time', () {
      expect(QuizConfig.maxScore, QuizConfig.questionCount * 10);
      expect(QuizConfig.maxScore, 100);
    });
  });

  group('AppConfig', () {
    test('defaults to the countriesnow.space base URL', () {
      expect(AppConfig.apiBaseUrl, 'https://countriesnow.space');
    });

    test('builds HTTPS flag URLs only', () {
      final String url = AppConfig.flagUrl('jp');
      expect(url, 'https://flagcdn.com/w320/jp.png');
      expect(url.startsWith('https://'), isTrue);
    });
  });

  group('Result', () {
    test('Ok exposes its value and no failure', () {
      const Result<int> result = Ok<int>(7);
      expect(result.isOk, isTrue);
      expect(result.isErr, isFalse);
      expect(result.valueOrNull, 7);
      expect(result.failureOrNull, isNull);
    });

    test('Err exposes its failure and no value', () {
      const Result<int> result = Err<int>(Failure.network());
      expect(result.isErr, isTrue);
      expect(result.valueOrNull, isNull);
      expect(result.failureOrNull?.kind, FailureKind.network);
    });

    test('map transforms a success and passes a failure through', () {
      expect(const Ok<int>(2).map((int v) => v * 3).valueOrNull, 6);

      const Result<int> failed = Err<int>(Failure.timeout());
      final Result<String> mapped = failed.map((int v) => '$v');
      expect(mapped.failureOrNull?.kind, FailureKind.timeout);
    });

    test('fold collapses both branches', () {
      expect(const Ok<int>(5).fold((int v) => v, (Failure f) => -1), 5);
      expect(
        const Err<int>(Failure.parsing()).fold((int v) => v, (Failure f) => -1),
        -1,
      );
    });
  });

  group('Failure', () {
    test('network and timeout are retryable, parsing is not', () {
      expect(const Failure.network().isRetryable, isTrue);
      expect(const Failure.timeout().isRetryable, isTrue);
      expect(const Failure.parsing().isRetryable, isFalse);
    });
  });

  group('offline fallback list', () {
    test('is not empty and holds unique lowercase codes', () {
      expect(countries, isNotEmpty);
      expect(countries.length, greaterThanOrEqualTo(4));

      final Set<String> codes =
          countries.map((c) => c.iso2).toSet();
      expect(codes.length, countries.length, reason: 'duplicate country codes');

      for (final country in countries) {
        expect(
          country.iso2Lowercase,
          matches(RegExp(r'^[a-z]{2}$')),
          reason: '${country.name} has a non ISO 3166-1 alpha-2 code',
        );
        expect(country.name.trim(), isNotEmpty);
      }
    });
  });
}
