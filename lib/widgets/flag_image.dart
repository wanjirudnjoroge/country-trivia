import 'package:flutter/material.dart';

import '../models/country.dart';

/// The country's flag, fetched over HTTPS from flagcdn.com.
///
/// The flag is cosmetic, so a failed load never stalls or crashes the quiz: the
/// placeholder keeps the question playable and offers a retry.
class FlagImage extends StatefulWidget {
  const FlagImage({super.key, required this.country});

  final Country country;

  @override
  State<FlagImage> createState() => _FlagImageState();
}

class _FlagImageState extends State<FlagImage> {
  int _attempt = 0;

  void _retry() => setState(() => _attempt++);

  @override
  Widget build(BuildContext context) {
    return Image.network(
      widget.country.flagUrl,
      // Retrying with a fresh key discards the failed image stream, so the same
      // URL is requested again instead of replaying the cached error.
      key: ValueKey<String>('${widget.country.iso2}#$_attempt'),
      fit: BoxFit.contain,
      gaplessPlayback: true,
      semanticLabel: 'Flag of ${widget.country.name}',
      loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? progress) {
        if (progress == null) return child;
        final int? total = progress.expectedTotalBytes;
        return _FlagPlaceholder(
          code: widget.country.iso2,
          fraction: total == null || total == 0
              ? null
              : (progress.cumulativeBytesLoaded / total).clamp(0.0, 1.0),
        );
      },
      errorBuilder: (BuildContext context, Object error, StackTrace? stack) =>
          _FlagPlaceholder(code: widget.country.iso2, onRetry: _retry),
    );
  }
}

/// Shown while the flag loads, or in place of it when it cannot be loaded.
class _FlagPlaceholder extends StatelessWidget {
  const _FlagPlaceholder({required this.code, this.fraction, this.onRetry});

  final String code;
  final double? fraction;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool failed = onRetry != null;

    return Semantics(
      label: failed ? 'Flag unavailable' : 'Loading flag',
      excludeSemantics: true,
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (failed)
                Icon(Icons.flag_outlined, size: 32, color: scheme.outline)
              else
                SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    value: fraction,
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                code,
                style: theme.textTheme.labelLarge?.copyWith(color: scheme.outline),
              ),
              if (failed) ...<Widget>[
                const SizedBox(height: 4),
                TextButton(onPressed: onRetry, child: const Text('Retry')),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
