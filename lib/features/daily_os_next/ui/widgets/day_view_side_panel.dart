import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/state/actual_time_blocks_provider.dart';
import 'package:lotti/features/daily_os_next/state/daily_os_preferences_controller.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/daily_os_date_strip.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_timeline.dart';
import 'package:lotti/features/design_system/components/headers/tab_section_header.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/lockdown/state/lockdown_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// Measured panel width at which the docked day view shows the planned and
/// actual lanes side by side. Below it the timeline falls back to its paged
/// mode, where a horizontal swipe moves between the two lanes — the same
/// interaction the Daily OS day surface uses on narrow panes.
const kDayViewSidePanelComparisonBreakpoint = 560.0;

/// The day-view column docked on the right edge of the desktop shell while
/// the Tasks tab is active — the surface where time is planned and tracked.
///
/// Reuses the Daily OS [DayTimeline] — the planned-vs-actual comparison for
/// one local day — fed by [currentDraftPlanProvider] (falling back to
/// [DraftPlan.emptyForDay] when no plan exists yet, so tracked time is still
/// visible) and [dailyOsActualTimeBlocksProvider]. It opens on today and is
/// navigated with the same [DailyOsDateStrip] as the Daily OS surface
/// header — prev/next chevrons, a date label that opens the picker (long
/// press for today) and a Today button once the selection has left today —
/// placed in the timeline's toolbar row beside the lane-format toggle. The
/// selection is the panel's own; it does not move the Daily OS tab's day. A
/// calendar button at the end of that row hides the column;
/// [DayViewSidePanelRail] is its hidden counterpart carrying the matching
/// button to bring it back. Visibility and width live in
/// `paneWidthControllerProvider` so both survive app restarts.
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

  /// The day on display. Starts on today and follows the chevrons.
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _currentDay();
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
  /// it would keep showing yesterday after midnight. Only a panel still
  /// sitting on today follows the clock; a day the user navigated to stays
  /// put, since they chose it deliberately.
  void _scheduleMidnightRollover() {
    final now = clock.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    _midnightTimer = Timer(
      nextMidnight.difference(now) + const Duration(seconds: 1),
      () {
        if (!mounted) return;
        final wasOnToday =
            _selectedDay ==
            DateTime(
              now.year,
              now.month,
              now.day,
            );
        if (wasOnToday) {
          setState(() => _selectedDay = _currentDay());
        }
        _scheduleMidnightRollover();
      },
    );
  }

  /// Moves the selection by [days]; the `DateTime` constructor keeps the
  /// day arithmetic DST-safe.
  void _shiftDay(int days) {
    setState(() {
      _selectedDay = DateTime(
        _selectedDay.year,
        _selectedDay.month,
        _selectedDay.day + days,
      );
    });
  }

  void _goToToday() {
    setState(() => _selectedDay = _currentDay());
  }

  /// Opens the shared Daily OS date picker and applies the pick to the
  /// panel's own selection.
  Future<void> _pickDay() async {
    final picked = await showDailyOsDayPicker(context, selected: _selectedDay);
    if (picked == null || !mounted) return;
    setState(
      () => _selectedDay = DateTime(picked.year, picked.month, picked.day),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final day = _selectedDay;
    // `.value` keeps the last rendered plan while the provider re-runs on a
    // background agent/sync update — no loading shell mid-session.
    final plan = ref.watch(currentDraftPlanProvider(day)).value;
    final actualBlocks = ref.watch(dailyOsActualTimeBlocksProvider(day)).value;
    final prefs = ref.watch(dailyOsPreferencesControllerProvider);
    final draft = plan ?? DraftPlan.emptyForDay(day);
    // Under lockdown the column keeps every block so the day still reads as
    // a whole, but blocks outside the locked category are drawn redacted —
    // a neutral slab with no text — rather than dropped. The unassigned
    // fallback category is outside every lockdown.
    final lockdown = ref.watch(lockdownControllerProvider);

    // Material rather than a plain ColoredBox: the date strip's label is an
    // InkWell, which needs a Material ancestor to draw its ink on.
    return Material(
      color: tokens.colors.background.level01,
      child: SafeArea(
        bottom: false,
        // One line of chrome: the Daily OS date strip leads the timeline's
        // toolbar row, the lane-format toggle follows, the hide button ends
        // it. The strip is the same widget the Daily OS surface header uses,
        // so the two read and behave alike.
        child: DayTimeline(
          draft: draft,
          actualBlocks: actualBlocks,
          comparisonBreakpoint: kDayViewSidePanelComparisonBreakpoint,
          toolbarLeading: DailyOsDateStrip(
            compact: true,
            selected: day,
            isToday: day == _currentDay(),
            onPrev: () => _shiftDay(-1),
            onNext: () => _shiftDay(1),
            onPick: _pickDay,
            onToday: _goToToday,
          ),
          toolbarTrailing: TabHeaderIconButton(
            key: const Key('day_view_panel_hide_button'),
            icon: LottiIcons.today,
            tooltip: context.messages.dailyOsDayViewPanelHide,
            active: true,
            onPressed: widget.onToggleHidden,
          ),
          isRedacted: lockdown.isActive
              ? (block) => !lockdown.allows(block.category.id)
              : null,
          showGestureHint: !prefs.timelineGesturesLearned,
          onGesturesLearned: ref
              .read(dailyOsPreferencesControllerProvider.notifier)
              .markTimelineGesturesLearned,
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
