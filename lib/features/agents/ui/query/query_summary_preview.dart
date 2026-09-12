import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/ui/widgets/agent_markdown_view.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// The current owner report loaded on explicit inspection, without leaving chat.
/// The hosting pane authorizes the owner before and after loading the report.
class QuerySummaryPreview extends StatelessWidget {
  const QuerySummaryPreview({
    required this.title,
    required this.report,
    super.key,
  });

  final String title;
  final AgentReportEntity? report;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final text = [
      if (report?.tldr?.trim().isNotEmpty ?? false) report!.tldr!,
      if (report?.content.trim().isNotEmpty ?? false) report!.content,
    ].join('\n\n');
    return SingleChildScrollView(
      padding: EdgeInsets.all(tokens.spacing.step4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: tokens.typography.styles.subtitle.subtitle1),
          SizedBox(height: tokens.spacing.step3),
          Text(
            context.messages.aiCardTitle,
            style: tokens.typography.styles.others.caption,
          ),
          SizedBox(height: tokens.spacing.step3),
          if (text.isEmpty)
            Text(
              context.messages.agentReportNone,
              style: tokens.typography.styles.body.bodySmall,
            )
          else
            SelectionArea(
              child: AgentMarkdownView(
                text,
                style: tokens.typography.styles.body.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}
