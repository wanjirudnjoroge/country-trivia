import 'package:flutter/material.dart';

import '../core/app_theme.dart';

/// One pip per allowed attempt, filled as attempts are spent.
///
/// The final remaining pip turns amber, and the label spells the count out so
/// the state never depends on counting circles.
class AttemptsIndicator extends StatelessWidget {
  const AttemptsIndicator({
    super.key,
    required this.attemptsUsed,
    required this.attemptsPerQuestion,
  });

  final int attemptsUsed;
  final int attemptsPerQuestion;

  static const Color _amber = Color(0xFFB26A00);
  static const Color _amberDark = Color(0xFFFFB733);

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int remaining = (attemptsPerQuestion - attemptsUsed).clamp(
      0,
      attemptsPerQuestion,
    );
    final bool isLastChance = remaining == 1;
    final Color accent = isLastChance
        ? (theme.brightness == Brightness.dark ? _amberDark : _amber)
        : theme.colorScheme.primary;

    final String label = switch (remaining) {
      0 => 'No attempts left — the answer is revealed',
      1 => 'Last attempt — 1 of $attemptsPerQuestion left',
      _ => '$remaining of $attemptsPerQuestion attempts left',
    };

    return Semantics(
      label: 'Attempts: $attemptsUsed of $attemptsPerQuestion used. $label',
      excludeSemantics: true,
      child: Row(
        children: <Widget>[
          for (int i = 0; i < attemptsPerQuestion; i++)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < attemptsUsed ? accent : Colors.transparent,
                  border: Border.all(
                    color: i < attemptsUsed
                        ? accent
                        : theme.colorScheme.outlineVariant,
                    width: 2,
                  ),
                ),
              ),
            ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isLastChance || remaining == 0
                    ? accent
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
