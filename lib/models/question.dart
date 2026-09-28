import 'country.dart';

/// One quiz question: the country to identify plus the four names offered.
///
/// Immutable. [QuestionGenerator] guarantees the invariants asserted by
/// [isValid]: four options, no duplicates, and the correct country at
/// [correctIndex].
class Question {
  Question({
    required this.country,
    required List<Country> options,
    required this.correctIndex,
  }) : options = List<Country>.unmodifiable(options);

  /// The country whose flag the player is shown.
  final Country country;

  /// The four candidate names, in display order.
  final List<Country> options;

  /// Index into [options] holding [country].
  final int correctIndex;

  /// Number of options, i.e. [QuizConfig.optionCount].
  int get optionCount => options.length;

  /// Whether tapping option [index] identifies the country correctly.
  bool isCorrect(int index) => index == correctIndex;

  /// The country shown at [index].
  Country optionAt(int index) => options[index];

  /// Display letter for [index]: A, B, C, D.
  String letterFor(int index) => String.fromCharCode(65 + index);

  /// Checks the invariants documented on the class.
  bool get isValid {
    if (options.length != 4) return false;
    if (correctIndex < 0 || correctIndex >= options.length) return false;
    if (options[correctIndex] != country) return false;
    final codes = options.map((Country c) => c.iso2).toSet();
    return codes.length == options.length;
  }

  @override
  String toString() => 'Question(${country.name}, correct: $correctIndex)';
}
