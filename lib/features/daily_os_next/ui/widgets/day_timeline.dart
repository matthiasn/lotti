import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/why_chip.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

/// Hour-by-hour timeline rendering of a [DraftPlan]. Read-only in
/// this milestone.
///
/// Layout:
/// - Left rail (50 px) with hour labels (6 AM → 10 PM).
/// - Content column with hour grid lines, energy bands behind, blocks
///   positioned absolutely by `start` / `end` minutes, and a now-line
///   if the current time falls inside the window.
/// - Drafted blocks gain a 1 px dashed outline so the whole frame
///   reads as provisional; committed blocks render solid.
class DayTimeline extends StatefulWidget {
  const DayTimeline({
    required this.draft,
    this.startHour = 6,
    this.endHour = 22,
    this.pxPerMinute = 1.0,
    this.clock,
    super.key,
  });

  final DraftPlan draft;
  final int startHour;
  final int endHour;
  final double pxPerMinute;

  /// Injected clock used by the now-line. Defaults to `DateTime.now`.
  /// Tests pass a fixed `DateTime` to render the line deterministically.
  final DateTime Function()? clock;

  @override
  State<DayTimeline> createState() => _DayTimelineState();
}

class _DayTimelineState extends State<DayTimeline> {
  Timer? _timer;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = (widget.clock ?? DateTime.now)();
    if (widget.clock == null) {
      // Re-render once per minute when using the real clock so the
      // now-line tracks time. Skipped under test (fixed clock).
      _scheduleNextMinute();
    }
  }

  void _scheduleNextMinute() {
    final now = DateTime.now();
    final delay = Duration(
      seconds: 60 - now.second,
      milliseconds: -now.millisecond,
    );
    _timer = Timer(delay, () {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
      _scheduleNextMinute();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final hours = widget.endHour - widget.startHour;
    final totalHeight = hours * 60 * widget.pxPerMinute;

    final windowStart = DateTime(
      widget.draft.dayDate.year,
      widget.draft.dayDate.month,
      widget.draft.dayDate.day,
      widget.startHour,
    );
    final windowEnd = windowStart.add(Duration(hours: hours));
    final nowInWindow =
        _now.isAfter(windowStart) &&
        _now.isBefore(windowEnd) &&
        _isSameDay(_now, widget.draft.dayDate);

    return SingleChildScrollView(
      child: SizedBox(
        height: totalHeight + tokens.spacing.step5,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: tokens.spacing.step3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HourRail(
                hours: hours,
                startHour: widget.startHour,
                pxPerMinute: widget.pxPerMinute,
                now: nowInWindow ? _now : null,
              ),
              Expanded(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _GridLines(
                      hours: hours,
                      pxPerMinute: widget.pxPerMinute,
                    ),
                    for (final band in widget.draft.bands)
                      _EnergyBandBox(
                        band: band,
                        windowStart: windowStart,
                        pxPerMinute: widget.pxPerMinute,
                      ),
                    for (final block in widget.draft.blocks)
                      _BlockPosition(
                        block: block,
                        windowStart: windowStart,
                        pxPerMinute: widget.pxPerMinute,
                      ),
                    if (nowInWindow)
                      _NowLine(
                        windowStart: windowStart,
                        now: _now,
                        pxPerMinute: widget.pxPerMinute,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _HourRail extends StatelessWidget {
  const _HourRail({
    required this.hours,
    required this.startHour,
    required this.pxPerMinute,
    required this.now,
  });

  final int hours;
  final int startHour;
  final double pxPerMinute;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return SizedBox(
      width: 50,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i <= hours; i++)
            Positioned(
              top: i * 60 * pxPerMinute - 6,
              right: 6,
              child: Text(
                _formatHour(startHour + i),
                style: tokens.typography.styles.others.caption.copyWith(
                  color: tokens.colors.text.lowEmphasis,
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
              ),
            ),
          if (now != null)
            Positioned(
              top:
                  (now!.hour - startHour) * 60 * pxPerMinute +
                  now!.minute * pxPerMinute -
                  9,
              right: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: tokens.colors.background.level01,
                  borderRadius: BorderRadius.circular(tokens.radii.xs),
                ),
                child: Text(
                  _formatNow(now!),
                  style: tokens.typography.styles.others.caption.copyWith(
                    color: tokens.colors.alert.error.defaultColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatHour(int hour24) {
    final h = hour24 % 24;
    final period = h < 12 ? 'AM' : 'PM';
    final hour12 = h % 12 == 0 ? 12 : h % 12;
    return '$hour12 $period';
  }

  String _formatNow(DateTime now) {
    final h = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final m = now.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _GridLines extends StatelessWidget {
  const _GridLines({required this.hours, required this.pxPerMinute});

  final int hours;
  final double pxPerMinute;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Positioned.fill(
      child: Stack(
        children: [
          for (var i = 0; i <= hours; i++)
            Positioned(
              top: i * 60 * pxPerMinute,
              left: 0,
              right: 0,
              child: Container(
                height: 1,
                color: tokens.colors.text.lowEmphasis.withValues(alpha: 0.10),
              ),
            ),
        ],
      ),
    );
  }
}

class _EnergyBandBox extends StatelessWidget {
  const _EnergyBandBox({
    required this.band,
    required this.windowStart,
    required this.pxPerMinute,
  });

  final EnergyBand band;
  final DateTime windowStart;
  final double pxPerMinute;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final top = band.start.difference(windowStart).inMinutes * pxPerMinute;
    final height = band.end.difference(band.start).inMinutes * pxPerMinute;

    final color = switch (band.level) {
      EnergyLevel.high => tokens.colors.interactive.enabled,
      EnergyLevel.low => tokens.colors.text.lowEmphasis,
      EnergyLevel.secondWind => tokens.colors.alert.info.defaultColor,
    };

    return Positioned(
      top: top,
      left: 4,
      right: 4,
      height: height,
      child: IgnorePointer(
        child: Semantics(
          label: band.label,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: 0.08),
                  color.withValues(alpha: 0.02),
                ],
              ),
              borderRadius: BorderRadius.circular(tokens.radii.m),
            ),
          ),
        ),
      ),
    );
  }
}

class _BlockPosition extends StatelessWidget {
  const _BlockPosition({
    required this.block,
    required this.windowStart,
    required this.pxPerMinute,
  });

  final TimeBlock block;
  final DateTime windowStart;
  final double pxPerMinute;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final top = block.start.difference(windowStart).inMinutes * pxPerMinute;
    final height = block.duration.inMinutes * pxPerMinute;
    return Positioned(
      top: top,
      left: tokens.spacing.step3,
      right: tokens.spacing.step3,
      height: height,
      child: DayBlock(block: block),
    );
  }
}

/// A single placed block on the Day timeline.
class DayBlock extends StatelessWidget {
  const DayBlock({required this.block, super.key});

  final TimeBlock block;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final category = _categoryColor(context);
    final isBuffer = block.type == TimeBlockType.buffer;
    final isDrafted = block.state == TimeBlockState.drafted;

    final fill = isBuffer
        ? Colors.transparent
        : category.withValues(alpha: 0.12);
    final leftStripeColor = isBuffer
        ? tokens.colors.text.lowEmphasis.withValues(alpha: 0.32)
        : category;

    return Container(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(tokens.radii.m),
        border: isDrafted
            ? Border.all(
                color: tokens.colors.text.lowEmphasis.withValues(alpha: 0.20),
              )
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 3,
            decoration: BoxDecoration(
              color: leftStripeColor,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(tokens.radii.m),
                bottomLeft: Radius.circular(tokens.radii.m),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: tokens.spacing.step3,
                vertical: tokens.spacing.step2,
              ),
              child: _BlockContent(block: block),
            ),
          ),
        ],
      ),
    );
  }

  Color _categoryColor(BuildContext context) {
    final hex = block.category.colorHex.replaceFirst('#', '');
    final value = int.tryParse(hex, radix: 16);
    if (value == null) return Colors.grey;
    return Color(value | 0xFF000000);
  }
}

class _BlockContent extends StatelessWidget {
  const _BlockContent({required this.block});

  final TimeBlock block;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final isBuffer = block.type == TimeBlockType.buffer;
    final isCal = block.type == TimeBlockType.cal;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Per the prototype: blocks shorter than 36 px collapse to the
        // title row only. The sub-title row would otherwise overflow
        // the block on 30-min cal events.
        final showSubtitle = !isBuffer && constraints.maxHeight >= 36;
        return ClipRect(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  if (isCal) ...[
                    Icon(
                      Icons.event_rounded,
                      size: 12,
                      color: tokens.colors.text.mediumEmphasis,
                    ),
                    SizedBox(width: tokens.spacing.step1),
                  ],
                  Expanded(
                    child: Text(
                      block.title,
                      style: tokens.typography.styles.body.bodySmall.copyWith(
                        color: tokens.colors.text.highEmphasis,
                        fontWeight: FontWeight.w600,
                        fontStyle: isBuffer
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (block.reason != null &&
                      block.type == TimeBlockType.ai) ...[
                    SizedBox(width: tokens.spacing.step2),
                    WhyChip(reason: block.reason!),
                  ],
                ],
              ),
              if (showSubtitle)
                Padding(
                  padding: EdgeInsets.only(top: tokens.spacing.step1),
                  child: Text(
                    _subTitle(block),
                    style: tokens.typography.styles.others.caption.copyWith(
                      color: tokens.colors.text.lowEmphasis,
                      fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  String _subTitle(TimeBlock block) {
    final parts = <String>[_formatRange(block)];
    if (block.sessionIndex != null && block.sessionTotal != null) {
      parts.add(
        'Session ${block.sessionIndex} of ${block.sessionTotal}',
      );
    }
    if (block.location != null) parts.add(block.location!);
    return parts.join(' · ');
  }

  String _formatRange(TimeBlock block) {
    return '${_clock(block.start)}–${_clock(block.end)}';
  }

  String _clock(DateTime t) {
    final h12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final m = t.minute.toString().padLeft(2, '0');
    final period = t.hour < 12 ? 'am' : 'pm';
    return t.minute == 0 ? '$h12$period' : '$h12:$m$period';
  }
}

class _NowLine extends StatelessWidget {
  const _NowLine({
    required this.windowStart,
    required this.now,
    required this.pxPerMinute,
  });

  final DateTime windowStart;
  final DateTime now;
  final double pxPerMinute;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final red = tokens.colors.alert.error.defaultColor;
    final top = now.difference(windowStart).inMinutes * pxPerMinute;
    return Positioned(
      top: top - 0.75,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: red, shape: BoxShape.circle),
            ),
            Expanded(
              child: Container(height: 1.5, color: red),
            ),
          ],
        ),
      ),
    );
  }
}
