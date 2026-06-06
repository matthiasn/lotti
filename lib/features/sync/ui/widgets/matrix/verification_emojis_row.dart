import 'package:flutter/foundation.dart';
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

  /// Builds one fixed-width emoji + label cell per entry; empty for a
  /// null or empty sequence. Pure so the cell contract is property-testable
  /// without pumping a widget tree.
  @visibleForTesting
  static List<Widget> buildEmojiCells(
    Iterable<KeyVerificationEmoji>? emojis, {
    TextStyle? nameStyle,
  }) {
    return [
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
                style: nameStyle,
              ),
            ],
          ),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      runAlignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: buildEmojiCells(emojis, nameStyle: context.textTheme.bodySmall),
    );
  }
}
