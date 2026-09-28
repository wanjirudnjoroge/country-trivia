import 'package:flutter/material.dart';

import '../core/app_theme.dart';

/// The tone of the message shown after a tap.
enum FeedbackKind {
  /// The correct option was tapped.
  correct,

  /// A wrong option was tapped and attempts remain.
  wrong,

  /// The attempts ran out, so the answer was revealed for no points.
  revealed,
}

/// Instant feedback under the flag: what happened, and what it earned.
class FeedbackBanner extends StatelessWidget {
  const FeedbackBanner({
    super.key,
    required this.kind,
    required this.message,
  });

  final FeedbackKind kind;
  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final QuizColors colors = QuizColors.of(context);

    final (Color background, Color foreground, IconData icon) = switch (kind) {
      FeedbackKind.correct => (
        colors.correctContainer,
        colors.onCorrectContainer,
        Icons.check_circle,
      ),
      FeedbackKind.wrong => (
        colors.wrongContainer,
        colors.onWrongContainer,
        Icons.cancel,
      ),
      FeedbackKind.revealed => (
        theme.colorScheme.surfaceContainerHighest,
        theme.colorScheme.onSurface,
        Icons.lightbulb_outline,
      ),
    };

    return Semantics(
      liveRegion: true,
      label: message,
      excludeSemantics: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, color: foreground, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
