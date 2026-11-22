import 'package:lotti/classes/agents/agent_report_section.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/widgets/markdown/agent_markdown_view.dart';
import 'package:material_ui/material_ui.dart';

/// A task report's body drawn from its sections instead of from Markdown:
/// each section a title over a points list, a read-only checklist or a
/// paragraph. Row and paragraph text is inline Markdown, so links still open.
class AgentReportSectionsView extends StatelessWidget {
  const AgentReportSectionsView({
    required this.sections,
    required this.bodyStyle,
    super.key,
  });

  final List<AgentReportSection> sections;

  /// The card's report prose style, shared with the summary above.
  final TextStyle bodyStyle;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: tokens.spacing.step5,
      children: [
        for (final (index, section) in sections.indexed)
          Column(
            key: ValueKey('agent-report-section-$index'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: tokens.spacing.step2,
            children: [
              if (section.title.isNotEmpty)
                Semantics(
                  header: true,
                  child: Text(
                    section.title,
                    style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                      color: ai.titleText,
                    ),
                  ),
                ),
              if (section.kind == AgentReportSectionKind.text)
                AgentMarkdownView(section.text, style: bodyStyle)
              else
                for (final item in section.items)
                  _ItemRow(
                    item: item,
                    checklist: section.kind == AgentReportSectionKind.checklist,
                    bodyStyle: bodyStyle,
                  ),
            ],
          ),
      ],
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.item,
    required this.checklist,
    required this.bodyStyle,
  });

  final AgentReportSectionItem item;
  final bool checklist;
  final TextStyle bodyStyle;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    // A point is a fact, so it gets a typographic bullet; an open ring would
    // read as an unticked to-do next to a checklist.
    final Widget marker = checklist
        // Centres the glyph on the first line of a row that may wrap.
        ? SizedBox(
            height:
                (bodyStyle.fontSize ?? IconSizes.s) * (bodyStyle.height ?? 1),
            child: Icon(
              item.done
                  ? LottiIcons.checkboxChecked
                  : LottiIcons.checkboxUnchecked,
              size: IconSizes.xs,
              color: item.done ? ai.accent : ai.metaText,
            ),
          )
        : ExcludeSemantics(
            child: Text('•', style: bodyStyle.copyWith(color: ai.metaText)),
          );
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: tokens.spacing.step3,
      children: [
        marker,
        Expanded(
          child: AgentMarkdownView(
            item.text,
            style: item.done
                ? bodyStyle.copyWith(color: ai.metaText)
                : bodyStyle,
          ),
        ),
      ],
    );
    return checklist
        ? MergeSemantics(
            child: Semantics(checked: item.done, child: row),
          )
        : row;
  }
}
