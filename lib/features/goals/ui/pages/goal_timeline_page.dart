import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/agents/agent_constants.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_query_providers.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_icon_action.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/goals/state/goal_assessment_state.dart';
import 'package:lotti/features/goals/state/goal_checkin_providers.dart';
import 'package:lotti/features/goals/state/goal_progress_view.dart';
import 'package:lotti/features/goals/ui/checkins/goal_checkin_composer.dart';
import 'package:lotti/features/goals/ui/checkins/goal_checkin_timeline.dart';
import 'package:lotti/features/goals/ui/goal_assessment_widgets.dart';
import 'package:lotti/features/goals/ui/pages/goal_page_state.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/goal_routes.dart';
import 'package:lotti/widgets/nav_bar/design_system_bottom_navigation_bar.dart';
import 'package:material_ui/material_ui.dart';

/// The phone's full check-in history — everything the inline card previews.
///
/// A dedicated route rather than a tab: the detail page already carries a range
/// picker, a chat action, a capture bar and an overflow menu, and a fifth
/// navigation control on one screen is too many.
class GoalTimelinePage extends ConsumerWidget {
  const GoalTimelinePage({required this.agentId, super.key});

  final String agentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final identityAsync = ref.watch(agentIdentityProvider(agentId));
    final identity = identityAsync.value;
    // The same three states the goal's page shows before it has a goal: a
    // first load, a failed read with Try again, and a link to a goal that
    // is gone — never a history page with an empty title over an
    // invitation to record.
    void back() => beamToNamed(goalDetailPath(agentId));
    // The error first: a Riverpod retry is loading and errored at once. A
    // read that resolved to nothing is a goal that is gone, not a load.
    if (!identityAsync.hasValue && identityAsync.hasError) {
      return GoalPageState(
        kind: GoalPageStateKind.failed,
        onBack: back,
        onRetry: () => ref.invalidate(agentIdentityProvider(agentId)),
      );
    }
    if (!identityAsync.hasValue) {
      return GoalPageState(kind: GoalPageStateKind.loading, onBack: back);
    }
    if (identity is! AgentIdentityEntity ||
        identity.kind != AgentKinds.goalAgent) {
      return GoalPageState(kind: GoalPageStateKind.notFound, onBack: back);
    }
    final goalIdentity = identity;
    final isActive = goalIdentity.lifecycle == AgentLifecycle.active;
    final health = ref.watch(goalAgentHealthProvider(agentId)).value;
    final title = health?.spec?.title ?? goalIdentity.displayName;
    final spec = health?.spec;
    final progress = spec == null
        ? null
        : ref.watch(goalAgentProgressViewProvider(agentId)).value;
    final assessments =
        ref.watch(goalAssessmentHistoryProvider(agentId)).value ?? const [];

    // Watched, not read at tap time: an unwatched lookup is still loading.
    final goalCategoryId = ref.watch(goalCategoryIdProvider(agentId)).value;
    void openComposer() => GoalCheckInComposer.show(
      context,
      agentId: agentId,
      goalTitle: title,
      // One tap and it is listening, as the goal page's Speak is.
      start: GoalCheckInStart.speaking,
      // The goal row's category, so a check-in is filed with its goal.
      categoryId: goalCategoryId,
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
            // The LIVE mic, as on the goal's page: `micIdle` is Lucide's
            // slashed mic-off, which on an enabled action reads as
            // "recording unavailable".
            DesignSystemIconAction(
              key: const ValueKey('goal-timeline-checkin-action'),
              icon: LottiIcons.mic,
              tooltip: context.messages.goalSpeak,
              onPressed: openComposer,
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            tokens.spacing.step5,
            tokens.spacing.step5,
            tokens.spacing.step5,
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
