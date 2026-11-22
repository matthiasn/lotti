import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/design_system/components/lists/grouped_card_row_surface.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/goals/state/goal_assessment_state.dart';
import 'package:lotti/features/goals/state/goal_progress_view.dart';
import 'package:lotti/features/goals/ui/goal_day_marks.dart';
import 'package:lotti/features/goals/ui/goal_health_direction.dart';
import 'package:lotti/features/goals/ui/unified/goal_companion.dart';
import 'package:lotti/features/goals/ui/unified/unified_goal_status.dart';
import 'package:lotti/features/nudges/ui/nudge_banner_widgets.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/goal_routes.dart';
import 'package:lotti/widgets/day_indicators/day_mark.dart';
import 'package:lotti/widgets/day_indicators/day_mark_strip.dart';
import 'package:material_ui/material_ui.dart';

/// One goal on the Goals list, a row of the list's rows card (DESIGN.md,
/// *Goal Row*): the goal's face (its monogram, or the companion whose pose
/// follows the goal's track status), then two tiers so the title leads — the
/// title in Subtitle 1 on a line of its own, and under it one caption line
/// with the status as a glyph and a word ([UnifiedGoalStatusMark]), the trend
/// and a pending proposal. The templated summary follows, and the 7-day strip
/// sits beside the words when the row is wide, under them when it is narrow
/// or the text is large.
///
/// The status used to be a pill on the title's line, and Behind a solid
/// amber block — the loudest thing on the page, outweighing the goal it
/// belonged to. It now reads the way a People row carries *5 days overdue*.
///
/// The row is a [GroupedCardRowSurface]: one button to assistive tech with
/// the title, the status and the summary as one sentence, and the shared
/// hover and focus fill. A health read that failed says so on the caption
/// line rather than leaving the row blank.
///
/// It used to embed the goal's habit rows as well, which spent several rows
/// restating what the status says in two words. A habit's own record is read
/// on the goal's page; the one-tap complete lives in the "not in a goal"
/// group, which is the Habits-tab daily loop.
class UnifiedGoalRow extends ConsumerWidget {
  const UnifiedGoalRow({
    required this.identity,
    super.key,
  });

  final AgentIdentityEntity identity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final healthAsync = ref.watch(goalAgentHealthProvider(identity.agentId));
    // Stale-while-revalidate mirror of the agents list row: only a RESOLVED
    // health carries a verdict; while loading the card shows no pill rather
    // than a false "No data".
    final health = healthAsync.value;
    final progressAsync = health?.spec == null
        ? null
        : ref.watch(goalAgentProgressViewProvider(identity.agentId));
    final progress = progressAsync?.value;
    final status = healthAsync.hasValue
        ? unifiedGoalStatusOf(health?.trackStatus)
        : null;
    final hasStanding = health?.reportOneLiner?.trim().isNotEmpty ?? false;
    // The coarse-health chip's documented display rule, carried over: a
    // "No data" pill must not sit beside a standing assessment that plainly
    // contains data-driven judgement.
    final showPill =
        status != null && !(status == UnifiedGoalStatus.noData && hasStanding);
    final recoveryHint = switch (health?.deficit) {
      final int deficit when deficit > 0 => messages.goalDaysToRecover(deficit),
      _ => null,
    };
    final summary = status == null
        ? null
        : unifiedGoalSummary(
            messages,
            status: status,
            progress: progress,
            oneLiner: health?.reportOneLiner,
          );
    final color = status == null
        ? tokens.colors.text.lowEmphasis
        : unifiedGoalStatusColor(status, tokens.colors);
    final companionEnabled =
        ref.watch(configFlagProvider(enableCompanionFlag)).value ?? false;

    // Same placeholder contract as the agents list: an unresolved strip
    // reserves its footprint with dashed cells, never the filled grey of a
    // genuinely-empty week.
    final resolvedDays = switch (progress?.compactWindow) {
      final days? when days.isNotEmpty => days,
      _ => null,
    };
    final days =
        resolvedDays ?? List<DayMarkState>.filled(7, DayMarkState.none);
    final ratingsByDay = health?.spec == null
        ? const <DateTime, DayVerdict>{}
        : latestRatingsByDay(
            ref.watch(goalAssessmentHistoryProvider(identity.agentId)).value ??
                const [],
            specVersionId: health!.spec!.id,
          );

    final title = health?.spec?.title ?? identity.displayName;
    final failed = !healthAsync.hasValue && healthAsync.hasError;
    final largeText =
        MediaQuery.textScalerOf(context).scale(1) >= TextScales.large;
    final caption = <Widget>[
      if (showPill)
        UnifiedGoalStatusMark(status: status, recoveryHint: recoveryHint),
      if (failed)
        Text(
          messages.goalDetailHealthUnavailable,
          key: const ValueKey('unified-goal-row-health-failed'),
          style: tokens.typography.styles.others.caption.copyWith(
            color: tokens.colors.text.mediumEmphasis,
          ),
        ),
      if (health?.direction case final direction?)
        GoalHealthDirectionChip(direction: direction),
      // A pending revision proposal is only approvable from the detail
      // page — without a list-level signal it stays undiscovered until the
      // user happens to open the goal.
      if ((health?.pendingProposals ?? 0) > 0) const _PendingProposalChip(),
    ];
    final semanticsLabel = [
      title,
      if (showPill)
        [
          unifiedGoalStatusLabel(messages, status),
          if (recoveryHint != null &&
              (status == UnifiedGoalStatus.behind ||
                  status == UnifiedGoalStatus.atRisk))
            recoveryHint,
        ].join(' · '),
      if (failed) messages.goalDetailHealthUnavailable,
      ?summary,
    ].join(', ');

    return GroupedCardRowSurface(
      rowKey: ValueKey('unified-goal-row-${identity.agentId}'),
      selected: false,
      hoverColor: tokens.colors.surface.hover,
      selectedColor: tokens.colors.surface.selected,
      padding: EdgeInsets.all(tokens.spacing.cardPadding),
      onTap: () => beamToNamed(goalDetailPath(identity.agentId)),
      child: Semantics(
        label: semanticsLabel,
        excludeSemantics: true,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide =
                constraints.maxWidth >= kActionListContentMaxWidth &&
                !largeText;
            final words = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  key: const ValueKey('unified-goal-row-title'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: tokens.typography.styles.subtitle.subtitle1.copyWith(
                    color: tokens.colors.text.highEmphasis,
                  ),
                ),
                if (caption.isNotEmpty) ...[
                  SizedBox(height: tokens.spacing.step2),
                  // A Wrap, like the task and People rows' meta line: what
                  // does not share a line takes the next one whole.
                  Wrap(
                    spacing: tokens.spacing.step4,
                    runSpacing: tokens.spacing.step2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: caption,
                  ),
                ],
                if (summary != null) ...[
                  SizedBox(height: tokens.spacing.step2),
                  Text(
                    summary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: tokens.typography.styles.body.bodySmall.copyWith(
                      color: tokens.colors.text.mediumEmphasis,
                    ),
                  ),
                ],
              ],
            );
            final strip = DayMarkStrip(
              marks: goalDayMarks(
                states: days,
                lastDay: progress?.today,
                verdictsByDay: ratingsByDay,
              ),
              placeholder: resolvedDays == null,
            );
            final fill = color.withValues(alpha: SurfaceAlphas.washChip);
            // With the companion on, she is the goal's face in place of the
            // monogram, and her pose follows its track status.
            final leading = companionEnabled
                ? GoalCompanionBust(
                    key: const ValueKey('goalCompanion'),
                    pose: goalCompanionPose(
                      health?.trackStatus,
                      resolved: healthAsync.hasValue,
                    ),
                    fill: fill,
                    agentId: identity.agentId,
                  )
                : NudgeBannerPersonaChip(
                    monogram: NudgeBannerPersonaChip.monogramFor(
                      identity.displayName,
                    ),
                    fill: fill,
                  );
            if (wide) {
              return Row(
                children: [
                  leading,
                  SizedBox(width: tokens.spacing.step4),
                  Expanded(child: words),
                  SizedBox(width: tokens.spacing.step4),
                  strip,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                leading,
                SizedBox(width: tokens.spacing.step4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      words,
                      SizedBox(height: tokens.spacing.step3),
                      strip,
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// "Proposal awaiting review" — the list-level surfacing of
/// `health.pendingProposals`. The info-alert wash with its `ink` foreground
/// mirrors the retired agents-list badge: the full hue as caption text fails
/// the 4.5:1 floor over its own wash.
class _PendingProposalChip extends StatelessWidget {
  const _PendingProposalChip();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final info = tokens.colors.alert.info;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step3,
        vertical: tokens.spacing.step1,
      ),
      decoration: BoxDecoration(
        color: info.defaultColor.withValues(alpha: SurfaceAlphas.washChip),
        // Informative, not tappable: the small-chip radius, never the pill.
        borderRadius: BorderRadius.circular(tokens.radii.smallChips),
      ),
      child: Text(
        context.messages.goalPendingProposalBadge,
        style: tokens.typography.styles.others.caption.copyWith(
          color: info.ink,
        ),
      ),
    );
  }
}
