import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/soul_query_providers.dart';
import 'package:lotti/features/agents/ui/agent_nav_helpers.dart';
import 'package:lotti/features/agents/ui/evolution/soul_evolution_chat_page.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/ritual_session_history_card.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/layout/detail_content_width.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/cards/modern_base_card.dart';
import 'package:lotti/widgets/cards/modern_icon_container.dart';
import 'package:lotti/widgets/nav_bar/bottom_nav_safe_navigator.dart';

/// History-first review home for standalone soul evolution sessions.
class SoulEvolutionReviewPage extends ConsumerWidget {
  const SoulEvolutionReviewPage({
    required this.soulId,
    super.key,
  });

  final String soulId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final soulAsync = ref.watch(soulDocumentProvider(soulId));
    final pendingAsync = ref.watch(pendingSoulEvolutionProvider(soulId));
    final historyAsync = ref.watch(
      soulEvolutionSessionHistoryProvider(soulId),
    );
    final templatesAsync = ref.watch(templatesUsingSoulProvider(soulId));

    final soulEntity = soulAsync.value;
    final soulName = soulEntity is SoulDocumentEntity
        ? soulEntity.displayName
        : context.messages.agentSoulReviewTitle;

    return Scaffold(
      appBar: AppBar(
        leading: agentBackButton(context),
        title: Text(soulName),
      ),
      body: DetailContentWidth(
        child: ListView(
          padding: EdgeInsets.symmetric(vertical: tokens.spacing.step5),
          children: [
            pendingAsync.when(
              data: (entity) {
                final hasTemplates = templatesAsync.value?.isNotEmpty ?? false;
                final session = entity is EvolutionSessionEntity
                    ? entity
                    : null;
                if (session == null) {
                  return _StartCard(
                    onPressed: hasTemplates ? () => _openChat(context) : null,
                    templateCount: templatesAsync.value?.length ?? 0,
                  );
                }
                return _PendingSessionCard(
                  session: session,
                  onPressed: () => _openChat(context),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, _) => _StartCard(
                onPressed: (templatesAsync.value?.isNotEmpty ?? false)
                    ? () => _openChat(context)
                    : null,
                templateCount: templatesAsync.value?.length ?? 0,
              ),
            ),
            SizedBox(height: tokens.spacing.step4),
            _SectionHeader(
              icon: Icons.history_rounded,
              title: context.messages.agentRitualReviewSessionHistory,
            ),
            SizedBox(height: tokens.spacing.step4),
            historyAsync.when(
              data: (entries) {
                if (entries.isEmpty) {
                  return _EmptyHistoryCard(
                    text: context.messages.agentSoulEvolutionNoSessions,
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
        builder: (_) => SoulEvolutionChatPage(soulId: soulId),
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

class _StartCard extends StatelessWidget {
  const _StartCard({this.onPressed, this.templateCount = 0});

  /// How many templates wear this soul. Zero is why the action is disabled,
  /// so the number belongs beside the button rather than in a banner.
  final int templateCount;

  final VoidCallback? onPressed;

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
            context.messages.agentSoulReviewTitle,
            style: tokens.typography.styles.heading.heading2.copyWith(
              color: tokens.colors.text.highEmphasis,
            ),
          ),
          SizedBox(height: tokens.spacing.step3),
          Text(
            context.messages.agentSoulReviewStartHint,
            style: tokens.typography.styles.body.bodyMedium.copyWith(
              color: tokens.colors.text.mediumEmphasis,
              height: 1.45,
            ),
          ),
          SizedBox(height: tokens.spacing.step5),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: tokens.spacing.step4,
            runSpacing: tokens.spacing.step3,
            children: [
              DesignSystemButton(
                onPressed: onPressed,
                label: context.messages.agentSoulReviewStartAction,
                size: DesignSystemButtonSize.medium,
              ),
              if (templateCount > 0)
                Text(
                  context.messages.agentSoulReviewTemplateCount(templateCount),
                  style: tokens.typography.styles.others.caption.copyWith(
                    color: tokens.colors.text.mediumEmphasis,
                  ),
                ),
            ],
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
      padding: EdgeInsets.all(tokens.spacing.step6),
      backgroundColor: tokens.colors.background.level02,
      borderColor: tokens.colors.decorative.level02,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.messages.agentRitualReviewProposalSection,
            style: tokens.typography.styles.heading.heading2.copyWith(
              color: tokens.colors.text.highEmphasis,
            ),
          ),
          SizedBox(height: tokens.spacing.step4),
          if (session.feedbackSummary case final summary?) ...[
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
                  height: 1.4,
                ),
              ),
            ),
            SizedBox(height: tokens.spacing.step4),
          ],
          SizedBox(
            width: double.infinity,
            child: DesignSystemButton(
              onPressed: onPressed,
              label: context.messages.agentSoulReviewStartAction,
              size: DesignSystemButtonSize.medium,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHistoryCard extends StatelessWidget {
  const _EmptyHistoryCard({required this.text});

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
