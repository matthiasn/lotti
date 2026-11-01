import 'package:lotti/features/agents/ui/ai_summary_card/tldr_section_part.dart';
import 'package:lotti/features/design_system/components/cards/design_system_section_card.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// The event's summary when no event agent writes one: the event's own note,
/// or the newest AI response linked to it.
///
/// It is the user's text (or an older one-off response), not an agent's
/// living recap, so it does not wear the AI card's accent wash: it is the
/// flat design-system section card with a *plain* report header — the same
/// header grammar as the agent card that replaces it once an agent is
/// attached, minus the claim to be an AI surface. The relationship
/// briefing's non-agent face is built the same way.
class EventPassiveSummaryCard extends StatelessWidget {
  const EventPassiveSummaryCard({required this.summary, super.key});

  final String summary;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return DesignSystemSectionCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TldrHeader(
            agentName: null,
            plain: true,
            icon: LottiIcons.note,
            title: context.messages.eventsSummaryTitle,
          ),
          Padding(
            padding: EdgeInsets.only(
              left: tokens.spacing.cardPadding,
              right: tokens.spacing.cardPadding,
              bottom: tokens.spacing.step4,
            ),
            child: Text(
              summary,
              style: tokens.typography.styles.body.bodySmall.copyWith(
                color: tokens.colors.text.highEmphasis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
