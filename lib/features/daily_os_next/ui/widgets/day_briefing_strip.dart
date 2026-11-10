import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/logic/day_briefing.dart';
import 'package:lotti/features/daily_os_next/logic/day_category_totals.dart';
import 'package:lotti/features/daily_os_next/ui/category_color.dart';
import 'package:lotti/features/daily_os_next/ui/time_format.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_briefing_companion.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_capacity_bar.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_row_scaffold.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// The day in one sentence and one line, under the Day page's header on
/// every tab: the page's one violet (`aiCard`) surface.
///
/// The sentence is the opening of the companion's spoken briefing
/// ([composeDayHeadline]: how many blocks, what is next), so the strip and
/// her voice never disagree; it is rewritten when the next block starts. Under
/// it, the [DayCapacityBar] — the plan's minutes per category, in category
/// colour, against the day's capacity — and two captions: the minutes
/// planned, and what is free or, in `alert.error` ink, how far over the day
/// is. Planned minutes come from [categoryTotalsFor], the same figures the
/// bar draws, so the numbers and the line cannot tell different stories.
///
/// Under the captions, a legend of the largest categories (at most three)
/// names the bar's colours, so they can be read without hovering.
///
/// Without a plan the sentence is her invitation to check in, the bar is the
/// recorded time in a quiet neutral, and the captions are the time tracked and
/// the sessions done.
///
/// While the companion can speak, a play button at the end of the sentence
/// does what a tap on her does ([DayBriefingVoice]) — it plays her briefing,
/// and stops it while she speaks. Otherwise there is no button and nothing
/// on the strip is tappable.
class DayBriefingStrip extends ConsumerStatefulWidget {
  const DayBriefingStrip({
    required this.draft,
    required this.hasPlan,
    this.actualBlocks = const [],
    this.dense = false,
    super.key,
  });

  /// Only the sentence and the line — no captions, no legend — where the
  /// strip stays pinned over a tab that needs the room (the timeline on a
  /// phone).
  final bool dense;

  final DraftPlan draft;
  final bool hasPlan;

  /// The day's recorded sessions, for the strip of a day without a plan.
  final List<TimeBlock> actualBlocks;

  @override
  ConsumerState<DayBriefingStrip> createState() => _DayBriefingStripState();
}

class _DayBriefingStripState extends ConsumerState<DayBriefingStrip> {
  Timer? _nextStarts;

  @override
  void dispose() {
    _nextStarts?.cancel();
    super.dispose();
  }

  /// Rebuilds once [next] has started, so the sentence moves on to the block
  /// after it rather than naming one already under way.
  void _rewriteWhenStarted(TimeBlock? next, DateTime now) {
    _nextStarts?.cancel();
    _nextStarts = next == null
        ? null
        : Timer(next.start.difference(now), () {
            if (mounted) setState(() {});
          });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final now = clock.now();
    final briefing = DayBriefing.of(
      draft: widget.draft,
      hasPlan: widget.hasPlan,
      now: now,
    );
    _rewriteWhenStarted(widget.hasPlan ? briefing.next : null, now);
    final voice = DayBriefingVoice.watch(
      context,
      ref,
      draft: widget.draft,
      hasPlan: widget.hasPlan,
    );
    final caption = tokens.typography.styles.others.caption.copyWith(
      color: tokens.colors.text.mediumEmphasis,
      fontFeatures: dayFigures,
    );
    final measure = widget.hasPlan
        ? _planMeasure(context, caption)
        : _trackedMeasure(context, caption);

    final content = Padding(
      padding: EdgeInsets.all(tokens.spacing.cardPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // On the sentence's first line, however many lines it takes.
              Padding(
                padding: EdgeInsets.only(
                  top:
                      (MediaQuery.textScalerOf(
                            context,
                          ).scale(tokens.typography.lineHeight.bodySmall) -
                          tokens.typography.size.bodySmall) /
                      2,
                ),
                child: Icon(
                  LottiIcons.aiSpark,
                  size: tokens.typography.size.bodySmall,
                  color: tokens.colors.aiCard.accent,
                ),
              ),
              SizedBox(width: tokens.spacing.step3),
              Expanded(
                child: Text(
                  composeDayHeadline(
                    messages,
                    briefing,
                    // A no-break space keeps "4:15 PM" on one line.
                    (moment) =>
                        formatClock(context, moment).replaceAll(' ', '\u00A0'),
                  ),
                  style: tokens.typography.styles.body.bodySmall.copyWith(
                    color: tokens.colors.text.highEmphasis,
                  ),
                ),
              ),
              if (voice != null) ...[
                SizedBox(width: tokens.spacing.step2),
                IconButton(
                  key: const Key('daily_os_briefing_play'),
                  tooltip: voice.active
                      ? messages.dailyOsNextBriefingStopTooltip
                      : messages.dailyOsNextBriefingPlayTooltip,
                  onPressed: voice.toggle,
                  icon: Icon(
                    voice.active ? LottiIcons.stop : LottiIcons.play,
                    size: tokens.typography.size.subtitle1,
                    color: tokens.colors.aiCard.accent,
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: tokens.spacing.step4),
          measure.bar,
          if (!widget.dense) ...[
            SizedBox(height: tokens.spacing.step2),
            Row(
              children: [
                Expanded(child: measure.leading),
                ?measure.trailing,
              ],
            ),
          ],
          if (!widget.dense && measure.legend.isNotEmpty) ...[
            SizedBox(height: tokens.spacing.step2),
            _CapacityLegend(totals: measure.legend),
          ],
        ],
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.colors.aiCard.background,
        borderRadius: BorderRadius.circular(tokens.radii.l),
        border: Border.all(color: tokens.colors.aiCard.border),
      ),
      child: content,
    );
  }

  /// The bar's segments for [totals], one per category in its colour. On a
  /// phone, the categories past the largest [_compactLegendEntries] fold into
  /// one neutral segment — the legend's "+N more" — so every colour on the
  /// bar is one the legend names.
  List<DayCapacitySegment> _segments(
    BuildContext context,
    List<DayCategoryTotal> totals,
  ) {
    final folds = _legendFolds(context, totals);
    final named = folds ? totals.take(_compactLegendEntries) : totals;
    final restMinutes = folds
        ? totals
              .skip(_compactLegendEntries)
              .fold<int>(0, (sum, t) => sum + t.minutes)
        : 0;
    return [
      for (final t in named)
        DayCapacitySegment(
          color: categoryColorFromHex(t.category.colorHex),
          minutes: t.minutes,
          label: '${t.category.name} · ${formatMinutesCompact(t.minutes)}',
        ),
      if (folds)
        DayCapacitySegment(
          color: context.designTokens.colors.decorative.level03,
          minutes: restMinutes,
          label: context.messages.dailyOsNextBriefingMoreCategories(
            totals.length - _compactLegendEntries,
            formatMinutesCompact(restMinutes),
          ),
        ),
    ];
  }

  _Measure _planMeasure(BuildContext context, TextStyle caption) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final totals = categoryTotalsFor(widget.draft);
    final planned = totals.fold<int>(0, (sum, t) => sum + t.minutes);
    final capacity = widget.draft.capacityMinutes;
    final remaining = capacity - planned;
    final breakdown = [
      for (final t in totals)
        '${t.category.name} ${formatMinutesCompact(t.minutes)}',
    ].join(', ');
    return (
      bar: DayCapacityBar(
        capacityMinutes: capacity,
        semanticsLabel: totals.isEmpty
            ? null
            : messages.dailyOsNextBriefingCapacityLabel(breakdown),
        segments: _segments(context, totals),
      ),
      leading: Text(
        messages.dailyOsNextBriefingPlannedCaption(
          formatMinutesCompact(planned),
        ),
        style: caption,
      ),
      legend: totals,
      // A day without a capacity has nothing to be free or over against.
      trailing: capacity <= 0
          ? null
          : remaining < 0
          ? Text(
              messages.dailyOsNextBriefingOverCaption(
                formatMinutesCompact(-remaining),
              ),
              style: caption.copyWith(color: tokens.colors.alert.error.ink),
            )
          : Text(
              messages.dailyOsNextBriefingFreeCaption(
                formatMinutesCompact(remaining),
              ),
              style: caption,
            ),
    );
  }

  _Measure _trackedMeasure(BuildContext context, TextStyle caption) {
    final messages = context.messages;
    final blocks = widget.actualBlocks;
    final tracked = formatMinutesCompact(blocks.totalMinutes);
    final totals = recordedTotalsFor(blocks);
    return (
      legend: totals,
      // No capacity to measure against without a plan: the recorded time is
      // one line of its categories — the plan's own encoding — not progress
      // towards a goal.
      bar: DayCapacityBar(
        capacityMinutes: 0,
        segments: _segments(context, totals),
      ),
      leading: Text(
        messages.dailyOsNextBriefingTrackedCaption(tracked),
        style: caption,
      ),
      trailing: Text(
        messages.dailyOsNextBriefingDoneCaption(blocks.completedCount),
        style: caption,
      ),
    );
  }
}

/// The strip's measure of the day: the bar and the captions either side of
/// the row beneath it.
typedef _Measure = ({
  Widget bar,
  Widget leading,
  Widget? trailing,
  List<DayCategoryTotal> legend,
});

/// How many categories the legend names on a phone before it sums the rest
/// up as "+N more"; a wide pane names them all.
const int _compactLegendEntries = 2;

/// Whether [totals] fold their tail into "+N more": on a phone, when more
/// than one category would be folded.
bool _legendFolds(BuildContext context, List<DayCategoryTotal> totals) =>
    !isDesktopLayout(context) && totals.length > _compactLegendEntries + 1;

/// The bar's categories, each as its dot, name and minutes, so every colour
/// on the bar is named: all of them on a wide pane, the largest two and
/// "+N more" with their time together on a phone.
class _CapacityLegend extends StatelessWidget {
  const _CapacityLegend({required this.totals});

  final List<DayCategoryTotal> totals;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final caption = tokens.typography.styles.others.caption.copyWith(
      color: tokens.colors.text.lowEmphasis,
      fontFeatures: dayFigures,
    );
    final folds = _legendFolds(context, totals);
    final named = folds ? totals.take(_compactLegendEntries) : totals;
    final rest = totals.skip(_compactLegendEntries);
    final entries = [
      for (final total in named)
        (
          color: categoryColorFromHex(total.category.colorHex),
          text:
              '${total.category.name} '
              '${formatMinutesCompact(total.minutes)}',
        ),
      if (folds)
        (
          color: tokens.colors.decorative.level03,
          text: context.messages.dailyOsNextBriefingMoreCategories(
            rest.length,
            formatMinutesCompact(
              rest.fold<int>(0, (sum, t) => sum + t.minutes),
            ),
          ),
        ),
    ];
    Widget entry(({Color color, String text}) entry) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(
          dimension: tokens.spacing.step2,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: entry.color,
              shape: BoxShape.circle,
            ),
          ),
        ),
        SizedBox(width: tokens.spacing.step2),
        Flexible(
          child: Text(
            entry.text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: caption,
          ),
        ),
      ],
    );
    return ExcludeSemantics(
      // The bar already reads every category out.
      // One line on a phone, its entries shortening rather than wrapping;
      // a wide pane wraps them if it ever must.
      child: folds
          ? Row(
              children: [
                for (final (i, e) in entries.indexed) ...[
                  if (i > 0) SizedBox(width: tokens.spacing.step4),
                  Flexible(child: entry(e)),
                ],
              ],
            )
          : Wrap(
              spacing: tokens.spacing.step4,
              runSpacing: tokens.spacing.step1,
              children: entries.map(entry).toList(),
            ),
    );
  }
}
