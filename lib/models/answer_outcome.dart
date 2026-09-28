import '../core/quiz_config.dart';

/// How a question ended.
enum AnswerStatus {
  /// The correct option was tapped within the attempt allowance.
  correct,

  /// A wrong option was tapped and attempts remain.
  wrong,

  /// All three attempts were used up, so the correct option was revealed and
  /// no points were awarded.
  revealed,
}

/// The record of one answered question, used for scoring and for the review list
/// on the results screen.
class AnswerOutcome {
  const AnswerOutcome({
    required this.questionIndex,
    required this.status,
    required this.attemptsUsed,
    required this.pointsAwarded,
    this.selectedIndex,
  });

  /// Builds the outcome of tapping [selectedIndex] on a question, given the
  /// correct answer's position.
  factory AnswerOutcome.fromTap({
    required int questionIndex,
    required int selectedIndex,
    required int correctIndex,
    required int attemptsUsedBefore,
  }) {
    if (selectedIndex == correctIndex) {
      final points = QuizConfig.pointsForAttempt(attemptsUsedBefore);
      return AnswerOutcome(
        questionIndex: questionIndex,
        status: AnswerStatus.correct,
        attemptsUsed: attemptsUsedBefore + 1,
        pointsAwarded: points,
        selectedIndex: selectedIndex,
      );
    }

    final attemptsUsed = attemptsUsedBefore + 1;
    return AnswerOutcome(
      questionIndex: questionIndex,
      status: attemptsUsed >= QuizConfig.attemptsPerQuestion
          ? AnswerStatus.revealed
          : AnswerStatus.wrong,
      attemptsUsed: attemptsUsed,
      pointsAwarded: 0,
      selectedIndex: selectedIndex,
    );
  }

  /// Position of this question in the run, from 0.
  final int questionIndex;

  /// Whether the question was solved, solved late, or revealed.
  final AnswerStatus status;

  /// Attempt that ended the question, 1-based. `1` means first try.
  final int attemptsUsed;

  /// 10, 8, 5, or 0.
  final int pointsAwarded;

  /// Option the player tapped, or `null` if the question was never answered.
  final int? selectedIndex;

  /// Solved on the very first attempt.
  bool get isFirstTry => status == AnswerStatus.correct && attemptsUsed == 1;

  /// Solved, but only after a wrong guess.
  bool get isLateSolve => status == AnswerStatus.correct && attemptsUsed > 1;

  /// Never solved; the answer was revealed.
  bool get isRevealed => status == AnswerStatus.revealed;

  @override
  String toString() =>
      'AnswerOutcome(q$questionIndex, ${status.name}, '
      'attempts: $attemptsUsed, points: $pointsAwarded)';
}
