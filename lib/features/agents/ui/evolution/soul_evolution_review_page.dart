import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/soul_query_providers.dart';
import 'package:lotti/features/agents/ui/agent_nav_helpers.dart';
import 'package:lotti/features/agents/ui/evolution/soul_evolution_chat_page.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/ritual_session_history_card.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/cards/modern_base_card.dart';
import 'package:lotti/widgets/cards/modern_icon_container.dart';

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
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.spacingLarge),
        children: [
          _HeroPanel(templateCount: templatesAsync.value?.length ?? 0),
          SizedBox(height: tokens.spacing.step5),
          pendingAsync.when(
            data: (entity) {
              final hasTemplates = templatesAsync.value?.isNotEmpty ?? false;
              final session = entity is EvolutionSessionEntity ? entity : null;
              if (session == null) {
                return _StartCard(
                  onPressed: hasTemplates ? () => _openChat(context) : null,
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
    );
  }

  void _openChat(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SoulEvolutionChatPage(soulId: soulId),
      ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({required this.templateCount});

  final int templateCount;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return ModernBaseCard(
      padding: EdgeInsets.all(tokens.spacing.step6),
      backgroundColor: tokens.colors.background.alternative01,
      borderColor: tokens.colors.decorative.level02,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const ModernIconContainer(
                icon: Icons.auto_awesome_rounded,
                isCompact: true,
              ),
              SizedBox(width: tokens.spacing.step4),
              Expanded(
                child: Text(
                  context.messages.agentSoulReviewTitle,
                  style: tokens.typography.styles.heading.heading1.copyWith(
                    color: tokens.colors.text.highEmphasis,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            context.messages.agentSoulReviewHeroSubtitle,
            style: tokens.typography.styles.body.bodyLarge.copyWith(
              color: tokens.colors.text.highEmphasis,
              height: 1.35,
            ),
          ),
          if (templateCount > 0) ...[
            SizedBox(height: tokens.spacing.step3),
            Container(
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
                context.messages.agentSoulReviewTemplateCount(templateCount),
                style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                  color: tokens.colors.text.highEmphasis,
                ),
              ),
            ),
          ],
        ],
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
        const SizedBox(width: 10),
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
  const _StartCard({this.onPressed});

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
          Row(
            children: [
              ModernIconContainer(
                icon: Icons.auto_awesome_rounded,
                isCompact: true,
                iconColor: tokens.colors.interactive.enabled,
              ),
              const SizedBox(width: 10),
              Text(
                context.messages.agentSoulReviewTitle,
                style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                  color: tokens.colors.text.mediumEmphasis,
                  letterSpacing: 0.25,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            context.messages.agentSoulReviewStartHint,
            style: tokens.typography.styles.body.bodyMedium.copyWith(
              color: tokens.colors.text.mediumEmphasis,
              height: 1.45,
            ),
          ),
          SizedBox(height: tokens.spacing.step5),
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
          Row(
            children: [
              ModernIconContainer(
                icon: Icons.bolt_rounded,
                isCompact: true,
                iconColor: tokens.colors.text.highEmphasis,
                borderColor: tokens.colors.decorative.level02,
              ),
              const SizedBox(width: 10),
              Text(
                context.messages.agentSoulReviewTitle,
                style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                  color: tokens.colors.text.highEmphasis,
                  letterSpacing: 0.25,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
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
