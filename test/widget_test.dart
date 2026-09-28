import 'package:country_trivia/app.dart';
import 'package:country_trivia/core/app_theme.dart';
import 'package:country_trivia/core/failure.dart';
import 'package:country_trivia/core/quiz_config.dart';
import 'package:country_trivia/screens/quiz_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

/// The debug panel prints the expected answer, so the test can find the correct
/// option without depending on the random question order.
String correctCountryName(WidgetTester tester) {
  final Text line = tester.widget<Text>(
    find.textContaining('Correct answer: '),
  );
  return line.data!.split('Correct answer: ').last.split(' (').first;
}

Finder optionButton(WidgetTester tester, String countryName) => find.ancestor(
  of: find.text(countryName),
  matching: find.byType(OutlinedButton),
);

/// Names of the three options that are not the correct answer.
List<String> wrongOptionNames(WidgetTester tester, List<String> pool) {
  final String correct = correctCountryName(tester);
  return pool
      .where(
        (String name) =>
            name != correct && find.text(name).evaluate().isNotEmpty,
      )
      .toList();
}

Future<void> pumpApp(WidgetTester tester, {FakeCountryRepository? repository}) async {
  await tester.pumpWidget(
    CountryTriviaApp(repository: repository ?? FakeCountryRepository()),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> tapOption(WidgetTester tester, String countryName) async {
  await tester.ensureVisible(optionButton(tester, countryName));
  await tester.pump();
  await tester.tap(optionButton(tester, countryName));
  await tester.pump();
}

void main() {
  group('debug panel', () {
    testWidgets('shows loading, then the first question', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        CountryTriviaApp(repository: FakeCountryRepository()),
      );
      expect(find.text('Loading countries...'), findsOneWidget);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Loading countries...'), findsNothing);
      expect(find.text('Question 1 of ${QuizConfig.questionCount}'), findsOneWidget);
      expect(find.textContaining('Correct answer: '), findsOneWidget);
    });

    testWidgets('offers four options, attempts and a score', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester);

      final List<String> pool = buildTestPool()
          .map((c) => c.name)
          .toList();
      final String correct = correctCountryName(tester);

      expect(find.text(correct), findsOneWidget);
      expect(wrongOptionNames(tester, pool), hasLength(QuizConfig.optionCount - 1));
      expect(find.text('Attempts left: 3'), findsOneWidget);
      expect(find.text('Score: 0'), findsOneWidget);
      expect(find.text('Streak: 0 (best 0)'), findsOneWidget);
      expect(find.text('Sovereign pool: 30 countries'), findsOneWidget);
      expect(find.textContaining('countriesnow.space API'), findsOneWidget);
    });

    testWidgets('a correct tap scores 10 and enables Next', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester);
      final String correct = correctCountryName(tester);

      final Finder next = find.widgetWithText(FilledButton, 'Next question');
      expect(
        tester.widget<FilledButton>(next).onPressed,
        isNull,
        reason: 'Next is disabled until the question is answered',
      );

      await tapOption(tester, correct);

      expect(find.textContaining('Correct! +10 points'), findsOneWidget);
      expect(find.text('Score: 10'), findsOneWidget);
      expect(find.text('Streak: 1 (best 1)'), findsOneWidget);
      expect(find.text('Attempts left: 2'), findsOneWidget);
      expect(tester.widget<FilledButton>(next).onPressed, isNotNull);
    });

    testWidgets('one wrong tap then correct scores 8', (
      WidgetTester tester,
    ) async {
      final List<String> pool = buildTestPool()
          .map((c) => c.name)
          .toList();
      await pumpApp(tester);
      final String correct = correctCountryName(tester);
      final String wrong = wrongOptionNames(tester, pool).first;

      await tapOption(tester, wrong);
      expect(find.textContaining('Wrong. 2 attempts left.'), findsOneWidget);
      expect(find.text('Score: 0'), findsOneWidget);

      await tapOption(tester, correct);
      expect(find.textContaining('Correct! +8 points'), findsOneWidget);
      expect(find.text('Score: 8'), findsOneWidget);
    });

    testWidgets('two wrong taps then correct scores 5', (
      WidgetTester tester,
    ) async {
      final List<String> pool = buildTestPool()
          .map((c) => c.name)
          .toList();
      await pumpApp(tester);
      final String correct = correctCountryName(tester);
      final List<String> wrong = wrongOptionNames(tester, pool);

      await tapOption(tester, wrong[0]);
      await tapOption(tester, wrong[1]);
      expect(find.textContaining('Wrong. 1 attempt left.'), findsOneWidget);

      await tapOption(tester, correct);
      expect(find.textContaining('Correct! +5 points'), findsOneWidget);
      expect(find.text('Score: 5'), findsOneWidget);
    });

    testWidgets('three wrong taps reveal the answer and score nothing', (
      WidgetTester tester,
    ) async {
      final List<String> pool = buildTestPool()
          .map((c) => c.name)
          .toList();
      await pumpApp(tester);
      final String correct = correctCountryName(tester);
      final List<String> wrong = wrongOptionNames(tester, pool);

      await tapOption(tester, wrong[0]);
      await tapOption(tester, wrong[1]);
      await tapOption(tester, wrong[2]);

      expect(
        find.textContaining('No attempts left. The answer was $correct. +0 points.'),
        findsOneWidget,
      );
      expect(find.text('Attempts left: 0'), findsOneWidget);
      expect(find.text('Score: 0'), findsOneWidget);

      await tapOption(tester, correct);
      expect(find.text('Score: 0'), findsOneWidget);
    });

    testWidgets('Next advances to the next question and clears attempts', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester);
      final String correct = correctCountryName(tester);

      await tapOption(tester, correct);
      await tester.tap(find.widgetWithText(FilledButton, 'Next question'));
      await tester.pump();

      expect(find.text('Question 2 of ${QuizConfig.questionCount}'), findsOneWidget);
      expect(find.text('Attempts left: 3'), findsOneWidget);
      expect(find.text('Score: 10'), findsOneWidget);
      expect(find.text('Streak: 1 (best 1)'), findsOneWidget);
    });

    testWidgets('a full run ends on the summary with a Play again button', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester);

      for (int i = 0; i < QuizConfig.questionCount; i++) {
        await tapOption(tester, correctCountryName(tester));
        if (i == QuizConfig.questionCount - 1) {
          await tester.tap(find.widgetWithText(FilledButton, 'Finish run'));
        } else {
          await tester.tap(find.widgetWithText(FilledButton, 'Next question'));
        }
        await tester.pump();
      }

      expect(find.text('Run complete'), findsOneWidget);
      expect(
        find.text('Final score ${QuizConfig.maxScore} / ${QuizConfig.maxScore}'),
        findsOneWidget,
      );
      expect(find.widgetWithText(FilledButton, 'Play again'), findsOneWidget);
    });

    testWidgets('New game resets the score', (WidgetTester tester) async {
      await pumpApp(tester);
      await tapOption(tester, correctCountryName(tester));
      expect(find.text('Score: 10'), findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, 'New game'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Score: 0'), findsOneWidget);
      expect(find.text('Question 1 of ${QuizConfig.questionCount}'), findsOneWidget);
    });

    testWidgets('shows a retryable error when loading fails', (
      WidgetTester tester,
    ) async {
      await pumpApp(
        tester,
        repository: FakeCountryRepository(failure: const Failure.network()),
      );

      expect(find.text('Could not load countries'), findsOneWidget);
      expect(find.textContaining('network'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Retry'), findsOneWidget);
    });

    testWidgets('the retry button asks the repository again', (
      WidgetTester tester,
    ) async {
      final FakeCountryRepository repository = FakeCountryRepository(
        failure: const Failure.network(),
      );
      await pumpApp(tester, repository: repository);
      expect(repository.calls, 1);

      repository.failure = null;
      await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(repository.calls, 2);
      expect(find.text('Question 1 of ${QuizConfig.questionCount}'), findsOneWidget);
    });
  });

  group('app shell', () {
    testWidgets('renders the quiz screen as the initial route', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester);
      expect(find.byType(QuizScreen), findsOneWidget);
      expect(find.text('Country Trivia'), findsOneWidget);
    });

    testWidgets('the light theme is Material 3 light', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light, home: const SizedBox()),
      );

      final ThemeData theme = Theme.of(tester.element(find.byType(SizedBox)));
      expect(theme.useMaterial3, isTrue);
      expect(theme.colorScheme.brightness, Brightness.light);
      expect(theme.extension<QuizColors>(), QuizColors.light);
    });

    testWidgets('the dark theme is Material 3 dark', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.dark, home: const SizedBox()),
      );

      final ThemeData theme = Theme.of(tester.element(find.byType(SizedBox)));
      expect(theme.useMaterial3, isTrue);
      expect(theme.colorScheme.brightness, Brightness.dark);
      expect(theme.extension<QuizColors>(), QuizColors.dark);
    });
  });
}
