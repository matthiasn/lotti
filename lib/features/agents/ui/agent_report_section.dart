import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:lotti/themes/theme.dart';

/// Displays the contents of an agent report rendered as markdown.
///
/// Expects a plain markdown string produced by the agent via the
/// `update_report` tool call. The markdown is rendered using [GptMarkdown].
/// An empty value results in an empty card.
class AgentReportSection extends StatelessWidget {
  const AgentReportSection({
    required this.content,
    super.key,
  });

  final String content;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.cardPaddingHalf,
        vertical: AppTheme.spacingSmall,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.cardPadding),
        child: content.isEmpty ? const SizedBox.shrink() : GptMarkdown(content),
      ),
    );
  }
}
