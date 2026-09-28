import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/quiz_config.dart';
import '../models/answer_outcome.dart';
import '../models/game_result.dart';
import '../models/question.dart';
import '../viewmodels/quiz_view_model.dart';

/// Final score for a finished run.
///
/// A pure function of the [GameResult] the ViewModel exposes: the screen reads
/// the app-scoped ViewModel but mutates nothing, and *Play again* hands control
/// back to the ViewModel.
class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key});

  void _playAgain(BuildContext context) {
    Navigator.of(context).pop();
    context.read<QuizViewModel>().restart();
  }

  @override
  Widget build(BuildContext context) {
    final QuizViewModel vm = context.watch<QuizViewModel>();
    final GameResult? result = vm.result;

    return Scaffold(
      appBar: AppBar(title: const Text('Results')),
      body: result == null
          ? const Center(child: Text('No finished run to show.'))
          : SafeArea(
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final bool isWide = constraints.maxWidth >= 600;
                  return SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      isWide ? 24 : 16,
                      24,
                      isWide ? 24 : 16,
                      32,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 640),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            _ScoreHeadline(result: result),
                            const SizedBox(height: 20),
                            _StatRow(result: result),
                            const SizedBox(height: 24),
                            const _ReviewHeading(),
                            const SizedBox(height: 8),
                            _ReviewList(result: result, questions: vm.questions),
                            const SizedBox(height: 28),
                            FilledButton(
                              onPressed: () => _playAgain(context),
                              child: const Text('Play again'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class _ScoreHeadline extends StatelessWidget {
  const _ScoreHeadline({required this.result});

  final GameResult result;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int maxScore = result.questionCount * QuizConfig.pointsLadder.first;

    return Column(
      children: <Widget>[
        Text(
          'Your score',
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Semantics(
          liveRegion: true,
          label: 'You scored ${result.score} out of $maxScore. ${result.grade}.',
          excludeSemantics: true,
          child: Text(
            '${result.score} / $maxScore',
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            result.grade,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.result});

  final GameResult result;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 10,
      children: <Widget>[
        _Stat(label: 'First try', value: '${result.firstTryCount}'),
        _Stat(label: 'After a miss', value: '${result.lateSolveCount}'),
        _Stat(label: 'Revealed', value: '${result.revealedCount}'),
        _Stat(label: 'Best streak', value: '${result.bestStreak}'),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewHeading extends StatelessWidget {
  const _ReviewHeading();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Question by question',
      style: Theme.of(context).textTheme.titleMedium,
    );
  }
}

/// One row per question: the country that was asked, and what it earned.
class _ReviewList extends StatelessWidget {
  const _ReviewList({required this.result, required this.questions});

  final GameResult result;
  final List<Question> questions;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final QuizColors colors = QuizColors.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: <Widget>[
            for (final AnswerOutcome outcome in result.outcomes)
              Builder(
                builder: (BuildContext context) {
                  final String name = outcome.questionIndex < questions.length
                      ? questions[outcome.questionIndex].country.name
                      : 'Question ${outcome.questionIndex + 1}';
                  final (IconData icon, Color tint, String status) =
                      switch (outcome.status) {
                        AnswerStatus.correct => (
                          Icons.check_circle,
                          colors.correct,
                          'Correct',
                        ),
                        AnswerStatus.revealed => (
                          Icons.visibility,
                          colors.wrong,
                          'Revealed',
                        ),
                        AnswerStatus.wrong => (
                          Icons.cancel,
                          colors.wrong,
                          'Wrong',
                        ),
                      };

                  return ListTile(
                    dense: true,
                    leading: SizedBox(
                      width: 28,
                      child: Text(
                        '${outcome.questionIndex + 1}',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    title: Text(name, style: theme.textTheme.bodyLarge),
                    subtitle: Text(
                      '$status on attempt ${outcome.attemptsUsed}',
                      style: theme.textTheme.bodySmall?.copyWith(color: tint),
                    ),
                    trailing: Text(
                      '+${outcome.pointsAwarded}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: outcome.pointsAwarded > 0
                            ? tint
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
