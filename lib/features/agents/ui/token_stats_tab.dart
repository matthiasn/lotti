import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/agents/model/daily_token_usage.dart';
import 'package:lotti/features/agents/state/agent_pending_wake_providers.dart';
import 'package:lotti/features/agents/state/token_stats_providers.dart';
import 'package:lotti/features/agents/ui/token_stats_tab_chart.dart';
import 'package:lotti/features/agents/ui/token_stats_tab_daily_section.dart';
import 'package:lotti/features/agents/ui/token_stats_tab_per_model_section.dart';
import 'package:lotti/features/agents/ui/wake_activity_chart.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/ds_surface_elevation.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/nav_bar/design_system_bottom_navigation_bar.dart';
import 'package:lotti/widgets/settings/settings_page_layout.dart';

/// Stats tab showing token usage in an iOS battery-usage-inspired layout.
///
/// Sections, each a quiet heading over a `dsCardSurface` card on the
/// `dsPageSurface` canvas, in answer-first order:
/// 1. Daily Usage hero — period total, comparison card, interactive chart
/// 2. Per-model compact charts (hidden when only one model is in play)
/// 3. Per-template source breakdown list
/// 4. Wake activity chart (hidden when the last 24h had no wakes)
///
/// The tab owns the day-range (7D/30D) and the day selection shared by
/// the hero chart and the per-model cards; see [DailyUsageSection]. All
/// sections share the settings content insets (one rail, desktop
/// max-width) applied at the [ListView] level.
class TokenStatsTab extends ConsumerStatefulWidget {
  const TokenStatsTab({super.key});

  @override
  ConsumerState<TokenStatsTab> createState() => _TokenStatsTabState();
}

class _TokenStatsTabState extends ConsumerState<TokenStatsTab> {
  int _days = 7;

  /// Last resolved values per provider, held across the 7D/30D switch (and,
  /// for the breakdown, across day retargets) so the established page never
  /// collapses to loading shells while the new value resolves
  /// (stale-while-revalidate; the swap is a frame or two).
  List<DailyTokenUsage>? _lastDaily;
  TokenUsageComparison? _lastComparison;
  Map<String, List<DailyTokenUsage>>? _lastByModel;
  List<TokenSourceBreakdown>? _lastBreakdown;

  /// [current] when it has data; otherwise the last resolved value, so a
  /// range switch repaints in place instead of deflating the layout.
  AsyncValue<T> _withStale<T>(AsyncValue<T> current, T? last) =>
      current.hasValue || last == null ? current : AsyncValue.data(last);

  /// Day selection shared by the hero chart and every per-model card, so
  /// picking a day anywhere focuses the whole page on it. Keyed by
  /// calendar date, not list index, so a 7D/30D switch (or a stale frame
  /// during one) keeps the same day ringed; a date outside the new window
  /// falls back to today (the last bar). A tap always retargets and never
  /// deselects, so re-tapping the bar you are reading cannot destroy the
  /// detail rows.
  DateTime? _selectedDate;

  int _selectedIndexFor(List<DailyTokenUsage>? days) {
    if (days == null || days.isEmpty) return _days - 1;
    if (_selectedDate != null) {
      final index = days.indexWhere((d) => d.date == _selectedDate);
      if (index >= 0) return index;
    }
    return days.length - 1;
  }

  /// Whether the wake-activity section will render anything — mirrors
  /// [WakeActivityChart]'s own hide condition so the section gap above it
  /// disappears together with the card.
  bool _hasWakeActivity(WidgetRef ref) {
    final buckets = ref.watch(hourlyWakeActivityProvider).value;
    return buckets != null && buckets.any((b) => b.count > 0);
  }

  // The selection is date-keyed, so the range toggle needs no index
  // remapping: the same calendar day stays selected in the new window
  // and _selectedIndexFor falls back to today if it dropped out.
  void _onDaysChanged(int days) => setState(() => _days = days);

  @override
  Widget build(BuildContext context) {
    final dailyAsync = _withStale(
      ref.watch(dailyTokenUsageProvider(_days)),
      _lastDaily,
    );
    final comparisonAsync = _withStale(
      ref.watch(tokenUsageComparisonProvider(_days)),
      _lastComparison,
    );
    final byModelAsync = _withStale(
      ref.watch(dailyTokenUsageByModelProvider(_days)),
      _lastByModel,
    );
    _lastDaily = dailyAsync.value ?? _lastDaily;
    _lastComparison = comparisonAsync.value ?? _lastComparison;
    _lastByModel = byModelAsync.value ?? _lastByModel;
    final tokens = context.designTokens;
    final selectedIndex = _selectedIndexFor(dailyAsync.value);
    final now = clock.now().toLocal();
    final todayMidnight = DateTime(now.year, now.month, now.day);
    // The day the whole page is focused on — resolved from the daily list
    // so it can only ever be a day a chart actually shows. Its today-ness
    // comes from the model flag, the same source the bars colour by.
    final daysList = dailyAsync.value;
    final selectedDayUsage =
        daysList != null &&
            daysList.isNotEmpty &&
            selectedIndex < daysList.length
        ? daysList[selectedIndex]
        : null;
    final selectedDay = selectedDayUsage?.date ?? todayMidnight;
    final selectedIsToday = selectedDayUsage?.isToday ?? true;
    // Today's calendar date as the DATA sees it — the list's isToday
    // entry, falling back to the clock only before the list resolves.
    final todayDate =
        daysList?.where((d) => d.isToday).firstOrNull?.date ?? todayMidnight;
    // The breakdown rides the same selection as every chart. Stale-held
    // across day retargets, so tapping a bar repaints the rows in place.
    final breakdownAsync = _withStale(
      ref.watch(tokenSourceBreakdownProvider(selectedDay)),
      _lastBreakdown,
    );
    _lastBreakdown = breakdownAsync.value ?? _lastBreakdown;
    // Today's breakdown feeds the hero notice regardless of the selected
    // day: the warning at the top must not vanish because the reader is
    // studying Wednesday. Same provider instance as the section when
    // today is selected, so this costs nothing in the common case.
    final todayBreakdown = ref
        .watch(tokenSourceBreakdownProvider(todayDate))
        .value;
    final highUsageSource = todayBreakdown
        ?.where((s) => s.isHighUsage)
        .firstOrNull;
    void selectDayAt(int index) {
      final list = dailyAsync.value;
      if (list == null || index < 0 || index >= list.length) return;
      setState(() => _selectedDate = list[index].date);
    }

    // Cards hug their content on wide panes: each section (heading row +
    // card) is capped to its chart's content width plus the card insets,
    // start-anchored on the shared left rail — no dead card slabs, and no
    // caption or value column floating far from what it describes. The
    // source list takes the hero's rail so its name→value measure matches
    // the card above it.
    Widget rail(double contentMaxWidth, Widget child) => Align(
      alignment: AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: contentMaxWidth + 2 * tokens.spacing.cardPadding,
        ),
        child: child,
      ),
    );
    final heroRail = chartContentMaxWidth(
      context,
      columnCount: _days,
      compact: false,
    );

    // The shared settings content insets give every section one left rail,
    // and on wide desktop panes they centre the column at the settings
    // max-width instead of letting bars stretch into full-width slabs.
    return LayoutBuilder(
      builder: (context, constraints) {
        final insets = SettingsPageLayout.contentInsets(constraints.maxWidth);
        return ListView(
          padding: EdgeInsetsDirectional.only(
            start: insets.start,
            end: insets.end,
            top: tokens.spacing.step4,
            bottom: math.max(
              tokens.spacing.step10,
              DesignSystemBottomNavigationBar.occupiedHeight(context),
            ),
          ),
          children: [
            // Hero first — the page's answer. Then what (models), who
            // (sources), and the when diagnostic (wake activity) last.
            // Gaps ride with their section so a self-hiding section
            // (single model, no wakes) does not leave a double gap.
            rail(
              heroRail,
              DailyUsageSection(
                days: _days,
                dailyAsync: dailyAsync,
                comparisonAsync: comparisonAsync,
                onDaysChanged: _onDaysChanged,
                selectedIndex: selectedIndex,
                onBarTap: selectDayAt,
                onResetToToday: () => setState(() => _selectedDate = null),
                highUsageSource: highUsageSource,
              ),
            ),
            if ((byModelAsync.value?.length ?? 0) > 1) ...[
              SizedBox(height: tokens.spacing.sectionGap),
              rail(
                chartContentMaxWidth(
                  context,
                  columnCount: _days,
                  compact: true,
                ),
                PerModelChartsSection(
                  byModelAsync: byModelAsync,
                  days: _days,
                  selectedIndex: selectedIndex,
                  // Same flag the hero resolves its accent from, so today's
                  // bar can never be amber above and teal below.
                  todayIsAboveAverage:
                      comparisonAsync.value?.isAboveAverage ?? false,
                  onDayTap: (date) => setState(() => _selectedDate = date),
                ),
              ),
            ],
            SizedBox(height: tokens.spacing.sectionGap),
            rail(
              heroRail,
              _SourceBreakdownSection(
                breakdownAsync: breakdownAsync,
                day: selectedDay,
                isToday: selectedIsToday,
              ),
            ),
            if (_hasWakeActivity(ref)) ...[
              SizedBox(height: tokens.spacing.sectionGap),
              // Clamped to the hero rail: the page keeps one right-edge
              // family on desktop instead of ending on its widest card.
              // The chart's 24 columns just share the narrower width, as
              // they already do on phones.
              rail(
                math.min(
                  heroRail,
                  chartContentMaxWidth(
                    context,
                    columnCount: 24,
                    compact: true,
                  ),
                ),
                const WakeActivityChart(),
              ),
            ],
          ],
        );
      },
    );
  }
}

// ── Daily Usage Section ─────────────────────────────────────────────────────

class _SourceBreakdownSection extends StatelessWidget {
  const _SourceBreakdownSection({
    required this.breakdownAsync,
    required this.day,
    required this.isToday,
  });

  final AsyncValue<List<TokenSourceBreakdown>> breakdownAsync;

  /// The page-wide selected day this breakdown covers — echoed in the
  /// caption so the section visibly rides the same selection as the
  /// charts above it.
  final DateTime day;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final breakdowns = breakdownAsync.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The caption names the day the rows cover — "Today" or the
        // selected date — so the section visibly rides the page-wide
        // selection.
        StatsSectionHeading(
          title: context.messages.agentStatsSourceActivityHeading,
          caption: isToday
              ? context.messages.agentStatsSourceScopeLabel
              : context.messages.agentStatsSourceScopeDayLabel(
                  DateFormat.MMMEd().format(day),
                ),
        ),
        SizedBox(height: tokens.spacing.step3),
        // The rows live in a card like every other section, so the page
        // speaks one heading-over-card grammar end to end.
        Container(
          decoration: BoxDecoration(
            color: dsCardSurface(context),
            borderRadius: BorderRadius.circular(tokens.radii.sectionCards),
          ),
          // step3 + the tiles' own step3/step2 insets sum to cardPadding
          // on both axes, so the rows' text sits on the same interior
          // grid as every other card's content.
          padding: EdgeInsets.symmetric(
            vertical: tokens.spacing.step3,
            horizontal: tokens.spacing.step4,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (breakdowns == null)
                // Reserve one real tile's height (icon chip + its row
                // padding) so the card doesn't grow when rows resolve.
                SizedBox(
                  height: tokens.spacing.step9 + tokens.spacing.step3 * 2,
                )
              else if (breakdowns.isEmpty)
                Text(
                  isToday
                      ? context.messages.agentStatsNoUsage
                      : context.messages.agentStatsSourceEmptyDay,
                  style: tokens.typography.styles.body.bodySmall.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                )
              else
                for (final source in breakdowns)
                  _SourceListTile(source: source, isToday: isToday),
            ],
          ),
        ),
      ],
    );
  }
}

class _SourceListTile extends StatelessWidget {
  const _SourceListTile({required this.source, required this.isToday});

  final TokenSourceBreakdown source;

  /// Chooses the warning's register: "today" when the section covers
  /// today, day-neutral wording when a past day is selected.
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    // One shared expression with every other amber text on the page.
    final warningColor = warningTextColor(context);

    return InkWell(
      onTap: () => beamToNamed(
        '/settings/agents/${source.isTemplate ? 'templates' : 'instances'}/${source.templateId}',
      ),
      borderRadius: BorderRadius.circular(tokens.radii.m),
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: tokens.spacing.step3,
          horizontal: tokens.spacing.step2,
        ),
        child: Row(
          children: [
            // Neutral chip from the background surface ramp — the page's
            // only accents stay the interactive teal and the warning
            // amber, so a coloured chip here would add a third voice.
            Container(
              width: tokens.spacing.step9,
              height: tokens.spacing.step9,
              decoration: BoxDecoration(
                color: tokens.colors.background.level03,
                borderRadius: BorderRadius.circular(tokens.radii.s),
              ),
              child: Icon(
                Icons.smart_toy_outlined,
                color: context.colorScheme.onSurfaceVariant,
                size: tokens.spacing.step6,
              ),
            ),
            SizedBox(width: tokens.spacing.step3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    source.displayName,
                    style: tokens.typography.styles.subtitle.subtitle2,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: tokens.spacing.step1),
                  Text(
                    _activityDescription(context, source),
                    style: tokens.typography.styles.body.bodySmall.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // The flag speaks: words instead of a bare triangle, so
                  // "something is wrong" always comes with what and how
                  // much. Demoted to a caption chip — a dot plus a short
                  // line — because the hero already carries the page's
                  // full-voice warning; here it only marks which row.
                  if (source.isHighUsage) ...[
                    SizedBox(height: tokens.spacing.step1),
                    Row(
                      children: [
                        Container(
                          width: tokens.spacing.step2,
                          height: tokens.spacing.step2,
                          decoration: BoxDecoration(
                            color: warningColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: tokens.spacing.step2),
                        Flexible(
                          child: Text(
                            isToday
                                ? context.messages.agentStatsSourceHighUsage
                                : context.messages.agentStatsSourceHighUsageDay,
                            style: tokens.typography.styles.others.caption
                                .copyWith(color: warningColor),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${source.percentage.round()}%',
                  style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                    color: context.colorScheme.onSurface,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                SizedBox(height: tokens.spacing.step1),
                Text(
                  formatTokenCount(source.totalTokens),
                  style: tokens.typography.styles.others.caption.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            SizedBox(width: tokens.spacing.step2),
            Icon(
              Icons.chevron_right,
              color: context.colorScheme.onSurfaceVariant,
              size: tokens.spacing.step5,
            ),
          ],
        ),
      ),
    );
  }

  String _activityDescription(
    BuildContext context,
    TokenSourceBreakdown source,
  ) {
    // Wake count leads: it is the page's primary unit, and leading with it
    // keeps it readable even if a long translation ever ellipsizes the
    // line's tail.
    final parts = <String>[
      context.messages.agentStatsSourceWakes(source.wakeCount),
      if (source.totalDuration > Duration.zero)
        context.messages.agentStatsSourceActiveFor(
          _formatDuration(source.totalDuration),
        ),
    ];
    return parts.join(' \u00b7 ');
  }
}

// ── Dashed Line Painter ─────────────────────────────────────────────────────

/// Paints a dashed horizontal line at [fraction] of the canvas height
/// (measured from the bottom), directly on the canvas with no layout overhead.
class AverageDashedLinePainter extends CustomPainter {
  AverageDashedLinePainter({
    required this.fraction,
    required this.color,
    this.casingColor,
  });

  final double fraction;
  final Color color;

  /// Optional surface-coloured stroke painted under the dashes so the
  /// reference line keeps its contrast where it crosses bars — its most
  /// important pixels.
  final Color? casingColor;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * (1 - fraction);
    if (casingColor != null) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        Paint()
          ..color = casingColor!
          ..strokeWidth = 3,
      );
    }

    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    const dashWidth = 4.0;
    const dashSpace = 3.0;
    var startX = 0.0;

    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, y),
        Offset(math.min(startX + dashWidth, size.width), y),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(AverageDashedLinePainter oldDelegate) =>
      fraction != oldDelegate.fraction ||
      color != oldDelegate.color ||
      casingColor != oldDelegate.casingColor;
}

// ── Helpers ─────────────────────────────────────────────────────────────────

String currentTimeString() => DateFormat.Hm().format(clock.now().toLocal());

final NumberFormat _compactFormat = NumberFormat.compact();

String formatTokenCount(int tokens) => _compactFormat.format(tokens);

String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours > 0) {
    return '${hours}h ${minutes}m';
  }
  return '${minutes}m';
}
