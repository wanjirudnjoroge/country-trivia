import 'package:country_trivia/app.dart';
import 'package:country_trivia/core/app_theme.dart';
import 'package:country_trivia/data/countries.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('boots into the quiz screen', (WidgetTester tester) async {
    await tester.pumpWidget(const CountryTriviaApp());

    expect(find.text('Country Trivia'), findsOneWidget);
    expect(find.text('Phase 1 foundation'), findsOneWidget);
    expect(find.text('Game rules'), findsOneWidget);
    expect(find.text('Start game'), findsOneWidget);
  });

  testWidgets('shows the rules from QuizConfig', (WidgetTester tester) async {
    await tester.pumpWidget(const CountryTriviaApp());

    expect(find.text('Questions per run'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
    expect(find.text('Options per question'), findsOneWidget);
    expect(find.text('Attempts per question'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('10 / 8 / 5'), findsOneWidget);
    expect(find.text('100'), findsOneWidget);
  });

  testWidgets('lists the offline fallback countries', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const CountryTriviaApp());

    expect(
      find.textContaining('${countries.length} countries'),
      findsOneWidget,
    );
    expect(find.text('Afghanistan (AF)'), findsOneWidget);
  });

  testWidgets('Start game responds when tapped', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const CountryTriviaApp());

    final FilledButton button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Start game'),
    );
    expect(button.onPressed, isNotNull, reason: 'button must be clickable');

    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Start game'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Start game'));
    await tester.pump();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('Phase 1 foundation is working'), findsOneWidget);
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

  testWidgets('light and dark themes differ in generated palette', (
    WidgetTester tester,
  ) async {
    expect(AppTheme.light.colorScheme.primary, isNot(AppTheme.dark.colorScheme.primary));
    expect(AppTheme.light.cardTheme.clipBehavior, Clip.antiAlias);
  });
}
