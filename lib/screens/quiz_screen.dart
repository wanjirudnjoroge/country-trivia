import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/quiz_config.dart';
import '../data/countries.dart';
import '../models/country.dart';

/// The game screen.
///
/// Phase 1 placeholder: it renders the foundation (Material 3 theme, the rules
/// from [QuizConfig], the offline country list, and one live HTTPS flag) so the
/// wiring can be verified in a browser. The playable question flow arrives in
/// Phases 2-4.
class QuizScreen extends StatelessWidget {
  const QuizScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Country Trivia')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 880),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _FoundationCard(theme: theme),
                  const SizedBox(height: 16),
                  _RulesCard(theme: theme),
                  const SizedBox(height: 16),
                  _CountryDataCard(theme: theme),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => _explainStagedBuild(context),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start game'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Questions are built in Phase 2 and Phase 3; this build is '
                    'the Phase 1 foundation.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  /// Phase 1 ships no playable quiz yet, so the button confirms it is wired up
  /// rather than sitting dead.
  static void _explainStagedBuild(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'Phase 1 foundation is working. The playable quiz arrives with '
            'Phase 2 (data) and Phase 3 (state).',
          ),
        ),
      );
  }
}

class _FoundationCard extends StatelessWidget {
  const _FoundationCard({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    final quizColors = QuizColors.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Phase 1 foundation',
                    style: theme.textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Theme, models, routing and config are wired up. The playable '
              'quiz arrives in Phase 2 (data) and Phase 3 (state).',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                Chip(
                  avatar: const Icon(Icons.palette_outlined, size: 18),
                  label: Text('Material 3: ${scheme.brightness.name}'),
                ),
                const Chip(
                  avatar: Icon(Icons.verified_outlined, size: 18),
                  label: Text('seed #1E88E5'),
                ),
                Chip(
                  avatar: const Icon(Icons.check, size: 18),
                  label: const Text('correct'),
                  backgroundColor: quizColors.correctContainer,
                  side: BorderSide(color: quizColors.correct),
                ),
                Chip(
                  avatar: const Icon(Icons.close, size: 18),
                  label: const Text('wrong'),
                  backgroundColor: quizColors.wrongContainer,
                  side: BorderSide(color: quizColors.wrong),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RulesCard extends StatelessWidget {
  const _RulesCard({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      ('Questions per run', '${QuizConfig.questionCount}'),
      ('Options per question', '${QuizConfig.optionCount}'),
      ('Attempts per question', '${QuizConfig.attemptsPerQuestion}'),
      (
        'Points for 1st / 2nd / 3rd try',
        QuizConfig.pointsLadder.join(' / '),
      ),
      ('If all attempts are used', 'answer revealed, 0 points'),
      ('Maximum score', '${QuizConfig.maxScore}'),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Game rules', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            for (final (String label, String value) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Text(label, style: theme.textTheme.bodyMedium),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      value,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CountryDataCard extends StatelessWidget {
  const _CountryDataCard({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    final sample = countries.take(10).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Offline fallback list',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              '${countries.length} countries in lib/data/countries.dart. '
              'Phase 2 loads these from the countriesnow.space API and falls '
              'back to this list when the network fails.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: _FlagPreview(country: sample.first),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final country in sample)
                  Chip(
                    label: Text('${country.name} (${country.iso2})'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Loads one flag over HTTPS so the CDN path, the loading indicator and the
/// error fallback can all be checked in a browser. Promoted to
/// `lib/widgets/flag_image.dart` in Phase 4.
class _FlagPreview extends StatefulWidget {
  const _FlagPreview({required this.country});

  final Country country;

  @override
  State<_FlagPreview> createState() => _FlagPreviewState();
}

class _FlagPreviewState extends State<_FlagPreview> {
  int _attempt = 0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final country = widget.country;
    final url = 'https://flagcdn.com/w320/${country.iso2Lowercase}.png';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          url,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        AspectRatio(
          aspectRatio: 4 / 3,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                url,
                key: ValueKey<int>(_attempt),
                fit: BoxFit.contain,
                gaplessPlayback: true,
                errorBuilder: (BuildContext context, Object error, StackTrace? stack) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(Icons.flag_outlined, color: scheme.error),
                        const SizedBox(height: 8),
                        Text(
                          'Flag unavailable',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        TextButton(
                          onPressed: () => setState(() => _attempt++),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                },
                loadingBuilder: (
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
                          'Loading ${country.iso2}...',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
