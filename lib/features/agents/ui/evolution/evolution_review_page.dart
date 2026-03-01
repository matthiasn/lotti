import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/ritual_review_providers.dart';
import 'package:lotti/features/agents/ui/agent_nav_helpers.dart';
import 'package:lotti/features/agents/ui/evolution/evolution_chat_page.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/evolution_session_timeline.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/feedback_summary_section.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/gamey/colors.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/buttons/lotti_primary_button.dart';

/// Read-only review page for classified feedback and evolution session history.
///
/// Provides a summary of feedback signals, the current active proposal,
/// and a "Start Conversation" button to navigate to [EvolutionChatPage].
class EvolutionReviewPage extends ConsumerWidget {
  const EvolutionReviewPage({
    required this.templateId,
    super.key,
  });

  final String templateId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templateAsync = ref.watch(agentTemplateProvider(templateId));
    final templateEntity = templateAsync.value;
    final templateName =
        templateEntity is AgentTemplateEntity ? templateEntity.displayName : '';

    final feedbackAsync = ref.watch(ritualFeedbackProvider(templateId));
    final pendingAsync = ref.watch(pendingRitualReviewProvider(templateId));

    return Scaffold(
      backgroundColor: GameyColors.surfaceDarkLow,
      appBar: AppBar(
        backgroundColor: GameyColors.surfaceDark,
        leading: agentBackButton(context),
        title: Text(
          context.messages.agentRitualReviewTitle,
          style: appBarTextStyleNewLarge.copyWith(
            color: GameyColors.primaryPurple,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Template name
          Text(
            templateName,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 20),

          // Section 1: Feedback Summary
          _SectionHeader(
            title: context.messages.agentRitualReviewFeedbackTitle,
            icon: Icons.analytics_outlined,
          ),
          const SizedBox(height: 12),
          feedbackAsync.when(
            data: (feedback) {
              if (feedback == null) {
                return _EmptyState(
                  text: context.messages.agentRitualReviewNoFeedback,
                );
              }
              return FeedbackSummarySection(feedback: feedback);
            },
            loading: () => const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            error: (_, __) => _EmptyState(
              text: context.messages.commonError,
            ),
          ),
          const SizedBox(height: 24),

          // Section 2: Current Proposal / Start Conversation
          _SectionHeader(
            title: context.messages.agentRitualReviewProposalSection,
            icon: Icons.auto_awesome,
          ),
          const SizedBox(height: 12),
          pendingAsync.when(
            data: (entity) {
              final session = entity is EvolutionSessionEntity ? entity : null;
              if (session == null) {
                return _EmptyState(
                  text: context.messages.agentRitualReviewNoProposal,
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (session.feedbackSummary != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Text(
                        session.feedbackSummary!,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Center(
                    child: LottiPrimaryButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => EvolutionChatPage(
                            templateId: templateId,
                          ),
                        ),
                      ),
                      label: context.messages.agentRitualReviewAction,
                      icon: Icons.chat,
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 24),

          // Section 3: Session History
          _SectionHeader(
            title: context.messages.agentRitualReviewSessionHistory,
            icon: Icons.timeline,
          ),
          const SizedBox(height: 12),
          EvolutionSessionTimeline(templateId: templateId),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.icon,
  });

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: GameyColors.primaryPurple),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          text,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
