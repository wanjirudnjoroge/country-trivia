import 'package:flutter/material.dart';

/// Semantic colours for answer feedback.
///
/// Kept as a [ThemeExtension] rather than raw `Colors.green`/`Colors.red` so
/// light and dark themes each get a checked, accessible pair, and so the
/// correct/wrong states stay legible alongside Material 3's own palette.
@immutable
class QuizColors extends ThemeExtension<QuizColors> {
  const QuizColors({
    required this.correct,
    required this.onCorrect,
    required this.correctContainer,
    required this.onCorrectContainer,
    required this.wrong,
    required this.onWrong,
    required this.wrongContainer,
    required this.onWrongContainer,
  });

  /// Fill for the correct answer.
  final Color correct;

  /// Content colour that meets contrast on [correct].
  final Color onCorrect;

  /// Tinted fill used for large surfaces such as the feedback banner.
  final Color correctContainer;

  /// Content colour that meets contrast on [correctContainer].
  final Color onCorrectContainer;

  /// Fill for a wrong answer.
  final Color wrong;

  /// Content colour that meets contrast on [wrong].
  final Color onWrong;

  /// Tinted fill used for large surfaces.
  final Color wrongContainer;

  /// Content colour that meets contrast on [wrongContainer].
  final Color onWrongContainer;

  static const QuizColors light = QuizColors(
    correct: Color(0xFF1B5E20),
    onCorrect: Colors.white,
    correctContainer: Color(0xFFC8E6C9),
    onCorrectContainer: Color(0xFF0B3D0F),
    wrong: Color(0xFFB3261E),
    onWrong: Colors.white,
    wrongContainer: Color(0xFFF9DEDC),
    onWrongContainer: Color(0xFF410E0B),
  );

  static const QuizColors dark = QuizColors(
    correct: Color(0xFF7BDD8A),
    onCorrect: Color(0xFF00390D),
    correctContainer: Color(0xFF1B4D24),
    onCorrectContainer: Color(0xFFC8E6C9),
    wrong: Color(0xFFFFB4AB),
    onWrong: Color(0xFF690005),
    wrongContainer: Color(0xFF5C1A16),
    onWrongContainer: Color(0xFFF9DEDC),
  );

  /// The active [QuizColors] for the nearest theme.
  static QuizColors of(BuildContext context) =>
      Theme.of(context).extension<QuizColors>() ?? light;

  @override
  QuizColors copyWith({
    Color? correct,
    Color? onCorrect,
    Color? correctContainer,
    Color? onCorrectContainer,
    Color? wrong,
    Color? onWrong,
    Color? wrongContainer,
    Color? onWrongContainer,
  }) => QuizColors(
    correct: correct ?? this.correct,
    onCorrect: onCorrect ?? this.onCorrect,
    correctContainer: correctContainer ?? this.correctContainer,
    onCorrectContainer: onCorrectContainer ?? this.onCorrectContainer,
    wrong: wrong ?? this.wrong,
    onWrong: onWrong ?? this.onWrong,
    wrongContainer: wrongContainer ?? this.wrongContainer,
    onWrongContainer: onWrongContainer ?? this.onWrongContainer,
  );

  @override
  QuizColors lerp(ThemeExtension<QuizColors>? other, double t) {
    if (other is! QuizColors) return this;
    return QuizColors(
      correct: Color.lerp(correct, other.correct, t)!,
      onCorrect: Color.lerp(onCorrect, other.onCorrect, t)!,
      correctContainer: Color.lerp(correctContainer, other.correctContainer, t)!,
      onCorrectContainer:
          Color.lerp(onCorrectContainer, other.onCorrectContainer, t)!,
      wrong: Color.lerp(wrong, other.wrong, t)!,
      onWrong: Color.lerp(onWrong, other.onWrong, t)!,
      wrongContainer: Color.lerp(wrongContainer, other.wrongContainer, t)!,
      onWrongContainer:
          Color.lerp(onWrongContainer, other.onWrongContainer, t)!,
    );
  }
}

/// Light and dark Material 3 themes for the app.
class AppTheme {
  const AppTheme._();

  /// Seed colour for the generated Material 3 palette.
  static const Color seedColor = Color(0xFF1E88E5);

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      extensions: <ThemeExtension<dynamic>>[
        brightness == Brightness.light ? QuizColors.light : QuizColors.dark,
      ],
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 2,
      ),
      cardTheme: CardThemeData(
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: ChipThemeData(
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        linearTrackColor: scheme.surfaceContainerHighest,
      ),
    );
  }
}
