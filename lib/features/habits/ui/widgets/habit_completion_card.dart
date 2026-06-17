import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/ds_surface_elevation.dart';
import 'package:lotti/features/habits/state/habit_completion_controller.dart';
import 'package:lotti/features/habits/ui/widgets/habit_action_row.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/widgets/charts/habits/dashboard_habits_data.dart';
import 'package:lotti/widgets/charts/utils.dart';

/// A habit row that carries its own per-day completion history strip — used by
/// the dashboard habit chart, where seeing the chain over the dashboard's range
/// is the point.
///
/// Wraps the shared [HabitActionRow] (swipe + quick-complete + dialog), adding
/// the range-keyed [habitCompletionControllerProvider] watch that feeds the
/// [_HistoryStrip] and derives the done-state from the latest in-range result.
/// The habits tab does NOT use this card — it renders [HabitActionRow] directly
/// (history lives in the consistency heatmap).
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

    return HabitActionRow(
      habitId: habitDefinition.id,
      completedToday: completedToday,
      showLinkedDashboard: widget.showLinkedDashboard,
      history: _HistoryStrip(
        results: results,
        showGaps: widget.showGaps,
        habitName: habitDefinition.name,
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
