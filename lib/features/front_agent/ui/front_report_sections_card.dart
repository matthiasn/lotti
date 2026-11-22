import 'package:clock/clock.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/agent_report_sections_view.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/front_agent/model/front_report_quote.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/relative_age_label.dart';
import 'package:material_ui/material_ui.dart';

/// Keys the tests and screenshots reach the card by.
abstract final class FrontReportSectionsCardKeys {
  /// The header of the quote from task [taskId]'s report, which opens it.
  static Key task(String taskId) => ValueKey('front-report-sections-$taskId');
}

/// Sections of a task's report quoted in her reply, drawn as the task page's
/// AI summary draws them, in its violet card: the task as the header, which
/// opens it ([onOpenTask]), how old the report is, then the sections. The
/// quote is the report she read, not the task's current one.
class FrontReportSectionsCard extends StatelessWidget {
  const FrontReportSectionsCard({
    required this.quote,
    required this.onOpenTask,
    super.key,
  });

  final FrontReportQuote quote;
  final ValueChanged<String> onOpenTask;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    final messages = context.messages;
    final radius = BorderRadius.circular(tokens.radii.l);
    final age = relativeAgeOrDateLabel(
      messages,
      at: quote.at,
      now: clock.now(),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ai.background,
        borderRadius: radius,
        border: Border.all(color: ai.border),
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DesignSystemListItem(
              key: FrontReportSectionsCardKeys.task(quote.taskId),
              title: quote.title,
              titleMaxLines: 2,
              subtitle: '${messages.aiCardTitle} · $age',
              subtitleEmphasis: ai.metaText,
              size: DesignSystemListItemSize.small,
              leading: Icon(
                LottiIcons.checkboxChecked,
                size: IconSizes.m,
                color: tokens.colors.text.mediumEmphasis,
              ),
              trailing: Icon(
                LottiIcons.chevronRight,
                size: IconSizes.m,
                color: tokens.colors.text.lowEmphasis,
              ),
              onTap: () => onOpenTask(quote.taskId),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                tokens.spacing.cardPadding,
                tokens.spacing.step2,
                tokens.spacing.cardPadding,
                tokens.spacing.cardPadding,
              ),
              child: AgentReportSectionsView(
                sections: quote.sections,
                bodyStyle: tokens.typography.styles.body.bodySmall.copyWith(
                  color: ai.bodyText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
