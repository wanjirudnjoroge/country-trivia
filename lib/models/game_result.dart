import 'answer_outcome.dart';

/// The immutable summary of a finished run, handed to the results screen.
///
/// The results screen is a pure function of this object, so it cannot mutate
/// live game state.
class GameResult {
  GameResult({
    required this.score,
    required this.questionCount,
    required this.bestStreak,
    required List<AnswerOutcome> outcomes,
  }) : outcomes = List<AnswerOutcome>.unmodifiable(outcomes);

  /// Total points earned.
  final int score;

  /// Questions in the run.
  final int questionCount;

  /// Longest run of consecutive correct answers.
  final int bestStreak;

  /// One entry per question, in order.
  final List<AnswerOutcome> outcomes;

  /// Questions answered correctly on the first attempt.
  int get firstTryCount => outcomes.where((AnswerOutcome o) => o.isFirstTry).length;

  /// Questions answered correctly only after a wrong guess.
  int get lateSolveCount => outcomes.where((AnswerOutcome o) => o.isLateSolve).length;

  /// Questions never solved; the answer was revealed.
  int get revealedCount => outcomes.where((AnswerOutcome o) => o.isRevealed).length;

  /// Questions solved at all.
  int get solvedCount => firstTryCount + lateSolveCount;

  /// Score as a 0..1 fraction.
  double get accuracy => questionCount == 0 ? 0 : score / (questionCount * 10);

  /// A one-line grade for the results screen.
  String get grade {
    if (firstTryCount == questionCount && questionCount > 0) return 'Flawless';
    if (score >= questionCount * 8) return 'Excellent';
    if (score >= questionCount * 6) return 'Good';
    return 'Keep practising';
  }

  @override
  String toString() =>
      'GameResult(score: $score/$questionCount, best streak: $bestStreak)';
}
