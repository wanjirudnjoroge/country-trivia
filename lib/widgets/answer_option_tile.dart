import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/question.dart';

/// Visual state of one answer option.
enum OptionState {
  /// Untouched and tappable.
  idle,

  /// The correct answer, either tapped or revealed after the last attempt.
  correct,

  /// The option the player tapped and got wrong.
  wrong,

  /// Not chosen, on a question that is already resolved.
  dimmed,
}

/// Derives an option's appearance from the ViewModel's answers.
///
/// The rule is deliberately total: once a question is resolved, the correct
/// option is green, the tapped wrong option is red, and everything else dims.
@visibleForTesting
OptionState resolveOptionState({
  required Question question,
  required int index,
  required int? selectedIndex,
  required bool isResolved,
}) {
  if (!isResolved) return OptionState.idle;
  if (question.isCorrect(index)) return OptionState.correct;
  if (index == selectedIndex) return OptionState.wrong;
  return OptionState.dimmed;
}

/// One tappable country option.
///
/// State is carried by an icon and a border as well as by hue, so the answer is
/// still readable without colour vision.
class AnswerOptionTile extends StatelessWidget {
  const AnswerOptionTile({
    super.key,
    required this.index,
    required this.question,
    required this.state,
    required this.onTap,
  });

  final int index;
  final Question question;
  final OptionState state;
  final VoidCallback? onTap;

  bool get _isLocked => state != OptionState.idle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final QuizColors colors = QuizColors.of(context);
    final String name = question.optionAt(index).name;

    final (Color background, Color border, Color foreground, IconData? icon) =
        switch (state) {
          OptionState.idle => (
            theme.colorScheme.surface,
            theme.colorScheme.outline,
            theme.colorScheme.onSurface,
            null,
          ),
          OptionState.correct => (
            colors.correct,
            colors.correct,
            colors.onCorrect,
            Icons.check_circle,
          ),
          OptionState.wrong => (
            colors.wrong,
            colors.wrong,
            colors.onWrong,
            Icons.cancel,
          ),
          OptionState.dimmed => (
            theme.colorScheme.surface,
            theme.colorScheme.outlineVariant,
            theme.colorScheme.onSurfaceVariant,
            null,
          ),
        };

    return Semantics(
      button: true,
      enabled: !_isLocked,
      excludeSemantics: true,
      label: _semanticsLabel(),
      child: Material(
        color: background,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: border, width: _isLocked ? 2 : 1),
        ),
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: <Widget>[
                  _LetterBadge(letter: question.letterFor(index), foreground: foreground),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (icon != null) ...<Widget>[
                    const SizedBox(width: 8),
                    Icon(icon, color: foreground, size: 22),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _semanticsLabel() {
    final String letter = question.letterFor(index);
    final String name = question.optionAt(index).name;
    return switch (state) {
      OptionState.idle => 'Option $letter, $name',
      OptionState.correct => 'Option $letter, $name, correct answer',
      OptionState.wrong => 'Option $letter, $name, incorrect',
      OptionState.dimmed => 'Option $letter, $name',
    };
  }
}

class _LetterBadge extends StatelessWidget {
  const _LetterBadge({required this.letter, required this.foreground});

  final String letter;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: foreground.withValues(alpha: 0.12),
      ),
      child: Text(
        letter,
        style: theme.textTheme.labelLarge?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
