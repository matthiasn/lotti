import 'package:flutter/foundation.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/features/goals/workflow/goal_agent_contract.dart';

/// The next steps a standing report showed the user, in order, as STORED:
/// the persisted sections carry `nextActions` as one list — the current
/// actions FACTS authorized, then the later ones.
///
/// The one reader of that shape: the day's Today card quotes the first step,
/// and the next briefing follows up on all of them.
List<String> goalReportNextSteps(AgentReportEntity report) {
  final sections = report.provenance[GoalReportProvenanceKeys.sections];
  if (sections is! Map) return const [];
  final steps = sections[GoalReportSectionKeys.nextActions];
  if (steps is! List) return const [];
  return [
    for (final step in steps)
      if (step is String && step.trim().isNotEmpty) step.trim(),
  ];
}

/// One goal's line in the Today card: where it stands, in the agent's own
/// one-liner, and the first thing to do next.
@immutable
class GoalTodayBriefingItem {
  const GoalTodayBriefingItem({
    required this.agentId,
    required this.title,
    required this.status,
    required this.read,
    required this.nextStep,
  });

  final String agentId;
  final String title;
  final GoalTrackStatus? status;

  /// The standing report's one-liner (or its summary when it has none).
  final String read;

  /// The first next step the report showed, or null when it showed none.
  final String? nextStep;
}

/// What the Today card needs to know about one goal.
typedef GoalTodayBriefingSource = ({
  String agentId,
  String title,
  GoalTrackStatus? status,
  String? specVersionId,
  DateTime? specCreatedAt,
  AgentReportEntity? report,
});

/// The Today card's lines: every goal whose standing report is today's — the
/// period [todayPeriodKey] — for its current spec, the goals that need
/// attention first.
///
/// A deterministic roll-up of what each goal's agent already wrote — no
/// inference of its own. An older report is left out rather than pairing
/// today's status with yesterday's read and steps; a report for a superseded
/// spec is left out rather than captioning the revised goal with the old
/// one's verdict (the health projection's rule, including its fallback to the
/// report's age for reports minted before they named their spec); and a goal
/// without today's report has nothing to say yet.
List<GoalTodayBriefingItem> goalTodayBriefingItems(
  List<GoalTodayBriefingSource> goals, {
  required String todayPeriodKey,
}) {
  final items = <GoalTodayBriefingItem>[];
  for (final goal in goals) {
    final report = goal.report;
    if (report == null || report.deletedAt != null) continue;
    if (report.provenance['periodKey'] != todayPeriodKey) continue;
    final reportSpec = report.provenance['specVersionId'];
    final specCreatedAt = goal.specCreatedAt;
    final forCurrentSpec = reportSpec is String
        ? reportSpec == goal.specVersionId
        : specCreatedAt == null || !report.createdAt.isBefore(specCreatedAt);
    if (!forCurrentSpec) continue;
    final read = [report.oneLiner, report.tldr]
        .map((text) => text?.trim())
        .firstWhere(
          (text) => text != null && text.isNotEmpty,
          orElse: () => null,
        );
    final steps = goalReportNextSteps(report);
    if (read == null && steps.isEmpty) continue;
    items.add(
      GoalTodayBriefingItem(
        agentId: goal.agentId,
        title: goal.title,
        status: goal.status,
        read: read ?? '',
        nextStep: steps.firstOrNull,
      ),
    );
  }
  // Stable: goals of equal urgency keep the page's own order.
  final ordered = items.indexed.toList()
    ..sort((a, b) {
      final byUrgency = _urgency(a.$2.status).compareTo(_urgency(b.$2.status));
      return byUrgency != 0 ? byUrgency : a.$1.compareTo(b.$1);
    });
  return [for (final (_, item) in ordered) item];
}

/// Behind first, then the goals that cannot be judged yet, then the ones
/// turning around, then those on track or done.
int _urgency(GoalTrackStatus? status) => switch (status) {
  GoalTrackStatus.offTrack => 0,
  GoalTrackStatus.atRisk => 1,
  GoalTrackStatus.insufficientData => 2,
  GoalTrackStatus.recovering => 3,
  GoalTrackStatus.onTrack => 4,
  GoalTrackStatus.achieved => 5,
  null => 6,
};
