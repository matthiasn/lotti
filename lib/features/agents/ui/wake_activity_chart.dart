import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/agents/model/hourly_wake_activity.dart';
import 'package:lotti/features/agents/state/agent_pending_wake_providers.dart';
import 'package:lotti/features/agents/ui/token_stats_tab_chart.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/ds_surface_elevation.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

/// 24-hour wake-activity section: a quiet section heading with the total,
/// and a card holding one single-hue bar per hour.
///
/// Height alone encodes magnitude — no y-axis gutter, gridlines, or
/// per-threshold hues; exact counts live in each bar's semantics label and
/// in the always-present detail line. Selection follows the daily chart's
/// grammar: it defaults to the most recent active hour (the "default to
/// now" anchor) and a tap retargets rather than toggles, so the detail
/// line never vanishes and the card never shifts height. Hidden entirely
/// when the last 24h had no wakes.
class WakeActivityChart extends ConsumerStatefulWidget {
  const WakeActivityChart({super.key});

  @override
  ConsumerState<WakeActivityChart> createState() => _WakeActivityChartState();
}

class _WakeActivityChartState extends ConsumerState<WakeActivityChart> {
  /// Selected hour of day (0–23). Keyed by hour rather than bucket index
  /// so the rolling 24h window cannot silently retarget a selection when
  /// the buckets shift under it.
  int? _selectedHour;

  /// Whether the focus system wants the chart's focus painted — same
  /// visible-mode rule as the daily chart's arrow-key support.
  bool _focusHighlighted = false;

  @override
  Widget build(BuildContext context) {
    final activityAsync = ref.watch(hourlyWakeActivityProvider);
    final buckets = activityAsync.value;

    if (buckets == null || buckets.every((b) => b.count == 0)) {
      return const SizedBox.shrink();
    }

    final tokens = context.designTokens;
    final maxCount = buckets.fold<int>(0, (m, b) => math.max(m, b.count));
    final totalWakes = buckets.fold<int>(0, (sum, b) => sum + b.count);
    // Default to the most recent active hour — the daily chart's
    // "default to now" grammar, anchored to the newest bucket that has a
    // story to tell (the hide guard above ensures one exists). A selected
    // hour that rolled out of the window also falls back here.
    final selectedFromHour = _selectedHour == null
        ? -1
        : buckets.indexWhere((b) => b.hour.hour == _selectedHour);
    final effectiveIndex = selectedFromHour >= 0
        ? selectedFromHour
        : buckets.lastIndexWhere((b) => b.count > 0);
    final selected = buckets[effectiveIndex];
    final labelStyle = tokens.typography.styles.others.caption.copyWith(
      color: context.colorScheme.onSurfaceVariant,
    );

    // No outer gutter of its own — the stats tab applies the shared
    // settings content insets (and desktop max-width) to every section.
    // Keyboard grammar mirrors the daily chart: once focused, the arrow
    // keys step the hour selection, clamped at the chart edges.
    return FocusableActionDetector(
      onShowFocusHighlight: (highlighted) =>
          setState(() => _focusHighlighted = highlighted),
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.arrowLeft): _StepHourIntent(-1),
        SingleActivator(LogicalKeyboardKey.arrowRight): _StepHourIntent(1),
      },
      actions: {
        _StepHourIntent: CallbackAction<_StepHourIntent>(
          onInvoke: (intent) {
            final next = (effectiveIndex + intent.delta).clamp(
              0,
              buckets.length - 1,
            );
            _onBarTap(buckets[next].hour.hour);
            return null;
          },
        ),
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StatsSectionHeading(
            title: context.messages.agentPendingWakesActivityTitle,
            caption: context.messages.agentPendingWakesActivityTotal(
              totalWakes,
            ),
          ),
          SizedBox(height: tokens.spacing.step3),
          Container(
            decoration: BoxDecoration(
              color: dsCardSurface(context),
              borderRadius: BorderRadius.circular(tokens.radii.sectionCards),
            ),
            padding: EdgeInsets.all(tokens.spacing.cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // The shared scrub gesture: dragging across the bars
                // retargets the selection continuously — the precision
                // answer for 24 narrow columns on touch.
                // The daily chart’s width-cap rule, verbatim: columns stop
                // growing once their bar has, start-anchored on the card’s
                // left rail.
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      // The daily chart's width-cap rule via the one
                      // shared expression — 24 dense compact columns.
                      maxWidth: chartContentMaxWidth(
                        context,
                        columnCount: buckets.length,
                        compact: true,
                      ),
                    ),
                    child: ChartScrubArea(
                      itemCount: buckets.length,
                      onIndex: (index) => _onBarTap(buckets[index].hour.hour),
                      child: DecoratedBox(
                        position: DecorationPosition.foreground,
                        decoration: _focusHighlighted
                            ? BoxDecoration(
                                border: chartSelectionBorder(context),
                                borderRadius: BorderRadius.circular(
                                  tokens.radii.xs,
                                ),
                              )
                            : const BoxDecoration(),
                        child: SizedBox(
                          height: chartWakeHeight,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              for (var i = 0; i < buckets.length; i++)
                                Expanded(
                                  child: _HourBar(
                                    bucket: buckets[i],
                                    maxCount: maxCount,
                                    isSelected: effectiveIndex == i,
                                    onTap: () =>
                                        _onBarTap(buckets[i].hour.hour),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: tokens.spacing.step2),
                // One Expanded slot per bucket with sparse labels — the
                // same column-aligned technique as the daily chart's label
                // row, so each label sits under the hour it names.
                Row(
                  children: [
                    for (var i = 0; i < buckets.length; i++)
                      Expanded(
                        child: i % 6 == 0 || i == buckets.length - 1
                            ? Text(
                                _fmtHour(buckets[i].hour),
                                style: labelStyle,
                                // First/last labels bias inward so their
                                // overflow never runs past the card edge.
                                textAlign: i == 0
                                    ? TextAlign.start
                                    : i == buckets.length - 1
                                    ? TextAlign.end
                                    : TextAlign.center,
                                softWrap: false,
                                overflow: TextOverflow.visible,
                              )
                            : const SizedBox.shrink(),
                      ),
                  ],
                ),
                Padding(
                  padding: EdgeInsets.only(top: tokens.spacing.step3),
                  // A two-line reserve sizes the slot (the card promises
                  // height stability), while the live line renders over
                  // it — retargeting between short and wrapping reason
                  // sets never shifts the chart above.
                  child: Stack(
                    children: [
                      ExcludeSemantics(
                        child: Opacity(
                          opacity: 0,
                          child: Text(
                            '\n',
                            style: tokens.typography.styles.others.caption,
                          ),
                        ),
                      ),
                      Text(
                        selected.reasons.isEmpty
                            ? context.messages
                                  .agentPendingWakesActivityHourDetailEmpty(
                                    _fmtHour(selected.hour),
                                    selected.count,
                                  )
                            : context.messages
                                  .agentPendingWakesActivityHourDetail(
                                    _fmtHour(selected.hour),
                                    selected.count,
                                    _reasonsLine(context, selected.reasons),
                                  ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: tokens.typography.styles.others.caption.copyWith(
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _onBarTap(int hourOfDay) {
    // Retarget, never deselect — same grammar as the daily chart, and the
    // detail line below stays populated so the card never changes height.
    setState(() => _selectedHour = hourOfDay);
  }

  static String _fmtHour(DateTime hour) => DateFormat.Hm().format(hour);

  /// The selected hour's reason breakdown as localized `Name count` pairs,
  /// busiest first — the detail line must never speak implementation
  /// language (raw `WakeReason` enum names).
  static String _reasonsLine(BuildContext context, Map<String, int> reasons) {
    final messages = context.messages;
    String name(String reason) => switch (reason) {
      'scheduled' => messages.agentWakeReasonScheduled,
      'subscription' => messages.agentWakeReasonSubscription,
      'creation' => messages.agentWakeReasonCreation,
      'reanalysis' => messages.agentWakeReasonReanalysis,
      'transcriptionComplete' => messages.agentWakeReasonTranscription,
      // An unmapped reason keeps its raw key: a wrong-register word beats
      // a hidden count.
      _ => reason,
    };
    final entries = reasons.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    // Non-breaking space inside each pair: a name and its count are one
    // fact and must never split across a wrap.
    return entries.map((e) => '${name(e.key)}\u00a0${e.value}').join(' · ');
  }
}

/// Steps the wake chart's hour selection by [delta] via the arrow keys.
class _StepHourIntent extends Intent {
  const _StepHourIntent(this.delta);

  final int delta;
}

class _HourBar extends StatefulWidget {
  const _HourBar({
    required this.bucket,
    required this.maxCount,
    required this.isSelected,
    required this.onTap,
  });

  final HourlyWakeActivity bucket;
  final int maxCount;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_HourBar> createState() => _HourBarState();
}

class _HourBarState extends State<_HourBar> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final fraction = widget.maxCount > 0
        ? widget.bucket.count / widget.maxCount
        : 0.0;
    final hour = DateFormat.Hm().format(widget.bucket.hour);

    // The daily chart's exact grammar, hour-sized: quiet grey history and
    // a ring on the selected hour. No teal here at all — on this page the
    // accent means "today", and an hour histogram has no today.
    final barColor = chartHistoryBarColor(
      context,
      selected: widget.isSelected,
      hovered: _hovered,
    );

    final label =
        '$hour: '
        '${context.messages.agentStatsSourceWakes(widget.bucket.count)}';
    return Semantics(
      button: true,
      selected: widget.isSelected,
      // Localized unit: "09:00: 5 wakes", not a bare number.
      label: label,
      // The same hover value readout the daily bars promise.
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        waitDuration: chartTooltipWaitDuration,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap,
            // The tap target is the full chart-height column — quiet hours
            // must not shrink to a few-pixel target, and empty hours must
            // stay tappable at all.
            child: SizedBox(
              height: chartWakeHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: chartDenseColumnGutter,
                ),
                child: FractionallySizedBox(
                  heightFactor: fraction > 0
                      ? math.max(
                          widget.isSelected
                              ? chartSelectedBarMinHeightFraction
                              : chartBarMinHeightFraction,
                          fraction,
                        )
                      : 0,
                  // Column fraction plus a height-aware cap: bars dominate
                  // their gutters at every width but can never grow wider
                  // than the chart is tall. The tap column stays full-width.
                  widthFactor: chartBarWidthFraction,
                  alignment: Alignment.bottomCenter,
                  child: Center(
                    child: Container(
                      width: double.infinity,
                      height: double.infinity,
                      constraints: BoxConstraints(
                        maxWidth: tokens.spacing.step7,
                      ),
                      decoration: BoxDecoration(
                        color: barColor,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(tokens.radii.xs),
                        ),
                        // Ring = selection, everywhere on the page.
                        border: widget.isSelected
                            ? chartSelectionBorder(context)
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
