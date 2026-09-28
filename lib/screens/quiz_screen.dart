import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/quiz_config.dart';
import '../core/result.dart';
import '../models/answer_outcome.dart';
import '../models/country.dart';
import '../models/question.dart';
import '../viewmodels/load_state.dart';
import '../viewmodels/quiz_view_model.dart';

/// Home screen hosting a temporary debug panel for the game logic.
///
/// The real quiz and results screens are built in Phase 4. Until then this panel
/// exposes everything the ViewModel holds so the state machine can be driven by
/// hand: the flag, four options, attempts left, score, and the Next control.
class QuizScreen extends StatelessWidget {
  const QuizScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final QuizViewModel vm = context.watch<QuizViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Country Trivia'),
        bottom: vm.loadState == LoadState.ready && !vm.isFinished
            ? PreferredSize(
                preferredSize: const Size.fromHeight(4),
                child: LinearProgressIndicator(
                  value: vm.totalQuestions == 0
                      ? 0
                      : vm.questionNumber / vm.totalQuestions,
                ),
              )
            : null,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _DebugPanel(vm: vm),
                  const SizedBox(height: 16),
                  _StatusCard(vm: vm),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DebugPanel extends StatelessWidget {
  const _DebugPanel({required this.vm});

  final QuizViewModel vm;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: switch (vm.loadState) {
          LoadState.idle || LoadState.loading => const _LoadingState(),
          LoadState.error => _ErrorState(vm: vm),
          LoadState.ready => vm.isFinished
              ? _FinishedState(vm: vm)
              : _PlayableState(vm: vm, theme: theme),
        },
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: <Widget>[
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading countries...'),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.vm});

  final QuizViewModel vm;

  @override
  Widget build(BuildContext context) {
    final Failure failure = vm.failure ?? const Failure.unknown();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: <Widget>[
          Icon(Icons.cloud_off, size: 40, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 12),
          Text(
            'Could not load countries',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(failure.toString(), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: vm.startNewGame,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _PlayableState extends StatelessWidget {
  const _PlayableState({required this.vm, required this.theme});

  final QuizViewModel vm;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final Question? question = vm.currentQuestion;
    if (question == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'Question ${vm.questionNumber} of ${vm.totalQuestions}',
                style: theme.textTheme.titleMedium,
              ),
            ),
            _StatChip(label: 'Score', value: '${vm.score}'),
            const SizedBox(width: 8),
            _StatChip(
              label: 'Streak',
              value: '${vm.currentStreak} (best ${vm.bestStreak})',
            ),
          ],
        ),
        const SizedBox(height: 12),
        _AttemptsRow(vm: vm),
        const SizedBox(height: 12),
        _FlagImage(key: ValueKey<String>(vm.currentCountry!.iso2), country: vm.currentCountry!),
        const SizedBox(height: 12),
        for (int i = 0; i < question.optionCount; i++) ...<Widget>[
          _OptionButton(
            question: question,
            index: i,
            enabled: vm.canSelectOption,
            selectedIndex: vm.selectedIndex,
            resolved: vm.isQuestionResolved,
            onTap: () => vm.selectOption(i),
          ),
          if (i != question.optionCount - 1) const SizedBox(height: 8),
        ],
        const SizedBox(height: 12),
        _FeedbackText(vm: vm),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: vm.isQuestionResolved ? vm.next : null,
          icon: const Icon(Icons.arrow_forward),
          label: Text(vm.isLastQuestion ? 'Finish run' : 'Next question'),
        ),
      ],
    );
  }
}

class _FinishedState extends StatelessWidget {
  const _FinishedState({required this.vm});

  final QuizViewModel vm;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int score = vm.result?.score ?? vm.score;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Icon(Icons.emoji_events, size: 48, color: theme.colorScheme.primary),
        const SizedBox(height: 8),
        Text('Run complete', style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          'Final score $score / ${QuizConfig.maxScore}',
          style: theme.textTheme.headlineSmall,
        ),
        Text(
          'Best streak ${vm.bestStreak} '
          '(first try ${vm.result?.firstTryCount ?? 0}, '
          'late ${vm.result?.lateSolveCount ?? 0}, '
          'revealed ${vm.result?.revealedCount ?? 0})',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: vm.restart,
          icon: const Icon(Icons.replay),
          label: const Text('Play again'),
        ),
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.vm});

  final QuizViewModel vm;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String source = vm.isUsingOfflineData
        ? 'offline fallback list (API failed)'
        : 'countriesnow.space API';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Debug status', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Text('Source: $source', style: theme.textTheme.bodySmall),
            Text(
              'Sovereign pool: ${vm.poolSize} countries',
              style: theme.textTheme.bodySmall,
            ),
            Text(
              'Rules: ${QuizConfig.questionCount} questions, '
              '${QuizConfig.optionCount} options, '
              '${QuizConfig.attemptsPerQuestion} attempts, '
              'points ${QuizConfig.pointsLadder.join('/')}, '
              'then reveal for 0',
              style: theme.textTheme.bodySmall,
            ),
            if (vm.isUsingOfflineData && vm.failure != null)
              Text(
                'Last API failure: ${vm.failure}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: vm.restart,
              icon: const Icon(Icons.restart_alt),
              label: const Text('New game'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label: $value',
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}

class _AttemptsRow extends StatelessWidget {
  const _AttemptsRow({required this.vm});

  final QuizViewModel vm;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int remaining = vm.attemptsRemaining;
    final bool lastOne = remaining == 1 && vm.attemptsUsed > 0;

    return Row(
      children: <Widget>[
        Text('Attempts left: $remaining', style: theme.textTheme.bodyMedium),
        const SizedBox(width: 12),
        for (int i = 0; i < QuizConfig.attemptsPerQuestion; i++)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Icon(
              Icons.circle,
              size: 14,
              color: i < remaining
                  ? (lastOne ? theme.colorScheme.error : theme.colorScheme.primary)
                  : theme.colorScheme.outlineVariant,
            ),
          ),
      ],
    );
  }
}

class _FeedbackText extends StatelessWidget {
  const _FeedbackText({required this.vm});

  final QuizViewModel vm;

  @override
  Widget build(BuildContext context) {
    final AnswerOutcome? outcome = vm.currentOutcome;
    if (outcome == null) return const SizedBox.shrink();

    final ThemeData theme = Theme.of(context);
    final QuizColors colors = QuizColors.of(context);
    final Question question = vm.currentQuestion!;

    final (String message, Color background, Color foreground) =
        switch (outcome.status) {
          AnswerStatus.correct => (
            'Correct! +${outcome.pointsAwarded} points',
            colors.correctContainer,
            colors.onCorrectContainer,
          ),
          AnswerStatus.wrong => (
            'Wrong. ${vm.attemptsRemaining} attempt'
            '${vm.attemptsRemaining == 1 ? '' : 's'} left.',
            colors.wrongContainer,
            colors.onWrongContainer,
          ),
          AnswerStatus.revealed => (
            'No attempts left. The answer was '
            '${question.options[question.correctIndex].name}. +0 points.',
            colors.wrongContainer,
            colors.onWrongContainer,
          ),
        };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        message,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _OptionButton extends StatelessWidget {
  const _OptionButton({
    required this.question,
    required this.index,
    required this.enabled,
    required this.selectedIndex,
    required this.resolved,
    required this.onTap,
  });

  final Question question;
  final int index;
  final bool enabled;
  final int? selectedIndex;
  final bool resolved;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final QuizColors colors = QuizColors.of(context);
    final bool isCorrect = index == question.correctIndex;
    final bool isSelected = selectedIndex == index;

    final Color background;
    final Color foreground;
    final Color border;
    final IconData? trailing;

    if (resolved && isCorrect) {
      background = colors.correctContainer;
      foreground = colors.onCorrectContainer;
      border = colors.correct;
      trailing = Icons.check_circle;
    } else if (isSelected) {
      background = colors.wrongContainer;
      foreground = colors.onWrongContainer;
      border = colors.wrong;
      trailing = Icons.cancel;
    } else if (resolved) {
      background = theme.colorScheme.surfaceContainerHighest;
      foreground = theme.colorScheme.onSurfaceVariant;
      border = theme.colorScheme.outlineVariant;
      trailing = null;
    } else {
      background = theme.colorScheme.surface;
      foreground = theme.colorScheme.onSurface;
      border = theme.colorScheme.outline;
      trailing = null;
    }

    return OutlinedButton(
      onPressed: enabled ? onTap : null,
      style: OutlinedButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        side: BorderSide(color: border, width: resolved && isCorrect ? 2 : 1),
        minimumSize: const Size.fromHeight(56),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
      child: Row(
        children: <Widget>[
          Text(question.letterFor(index), style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              question.options[index].name,
              textAlign: TextAlign.left,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailing != null) ...<Widget>[
            const SizedBox(width: 8),
            Icon(trailing, size: 20),
          ],
        ],
      ),
    );
  }
}

/// Loads a flag over HTTPS with a loading indicator, an error fallback and a
/// retry. Promoted to `lib/widgets/flag_image.dart` in Phase 4.
class _FlagImage extends StatefulWidget {
  const _FlagImage({super.key, required this.country});

  final Country country;

  @override
  State<_FlagImage> createState() => _FlagImageState();
}

class _FlagImageState extends State<_FlagImage> {
  int _attempt = 0;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String url = widget.country.flagUrl;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AspectRatio(
          aspectRatio: 4 / 3,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                url,
                key: ValueKey<int>(_attempt),
                fit: BoxFit.contain,
                gaplessPlayback: true,
                semanticLabel: 'Flag of ${widget.country.name}',
                errorBuilder:
                    (BuildContext context, Object error, StackTrace? stack) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              Icons.flag_outlined,
                              color: theme.colorScheme.error,
                            ),
                            const SizedBox(height: 8),
                            Text('Flag unavailable', style: theme.textTheme.bodySmall),
                            TextButton(
                              onPressed: () => setState(() => _attempt++),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      );
                    },
                loadingBuilder:
                    (
                      BuildContext context,
                      Widget child,
                      ImageChunkEvent? progress,
                    ) {
                      if (progress == null) return child;
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const CircularProgressIndicator(),
                            const SizedBox(height: 8),
                            Text(
                              'Loading ${widget.country.iso2}...',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      );
                    },
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Correct answer: ${widget.country.name} (${widget.country.iso2})',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
