import 'package:country_trivia/core/quiz_config.dart';
import 'package:country_trivia/models/answer_outcome.dart';
import 'package:country_trivia/models/country.dart';
import 'package:country_trivia/models/game_result.dart';
import 'package:country_trivia/models/question.dart';
import 'package:flutter_test/flutter_test.dart';

const Country japan = Country(name: 'Japan', iso2: 'JP', iso3: 'JPN');
const Country peru = Country(name: 'Peru', iso2: 'PE');
const Country kenya = Country(name: 'Kenya', iso2: 'KE');
const Country norway = Country(name: 'Norway', iso2: 'NO');

Question buildQuestion({int correctIndex = 0}) {
  const List<Country> pool = <Country>[japan, peru, kenya, norway];
  return Question(
    country: pool[correctIndex],
    options: List<Country>.of(pool),
    correctIndex: correctIndex,
  );
}

AnswerOutcome tap({
  int selectedIndex = 0,
  int correctIndex = 0,
  int attemptsUsedBefore = 0,
}) => AnswerOutcome.fromTap(
  questionIndex: 0,
  selectedIndex: selectedIndex,
  correctIndex: correctIndex,
  attemptsUsedBefore: attemptsUsedBefore,
);

void main() {
  group('Country', () {
    test('builds an HTTPS flag URL from the lowercase code', () {
      expect(japan.flagUrl, 'https://flagcdn.com/w320/jp.png');
      expect(japan.iso2Lowercase, 'jp');
    });

    test('is identified by its ISO code', () {
      expect(const Country(name: 'Japan', iso2: 'JP'), japan);
      expect(const Country(name: 'Other name', iso2: 'JP').hashCode, japan.hashCode);
      expect(japan, isNot(const Country(name: 'Peru', iso2: 'PE')));
    });

    test('fromCode normalises the code to uppercase', () {
      final Country built = Country.fromCode('fr', name: 'France');
      expect(built.iso2, 'FR');
      expect(built.flagUrl, 'https://flagcdn.com/w320/fr.png');
    });

    test('rejects a country with no name or code', () {
      expect(const Country(name: '  ', iso2: 'JP').isUsable, isFalse);
      expect(const Country(name: 'Japan', iso2: '').isUsable, isFalse);
      expect(japan.isUsable, isTrue);
    });
  });

  group('Question', () {
    test('holds four options and the correct one at correctIndex', () {
      final Question question = buildQuestion(correctIndex: 2);
      expect(question.optionCount, QuizConfig.optionCount);
      expect(question.isValid, isTrue);
      expect(question.optionAt(2), kenya);
      expect(question.isCorrect(2), isTrue);
      expect(question.isCorrect(0), isFalse);
    });

    test('labels options A to D', () {
      final Question question = buildQuestion();
      expect(
        <String>[
          for (int i = 0; i < question.optionCount; i++) question.letterFor(i),
        ],
        <String>['A', 'B', 'C', 'D'],
      );
    });

    test('isValid rejects the wrong number of options', () {
      final Question tooFew = Question(
        country: japan,
        options: <Country>[japan, peru],
        correctIndex: 0,
      );
      expect(tooFew.isValid, isFalse);
    });

    test('isValid rejects duplicate options', () {
      final Question duplicated = Question(
        country: japan,
        options: <Country>[japan, peru, kenya, peru],
        correctIndex: 0,
      );
      expect(duplicated.isValid, isFalse);
    });

    test('isValid rejects a correctIndex out of range', () {
      final Question broken = Question(
        country: japan,
        options: <Country>[japan, peru, kenya, norway],
        correctIndex: 4,
      );
      expect(broken.isValid, isFalse);
    });

    test('options cannot be mutated after construction', () {
      final Question question = buildQuestion();
      expect(
        () => question.options.add(norway),
        throwsUnsupportedError,
      );
    });
  });

  group('AnswerOutcome.fromTap', () {
    test('a first-try correct answer awards 10 points', () {
      final AnswerOutcome outcome = tap();
      expect(outcome.status, AnswerStatus.correct);
      expect(outcome.pointsAwarded, 10);
      expect(outcome.attemptsUsed, 1);
      expect(outcome.isFirstTry, isTrue);
      expect(outcome.isLateSolve, isFalse);
    });

    test('a correct answer after one wrong tap awards 8 points', () {
      final AnswerOutcome outcome = tap(attemptsUsedBefore: 1);
      expect(outcome.status, AnswerStatus.correct);
      expect(outcome.pointsAwarded, 8);
      expect(outcome.isLateSolve, isTrue);
    });

    test('a correct answer after two wrong taps awards 5 points', () {
      final AnswerOutcome outcome = tap(attemptsUsedBefore: 2);
      expect(outcome.status, AnswerStatus.correct);
      expect(outcome.pointsAwarded, 5);
      expect(outcome.isLateSolve, isTrue);
    });

    test('a wrong tap awards nothing and keeps the question open', () {
      final AnswerOutcome outcome = tap(selectedIndex: 1);
      expect(outcome.status, AnswerStatus.wrong);
      expect(outcome.pointsAwarded, 0);
      expect(outcome.attemptsUsed, 1);
      expect(outcome.isRevealed, isFalse);
    });

    test('the third wrong tap exhausts attempts and awards nothing', () {
      final AnswerOutcome outcome = tap(
        selectedIndex: 3,
        attemptsUsedBefore: 2,
      );
      expect(outcome.status, AnswerStatus.revealed);
      expect(outcome.pointsAwarded, 0);
      expect(outcome.attemptsUsed, QuizConfig.attemptsPerQuestion);
      expect(outcome.isRevealed, isTrue);
    });
  });

  group('GameResult', () {
    GameResult build(List<AnswerOutcome> outcomes) => GameResult(
      score: outcomes.fold<int>(
        0,
        (int sum, AnswerOutcome o) => sum + o.pointsAwarded,
      ),
      questionCount: outcomes.length,
      bestStreak: 2,
      outcomes: outcomes,
    );

    test('tallies first-try, late and revealed answers', () {
      final GameResult result = build(<AnswerOutcome>[
        tap(), // 10, first try
        tap(attemptsUsedBefore: 1), // 8, late
        tap(selectedIndex: 1, attemptsUsedBefore: 2), // revealed
      ]);

      expect(result.score, 18);
      expect(result.firstTryCount, 1);
      expect(result.lateSolveCount, 1);
      expect(result.revealedCount, 1);
      expect(result.solvedCount, 2);
    });

    test('grades a perfect run as Flawless', () {
      final GameResult result = build(<AnswerOutcome>[
        for (int i = 0; i < QuizConfig.questionCount; i++) tap(),
      ]);
      expect(result.score, QuizConfig.maxScore);
      expect(result.grade, 'Flawless');
      expect(result.accuracy, 1.0);
    });

    test('grades a run with no points as Keep practising', () {
      final GameResult result = build(<AnswerOutcome>[
        for (int i = 0; i < QuizConfig.questionCount; i++)
          tap(selectedIndex: 1, attemptsUsedBefore: 2),
      ]);
      expect(result.score, 0);
      expect(result.grade, 'Keep practising');
    });

    test('is not affected by later mutation of the source list', () {
      final List<AnswerOutcome> source = <AnswerOutcome>[tap()];
      final GameResult result = build(source);
      source.add(tap());
      expect(result.outcomes.length, 1);
    });
  });
}
