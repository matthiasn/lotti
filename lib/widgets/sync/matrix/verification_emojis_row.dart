import 'package:flutter/material.dart';
import 'package:lotti/themes/theme.dart';
import 'package:matrix/encryption.dart';

class VerificationEmojisRow extends StatelessWidget {
  const VerificationEmojisRow(
    this.emojis, {
    super.key,
  });

  final Iterable<KeyVerificationEmoji>? emojis;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ...?emojis?.map(
          (emoji) => Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 6,
            ),
            child: Column(
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
