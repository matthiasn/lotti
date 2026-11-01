import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:lotti/features/daily_os_next/ui/pages/day_planning_modal.dart';
import 'package:lotti/features/projects/ui/widgets/project_create_modal.dart';
import 'package:material_ui/material_ui.dart';

/// The ways out of a door that open another feature's own form with the
/// user's words in it. The form is where the user confirms; the door only
/// records what came of it. Each is a provider, so the pane can be tested
/// without the form behind it.

/// Takes [words] the user told the companion about today into the Daily OS
/// planning, opened over her; resolves whether a plan was accepted there.
typedef FrontDayPlanner =
    Future<bool> Function(BuildContext context, String words);

/// The day door's tap: today's plan refined with the words, or the day
/// planned from them when it has no plan yet. The plan changes only when
/// the user accepts in the Daily OS's own review (decision 1).
final frontDayPlannerProvider = Provider<FrontDayPlanner>(
  (ref) => (context, words) async {
    final now = clock.now();
    final today = DateTime(now.year, now.month, now.day);
    final plan = await ref.read(dayAgentProvider).currentPlanForDate(today);
    if (!context.mounted) return false;
    final planned = await showDayPlanningModal(
      context: context,
      dayDate: today,
      intent: frontDayPlanningIntent(plan, words),
    );
    return planned != null;
  },
  name: 'frontDayPlannerProvider',
);

/// What the planning opens to: refining [plan] with [words] sent at once,
/// or — with no plan yet — the capture of a new one with [words] typed in.
DayPlanningIntent frontDayPlanningIntent(DraftPlan? plan, String words) =>
    plan == null
    ? DayPlanningCreate(initialTranscript: words)
    : DayPlanningAdapt(plan, initialTranscript: words);

/// Opens the project form with [words] as its title; resolves the id of
/// the project it created, or null when the user closed it.
typedef FrontNewProject =
    Future<String?> Function(BuildContext context, String words);

/// The inbox's "New project" way: the project form, titled with the words.
final frontNewProjectProvider = Provider<FrontNewProject>(
  (ref) => (context, words) async {
    final project = await showProjectCreateModal(
      context: context,
      initialTitle: words,
    );
    return project?.meta.id;
  },
  name: 'frontNewProjectProvider',
);
