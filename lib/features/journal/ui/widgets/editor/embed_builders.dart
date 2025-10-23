import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

/// Lightweight builder for Quill's horizontal rule embed (type: 'divider').
class DividerEmbedBuilder extends EmbedBuilder {
  const DividerEmbedBuilder();

  static const double _dividerOpacity = 0.6;
  static const double _verticalPadding = 12;

  /// Quill serializes horizontal rules with the `divider` embed type.
  @override
  String get key => 'divider';

  @override
  bool get expanded => true;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final theme = Theme.of(context);
    final dividerColor = theme.dividerColor.withValues(alpha: _dividerOpacity);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: _verticalPadding),
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

  static const double _containerOpacity = 0.12;
  static const double _outlineOpacity = 0.31;
  static const double _verticalMargin = 8;
  static const double _padding = 12;

  @override
  String get key => 'unknown';

  @override
  bool get expanded => true;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final theme = Theme.of(context);
    final label = embedContext.node.value.type;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: _verticalMargin),
      padding: const EdgeInsets.all(_padding),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest
            .withValues(alpha: _containerOpacity),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outlineVariant
              .withValues(alpha: _outlineOpacity),
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
