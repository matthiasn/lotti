import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/features/categories/ui/widgets/category_icon_compact.dart';
import 'package:lotti/features/design_system/components/celebration/celebration_selection.dart';
import 'package:lotti/features/design_system/components/celebration/completion_burst.dart';
import 'package:lotti/features/design_system/components/celebration/completion_glow.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/ds_surface_elevation.dart';
import 'package:lotti/features/habits/ui/pages/habit_editor_launcher.dart';
import 'package:lotti/features/habits/ui/sheets/habit_completion_sheet.dart';
import 'package:lotti/features/settings/state/celebration_preferences_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/utils/date_utils_extension.dart';
import 'package:lotti/widgets/charts/habits/dashboard_habits_data.dart';
import 'package:lotti/widgets/day_indicators/day_mark.dart';
import 'package:lotti/widgets/day_indicators/day_mark_strip.dart';

/// The 0→1 progress of a celebration beat whose window is `[start, end]` within
/// the shared timeline [c], or `null` when [c] is outside that window so the
/// caller renders nothing. This is what staggers the beats off one controller:
/// each reads its own slice, so the glow and the burst start at different times.
double? _stageProgress(double c, double start, double end) {
  if (c <= start || c >= end) return null;
  return (c - start) / (end - start);
}

/// How many days a habit row's history strip shows on a desktop window.
///
/// A phone card has room for the handover's week; a desktop row has several
/// times that width, and seven squares left most of it empty. Two weeks is
/// the span the habits chart also opens on.
const int kHabitHistoryDaysDesktop = 14;

/// The days a habit row's history strip shows in this window: two weeks on a
/// desktop-width window, the handover's seven otherwise. The rows' callers
/// pass it to `habitHistoryMarks` so the state slices the same span the row
/// draws.
int habitHistoryDays(BuildContext context) =>
    isDesktopLayout(context) ? kHabitHistoryDaysDesktop : DateTime.daysPerWeek;

/// The shared habit action row used by the habits tab and the dashboard habit
/// chart: a swipe-to-record row (right = success, left = missed) whose body
/// opens the completion dialog on tap, with a category icon, an optional
/// priority star, the habit name, the handover's history strip — one square
/// per day of [history], each opening the completion sheet for its own day,
/// then a flame and [currentStreak] — and a trailing
/// one-tap complete button.
///
/// The history is the caller's to supply: the habits tab reads its week off
/// `HabitsState` (`habitHistoryMarks`), the dashboard card off its own range.
/// [completedToday] is supplied by the caller too — the tab derives it from
/// the controller's `successfulToday` bucket, the dashboard card from its
/// latest in-range result — so the row stays presentational.
class HabitActionRow extends ConsumerStatefulWidget {
  const HabitActionRow({
    required this.habitId,
    required this.completedToday,
    this.currentStreak = 0,
    this.history = const [],
    this.autoCompleted = false,
    this.autoCompleteReason,
    this.autoCompletedAt,
    super.key,
  });

  final String habitId;

  /// Whether the habit counts as done today — drives the done-border and the
  /// trailing button's two modes.
  final bool completedToday;

  /// This habit's current consecutive-day streak, drawn as a flame and the
  /// count after the history squares once it reaches 1 — the per-habit
  /// "don't break the chain" signal the combined heatmap can't give.
  final int currentStreak;

  /// The per-day history under the name, oldest first. Empty draws no
  /// squares; the streak tail still shows when there is a run going.
  final List<DayMark> history;

  /// Whether today's completion was written by the auto-completion engine —
  /// shows the "auto" pill and, with [autoCompleteReason], the caption naming
  /// the signal that checked it off. Tapping still opens the sheet, so the
  /// outcome can be changed (a manual entry always overrides).
  final bool autoCompleted;
  final String? autoCompleteReason;

  /// When the engine wrote today's completion (`HH:mm`, local), for the
  /// caption.
  final String? autoCompletedAt;

  @override
  ConsumerState<HabitActionRow> createState() => _HabitActionRowState();
}

class _HabitActionRowState extends ConsumerState<HabitActionRow>
    with SingleTickerProviderStateMixin {
  /// Drives the staged completion celebration as one timeline (0→1 over ~950ms);
  /// the beats read off windowed slices of it so they *cascade* — glow bloom,
  /// then spark burst — instead of all firing on the same frame. The check pop
  /// is the t=0 anchor and stays on its own [AnimatedSwitcher]. Fired from
  /// [didUpdateWidget] so it only plays on the completion *transition*, never on
  /// a row that was already done when the list first built.
  ///
  /// Created in [initState] (not a lazy initializer) so it always exists by the
  /// time [dispose] runs — even for a missing habit whose `build` returns early.
  late final AnimationController _celebrate;

  /// The base habit-celebration timeline; the active habit variant's
  /// `durationScale` stretches it (bubbles run slower) right before each play so
  /// the burst doesn't read too fast.
  static const _celebrateBaseDuration = Duration(milliseconds: 1400);

  /// True between an optimistic (tap-time) celebration and the matching
  /// data-driven `completedToday` flip, so the flip doesn't restart the
  /// animation that's already playing.
  bool _optimisticCelebration = false;

  @override
  void initState() {
    super.initState();
    _celebrate = AnimationController(
      vsync: this,
      duration: _celebrateBaseDuration,
    );
  }

  /// The variant(s) resolved for the in-flight celebration. Re-rolled on every
  /// fire so Random / Combine vary each completion; drives the burst + glow tint.
  ResolvedCelebration? _resolved;

  /// Resolves the habit selection for this fire (re-rolling Random / Combine)
  /// and re-times [_celebrate] to the resolved variant before it plays, so a
  /// slower-feeling variant (bubbles) gets a longer window. Call right before
  /// `_celebrate.forward`.
  void _beginCelebration() {
    final resolved = ref
        .read(celebrationPreferencesProvider)
        .habitsSelection
        .resolve(seed: nextCelebrationSeed());
    _resolved = resolved;
    // For a combined pair, honour the slower of the two so a layered bubbles
    // half still gets its full window — mirrors spawnCompletionBurst.
    final primaryScale = resolved.primary.durationScale;
    final secondScale = resolved.secondary?.durationScale ?? primaryScale;
    _celebrate.duration =
        _celebrateBaseDuration *
        (primaryScale > secondScale ? primaryScale : secondScale);
  }

  @override
  void didUpdateWidget(HabitActionRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.completedToday && widget.completedToday) {
      if (_optimisticCelebration) {
        // A tap on this row already started the timeline; the provider just
        // caught up. Don't restart it — let the in-flight animation continue.
        _optimisticCelebration = false;
      } else if (ref.read(celebrationPreferencesProvider).animateHabits) {
        // Completed from elsewhere (the dialog, a sync). Run the timeline; the
        // builders decide what it *looks* like — an opacity-only glow under
        // reduced motion, the full staged celebration otherwise. Skipped when
        // the user turned habit celebrations off.
        _beginCelebration();
        _celebrate.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _celebrate.dispose();
    super.dispose();
  }

  void onTapAdd({String? dateString}) {
    HabitCompletionSheet.show(
      context,
      habitId: widget.habitId,
      dateString: dateString,
    );
  }

  /// A tap on one of the history squares: the sheet for THAT day, so a
  /// missed Tuesday is recorded on Tuesday rather than on today with the
  /// date to be corrected by hand. The page state's span ends today; a
  /// dashboard range can run past it, and there is nothing to record on a
  /// day that has not happened.
  void _onHistoryDaySelected(DateTime day) {
    final ymd = day.ymd;
    if (ymd.compareTo(clock.now().ymd) > 0) return;
    onTapAdd(dateString: ymd);
  }

  /// Records a one-tap completion for *today* with [completionType] and no
  /// comment — the fast path shared by the trailing check button (success) and
  /// the horizontal swipe gestures (success / fail). The detailed dialog (date,
  /// comment, linked dashboard) stays one tap away on the row body.
  ///
  /// Confirms with a brief outcome SnackBar so the action is acknowledged
  /// instantly, before the provider round-trips and recolours the row.
  Future<void> _recordQuickCompletion(
    HabitCompletionType completionType,
    HabitDefinition habitDefinition,
  ) async {
    // Fire the celebration first, the instant the tap lands, then persist +
    // recompute afterwards. Gating the animation behind the provider round-trip
    // made the burst feel laggy on mobile ("the UI blocks, then particles fly
    // later"). Only a fresh success flips the row to done, so only that case
    // celebrates; [didUpdateWidget] won't double-fire it (see
    // [_optimisticCelebration]).
    final prefs = ref.read(celebrationPreferencesProvider);
    final isSuccess = completionType == HabitCompletionType.success;
    if (isSuccess && !widget.completedToday && prefs.animateHabits) {
      _optimisticCelebration = true;
      _beginCelebration();
      _celebrate.forward(from: 0);
    }
    // A success completion honours the independent haptics switch; the "missed"
    // (fail) swipe always buzzes — that is corrective feedback, not a
    // celebration. Fire-and-forget so it never delays the persist + recompute.
    if (!isSuccess || prefs.haptics) {
      unawaited(HapticFeedback.lightImpact());
    }
    final now = DateTime.now();
    final saved = await getIt<PersistenceLogic>().createHabitCompletionEntry(
      data: HabitCompletionData(
        habitId: habitDefinition.id,
        dateFrom: now,
        dateTo: now,
        completionType: completionType,
      ),
      comment: '',
      habitDefinition: habitDefinition,
    );
    if (!mounted) return;
    if (saved == null) {
      // The write didn't commit (PersistenceLogic logs the cause and returns
      // null); the `completedToday` flip that consumes the optimistic flag will
      // never arrive, so clear it here or a later real completion — and its
      // celebration — would be suppressed. No success SnackBar either, since
      // nothing was recorded.
      //
      // This branch means the *write* failed, and only that. Side effects of a
      // successful write — scheduling the next reminder, for one — are caught
      // where they happen. Reaching here after a successful write also
      // double-fires the celebration: clearing the flag lets `didUpdateWidget`
      // treat the incoming `completedToday` flip as a fresh completion.
      _optimisticCelebration = false;
      return;
    }
    final tokens = context.designTokens;
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          content: Row(
            children: [
              Icon(
                completionType == HabitCompletionType.fail
                    ? LottiIcons.closeCircled
                    : LottiIcons.confirmCircled,
                color: habitCompletionColor(completionType),
              ),
              SizedBox(width: tokens.spacing.step4),
              Expanded(child: Text(habitDefinition.name)),
            ],
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final habitDefinition = getIt<EntitiesCacheService>().getHabitById(
      widget.habitId,
    );

    if (habitDefinition == null) {
      return const SizedBox.shrink();
    }

    final tokens = context.designTokens;
    final messages = context.messages;
    final doneColor = habitCompletionColor(HabitCompletionType.success);
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    // The master switch + the "celebrate habit completion" switch. Off → no
    // glow/burst/streak pop (the glow/burst controller is simply never started
    // above; the burst builder and the streak pop also check this so a late
    // rebuild can't re-introduce them). The completion haptic is unaffected.
    final prefs = ref.watch(celebrationPreferencesProvider);
    final celebrate = prefs.animateHabits;

    return Padding(
      padding: EdgeInsets.only(bottom: tokens.spacing.cardItemSpacing),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // A soft accent glow that blooms around the card on completion —
          // behind the (opaque) card and outside the swipe clip so the halo
          // shows around the edges instead of being cut off. Starts ~80ms in so
          // it reads as caused by the check landing, not co-fired with it. Under
          // reduced motion it holds a fixed size and only fades (no expansion).
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _celebrate,
                builder: (context, _) {
                  final v = _stageProgress(_celebrate.value, 0.08, 0.78);
                  return v == null
                      ? const SizedBox.shrink()
                      : CompletionGlow(
                          key: const ValueKey('habit-completion-flash'),
                          value: v,
                          staticGlow: reduceMotion,
                          // A warm resolved variant blooms warm; the rest keep
                          // the accent.
                          color: (_resolved?.primary.isWarm ?? false)
                              ? starredGold
                              : null,
                        );
                },
              ),
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(tokens.radii.m),
            child: Dismissible(
              key: ValueKey<String>('habit-swipe-${habitDefinition.id}'),
              dismissThresholds: const {
                DismissDirection.startToEnd: 0.4,
                DismissDirection.endToStart: 0.4,
              },
              background: _SwipeActionBackground(
                alignment: Alignment.centerLeft,
                color: habitCompletionColor(HabitCompletionType.success),
                icon: LottiIcons.confirmCircled,
                label: messages.completeHabitSuccessButton,
              ),
              secondaryBackground: _SwipeActionBackground(
                alignment: Alignment.centerRight,
                color: habitCompletionColor(HabitCompletionType.fail),
                icon: LottiIcons.closeCircled,
                label: messages.completeHabitFailButton,
              ),
              confirmDismiss: (direction) async {
                final completionType = direction == DismissDirection.startToEnd
                    ? HabitCompletionType.success
                    : HabitCompletionType.fail;
                await _recordQuickCompletion(completionType, habitDefinition);
                // Record, then snap back — the row reflects the new state via its
                // host's state; it is never removed from the list.
                return false;
              },
              child: _HabitCardBody(
                habitDefinition: habitDefinition,
                completedToday: widget.completedToday,
                autoCompleted: widget.autoCompleted,
                autoCompleteReason: widget.autoCompleteReason,
                autoCompletedAt: widget.autoCompletedAt,
                currentStreak: widget.currentStreak,
                doneColor: doneColor,
                celebrate: celebrate,
                history: widget.history,
                onTapAdd: onTapAdd,
                onHistoryDaySelected: _onHistoryDaySelected,
                onEdit: () => openHabitEditor(context, habitId: widget.habitId),
                onQuickComplete: () => _recordQuickCompletion(
                  HabitCompletionType.success,
                  habitDefinition,
                ),
              ),
            ),
          ),
          // Sparks flying out of the completed check — over the card and free to
          // leave the rounded rect (the Stack does not clip). Launches ~135ms in
          // so the sparks read as thrown by the check as it lands. Suppressed
          // under reduced motion or when habit celebrations are switched off.
          if (!reduceMotion && celebrate)
            Positioned.fill(
              child: IgnorePointer(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Centre the burst on the trailing complete button. It sits
                    // one card padding (step4) plus half a button (step9) in
                    // from the right edge, so the fractional origin has to track
                    // the real card width — a fixed value drifts left of the
                    // button on wide dashboard cards.
                    final inset =
                        tokens.spacing.step4 + tokens.spacing.step9 / 2;
                    final originX = constraints.maxWidth > 0
                        ? (1 - 2 * inset / constraints.maxWidth).clamp(0.0, 1.0)
                        : 0.82;
                    return AnimatedBuilder(
                      animation: _celebrate,
                      builder: (context, _) {
                        final p = _stageProgress(_celebrate.value, 0.12, 0.96);
                        final resolved = _resolved;
                        return p == null || resolved == null
                            ? const SizedBox.shrink()
                            : CompletionBurst(
                                progress: p,
                                params: prefs.paramsFor(resolved.primary),
                                secondParams: resolved.secondary == null
                                    ? null
                                    : prefs.paramsFor(resolved.secondary!),
                                origin: Alignment(originX, 0),
                              );
                      },
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The visible row content (icon, name, optional history, trailing action).
/// Split from the swipe wrapper so the layout reads on its own and is testable
/// without driving a gesture.
class _HabitCardBody extends StatelessWidget {
  const _HabitCardBody({
    required this.habitDefinition,
    required this.completedToday,
    required this.autoCompleted,
    required this.autoCompleteReason,
    required this.autoCompletedAt,
    required this.currentStreak,
    required this.doneColor,
    required this.celebrate,
    required this.onTapAdd,
    required this.onHistoryDaySelected,
    required this.onEdit,
    required this.onQuickComplete,
    required this.history,
  });

  final HabitDefinition habitDefinition;
  final bool completedToday;
  final bool autoCompleted;
  final String? autoCompleteReason;
  final String? autoCompletedAt;
  final int currentStreak;
  final Color doneColor;

  /// Whether habit-completion celebrations are enabled.
  final bool celebrate;
  final List<DayMark> history;
  final void Function({String? dateString}) onTapAdd;

  /// A tap on one of the [history] squares, with that square's day.
  final ValueChanged<DateTime> onHistoryDaySelected;
  final VoidCallback onEdit;

  /// One-tap "mark done today" — the trailing check records a success directly
  /// (the icon's universal meaning), instead of opening the detail dialog the
  /// row body opens.
  final VoidCallback onQuickComplete;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final titleStyle = tokens.typography.styles.subtitle.subtitle1.copyWith(
      color: tokens.colors.text.highEmphasis,
    );

    return Material(
      color: dsCardSurface(context),
      child: InkWell(
        onTap: onTapAdd,
        // Press-and-hold the body → the editor for this habit.
        onLongPress: onEdit,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(tokens.radii.m),
            border: Border.all(
              color: completedToday
                  ? doneColor.withValues(alpha: 0.55)
                  : tokens.colors.decorative.level01,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: tokens.spacing.step4,
              vertical: tokens.spacing.step3,
            ),
            child: Row(
              children: [
                CategoryIconCompact(
                  habitDefinition.categoryId,
                  size: CategoryIconConstants.iconSizeMedium,
                ),
                SizedBox(width: tokens.spacing.step4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (habitDefinition.priority ?? false) ...[
                            Icon(
                              LottiIcons.star,
                              size: tokens.spacing.step5,
                              color: starredGold,
                            ),
                            SizedBox(width: tokens.spacing.step2),
                          ],
                          Flexible(
                            child: Text(
                              habitDefinition.name,
                              style: titleStyle,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (autoCompleted) ...[
                            SizedBox(width: tokens.spacing.step2),
                            DsPill(
                              key: const ValueKey('habit-auto-pill'),
                              variant: DsPillVariant.tinted,
                              color: tokens.colors.interactive.enabled,
                              leading: Icon(
                                LottiIcons.aiSpark,
                                size: IconSizes.xs,
                                color: tokens.colors.interactive.enabled,
                              ),
                              label: messages.habitAutoPillLabel,
                            ),
                          ],
                        ],
                      ),
                      if (autoCompleted &&
                          autoCompleteReason != null &&
                          autoCompletedAt != null) ...[
                        SizedBox(height: tokens.spacing.step1),
                        Text(
                          messages.habitAutoCompletedCaption(
                            autoCompleteReason!,
                            autoCompletedAt!,
                          ),
                          key: const ValueKey('habit-auto-caption'),
                          style: tokens.typography.styles.others.caption
                              .copyWith(
                                color: tokens.colors.text.mediumEmphasis,
                              ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      // The handover's history strip: the span's squares,
                      // then the flame and the streak. Nothing when there is
                      // neither history nor a run going. Each square is the
                      // door to its own day's sheet, and a tappable track
                      // brings its own air — the touch-floor slot with the
                      // weekday initial and the square centred in it — so
                      // the gap above it is the small one.
                      if (history.isNotEmpty || currentStreak >= 1) ...[
                        SizedBox(height: tokens.spacing.step1),
                        DayMarkStrip(
                          marks: history,
                          streak: currentStreak,
                          onDaySelected: onHistoryDaySelected,
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(width: tokens.spacing.step3),
                _CompleteButton(
                  // Not done → one-tap success (the icon's universal meaning),
                  // shown as a filled accent button so it clearly reads as the
                  // row's primary action. Already done → a quiet status check
                  // that opens the dialog to review/adjust (never a silent
                  // duplicate).
                  completed: completedToday,
                  doneColor: doneColor,
                  semanticLabel: messages.habitCompleteSemanticLabel(
                    habitDefinition.name,
                  ),
                  onPressed: completedToday ? onTapAdd : onQuickComplete,
                  // Press-and-hold → the dialog with the date picker, to log a
                  // past or specific day.
                  onLongPress: onTapAdd,
                  longPressHint: messages.habitLogOtherDayHint,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The row's primary action affordance. When the habit is not yet done it is a
/// hollow, accent-ringed 48dp circle with a "+" — unmistakably "tap to log",
/// never confusable with a completed state. Once done it becomes a green
/// check-circle that opens the dialog for review (never a silent duplicate).
/// The 48dp target clears the accessible minimum.
class _CompleteButton extends StatelessWidget {
  const _CompleteButton({
    required this.completed,
    required this.doneColor,
    required this.semanticLabel,
    required this.onPressed,
    required this.onLongPress,
    required this.longPressHint,
  });

  final bool completed;
  final Color doneColor;
  final String semanticLabel;
  final VoidCallback onPressed;

  /// Press-and-hold opens the full completion dialog (with the date picker), so
  /// a past or specific day can be logged without leaving the row — the tap
  /// stays the instant "done today" path.
  final VoidCallback onLongPress;
  final String longPressHint;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final accent = tokens.colors.interactive.enabled;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Tooltip(
      message: longPressHint,
      // Hover (desktop) reveals the hint; the touch long-press is reserved for
      // the gesture itself rather than popping the tooltip.
      triggerMode: TooltipTriggerMode.manual,
      child: Semantics(
        button: true,
        label: semanticLabel,
        onLongPress: onLongPress,
        child: SizedBox(
          width: tokens.spacing.step9,
          height: tokens.spacing.step9,
          child: Material(
            color: Colors.transparent,
            shape: completed
                ? const CircleBorder()
                : CircleBorder(side: BorderSide(color: accent, width: 2)),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
              onLongPress: onLongPress,
              customBorder: const CircleBorder(),
              // Pop the check in when the habit is completed, so the tap lands
              // with a real reward beat: the incoming check overshoots past full
              // size and settles back, while the "+" fades out underneath. Snaps
              // instantly when the platform asks to reduce motion.
              child: AnimatedSwitcher(
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 320),
                switchInCurve: Curves.easeOutBack,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) =>
                    ScaleTransition(scale: animation, child: child),
                child: Icon(
                  completed ? LottiIcons.confirmCircled : LottiIcons.add,
                  key: ValueKey(completed),
                  color: completed ? doneColor : accent,
                  size: tokens.spacing.step7,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The coloured reveal behind a row while it is being swiped — an outcome
/// colour with a leading/trailing icon and label so the gesture's effect is
/// legible before the user commits to it.
class _SwipeActionBackground extends StatelessWidget {
  const _SwipeActionBackground({
    required this.alignment,
    required this.color,
    required this.icon,
    required this.label,
  });

  final Alignment alignment;
  final Color color;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final onColor = tokens.colors.text.highEmphasis;
    return ColoredBox(
      color: color,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step5),
        child: Align(
          alignment: alignment,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: onColor, size: tokens.spacing.step6),
              SizedBox(width: tokens.spacing.step2),
              Text(
                label,
                style: tokens.typography.styles.body.bodyMedium.copyWith(
                  color: onColor,
                  fontWeight: tokens.typography.weight.semiBold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
