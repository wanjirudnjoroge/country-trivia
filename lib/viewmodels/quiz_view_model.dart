import 'dart:math';

import 'package:flutter/foundation.dart';

import '../core/quiz_config.dart';
import '../core/result.dart';
import '../data/country_repository.dart';
import '../data/question_generator.dart';
import '../data/fallback_country_repository.dart';
import '../models/answer_outcome.dart';
import '../models/country.dart';
import '../models/game_result.dart';
import '../models/question.dart';
import 'load_state.dart';

/// Owns all game state and the per-question state machine.
///
/// The only three intents a view may send are [startNewGame], [selectOption] and
/// [next]. Everything else is a read-only getter, so the view cannot corrupt the
/// game by touching state directly.
///
/// Scoring rule: points are never computed here. The single scoring path is
/// [AnswerOutcome.fromTap], which reads the ladder from [QuizConfig.pointsForAttempt].
class QuizViewModel extends ChangeNotifier {
  QuizViewModel(
    this._repository, {
    QuestionGenerator? generator,
  }) : _generator = generator ?? QuestionGenerator();
  final CountryRepository _repository;
  final QuestionGenerator _generator;

  LoadState _loadState = LoadState.idle;
  List<Question> _questions = const <Question>[];
  List<AnswerOutcome> _outcomes = <AnswerOutcome>[];
  AnswerOutcome? _currentOutcome;
  GameResult? _result;
  int _currentIndex = 0;
  int _score = 0;
  int _currentStreak = 0;
  int _bestStreak = 0;
  int _attemptsUsed = 0;
  int? _selectedIndex;
  int _poolSize = 0;
  bool _isUsingOfflineData = false;
  Failure? _failure;

  // ---------------------------------------------------------------- state

  LoadState get loadState => _loadState;
  int get score => _score;
  int get currentStreak => _currentStreak;
  int get bestStreak => _bestStreak;
  int get questionNumber => _questions.isEmpty ? 0 : _currentIndex + 1;
  int get totalQuestions => _questions.length;
  int get attemptsUsed => _attemptsUsed;
  int get poolSize => _poolSize;
  bool get isUsingOfflineData => _isUsingOfflineData;
  Failure? get failure => _failure;

  /// The question on screen, or `null` before the first load.
  Question? get currentQuestion =>
      _questions.isEmpty ? null : _questions[_currentIndex];

  /// The country whose flag is on screen.
  Country? get currentCountry => currentQuestion?.country;

  /// Index of the option the player tapped on this question.
  int? get selectedIndex => _selectedIndex;

  /// Attempts still available on this question.
  int get attemptsRemaining =>
      max(0, QuizConfig.attemptsPerQuestion - _attemptsUsed);

  /// The outcome of the current question, or `null` while it is still open.
  AnswerOutcome? get currentOutcome => _currentOutcome;

  /// True once the question is over: the correct answer was found, or the third
  /// wrong attempt revealed it.
  ///
  /// A wrong tap that still leaves attempts available is not resolved, because
  /// the player is expected to try again for 8 or 5 points.
  bool get isQuestionResolved {
    final AnswerStatus? status = _currentOutcome?.status;
    return status == AnswerStatus.correct || status == AnswerStatus.revealed;
  }

  /// True when the correct answer has been found, or attempts are gone.
  bool get isQuestionLocked =>
      isQuestionResolved || _attemptsUsed >= QuizConfig.attemptsPerQuestion;

  /// True while the options still respond to taps.
  bool get canSelectOption =>
      _loadState == LoadState.ready &&
      currentQuestion != null &&
      !isQuestionLocked;

  /// True when the answer was solved, at any attempt.
  bool get isSolved => _currentOutcome?.status == AnswerStatus.correct;

  /// True when the current question was solved on the first attempt.
  bool get isFirstTryAnswer => _currentOutcome?.isFirstTry ?? false;

  /// The whole run's questions.
  List<Question> get questions => List<Question>.unmodifiable(_questions);

  /// True when the third wrong attempt revealed the answer.
  bool get isRevealed => _currentOutcome?.status == AnswerStatus.revealed;

  bool get isLastQuestion =>
      _questions.isNotEmpty && _currentIndex == _questions.length - 1;

  /// True once the player has answered the final question and pressed Next.
  bool get isFinished => _result != null;

  /// The finished run, available only when [isFinished].
  GameResult? get result => _result;

  /// Outcomes committed so far, one per answered question.
  List<AnswerOutcome> get outcomes => List<AnswerOutcome>.unmodifiable(_outcomes);

  // -------------------------------------------------------------- intents

  /// Loads countries and starts a fresh run. Safe to call again to restart.
  Future<void> startNewGame() async {
    if (_loadState == LoadState.loading) return;

    _loadState = LoadState.loading;
    _failure = null;
    notifyListeners();

    final Result<List<Country>> countries = await _repository.getCountries(
      forceRefresh: true,
    );

    switch (countries) {
      case Err<List<Country>>(:final Failure failure):
        _loadState = LoadState.error;
        _failure = failure;
        _questions = const <Question>[];
        notifyListeners();
      case Ok<List<Country>>(:final List<Country> value):
        _applyCountries(value);
    }
  }

  /// Alias for [startNewGame], bound to the Play again control.
  Future<void> restart() => startNewGame();

  /// Handles a tap on option [index]. Ignored when the question is locked or the
  /// index is out of range.
  void selectOption(int index) {
    final Question? question = currentQuestion;
    if (!canSelectOption || question == null) return;
    if (index < 0 || index >= question.optionCount) return;

    final AnswerOutcome outcome = AnswerOutcome.fromTap(
      questionIndex: _currentIndex,
      selectedIndex: index,
      correctIndex: question.correctIndex,
      attemptsUsedBefore: _attemptsUsed,
    );

    _currentOutcome = outcome;
    _selectedIndex = index;
    _attemptsUsed = outcome.attemptsUsed;

    if (outcome.status == AnswerStatus.correct) {
      _score += outcome.pointsAwarded;
      _currentStreak++;
      _bestStreak = max(_bestStreak, _currentStreak);
    } else {
      _currentStreak = 0;
    }

    notifyListeners();
  }

  /// Commits the current question and advances. On the last question this
  /// finishes the run and exposes [result].
  ///
  /// Only resolved questions are committed, so a run records either a solve or
  /// a reveal per question, never a bare wrong attempt.
  void next() {
    if (!isQuestionResolved) return;
    final AnswerOutcome outcome = _currentOutcome!;

    _outcomes = <AnswerOutcome>[..._outcomes, outcome];

    if (isLastQuestion) {
      _result = GameResult(
        score: _score,
        questionCount: _outcomes.length,
        bestStreak: _bestStreak,
        outcomes: _outcomes,
      );
      _loadState = LoadState.ready;
    } else {
      _currentIndex++;
      _resetQuestionState();
    }

    notifyListeners();
  }

  // ---------------------------------------------------------------- private

  void _applyCountries(List<Country> value) {
    _poolSize = value.length;
    if (_repository case final FallbackCountryRepository fallback) {
      _isUsingOfflineData = fallback.isUsingOfflineData;
    }

    try {
      _questions = _generator.generate(value);
    } on ArgumentError {
      _loadState = LoadState.error;
      _failure = const Failure(
        FailureKind.parsing,
        'Not enough countries to build a question.',
      );
      _questions = const <Question>[];
      notifyListeners();
      return;
    }

    _outcomes = <AnswerOutcome>[];
    _currentIndex = 0;
    _score = 0;
    _currentStreak = 0;
    _bestStreak = 0;
    _failure = null;
    _resetQuestionState();
    _loadState = LoadState.ready;
    notifyListeners();
  }

  void _resetQuestionState() {
    _currentOutcome = null;
    _selectedIndex = null;
    _attemptsUsed = 0;
  }
}
