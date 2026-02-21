import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:lotti/themes/theme.dart';

/// Displays the contents of an agent report rendered as markdown.
///
/// Expects a `content` map with a single `'markdown'` key whose value is the
/// free-form markdown text produced by the agent. The markdown is rendered
/// using [GptMarkdown]. An empty or missing value results in an empty card.
class AgentReportSection extends StatelessWidget {
  const AgentReportSection({
    required this.content,
    super.key,
  });

  final Map<String, Object?> content;

  @override
  Widget build(BuildContext context) {
    final markdown = content['markdown'] as String? ?? '';

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
        child:
            markdown.isEmpty ? const SizedBox.shrink() : GptMarkdown(markdown),
      ),
    );
  }
}
