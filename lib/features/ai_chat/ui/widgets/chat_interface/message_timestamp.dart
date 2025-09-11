import 'package:flutter/material.dart';

class MessageTimestamp extends StatelessWidget {
  const MessageTimestamp({
    required this.timestamp,
    required this.isUser,
    super.key,
  });

  final DateTime timestamp;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeString =
        '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';

    return Text(
      timeString,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.45),
        fontSize: 11,
      ),
      textAlign: isUser ? TextAlign.left : TextAlign.right,
    );
  }
}
