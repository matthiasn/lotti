import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/relationships/model/relationship_health_metrics.dart';
import 'package:lotti/features/relationships/state/relationship_agent_providers.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';

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

    final bandColor = switch (health?.band) {
      RelationshipHealthBand.thriving =>
        tokens.colors.alert.success.defaultColor,
      RelationshipHealthBand.steady => tokens.colors.aiCard.accent,
      RelationshipHealthBand.needsAttention =>
        tokens.colors.alert.warning.defaultColor,
      RelationshipHealthBand.strained => tokens.colors.alert.error.defaultColor,
      null => tokens.colors.background.level03,
    };

    return Container(
      key: const ValueKey('relationship-briefing-card'),
      width: double.infinity,
      padding: EdgeInsets.all(tokens.spacing.cardPadding),
      decoration: BoxDecoration(
        color: tokens.colors.background.level02,
        borderRadius: BorderRadius.circular(tokens.radii.l),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  messages.relationshipBriefingTitle,
                  style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                    color: tokens.colors.text.highEmphasis,
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey('relationship-chat-button'),
                tooltip: messages.relationshipChatTooltip,
                onPressed: () => beamToNamed(
                  '/people/${widget.relationship.meta.id}/chat',
                ),
                icon: Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: tokens.spacing.step5,
                ),
              ),
              DesignSystemButton(
                key: const ValueKey('relationship-brief-me'),
                label: messages.relationshipBriefMeButton,
                size: DesignSystemButtonSize.dense,
                onPressed: _requesting ? null : _briefMe,
              ),
            ],
          ),
          if (health != null) ...[
            SizedBox(height: tokens.spacing.step2),
            Tooltip(
              message: health.rationale,
              child: Container(
                key: const ValueKey('relationship-health-chip'),
                padding: EdgeInsets.symmetric(
                  horizontal: tokens.spacing.step3,
                  vertical: tokens.spacing.step1,
                ),
                decoration: BoxDecoration(
                  color: bandColor.withValues(alpha: SurfaceAlphas.washChip),
                  borderRadius: BorderRadius.circular(
                    tokens.radii.badgesPills,
                  ),
                ),
                child: Text(
                  relationshipHealthBandLabel(context, health.band),
                  style: tokens.typography.styles.others.overline.copyWith(
                    color: tokens.colors.text.highEmphasis,
                  ),
                ),
              ),
            ),
          ],
          if (current != null) ...[
            SizedBox(height: tokens.spacing.step2),
            SelectableText(
              (current.tldr?.isNotEmpty ?? false)
                  ? current.tldr!
                  : current.content,
              style: tokens.typography.styles.body.bodyMedium.copyWith(
                color: tokens.colors.text.highEmphasis,
              ),
            ),
            if (_expanded) ...[
              SizedBox(height: tokens.spacing.step2),
              SelectableText(
                current.content,
                key: const ValueKey('relationship-briefing-content'),
                style: tokens.typography.styles.body.bodyMedium.copyWith(
                  color: tokens.colors.text.mediumEmphasis,
                ),
              ),
            ],
            if (current.content.trim() != (current.tldr ?? '').trim())
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  key: const ValueKey('relationship-briefing-expand'),
                  onPressed: () => setState(() => _expanded = !_expanded),
                  child: Text(
                    _expanded
                        ? messages.aiResponseShowLess
                        : messages.aiResponseShowMore,
                  ),
                ),
              ),
          ] else ...[
            SizedBox(height: tokens.spacing.step2),
            Text(
              messages.relationshipBriefingEmpty,
              style: tokens.typography.styles.body.bodySmall.copyWith(
                color: tokens.colors.text.mediumEmphasis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
