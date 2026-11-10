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
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart' show numericBadgeFontFeatures;
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
/// Without a plan the sentence is her invitation to check in, the bar is the
/// recorded time in `interactive.enabled`, and the captions are the time
/// tracked and the sessions done.
///
/// A tap does what a tap on the companion does ([DayBriefingVoice]) while
/// she can speak; otherwise the strip is inert. [trailing] sits at the end of
/// the sentence's row, for a tab's own controls.
class DayBriefingStrip extends ConsumerStatefulWidget {
  const DayBriefingStrip({
    required this.draft,
    required this.hasPlan,
    this.actualBlocks = const [],
    this.trailing,
    super.key,
  });

  final DraftPlan draft;
  final bool hasPlan;

  /// The day's recorded sessions, for the strip of a day without a plan.
  final List<TimeBlock> actualBlocks;

  final Widget? trailing;

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
      color: tokens.colors.text.lowEmphasis,
      fontFeatures: numericBadgeFontFeatures,
    );
    final measure = widget.hasPlan
        ? _planMeasure(context, caption)
        : _trackedMeasure(context, caption);
    final radius = BorderRadius.circular(tokens.radii.l);
    final trailing = widget.trailing;

    final content = Padding(
      padding: EdgeInsets.all(tokens.spacing.cardPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                LottiIcons.aiSpark,
                size: tokens.typography.size.bodySmall,
                color: tokens.colors.aiCard.accent,
              ),
              SizedBox(width: tokens.spacing.step3),
              Expanded(
                child: Text(
                  composeDayHeadline(
                    messages,
                    briefing,
                    (moment) => formatClock(context, moment),
                  ),
                  style: tokens.typography.styles.body.bodySmall.copyWith(
                    color: tokens.colors.text.highEmphasis,
                  ),
                ),
              ),
              if (trailing != null) ...[
                SizedBox(width: tokens.spacing.step2),
                trailing,
              ],
            ],
          ),
          SizedBox(height: tokens.spacing.step4),
          measure.bar,
          SizedBox(height: tokens.spacing.step2),
          Row(
            children: [
              Expanded(child: measure.leading),
              ?measure.trailing,
            ],
          ),
        ],
      ),
    );

    return Material(
      type: MaterialType.transparency,
      child: Ink(
        decoration: BoxDecoration(
          color: tokens.colors.aiCard.background,
          borderRadius: radius,
          border: Border.all(color: tokens.colors.aiCard.border),
        ),
        child: voice == null
            ? content
            : Tooltip(
                message: voice.active
                    ? messages.dailyOsNextBriefingStopTooltip
                    : messages.dailyOsNextBriefingPlayTooltip,
                child: InkWell(
                  key: const Key('daily_os_briefing_strip_tap'),
                  onTap: voice.toggle,
                  borderRadius: radius,
                  child: content,
                ),
              ),
      ),
    );
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
        segments: [
          for (final t in totals)
            DayCapacitySegment(
              color: categoryColorFromHex(t.category.colorHex),
              minutes: t.minutes,
              label: '${t.category.name} · ${formatMinutesCompact(t.minutes)}',
            ),
        ],
      ),
      leading: Text(
        messages.dailyOsNextBriefingPlannedCaption(
          formatMinutesCompact(planned),
        ),
        style: caption,
      ),
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
    final tokens = context.designTokens;
    final messages = context.messages;
    final blocks = widget.actualBlocks;
    final tracked = formatMinutesCompact(blocks.totalMinutes);
    return (
      bar: DayCapacityBar(
        capacityMinutes: widget.draft.capacityMinutes,
        segments: [
          DayCapacitySegment(
            color: tokens.colors.interactive.enabled,
            minutes: blocks.totalMinutes,
            label: messages.dailyOsNextBriefingTrackedCaption(tracked),
          ),
        ],
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
typedef _Measure = ({Widget bar, Widget leading, Widget? trailing});
