import 'package:flutter/material.dart';
import 'package:lotti/themes/theme.dart';
import 'package:matrix/encryption.dart';

/// Renders the verification emoji sequence as a wrapping grid so the row
/// adapts to narrow screens (e.g. Samsung phones in portrait) instead of
/// overflowing horizontally. Items keep their fixed cell width so the
/// individual emoji + label stays legible regardless of the wrap point.
class VerificationEmojisRow extends StatelessWidget {
  const VerificationEmojisRow(
    this.emojis, {
    super.key,
  });

  final Iterable<KeyVerificationEmoji>? emojis;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      runAlignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        ...?emojis?.map(
          (emoji) => Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 4,
              vertical: 6,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  emoji.emoji,
                  style: const TextStyle(fontSize: 40),
                ),
                Text(
                  emoji.name,
                  style: context.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
