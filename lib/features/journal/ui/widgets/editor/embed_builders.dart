import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

/// Lightweight builder for Quill's horizontal rule embed (type: 'divider').
class DividerEmbedBuilder extends EmbedBuilder {
  const DividerEmbedBuilder();

  /// Quill serializes horizontal rules with the `divider` embed type.
  @override
  String get key => 'divider';

  @override
  bool get expanded => true;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final theme = Theme.of(context);
    final dividerColor = theme.dividerColor.withAlpha((0.6 * 0xFF).round());
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Divider(
        color: dividerColor,
        thickness: 1,
        height: 1,
      ),
    );
  }
}

/// Graceful fallback builder for any embed type we don't explicitly support.
class UnknownEmbedBuilder extends EmbedBuilder {
  const UnknownEmbedBuilder();

  @override
  String get key => 'unknown';

  @override
  bool get expanded => true;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final theme = Theme.of(context);
    final label = embedContext.node.value.type;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(30),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withAlpha(80),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Unsupported content ($label)',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
