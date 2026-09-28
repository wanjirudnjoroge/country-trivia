import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_routes.dart';
import '../core/quiz_config.dart';
import '../models/answer_outcome.dart';
import '../models/country.dart';
import '../models/question.dart';
import '../viewmodels/load_state.dart';
import '../viewmodels/quiz_view_model.dart';
import '../widgets/answer_option_tile.dart';
import '../widgets/attempts_indicator.dart';
import '../widgets/feedback_banner.dart';
import '../widgets/flag_image.dart';
import '../widgets/score_header.dart';

/// Width at or above which the options sit in a 2x2 grid.
const double _kWideBreakpoint = 1000;

/// Content never grows past this, however wide the window gets.
const double _kMaxContentWidth = 880;

/// Flag card is capped so it does not dominate a desktop window.
const double _kMaxFlagWidth = 420;

/// The game.
///
/// Holds no state of its own: everything rendered comes from the app-scoped
/// [QuizViewModel], and the only intents it sends are `selectOption`, `next` and
/// `startNewGame`.
class QuizScreen extends StatelessWidget {
  const QuizScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final QuizViewModel vm = context.watch<QuizViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('Country Trivia')),
      body: SafeArea(child: _QuizBody(vm: vm)),
    );
  }
}

class _QuizBody extends StatelessWidget {
  const _QuizBody({required this.vm});

  final QuizViewModel vm;

  @override
  Widget build(BuildContext context) {
    return switch (vm.loadState) {
      LoadState.idle || LoadState.loading => const _LoadingView(),
      LoadState.error => _ErrorView(vm: vm),
      LoadState.ready => vm.isFinished ? _FinishedView(vm: vm) : _PlayView(vm: vm),
    };
  }
}

class _PlayView extends StatelessWidget {
  const _PlayView({required this.vm});

  final QuizViewModel vm;

  void _advance(BuildContext context) {
    final bool wasLastQuestion = vm.isLastQuestion;
    vm.next();
    if (wasLastQuestion) Navigator.of(context).pushNamed(AppRoutes.results);
  }

  @override
  Widget build(BuildContext context) {
    final Question? question = vm.currentQuestion;
    if (question == null) return const _LoadingView();

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        final bool isPhone = width < 600;
        final bool isWide = width >= _kWideBreakpoint;
        final double contentWidth = isPhone
            ? width
            : (isWide ? _kMaxContentWidth : 600);

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(isPhone ? 16 : 24, 16, isPhone ? 16 : 24, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: contentWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  ScoreHeader(
                    score: vm.score,
                    streak: vm.currentStreak,
                    bestStreak: vm.bestStreak,
                    questionNumber: vm.questionNumber,
                    totalQuestions: vm.totalQuestions,
                  ),
                  if (vm.isUsingOfflineData) ...<Widget>[
                    const SizedBox(height: 12),
                    const _OfflineBanner(),
                  ],
                  const SizedBox(height: 20),
                  Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isWide ? _kMaxFlagWidth : double.infinity,
                      ),
                      child: _FlagCard(country: question.country),
                    ),
                  ),
                  const SizedBox(height: 20),
                  AttemptsIndicator(
                    attemptsUsed: vm.attemptsUsed,
                    attemptsPerQuestion: QuizConfig.attemptsPerQuestion,
                  ),
                  const SizedBox(height: 16),
                  _Feedback(vm: vm),
                  const SizedBox(height: 20),
                  _Options(question: question, vm: vm, isWide: isWide),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: vm.isQuestionResolved ? () => _advance(context) : null,
                    child: Text(
                      vm.isLastQuestion ? 'Finish run' : 'Next question',
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The flag card hosts a keyed [FlagImage] so a new question fades the old
/// image out rather than repainting it in place.
class _FlagCard extends StatelessWidget {
  const _FlagCard({required this.country});

  final Country country;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: FlagImage(
              key: ValueKey<String>(country.iso2),
              country: country,
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows the outcome of the last tap, and reserves its own height so the
/// options do not jump when feedback appears.
class _Feedback extends StatelessWidget {
  const _Feedback({required this.vm});

  final QuizViewModel vm;

  @override
  Widget build(BuildContext context) {
    final AnswerOutcome? outcome = vm.currentOutcome;
    final String? message = _message(outcome);
    if (message == null) return const SizedBox(height: 8);

    final FeedbackKind kind = switch (outcome!.status) {
      AnswerStatus.correct => FeedbackKind.correct,
      AnswerStatus.revealed => FeedbackKind.revealed,
      AnswerStatus.wrong => FeedbackKind.wrong,
    };

    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      alignment: Alignment.topCenter,
      child: FeedbackBanner(key: ValueKey<String>(message), kind: kind, message: message),
    );
  }

  String? _message(AnswerOutcome? outcome) {
    if (outcome == null) return null;
    return switch (outcome.status) {
      AnswerStatus.correct => 'Correct! +${outcome.pointsAwarded} points',
      AnswerStatus.wrong =>
        'Wrong — ${vm.attemptsRemaining} '
            '${vm.attemptsRemaining == 1 ? 'attempt' : 'attempts'} left',
      AnswerStatus.revealed =>
        'No attempts left. The answer was ${vm.currentCountry?.name}.',
    };
  }
}

/// Renders all four options from the same tile, laid out in one or two columns.
class _Options extends StatelessWidget {
  const _Options({required this.question, required this.vm, required this.isWide});

  final Question question;
  final QuizViewModel vm;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final List<Widget> tiles = <Widget>[
      for (int i = 0; i < question.optionCount; i++)
        _OptionTile(index: i, question: question, vm: vm),
    ];

    if (!isWide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (int i = 0; i < tiles.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(height: 10),
            tiles[i],
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (int row = 0; row * 2 < tiles.length; row++) ...<Widget>[
          if (row > 0) const SizedBox(height: 10),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(child: tiles[row * 2]),
                const SizedBox(width: 10),
                Expanded(child: tiles[row * 2 + 1]),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.index,
    required this.question,
    required this.vm,
  });

  final int index;
  final Question question;
  final QuizViewModel vm;

  @override
  Widget build(BuildContext context) {
    final OptionState state = resolveOptionState(
      question: question,
      index: index,
      selectedIndex: vm.selectedIndex,
      isResolved: vm.isQuestionResolved,
    );

    return AnswerOptionTile(
      key: ValueKey<int>(index),
      index: index,
      question: question,
      state: state,
      onTap: vm.canSelectOption ? () => vm.selectOption(index) : null,
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.cloud_off,
            size: 20,
            color: theme.colorScheme.onTertiaryContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "Couldn't reach the country list — playing the built-in one.",
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onTertiaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Loading countries…',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.vm});

  final QuizViewModel vm;

  @override
  Widget build(BuildContext context) {
    final String message = vm.failure?.message ?? 'Something went wrong.';

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.cloud_off,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              "Couldn't load countries",
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: vm.startNewGame,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Reachable if the player returns to the quiz route on a finished run, for
/// example by popping the results screen without playing again.
class _FinishedView extends StatelessWidget {
  const _FinishedView({required this.vm});

  final QuizViewModel vm;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.emoji_events,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Run complete',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text('You scored ${vm.result?.score ?? 0} points.'),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).pushNamed(AppRoutes.results),
              child: const Text('See results'),
            ),
          ],
        ),
      ),
    );
  }
}
