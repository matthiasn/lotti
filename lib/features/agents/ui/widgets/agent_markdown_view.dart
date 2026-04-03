import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:lotti/themes/theme.dart';

/// Shared markdown renderer for agent-authored content.
class AgentMarkdownView extends StatelessWidget {
  const AgentMarkdownView(
    this.text, {
    this.style,
    super.key,
  });

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final effectiveStyle =
        style ??
        Theme.of(context).textTheme.bodyMedium?.copyWith(
          height: 1.5,
          color: context.colorScheme.onSurface,
        ) ??
        TextStyle(
          color: context.colorScheme.onSurface,
          fontSize: 14,
          height: 1.5,
        );

    return GptMarkdown(
      text,
      style: effectiveStyle,
    );
  }
}
