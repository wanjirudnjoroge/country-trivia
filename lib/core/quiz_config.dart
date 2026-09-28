/// Rules of the game, kept as data so they can be tuned without touching logic.
class QuizConfig {
  const QuizConfig._();

  /// Questions per run.
  static const int questionCount = 10;

  /// Country names offered per question, including the correct one.
  static const int optionCount = 4;

  /// Scoring attempts available per question. A fourth tap reveals the answer.
  static const int attemptsPerQuestion = 3;

  /// Points for answering correctly on the 1st, 2nd and 3rd attempt.
  /// A question revealed after [attemptsPerQuestion] wrong taps awards nothing.
  static const List<int> pointsLadder = <int>[10, 8, 5];

  /// Points for a correct answer given [attemptsUsed] wrong taps before it.
  static int pointsForAttempt(int attemptsUsed) =>
      attemptsUsed < pointsLadder.length ? pointsLadder[attemptsUsed] : 0;

  /// Highest score achievable in a full run.
  static int get maxScore => questionCount * pointsLadder.first;
}
