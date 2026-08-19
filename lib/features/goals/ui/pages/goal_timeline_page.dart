import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_query_providers.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/goals/state/goal_assessment_state.dart';
import 'package:lotti/features/goals/state/goal_progress_view.dart';
import 'package:lotti/features/goals/ui/checkins/goal_checkin_composer.dart';
import 'package:lotti/features/goals/ui/checkins/goal_checkin_timeline.dart';
import 'package:lotti/features/goals/ui/goal_assessment_widgets.dart';
import 'package:lotti/features/goals/ui/goal_routes.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/widgets/nav_bar/design_system_bottom_navigation_bar.dart';

/// The phone's full check-in history — everything the inline card previews.
///
/// A dedicated route rather than a tab: the detail page already carries a range
/// picker, a chat action, a mic and an overflow menu, and a fifth navigation
/// control on one screen is too many.
class GoalTimelinePage extends ConsumerWidget {
  const GoalTimelinePage({required this.agentId, super.key});

  final String agentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final identity = ref.watch(agentIdentityProvider(agentId)).value;
    final goalIdentity = identity is AgentIdentityEntity ? identity : null;
    final isActive = goalIdentity?.lifecycle == AgentLifecycle.active;
    final health = ref.watch(goalAgentHealthProvider(agentId)).value;
    final title = health?.spec?.title ?? goalIdentity?.displayName ?? '';
    final spec = health?.spec;
    final progress = spec == null
        ? null
        : ref.watch(goalAgentProgressViewProvider(agentId)).value;
    final assessments =
        ref.watch(goalAssessmentHistoryProvider(agentId)).value ?? const [];

    void openComposer() => GoalCheckInComposer.show(
      context,
      agentId: agentId,
      goalTitle: title,
      personaName: goalIdentity?.displayName,
      categoryId: goalIdentity?.allowedCategoryIds.firstOrNull,
    );

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () => beamToNamed(goalDetailPath(agentId)),
        ),
        title: Text(
          context.messages.goalCheckInsTitle,
          style: tokens.typography.styles.subtitle.subtitle2.copyWith(
            color: tokens.colors.text.highEmphasis,
          ),
        ),
        actions: [
          // Creating stays reachable without scrolling to the bottom of a
          // history that may be months long.
          if (isActive)
            IconButton(
              key: const ValueKey('goal-timeline-checkin-action'),
              icon: const Icon(LottiIcons.micIdle),
              tooltip: context.messages.goalCheckInRecordCta,
              onPressed: openComposer,
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            tokens.spacing.step6,
            tokens.spacing.step5,
            tokens.spacing.step6,
            tokens.spacing.step5 +
                DesignSystemBottomNavigationBar.occupiedHeight(context),
          ),
          child: GoalCheckInTimeline(
            agentId: agentId,
            // The full history must reopen reflections exactly like the
            // inline preview — the same shared sheet, gated the same way.
            onOpenReflection: !(isActive && spec != null && progress != null)
                ? null
                : (day) => showGoalDayAssessmentSheet(
                    context,
                    agentId: agentId,
                    spec: spec,
                    progress: progress,
                    assessments: assessments,
                    day: day,
                  ),
          ),
        ),
      ),
    );
  }
}
