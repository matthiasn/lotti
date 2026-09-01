import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/state/actual_time_blocks_provider.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_preferences_controller.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_timeline.dart';
import 'package:lotti/features/design_system/components/headers/tab_section_header.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/lockdown/state/lockdown_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Measured panel width at which the docked day view shows the planned and
/// actual lanes side by side. Below it the timeline falls back to its paged
/// mode, where a horizontal swipe moves between the two lanes — the same
/// interaction the Daily OS day surface uses on narrow panes.
const kDayViewSidePanelComparisonBreakpoint = 560.0;

/// The day-view column docked on the right edge of the desktop shell while
/// the Tasks tab is active — the surface where time is planned and tracked.
///
/// Reuses the Daily OS [DayTimeline] — the planned-vs-actual comparison for
/// the current local day — fed by [currentDraftPlanProvider] (falling back to
/// [DraftPlan.emptyForDay] when no plan exists yet, so tracked time is still
/// visible) and [dailyOsActualTimeBlocksProvider]. A calendar button at the
/// top hides the column; [DayViewSidePanelRail] is its hidden counterpart
/// carrying the matching button to bring it back. Visibility and width live
/// in `paneWidthControllerProvider` so both survive app restarts.
class DayViewSidePanel extends ConsumerStatefulWidget {
  const DayViewSidePanel({required this.onToggleHidden, super.key});

  /// Hides the panel (wired to `PaneWidthController.toggleDayViewPanelHidden`
  /// by the shell).
  final VoidCallback onToggleHidden;

  @override
  ConsumerState<DayViewSidePanel> createState() => _DayViewSidePanelState();
}

class _DayViewSidePanelState extends ConsumerState<DayViewSidePanel> {
  Timer? _midnightTimer;
  late DateTime _today;

  @override
  void initState() {
    super.initState();
    _today = _currentDay();
    _scheduleMidnightRollover();
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
    super.dispose();
  }

  DateTime _currentDay() {
    final now = clock.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// The panel is a long-lived shell surface, so unlike the Daily OS root it
  /// must notice the date rolling over while the app stays open — otherwise
  /// it would keep showing yesterday after midnight.
  void _scheduleMidnightRollover() {
    final now = clock.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    _midnightTimer = Timer(
      nextMidnight.difference(now) + const Duration(seconds: 1),
      () {
        if (!mounted) return;
        setState(() => _today = _currentDay());
        _scheduleMidnightRollover();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final today = _today;
    // `.value` keeps the last rendered plan while the provider re-runs on a
    // background agent/sync update — no loading shell mid-session.
    final plan = ref.watch(currentDraftPlanProvider(today)).value;
    final actualBlocks = ref
        .watch(dailyOsActualTimeBlocksProvider(today))
        .value;
    final prefs = ref.watch(dailyOsPreferencesControllerProvider);
    final draft = plan ?? DraftPlan.emptyForDay(today);
    // Under lockdown the column keeps every block so the day still reads as
    // a whole, but blocks outside the locked category are drawn redacted —
    // a neutral slab with no text — rather than dropped. The unassigned
    // fallback category is outside every lockdown.
    final lockdown = ref.watch(lockdownControllerProvider);

    return ColoredBox(
      color: tokens.colors.background.level01,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                tokens.spacing.step4,
                tokens.spacing.step3,
                tokens.spacing.step3,
                0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.messages.dailyOsTodayButton,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tokens.typography.styles.subtitle.subtitle2
                              .copyWith(
                                color: tokens.colors.text.highEmphasis,
                              ),
                        ),
                        Text(
                          MaterialLocalizations.of(
                            context,
                          ).formatMediumDate(today),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tokens.typography.styles.others.caption
                              .copyWith(
                                color: tokens.colors.text.mediumEmphasis,
                              ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: tokens.spacing.step3),
                  SizedBox.square(
                    dimension: TapTargets.minimum,
                    child: Center(
                      child: TabHeaderIconButton(
                        key: const Key('day_view_panel_hide_button'),
                        icon: LottiIcons.today,
                        tooltip: context.messages.dailyOsDayViewPanelHide,
                        active: true,
                        onPressed: widget.onToggleHidden,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: DayTimeline(
                draft: draft,
                actualBlocks: actualBlocks,
                comparisonBreakpoint: kDayViewSidePanelComparisonBreakpoint,
                isRedacted: lockdown.isActive
                    ? (block) => !lockdown.allows(block.category.id)
                    : null,
                showGestureHint: !prefs.timelineGesturesLearned,
                onGesturesLearned: ref
                    .read(dailyOsPreferencesControllerProvider.notifier)
                    .markTimelineGesturesLearned,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The hidden state of the docked day-view column: a slim rail on the right
/// edge whose calendar button at the top restores the panel. Keeping a rail
/// (instead of removing the column entirely) means the toggle stays in the
/// same corner in both states.
class DayViewSidePanelRail extends StatelessWidget {
  const DayViewSidePanelRail({required this.onToggleHidden, super.key});

  /// Shows the panel again.
  final VoidCallback onToggleHidden;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return ColoredBox(
      color: tokens.colors.background.level01,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.only(top: tokens.spacing.step3),
          child: Column(
            children: [
              SizedBox.square(
                dimension: TapTargets.minimum,
                child: Center(
                  child: TabHeaderIconButton(
                    key: const Key('day_view_panel_show_button'),
                    icon: LottiIcons.today,
                    tooltip: context.messages.dailyOsDayViewPanelShow,
                    onPressed: onToggleHidden,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
