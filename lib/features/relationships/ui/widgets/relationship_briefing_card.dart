import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/ui/agent_internals_panel.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/tldr_section_part.dart';
import 'package:lotti/features/agents/ui/widgets/ai_card_chrome.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/relationships/model/relationship_health_metrics.dart';
import 'package:lotti/features/relationships/state/relationship_agent_providers.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:material_ui/material_ui.dart';

/// The localized label of a health band — shared by the chip and any
/// future list surface.
String relationshipHealthBandLabel(
  BuildContext context,
  RelationshipHealthBand band,
) => switch (band) {
  RelationshipHealthBand.thriving =>
    context.messages.relationshipHealthThriving,
  RelationshipHealthBand.steady => context.messages.relationshipHealthSteady,
  RelationshipHealthBand.needsAttention =>
    context.messages.relationshipHealthNeedsAttention,
  RelationshipHealthBand.strained =>
    context.messages.relationshipHealthStrained,
};

/// The executive briefing on the person's detail page (plan v2 phase 5
/// item 5): the latest report's health chip and TLDR, the expandable full
/// briefing, the explicit "Brief me" trigger — with provider disclosure
/// when the resolved route is not local (ADR 0037) — and the chat entry.
///
/// It is the SAME panel as the task agent's section on Task Details and the
/// goal agent's read: [aiCardDecoration] chrome, [TldrHeader] identity
/// (tapping it opens the agent internals), and [TldrBody] for the report
/// prose — which means the briefing renders as Markdown rather than as the
/// raw asterisks and hashes the model wrote, and its Read more is the same
/// control, in the same place, as the one on a task.
///
/// Renders nothing while the person is not important and no briefing
/// exists yet: the `important` flag is the consent switch, and an inert
/// card would advertise a feature the person is not enrolled in.
class RelationshipBriefingCard extends ConsumerStatefulWidget {
  const RelationshipBriefingCard({required this.relationship, super.key});

  final RelationshipEntry relationship;

  @override
  ConsumerState<RelationshipBriefingCard> createState() =>
      _RelationshipBriefingCardState();
}

class _RelationshipBriefingCardState
    extends ConsumerState<RelationshipBriefingCard> {
  bool _expanded = false;
  bool _requesting = false;

  String get _agentId => relationshipAgentIdFor(widget.relationship.meta.id);

  void _openInternals(String? agentName) {
    Navigator.of(context).push(
      AgentInternalsPanel.route(
        context: context,
        agentId: _agentId,
        agentName: agentName,
      ),
    );
  }

  Future<void> _briefMe() async {
    if (_requesting) return;
    final messages = context.messages;
    setState(() => _requesting = true);
    try {
      // Name the provider BEFORE any cloud-bound trigger (ADR 0037): the
      // locality check fails closed, so an unresolvable profile discloses.
      final providerName = await ref.read(
        relationshipBriefingDisclosureProvider(
          widget.relationship.meta.id,
        ).future,
      );
      if (!mounted) return;
      if (providerName != null) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(
              messages.relationshipBriefingDisclosureTitle(providerName),
            ),
            content: Text(
              messages.relationshipBriefingDisclosureBody(providerName),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(messages.cancelButton),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(
                  messages.relationshipBriefingDisclosureConfirm,
                ),
              ),
            ],
          ),
        );
        if (confirmed != true || !mounted) return;
      }
      await ref
          .read(relationshipAgentServiceProvider)
          .requestBriefing(widget.relationship);
      if (!mounted) return;
      context.showToast(
        tone: DesignSystemToastTone.success,
        title: messages.relationshipBriefingRequested,
      );
    } catch (_) {
      if (!mounted) return;
      context.showToast(
        tone: DesignSystemToastTone.error,
        title: messages.relationshipBriefingRequestFailed,
      );
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    final messages = context.messages;
    final reportAsync = ref.watch(agentReportProvider(_agentId));
    final report = reportAsync.value;
    final current =
        report is AgentReportEntity &&
            report.scope == AgentReportScopes.current &&
            report.deletedAt == null
        ? report
        : null;
    final health = current == null
        ? null
        : relationshipHealthMetricsFromReport(current);

    if (current == null && !widget.relationship.data.important) {
      return const SizedBox.shrink();
    }

    final identity = ref.watch(agentIdentityProvider(_agentId)).value;
    // The relationship agent is NAMED after the person it watches, and this
    // card sits under an app bar already carrying that name — printing it
    // again as the card's subtitle says nothing and reads as a duplicate.
    // A name that has diverged (a synced rename not yet applied) is still
    // worth showing, so the check is equality, not the kind.
    final rawAgentName = identity is AgentIdentityEntity
        ? identity.displayName.trim()
        : null;
    final agentName = rawAgentName == widget.relationship.data.title.trim()
        ? null
        : rawAgentName;

    final bandColor = switch (health?.band) {
      RelationshipHealthBand.thriving =>
        tokens.colors.alert.success.defaultColor,
      RelationshipHealthBand.steady => ai.accent,
      RelationshipHealthBand.needsAttention =>
        tokens.colors.alert.warning.defaultColor,
      RelationshipHealthBand.strained => tokens.colors.alert.error.defaultColor,
      null => tokens.colors.background.level03,
    };

    return DecoratedBox(
      key: const ValueKey('relationship-briefing-card'),
      // The chrome every AI panel shares — see [aiCardDecoration].
      decoration: aiCardDecoration(context),
      child: ClipRRect(
        borderRadius: aiCardRadius(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TldrHeader(
              title: messages.relationshipBriefingTitle,
              agentName: agentName,
              onAgentTap: () => _openInternals(agentName),
            ),
            // Deliberately NOT in the header's trailing rail, where the
            // goal card keeps its meta: that rail is capped at half the
            // header, and a band label is a two-word verdict that a longer
            // locale or a raised text scale pushes past the cap — measured,
            // "Braucht Aufmerksamkeit" already ellipsizes on a 320 px phone
            // at 1.0x. Truncating the card's headline judgement to make
            // room for the title is the wrong trade, so the pill takes the
            // full content width above the prose it qualifies.
            if (health != null)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  tokens.spacing.cardPadding,
                  0,
                  tokens.spacing.cardPadding,
                  tokens.spacing.step3,
                ),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Tooltip(
                    message: health.rationale,
                    child: DsPill(
                      key: const ValueKey('relationship-health-chip'),
                      variant: DsPillVariant.tinted,
                      shape: DsPillShape.tag,
                      color: bandColor,
                      // The band accent as text on its own tint is a
                      // contrast failure; the colour identity rides the
                      // tint, as it does on the task status tag.
                      labelColor: tokens.colors.text.highEmphasis,
                      label: relationshipHealthBandLabel(
                        context,
                        health.band,
                      ),
                    ),
                  ),
                ),
              ),
            Padding(
              // No bottom inset: TldrBody's disclosure row carries the
              // trailing optical gap inside its tap target, and supplies an
              // explicit one when it renders no row at all.
              padding: EdgeInsets.symmetric(
                horizontal: tokens.spacing.cardPadding,
              ),
              child: current == null
                  ? Padding(
                      padding: EdgeInsets.only(bottom: tokens.spacing.step3),
                      child: Text(
                        messages.relationshipBriefingEmpty,
                        style: tokens.typography.styles.body.bodySmall.copyWith(
                          color: ai.metaText,
                        ),
                      ),
                    )
                  : TldrBody(
                      key: const ValueKey('relationship-briefing-body'),
                      disclosureKey: const ValueKey(
                        'relationship-briefing-expand',
                      ),
                      tldr: resolveReportTldr(current),
                      expanded: _expanded,
                      additionalReport: resolveReportAdditional(current),
                      onToggle: () => setState(() => _expanded = !_expanded),
                      onOpenInternals: () => _openInternals(agentName),
                    ),
            ),
            _BriefingActionsFooter(
              onChat: () => beamToNamed(
                '/people/${widget.relationship.meta.id}/chat',
              ),
              onBriefMe: _requesting ? null : _briefMe,
            ),
          ],
        ),
      ),
    );
  }
}

/// The card's quiet controls band — the same wash and hairline the task
/// card's footer wears, holding the two things this panel can do: open the
/// per-person chat, and ask for a fresh briefing.
class _BriefingActionsFooter extends StatelessWidget {
  const _BriefingActionsFooter({
    required this.onChat,
    required this.onBriefMe,
  });

  final VoidCallback onChat;
  final VoidCallback? onBriefMe;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    final messages = context.messages;

    return Container(
      decoration: BoxDecoration(
        color: ai.footerWash,
        border: Border(top: BorderSide(color: ai.borderSoft)),
      ),
      // `cardPadding` horizontally so the primary action's trailing edge
      // lands in the same column as the header title and the report prose;
      // the icon button brings its own optical inset on top of that.
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.cardPadding,
        vertical: tokens.spacing.step2,
      ),
      // Both controls sit together on the trailing edge, the way they did
      // in the header this band replaced: a lone icon at the far left read
      // as orphaned once the card grew to desktop width.
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          IconButton(
            key: const ValueKey('relationship-chat-button'),
            tooltip: messages.relationshipChatTooltip,
            onPressed: onChat,
            icon: Icon(
              LottiIcons.chat,
              size: tokens.spacing.step5,
              color: ai.metaText,
            ),
          ),
          SizedBox(width: tokens.spacing.step2),
          DesignSystemButton(
            key: const ValueKey('relationship-brief-me'),
            label: messages.relationshipBriefMeButton,
            size: DesignSystemButtonSize.dense,
            onPressed: onBriefMe,
          ),
        ],
      ),
    );
  }
}
