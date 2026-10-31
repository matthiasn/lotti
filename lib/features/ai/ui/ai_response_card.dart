import 'package:lotti/classes/ai_attribution.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai_consumption/ui/widgets/ai_attribution_summary.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// The one surface every AI response renders on — an analysis, a summary, a
/// generated coding or image prompt — so all AI output reads as the same kind
/// of thing.
///
/// A flat, non-elevated card in the `aiCard` color family: a half-strength
/// `background` fill and a `borderSoft` accent hairline, no shadow. It is the
/// same family as the task-agent report cards, without their accent-blended
/// fill and badges, so a response nested inside an entry card is recognizably
/// AI-generated without becoming a second elevated card. Its inset is one
/// step tighter than a top-level card's for the same reason.
///
/// Top to bottom it lays out the optional [header], the optional [body], the
/// "Show more"/"Show less" toggle when [collapsed] is non-null, and always the
/// attribution caption naming the model that wrote the response.
class AiResponseCard extends StatelessWidget {
  const AiResponseCard({
    required this.aiResponse,
    this.header,
    this.body,
    this.collapsed,
    this.onToggleCollapsed,
    super.key,
  }) : assert(
         (collapsed == null) == (onToggleCollapsed == null),
         'collapsed and onToggleCollapsed come together',
       );

  /// Key of the "Show more"/"Show less" toggle — used for testing.
  static const collapseToggleKey = Key('ai_response_card_collapse_toggle');

  /// The response whose attribution the caption names.
  final AiResponseEntry aiResponse;

  /// Row above the body, e.g. a title with copy and expand actions.
  final Widget? header;

  /// The response content. Null renders a card that is only the toggle and
  /// the caption — a collapsed response with no short version to show.
  final Widget? body;

  /// Whether the response is currently collapsed. Null hides the toggle: the
  /// response has nothing to collapse.
  final bool? collapsed;

  /// Flips [collapsed]; required exactly when [collapsed] is set.
  final VoidCallback? onToggleCollapsed;

  /// The body text style every AI response uses: the entry editor's
  /// `body.bodySmall` measure in the AI body color, so an analysis never reads
  /// louder than the entry text it belongs to.
  static TextStyle bodyStyle(BuildContext context) {
    final tokens = context.designTokens;
    return tokens.typography.styles.body.bodySmall.copyWith(
      color: tokens.colors.aiCard.bodyText,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    final isCollapsed = collapsed;

    return Container(
      decoration: BoxDecoration(
        // Half-strength tint: keeps the AI color identity while letting the
        // entry card's surface blend through, so the nested card stays
        // clearly subordinate to its parent.
        color: ai.background.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(tokens.radii.l),
        border: Border.all(color: ai.borderSoft),
      ),
      padding: EdgeInsets.all(tokens.spacing.step4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ?header,
          ?body,
          if (isCollapsed != null)
            _CollapseToggle(
              collapsed: isCollapsed,
              onTap: onToggleCollapsed!,
            ),
          AiAttributionSummary(
            artifact: AiArtifactReference(
              type: AiArtifactType.journalAiResponse,
              id: aiResponse.meta.id,
            ),
            attribution: aiResponse.data.aiAttribution,
            asCaption: true,
            // A response older than attribution still names its model.
            unrecordedModel: aiResponse.data.model,
          ),
        ],
      ),
    );
  }
}

class _CollapseToggle extends StatelessWidget {
  const _CollapseToggle({required this.collapsed, required this.onTap});

  final bool collapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final accent = tokens.colors.aiCard.accent;
    final label = collapsed
        ? context.messages.aiResponseShowMore
        : context.messages.aiResponseShowLess;
    return InkWell(
      key: AiResponseCard.collapseToggleKey,
      onTap: onTap,
      borderRadius: BorderRadius.circular(tokens.radii.xs),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: tokens.spacing.step2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              collapsed ? LottiIcons.expand : LottiIcons.collapse,
              size: tokens.spacing.step5,
              color: accent,
            ),
            SizedBox(width: tokens.spacing.step2),
            Text(
              label,
              style: tokens.typography.styles.others.caption.copyWith(
                color: accent,
                fontWeight: tokens.typography.weight.semiBold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
