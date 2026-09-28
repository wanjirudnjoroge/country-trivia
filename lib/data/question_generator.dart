import 'dart:math';

import '../core/quiz_config.dart';
import '../models/country.dart';
import '../models/question.dart';

/// Builds a run of questions from a pool of countries.
///
/// Pure logic with no Flutter or network dependency, and an injectable
/// [Random] so tests can make it deterministic.
class QuestionGenerator {
  QuestionGenerator({Random? random}) : _random = random ?? Random();

  final Random _random;

  /// Returns up to [count] questions, each with [QuizConfig.optionCount]
  /// options containing exactly one correct answer.
  ///
  /// Countries are drawn without replacement, so a run never repeats a country,
  /// and the correct answer is shuffled across positions.
  ///
  /// Throws [ArgumentError] if [pool] is smaller than [QuizConfig.optionCount],
  /// because no question could be built.
  List<Question> generate(
    List<Country> pool, {
    int count = QuizConfig.questionCount,
  }) {
    if (pool.length < QuizConfig.optionCount) {
      throw ArgumentError.value(
        pool.length,
        'pool',
        'needs at least ${QuizConfig.optionCount} countries to build a question',
      );
    }

    final List<Country> draw = List<Country>.of(pool)..shuffle(_random);
    final List<Country> picked = draw.take(min(count, draw.length)).toList();

    return <Question>[
      for (final Country country in picked) _buildQuestion(country, pool),
    ];
  }

  /// One question: the given country plus three random distinct others,
  /// shuffled into a random position.
  Question _buildQuestion(Country country, List<Country> pool) {
    final List<Country> distractors = pool
        .where((Country candidate) => candidate != country)
        .toList()
      ..shuffle(_random);

    final List<Country> options = <Country>[
      ...distractors.take(QuizConfig.optionCount - 1),
      country,
    ]..shuffle(_random);

    return Question(
      country: country,
      options: options,
      correctIndex: options.indexOf(country),
    );
  }
}
