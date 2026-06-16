import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/features/categories/ui/widgets/category_icon_compact.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/ds_surface_elevation.dart';
import 'package:lotti/features/habits/state/habit_completion_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/pages/create/complete_habit_dialog.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/widgets/charts/habits/dashboard_habits_data.dart';
import 'package:lotti/widgets/charts/utils.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

class HabitCompletionCard extends ConsumerStatefulWidget {
  const HabitCompletionCard({
    required this.habitId,
    required this.rangeStart,
    required this.rangeEnd,
    this.showGaps = true,
    this.showLinkedDashboard = true,
    super.key,
  });

  final String habitId;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final bool showGaps;

  /// Whether the completion dialog embeds the habit's linked dashboard.
  /// Set to false when this card is itself rendered inside that dashboard, so
  /// tapping a row doesn't re-open the dashboard the user is already viewing.
  final bool showLinkedDashboard;

  @override
  ConsumerState<HabitCompletionCard> createState() =>
      _HabitCompletionCardState();
}

class _HabitCompletionCardState extends ConsumerState<HabitCompletionCard> {
  /// Last loaded results, retained so changing the time span keeps the card
  /// visible (stale-while-revalidate) instead of blinking to nothing while the
  /// new range-keyed provider loads.
  List<HabitResult>? _lastResults;

  @override
  void didUpdateWidget(HabitCompletionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Drop the cache when the card is rebound to a different habit (callers key
    // by habitId, so this is defensive), otherwise the previous habit's
    // completion squares would flash under the new habit's name until its
    // provider resolves. A range-only change deliberately keeps the stale
    // results visible (see [_lastResults]).
    if (widget.habitId != oldWidget.habitId) {
      _lastResults = null;
    }
  }

  void onTapAdd({String? dateString}) {
    final height = MediaQuery.of(context).size.height;
    final maxHeight = height * 0.9;
    final habitDefinition = getIt<EntitiesCacheService>().getHabitById(
      widget.habitId,
    );

    if (habitDefinition == null) {
      return;
    }

    // Mirror the dialog's gate: the linked dashboard only fills the sheet when
    // it will actually be shown, otherwise the form floats on a transparent
    // background.
    final showLinkedDashboard =
        widget.showLinkedDashboard && habitDefinition.dashboardId != null;

    ModalUtils.showBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(maxHeight: maxHeight),
      backgroundColor: showLinkedDashboard
          ? Theme.of(context).bottomSheetTheme.backgroundColor
          : Colors.transparent,
      builder: (BuildContext context) {
        return HabitDialog(
          habitId: habitDefinition.id,
          themeData: Theme.of(context),
          dateString: dateString,
          showLinkedDashboard: widget.showLinkedDashboard,
        );
      },
    );
  }

  /// Records a one-tap completion for *today* with [completionType] and no
  /// comment — the fast path shared by the trailing check button (success) and
  /// the horizontal swipe gestures (success / fail). The detailed dialog (date,
  /// comment, linked dashboard) stays one tap away on the row body.
  ///
  /// Confirms with a brief outcome SnackBar so the action is acknowledged
  /// instantly, before the provider round-trips and recolours the strip.
  Future<void> _recordQuickCompletion(
    HabitCompletionType completionType,
    HabitDefinition habitDefinition,
  ) async {
    await HapticFeedback.lightImpact();
    final now = DateTime.now();
    await getIt<PersistenceLogic>().createHabitCompletionEntry(
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
                    ? Icons.cancel_rounded
                    : Icons.check_circle_rounded,
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

    final resultsAsync = ref.watch(
      habitCompletionControllerProvider(
        habitId: habitDefinition.id,
        rangeStart: widget.rangeStart,
        rangeEnd: widget.rangeEnd,
      ),
    );
    if (resultsAsync.hasValue) {
      _lastResults = resultsAsync.value;
    }
    final results = _lastResults;

    if (results == null) {
      return const SizedBox.shrink();
    }

    final completedToday =
        results.isNotEmpty &&
        {
          HabitCompletionType.success,
          HabitCompletionType.skip,
        }.contains(results.last.completionType);

    final tokens = context.designTokens;
    final messages = context.messages;
    final doneColor = habitCompletionColor(HabitCompletionType.success);

    return Padding(
      padding: EdgeInsets.only(bottom: tokens.spacing.cardItemSpacing),
      child: ClipRRect(
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
            icon: Icons.check_circle_rounded,
            label: messages.completeHabitSuccessButton,
          ),
          secondaryBackground: _SwipeActionBackground(
            alignment: Alignment.centerRight,
            color: habitCompletionColor(HabitCompletionType.fail),
            icon: Icons.cancel_rounded,
            label: messages.completeHabitFailButton,
          ),
          confirmDismiss: (direction) async {
            final completionType = direction == DismissDirection.startToEnd
                ? HabitCompletionType.success
                : HabitCompletionType.fail;
            await _recordQuickCompletion(completionType, habitDefinition);
            // Record, then snap back — the row reflects the new state via its
            // provider; it is never removed from the list.
            return false;
          },
          child: _HabitCardBody(
            habitDefinition: habitDefinition,
            results: results,
            rangeStart: widget.rangeStart,
            rangeEnd: widget.rangeEnd,
            showGaps: widget.showGaps,
            completedToday: completedToday,
            doneColor: doneColor,
            onTapAdd: onTapAdd,
            onQuickComplete: () => _recordQuickCompletion(
              HabitCompletionType.success,
              habitDefinition,
            ),
          ),
        ),
      ),
    );
  }
}

/// The visible row content (icon, name, history strip, trailing action). Split
/// from the swipe wrapper so the layout reads on its own and is testable
/// without driving a gesture.
class _HabitCardBody extends StatelessWidget {
  const _HabitCardBody({
    required this.habitDefinition,
    required this.results,
    required this.rangeStart,
    required this.rangeEnd,
    required this.showGaps,
    required this.completedToday,
    required this.doneColor,
    required this.onTapAdd,
    required this.onQuickComplete,
  });

  final HabitDefinition habitDefinition;
  final List<HabitResult> results;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final bool showGaps;
  final bool completedToday;
  final Color doneColor;
  final void Function({String? dateString}) onTapAdd;

  /// One-tap "mark done today" — the trailing check records a success directly
  /// (the icon's universal meaning), instead of opening the detail dialog the
  /// row body / a strip cell open.
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
                              Icons.star_rounded,
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
                        ],
                      ),
                      SizedBox(height: tokens.spacing.step3),
                      _HistoryStrip(
                        results: results,
                        showGaps: showGaps,
                        habitName: habitDefinition.name,
                      ),
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
/// filled, accent-tinted 48dp circle with a bare check — unmistakably a "tap to
/// complete" button. Once done it becomes a quiet filled status check that opens
/// the dialog for review. The 48dp target clears the accessible minimum.
class _CompleteButton extends StatelessWidget {
  const _CompleteButton({
    required this.completed,
    required this.doneColor,
    required this.semanticLabel,
    required this.onPressed,
  });

  final bool completed;
  final Color doneColor;
  final String semanticLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final accent = tokens.colors.interactive.enabled;
    return Semantics(
      button: true,
      label: semanticLabel,
      child: SizedBox(
        width: tokens.spacing.step9,
        height: tokens.spacing.step9,
        child: Material(
          color: completed
              ? Colors.transparent
              : accent.withValues(alpha: 0.12),
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: Icon(
              completed ? Icons.check_circle_rounded : Icons.check_rounded,
              color: completed ? doneColor : accent,
              size: tokens.spacing.step7,
            ),
          ),
        ),
      ),
    );
  }
}

/// The per-day completion history strip — a compact "don't break the chain"
/// calendar, one rounded cell per day in range. Each cell is coloured by
/// outcome AND carries a glyph (✓ / – / ✕), so state never depends on colour
/// alone.
///
/// The strip is read-only: it's a glanceable record, not a control. Tapping
/// anywhere on the row (or the complete button) opens the dialog, where any
/// past day can be backfilled via the date field — so the strip needs no tiny,
/// swipe-conflicting per-cell tap targets. Each cell still exposes its date +
/// outcome to screen readers. Cells are size-capped squares laid out from the
/// start, so the strip stays a quiet footprint instead of stretching into wide
/// "pill bars" on desktop; on dense ranges they shrink and the glyph drops out
/// below a legibility floor.
class _HistoryStrip extends StatelessWidget {
  const _HistoryStrip({
    required this.results,
    required this.showGaps,
    required this.habitName,
  });

  final List<HabitResult> results;
  final bool showGaps;
  final String habitName;

  /// Data-viz dimensions (not layout spacing): cells never exceed this square
  /// size, and the outcome glyph is only drawn once a cell clears the legibility
  /// floor — below it the colour + shape would be too small to read.
  static const double _maxCell = 24;
  static const double _glyphFloor = 14;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final surface = dsCardSurface(context);
    final n = results.length;
    if (n == 0) return const SizedBox.shrink();
    final gap = showGaps ? tokens.spacing.step1 : 0.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final raw = (constraints.maxWidth - gap * (n - 1)) / n;
        final size = raw.clamp(6.0, _maxCell);
        final showGlyph = size >= _glyphFloor;

        return Row(
          children: [
            for (var i = 0; i < n; i++) ...[
              if (i > 0) SizedBox(width: gap),
              _cell(tokens, messages, surface, results[i], size, showGlyph),
            ],
          ],
        );
      },
    );
  }

  Widget _cell(
    DsTokens tokens,
    AppLocalizations messages,
    Color surface,
    HabitResult res,
    double size,
    bool showGlyph,
  ) {
    final appearance = _cellAppearance(res.completionType, tokens, surface);
    final statusWord = _statusWord(res.completionType, messages);

    return Tooltip(
      excludeFromSemantics: true,
      message: chartDateFormatter(res.dayString),
      child: Semantics(
        label: messages.habitDayStatusSemantic(habitName, statusWord),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(showGaps ? tokens.radii.xs : 0),
          child: Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            color: appearance.background,
            child: showGlyph && appearance.glyph != null
                ? Icon(
                    appearance.glyph,
                    size: size * 0.68,
                    color: appearance.ink,
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

/// The localized outcome word for a strip cell's screen-reader label, so the
/// glyph's meaning is conveyed non-visually too.
String _statusWord(HabitCompletionType type, AppLocalizations messages) {
  switch (type) {
    case HabitCompletionType.success:
      return messages.completeHabitSuccessButton;
    case HabitCompletionType.skip:
      return messages.completeHabitSkipButton;
    case HabitCompletionType.fail:
      return messages.completeHabitFailButton;
    case HabitCompletionType.open:
      return messages.habitNotRecordedLabel;
  }
}

/// The higher-contrast ink (near-black or white) for a glyph drawn on [bg],
/// chosen by actual WCAG contrast ratio rather than a luminance threshold — the
/// outcome fills are mid-tones where a naive `luminance > 0.5` test picks the
/// *wrong* (low-contrast) ink. Callers pass the fill already composited over the
/// card surface so translucent fills resolve to their true on-screen colour.
Color _glyphInk(Color bg) {
  double ratio(double a, double b) {
    final hi = a > b ? a : b;
    final lo = a > b ? b : a;
    return (hi + 0.05) / (lo + 0.05);
  }

  final l = bg.computeLuminance();
  return ratio(0, l) >= ratio(1, l) ? Colors.black87 : Colors.white;
}

/// Resolves a per-day strip cell's fill, optional glyph, and on-fill ink.
///
/// The palette is deliberately calm so the chain reads as "mostly done with a
/// few quiet gaps", not a battlefield:
/// - success is the only saturated fill (the win should be visible);
/// - a miss is a *light tint*, never a solid red block, so it registers without
///   shouting;
/// - skip is a neutral grey; an empty (not-yet-recorded) day is the faintest
///   neutral and carries no glyph — "not done yet" must never read as "failed".
///
/// Every recorded outcome also carries a distinct glyph (✓ / – / ✕) so state is
/// never colour-only (colour-blind + low-vision support). [surface] is the card
/// colour the cell sits on, so the ink contrast is computed against the real
/// composited fill.
({Color background, IconData? glyph, Color ink}) _cellAppearance(
  HabitCompletionType type,
  DsTokens tokens,
  Color surface,
) {
  Color inkOn(Color fill) => _glyphInk(Color.alphaBlend(fill, surface));

  switch (type) {
    case HabitCompletionType.success:
      return (
        background: successColor,
        glyph: Icons.check_rounded,
        ink: inkOn(successColor),
      );
    case HabitCompletionType.skip:
      final fill = tokens.colors.background.level03;
      return (background: fill, glyph: Icons.remove_rounded, ink: inkOn(fill));
    case HabitCompletionType.fail:
      final fill = alarm.withValues(alpha: 0.32);
      return (background: fill, glyph: Icons.close_rounded, ink: inkOn(fill));
    case HabitCompletionType.open:
      return (
        background: tokens.colors.decorative.level01,
        glyph: null,
        ink: Colors.transparent,
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
