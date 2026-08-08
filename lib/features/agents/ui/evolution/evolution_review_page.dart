import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/ritual_review_providers.dart';
import 'package:lotti/features/agents/ui/agent_nav_helpers.dart';
import 'package:lotti/features/agents/ui/evolution/evolution_chat_page.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/ritual_session_history_card.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/ritual_summary_card.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/layout/detail_content_width.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/cards/modern_base_card.dart';
import 'package:lotti/widgets/cards/modern_icon_container.dart';
import 'package:lotti/widgets/nav_bar/bottom_nav_safe_navigator.dart';

/// History-first one-on-one home for a template.
///
/// Three things in one order, and nothing else: what you can do right now,
/// what the agent has been doing since you last spoke, and what the two of
/// you decided last time.
class EvolutionReviewPage extends ConsumerWidget {
  const EvolutionReviewPage({
    required this.templateId,
    super.key,
  });

  final String templateId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final templateAsync = ref.watch(agentTemplateProvider(templateId));
    final pendingAsync = ref.watch(pendingRitualReviewProvider(templateId));
    final summaryAsync = ref.watch(ritualSummaryMetricsProvider(templateId));
    final historyAsync = ref.watch(ritualSessionHistoryProvider(templateId));

    final templateEntity = templateAsync.value;
    final templateName = templateEntity is AgentTemplateEntity
        ? templateEntity.displayName
        : context.messages.agentRitualReviewTitle;

    return Scaffold(
      appBar: AppBar(
        leading: agentBackButton(context),
        title: Text(templateName),
      ),
      body: DetailContentWidth(
        child: ListView(
          padding: EdgeInsets.symmetric(vertical: tokens.spacing.step5),
          children: [
            pendingAsync.when(
              data: (entity) {
                final session = entity is EvolutionSessionEntity
                    ? entity
                    : null;
                if (session == null) {
                  return _StartCard(onPressed: () => _openChat(context));
                }
                return _PendingSessionCard(
                  session: session,
                  onPressed: () => _openChat(context),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, _) => _StartCard(onPressed: () => _openChat(context)),
            ),
            SizedBox(height: tokens.spacing.sectionGap),
            summaryAsync.when(
              data: (metrics) => RitualSummaryCard(metrics: metrics),
              loading: () => const _LoadingCard(),
              error: (_, _) => const SizedBox.shrink(),
            ),
            SizedBox(height: tokens.spacing.sectionGap),
            _SectionHeader(
              icon: Icons.history_rounded,
              title: context.messages.agentRitualReviewSessionHistory,
            ),
            SizedBox(height: tokens.spacing.step4),
            historyAsync.when(
              data: (entries) {
                if (entries.isEmpty) {
                  return _EmptyHistoryCard(
                    text: context.messages.agentEvolutionNoSessions,
                  );
                }
                return Column(
                  children: entries
                      .map((entry) => RitualSessionHistoryCard(entry: entry))
                      .toList(),
                );
              },
              loading: () => const _LoadingCard(),
              error: (_, _) => _EmptyHistoryCard(
                text: context.messages.commonError,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openChat(BuildContext context) {
    // Root navigator on mobile so the chat's message input clears the
    // floating bottom nav (this push keeps the review route's URL).
    bottomNavSafeNavigatorOf(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EvolutionChatPage(
          templateId: templateId,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
  });

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Row(
      children: [
        ModernIconContainer(
          icon: icon,
          isCompact: true,
          iconColor: tokens.colors.interactive.enabled,
        ),
        SizedBox(width: tokens.spacing.step4),
        Expanded(
          child: Text(
            title,
            style: tokens.typography.styles.subtitle.subtitle1.copyWith(
              color: tokens.colors.text.highEmphasis,
            ),
          ),
        ),
      ],
    );
  }
}

/// Shown when no session is waiting. Its heading says what the card does —
/// it used to be titled *Current Proposal* in the state where there is no
/// proposal at all.
class _StartCard extends StatelessWidget {
  const _StartCard({
    required this.onPressed,
  });

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return ModernBaseCard(
      padding: EdgeInsets.all(tokens.spacing.cardPadding),
      backgroundColor: tokens.colors.background.level01,
      borderColor: tokens.colors.decorative.level02,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.messages.agentRitualStartHeading,
            style: tokens.typography.styles.heading.heading2.copyWith(
              color: tokens.colors.text.highEmphasis,
            ),
          ),
          SizedBox(height: tokens.spacing.step3),
          Text(
            context.messages.agentRitualSummaryStartHint,
            style: tokens.typography.styles.body.bodyMedium.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
          SizedBox(height: tokens.spacing.step5),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: DesignSystemButton(
              onPressed: onPressed,
              label: context.messages.agentRitualReviewAction,
              size: DesignSystemButtonSize.medium,
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingSessionCard extends StatelessWidget {
  const _PendingSessionCard({
    required this.session,
    required this.onPressed,
  });

  final EvolutionSessionEntity session;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return ModernBaseCard(
      padding: EdgeInsets.all(tokens.spacing.cardPadding),
      backgroundColor: tokens.colors.background.level02,
      borderColor: tokens.colors.decorative.level02,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.messages.agentRitualReviewProposalSection,
                  style: tokens.typography.styles.heading.heading2.copyWith(
                    color: tokens.colors.text.highEmphasis,
                  ),
                ),
              ),
              SizedBox(width: tokens.spacing.step4),
              _SessionBadge(session: session),
            ],
          ),
          if (session.feedbackSummary case final summary?) ...[
            SizedBox(height: tokens.spacing.step4),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(tokens.spacing.step4),
              decoration: BoxDecoration(
                color: tokens.colors.background.level03,
                borderRadius: BorderRadius.circular(tokens.radii.l),
                border: Border.all(
                  color: tokens.colors.decorative.level02,
                ),
              ),
              child: Text(
                summary,
                style: tokens.typography.styles.body.bodyMedium.copyWith(
                  color: tokens.colors.text.highEmphasis,
                ),
              ),
            ),
          ],
          SizedBox(height: tokens.spacing.step5),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: DesignSystemButton(
              onPressed: onPressed,
              label: context.messages.agentRitualContinueAction,
              size: DesignSystemButtonSize.medium,
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionBadge extends StatelessWidget {
  const _SessionBadge({
    required this.session,
  });

  final EvolutionSessionEntity session;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step4,
        vertical: tokens.spacing.step3,
      ),
      decoration: BoxDecoration(
        color: tokens.colors.background.level03,
        borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
        border: Border.all(
          color: tokens.colors.decorative.level02,
        ),
      ),
      child: Text(
        context.messages.agentEvolutionSessionProgress(
          session.sessionNumber,
          session.sessionNumber,
        ),
        style: tokens.typography.styles.subtitle.subtitle2.copyWith(
          color: tokens.colors.text.highEmphasis,
        ),
      ),
    );
  }
}

class _EmptyHistoryCard extends StatelessWidget {
  const _EmptyHistoryCard({
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return ModernBaseCard(
      backgroundColor: tokens.colors.background.level01,
      borderColor: tokens.colors.decorative.level02,
      child: Text(
        text,
        style: tokens.typography.styles.body.bodyMedium.copyWith(
          color: tokens.colors.text.mediumEmphasis,
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return ModernBaseCard(
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: tokens.spacing.step4),
          child: const CircularProgressIndicator(),
        ),
      ),
    );
  }
}
