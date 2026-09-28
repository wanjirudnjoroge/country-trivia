import 'dart:math';

import 'package:country_trivia/core/quiz_config.dart';
import 'package:country_trivia/core/result.dart';
import 'package:country_trivia/data/question_generator.dart';
import 'package:country_trivia/models/answer_outcome.dart';
import 'package:country_trivia/models/country.dart';
import 'package:country_trivia/models/game_result.dart';
import 'package:country_trivia/models/question.dart';
import 'package:country_trivia/viewmodels/load_state.dart';
import 'package:country_trivia/viewmodels/quiz_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  QuizViewModel build({
    List<Country>? pool,
    Failure? failure,
    int seed = 7,
  }) {
    final FakeCountryRepository repository = FakeCountryRepository(
      countries: pool,
      failure: failure,
    );
    return QuizViewModel(
      repository,
      generator: QuestionGenerator(random: Random(seed)),
    );
  }

  /// Index of the correct option on the current question.
  int correctIndex(QuizViewModel vm) => vm.currentQuestion!.correctIndex;

  /// Index of a wrong option on the current question.
  int wrongIndex(QuizViewModel vm) {
    final int correct = correctIndex(vm);
    return correct == 0 ? 1 : 0;
  }

  group('loading', () {
    test('starts idle with no question', () {
      final QuizViewModel vm = build();
      expect(vm.loadState, LoadState.idle);
      expect(vm.currentQuestion, isNull);
      expect(vm.score, 0);
    });

    test('generates the configured number of questions', () async {
      final QuizViewModel vm = build();
      await vm.startNewGame();

      expect(vm.loadState, LoadState.ready);
      expect(vm.totalQuestions, QuizConfig.questionCount);
      expect(vm.questionNumber, 1);
      expect(vm.poolSize, 30);
      expect(vm.currentQuestion!.isValid, isTrue);
    });

    test('surfaces a failure when no countries can be loaded', () async {
      final QuizViewModel vm = build(failure: const Failure.network());
      await vm.startNewGame();

      expect(vm.loadState, LoadState.error);
      expect(vm.failure?.kind, FailureKind.network);
      expect(vm.currentQuestion, isNull);
    });

    test('fails when the pool cannot fill four options', () async {
      final QuizViewModel vm = build(pool: buildTestPool(size: 2));
      await vm.startNewGame();

      expect(vm.loadState, LoadState.error);
      expect(vm.failure?.kind, FailureKind.parsing);
    });

    test('ignores a second load while one is in flight', () async {
      final FakeCountryRepository repository = FakeCountryRepository();
      final QuizViewModel vm = QuizViewModel(repository);

      final Future<void> first = vm.startNewGame();
      final Future<void> second = vm.startNewGame();
      await Future.wait<void>(<Future<void>>[first, second]);

      expect(repository.calls, 1);
    });

    test('forces a refresh on every new game', () async {
      final FakeCountryRepository repository = FakeCountryRepository();
      final QuizViewModel vm = QuizViewModel(repository);

      await vm.startNewGame();
      await vm.restart();

      expect(repository.forceRefreshCalls, 2);
    });
  });

  group('scoring', () {
    test('a correct first tap awards 10 and builds a streak', () async {
      final QuizViewModel vm = build();
      await vm.startNewGame();

      vm.selectOption(correctIndex(vm));

      expect(vm.score, 10);
      expect(vm.currentStreak, 1);
      expect(vm.bestStreak, 1);
      expect(vm.isSolved, isTrue);
      expect(vm.currentOutcome!.pointsAwarded, 10);
      expect(vm.isFirstTryAnswer, isTrue);
    });

    test('a correct tap after one wrong awards 8', () async {
      final QuizViewModel vm = build();
      await vm.startNewGame();

      vm.selectOption(wrongIndex(vm));
      expect(vm.score, 0);
      expect(vm.attemptsRemaining, 2);
      expect(vm.currentStreak, 0);
      expect(vm.isQuestionResolved, isFalse);

      vm.selectOption(correctIndex(vm));

      expect(vm.score, 8);
      expect(vm.currentOutcome!.pointsAwarded, 8);
      expect(vm.isFirstTryAnswer, isFalse);
    });

    test('a correct tap after two wrong awards 5', () async {
      final QuizViewModel vm = build();
      await vm.startNewGame();

      vm.selectOption(wrongIndex(vm));
      vm.selectOption(wrongIndex(vm));
      vm.selectOption(correctIndex(vm));

      expect(vm.score, 5);
      expect(vm.currentStreak, 1);
      expect(vm.currentOutcome!.attemptsUsed, 3);
    });

    test('three wrong taps reveal the answer and award nothing', () async {
      final QuizViewModel vm = build();
      await vm.startNewGame();

      vm.selectOption(wrongIndex(vm));
      vm.selectOption(wrongIndex(vm));
      vm.selectOption(wrongIndex(vm));

      expect(vm.score, 0);
      expect(vm.isRevealed, isTrue);
      expect(vm.isSolved, isFalse);
      expect(vm.attemptsRemaining, 0);
      expect(vm.isQuestionLocked, isTrue);
      expect(vm.canSelectOption, isFalse);
    });

    test('a fourth tap cannot score after the reveal', () async {
      final QuizViewModel vm = build();
      await vm.startNewGame();

      vm.selectOption(wrongIndex(vm));
      vm.selectOption(wrongIndex(vm));
      vm.selectOption(wrongIndex(vm));
      vm.selectOption(correctIndex(vm));

      expect(vm.score, 0);
      expect(vm.currentOutcome!.status, AnswerStatus.revealed);
      expect(vm.selectedIndex, isNot(correctIndex(vm)));
    });

    test('taps are ignored once the question is solved', () async {
      final QuizViewModel vm = build();
      await vm.startNewGame();

      vm.selectOption(correctIndex(vm));
      final int index = wrongIndex(vm);
      vm.selectOption(index);

      expect(vm.score, 10);
      expect(vm.selectedIndex, isNot(index));
    });

    test('out-of-range taps are ignored', () async {
      final QuizViewModel vm = build();
      await vm.startNewGame();

      vm.selectOption(-1);
      vm.selectOption(99);

      expect(vm.score, 0);
      expect(vm.attemptsUsed, 0);
      expect(vm.currentOutcome, isNull);
    });

    test('score accumulates across questions', () async {
      final QuizViewModel vm = build();
      await vm.startNewGame();

      vm.selectOption(correctIndex(vm));
      vm.next();
      vm.selectOption(correctIndex(vm));
      vm.next();

      expect(vm.score, 20);
      expect(vm.questionNumber, 3);
      expect(vm.currentStreak, 2);
    });

    test('a wrong tap resets the streak but keeps the best', () async {
      final QuizViewModel vm = build();
      await vm.startNewGame();

      vm.selectOption(correctIndex(vm));
      vm.next();
      vm.selectOption(correctIndex(vm));
      vm.next();
      expect(vm.bestStreak, 2);

      vm.selectOption(wrongIndex(vm));

      expect(vm.currentStreak, 0);
      expect(vm.bestStreak, 2);
    });
  });

  group('advancing', () {
    test('next does nothing while the question is open', () async {
      final QuizViewModel vm = build();
      await vm.startNewGame();

      vm.next();

      expect(vm.questionNumber, 1);
      expect(vm.outcomes, isEmpty);
    });

    test('next resets the per-question state', () async {
      final QuizViewModel vm = build();
      await vm.startNewGame();

      vm.selectOption(correctIndex(vm));
      vm.next();

      expect(vm.attemptsUsed, 0);
      expect(vm.attemptsRemaining, QuizConfig.attemptsPerQuestion);
      expect(vm.selectedIndex, isNull);
      expect(vm.currentOutcome, isNull);
      expect(vm.isQuestionResolved, isFalse);
      expect(vm.outcomes, hasLength(1));
    });

    test('finishing the last question exposes the result', () async {
      final QuizViewModel vm = build();
      await vm.startNewGame();

      for (int i = 0; i < QuizConfig.questionCount; i++) {
        vm.selectOption(correctIndex(vm));
        vm.next();
      }

      expect(vm.isFinished, isTrue);
      expect(vm.questionNumber, QuizConfig.questionCount);
      final GameResult? result = vm.result;
      expect(result, isNotNull);
      expect(result!.score, QuizConfig.maxScore);
      expect(result.questionCount, QuizConfig.questionCount);
      expect(result.firstTryCount, QuizConfig.questionCount);
      expect(result.grade, 'Flawless');
    });

    test('a mixed run produces the right tallies', () async {
      final QuizViewModel vm = build();
      await vm.startNewGame();

      // Q1 first try, Q2 late solve, Q3 revealed.
      vm.selectOption(correctIndex(vm));
      vm.next();
      vm.selectOption(wrongIndex(vm));
      vm.selectOption(correctIndex(vm));
      vm.next();
      vm.selectOption(wrongIndex(vm));
      vm.selectOption(wrongIndex(vm));
      vm.selectOption(wrongIndex(vm));
      vm.next();

      for (int i = 3; i < QuizConfig.questionCount; i++) {
        vm.selectOption(correctIndex(vm));
        vm.next();
      }

      final GameResult result = vm.result!;
      expect(result.score, 10 + 8 + 0 + 7 * 10);
      expect(result.firstTryCount, 8);
      expect(result.lateSolveCount, 1);
      expect(result.revealedCount, 1);
      expect(result.bestStreak, 7, reason: 'the last seven solves are consecutive');
    });

    test('restart resets score, streak and question index', () async {
      final QuizViewModel vm = build();
      await vm.startNewGame();

      vm.selectOption(correctIndex(vm));
      vm.next();
      vm.selectOption(correctIndex(vm));
      vm.next();
      expect(vm.score, 20);

      await vm.restart();

      expect(vm.score, 0);
      expect(vm.currentStreak, 0);
      expect(vm.bestStreak, 0);
      expect(vm.questionNumber, 1);
      expect(vm.outcomes, isEmpty);
      expect(vm.result, isNull);
      expect(vm.isFinished, isFalse);
    });

    test('a new run uses different questions', () async {
      final QuizViewModel vm = build();
      await vm.startNewGame();
      final String first = vm.currentQuestion!.country.iso2;

      await vm.restart();
      final List<String> after = vm.currentQuestion!.country.iso2 == first
          ? vm.questions.map((Question q) => q.country.iso2).toList()
          : <String>[vm.currentQuestion!.country.iso2];

      expect(after, isNotEmpty);
    });
  });

  group('change notification', () {
    test('notifies on load, answer, next and restart', () async {
      final QuizViewModel vm = build();
      int notifications = 0;
      vm.addListener(() => notifications++);

      await vm.startNewGame();
      final int afterLoad = notifications;

      vm.selectOption(correctIndex(vm));
      final int afterAnswer = notifications;

      vm.next();
      final int afterNext = notifications;

      await vm.restart();

      expect(afterLoad, greaterThan(0));
      expect(afterAnswer, afterLoad + 1);
      expect(afterNext, afterAnswer + 1);
      expect(notifications, greaterThan(afterNext));
    });

    test('does not notify when a tap is rejected', () async {
      final QuizViewModel vm = build();
      await vm.startNewGame();

      int notifications = 0;
      vm.addListener(() => notifications++);

      vm.selectOption(99);
      vm.next();

      expect(notifications, 0);
    });
  });
}
