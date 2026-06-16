import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/ui/category_color.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_timeline_folding.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/editable_title.dart';
import 'package:lotti/features/design_system/components/ds_dashed_border.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/features/tasks/state/task_focus_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/consts.dart';

/// Positions a [DayBlock] absolutely within the timeline stack. Converts the
/// block's start/end through the [foldingState] (which collapses idle gaps) to
/// pixel offsets, then carves a small inter-block gap out of tall enough blocks
/// so adjacent blocks read as distinct without overlapping.
class BlockPosition extends StatelessWidget {
  const BlockPosition({
    required this.block,
    required this.windowStart,
    required this.foldingState,
    required this.pxPerMinute,
    required this.tracked,
    required this.onRename,
    super.key,
  });

  final TimeBlock block;
  final DateTime windowStart;
  final TimelineFoldingState foldingState;
  final double pxPerMinute;
  final bool tracked;
  final ValueChanged<String>? onRename;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final top = foldingState.positionForDate(
      block.start,
      windowStart: windowStart,
      pxPerMinute: pxPerMinute,
    );
    final end = foldingState.positionForDate(
      block.end,
      windowStart: windowStart,
      pxPerMinute: pxPerMinute,
    );
    final rawHeight = math.max(0, end - top).toDouble();
    final minimumReadableHeight =
        tokens.typography.lineHeight.bodySmall + tokens.spacing.step2 * 2;
    final preferredGap = tokens.spacing.step1;
    final blockGap = rawHeight > minimumReadableHeight + preferredGap
        ? math.min(preferredGap, rawHeight / 3)
        : 0.0;
    final height = math.max(0, rawHeight - blockGap).toDouble();
    return Positioned(
      top: top + blockGap / 2,
      left: tokens.spacing.step3,
      right: tokens.spacing.step3,
      height: height,
      child: DayBlock(
        key: Key('daily_os_day_block_${block.id}'),
        block: block,
        tracked: tracked,
        onRename: onRename,
      ),
    );
  }
}

/// A single placed block on the Day timeline.
///
/// Paint-by-numbers contract: PLANNED blocks are the faint outline waiting
/// to be filled in — a whisper of category color (5% fill, tinted dashed
/// outline while drafted) — and [tracked] blocks (recorded sessions) are
/// the filled-in paint: full-strength category stripe, an 18% category
/// fill, a green check when done, and a mono time range. Doing is what
/// makes a block alive, so the recorded lane carries the color.
class DayBlock extends ConsumerWidget {
  const DayBlock({
    required this.block,
    this.tracked = false,
    this.onRename,
    super.key,
  });

  final TimeBlock block;
  final bool tracked;

  /// Inline rename for standalone blocks. Ignored for task-linked,
  /// calendar, buffer, and tracked blocks.
  final ValueChanged<String>? onRename;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final category = _categoryColor();
    final isBuffer = block.type == TimeBlockType.buffer;
    final isDrafted = !tracked && block.state == TimeBlockState.drafted;
    final taskId = block.taskId?.trim();
    final onTap = taskId == null || taskId.isEmpty
        ? null
        : () {
            // Tracked blocks project a real time recording. Publish the
            // focus intent before navigating so the task detail page
            // scrolls to (and highlights) that exact recording, matching
            // the old calendar behaviour. Drafted/agent blocks have no
            // backing entry, so they just open the task at the top.
            final entryId = block.trackedEntryId;
            if (entryId != null) {
              publishTaskFocus(
                taskId: taskId,
                entryId: entryId,
                ref: ref,
                alignment: kDefaultScrollAlignment,
              );
            }
            beamToNamed('/tasks/$taskId');
          };

    final isLight = Theme.of(context).brightness == Brightness.light;
    final canvas = tokens.colors.background.level01;
    final fill = isBuffer
        ? Colors.transparent
        : Color.alphaBlend(
            category.withValues(
              alpha: timelineBlockTintAlpha(
                tracked: tracked,
                isLight: isLight,
              ),
            ),
            canvas,
          );
    final leftStripeColor = isBuffer
        ? tokens.colors.text.lowEmphasis.withValues(alpha: 0.32)
        : tracked
        ? category
        : category.withValues(alpha: kTimelinePlannedAccentAlpha);

    final borderRadius = BorderRadius.circular(tokens.radii.m);
    final card = Ink(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: borderRadius,
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
              child: _BlockContent(
                block: block,
                tracked: tracked,
                onRename: onRename,
              ),
            ),
          ),
        ],
      ),
    );

    // Drafted blocks read provisional via a dashed outline; committed
    // and tracked blocks read solid.
    final outlined = isDrafted
        ? DsDashedBorder(
            color: category.withValues(alpha: kTimelinePlannedAccentAlpha),
            radius: tokens.radii.m,
            child: card,
          )
        : card;

    // Recorded-vs-planned is otherwise purely chromatic; the semantics
    // label keeps the distinction for screen readers, and gives micro
    // blocks (whose visual content collapses to fill+stripe) an
    // accessible name at all.
    final semanticsLabel = [
      block.title,
      '${_clock(block.start)}–${_clock(block.end)}',
      if (tracked)
        context.messages.dailyOsNextTimelineTracked
      else
        context.messages.dailyOsNextTimelinePlanned,
    ].join(', ');

    if (onTap == null) {
      return Semantics(
        label: semanticsLabel,
        child: Material(
          type: MaterialType.transparency,
          child: outlined,
        ),
      );
    }

    return Semantics(
      button: true,
      label: semanticsLabel,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          child: outlined,
        ),
      ),
    );
  }

  Color _categoryColor() => categoryColorFromHex(block.category.colorHex);
}

String _clock(DateTime t) {
  final h = t.hour.toString().padLeft(2, '0');
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

class _BlockContent extends StatelessWidget {
  const _BlockContent({
    required this.block,
    required this.tracked,
    required this.onRename,
  });

  final TimeBlock block;
  final bool tracked;
  final ValueChanged<String>? onRename;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final isBuffer = block.type == TimeBlockType.buffer;
    final isCal = block.type == TimeBlockType.cal;
    final isTaskLinked =
        block.taskId != null && block.taskId!.trim().isNotEmpty;
    final isDone = block.state == TimeBlockState.completed;
    // Standalone ai/manual placements are click-to-edit; everything
    // else (cal events, buffers, task-linked, tracked) is read-only.
    final editable =
        !tracked && !isBuffer && !isCal && !isTaskLinked && onRename != null;
    // Recorded titles read at full strength; planned ones recede a step —
    // the plan is the sketch, the recording is the ink.
    final titleStyle = tokens.typography.styles.body.bodySmall.copyWith(
      color: tracked
          ? tokens.colors.text.highEmphasis
          : tokens.colors.text.mediumEmphasis,
      fontWeight: FontWeight.w600,
      fontStyle: isBuffer ? FontStyle.italic : FontStyle.normal,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Height-tiered content policy: never let text shear mid-glyph.
        // Micro blocks (< ~3/4 caption line) show fill + stripe only;
        // short blocks a single fitted title line; the subtitle joins
        // from ~44px; two title lines from 64px. ALL thresholds use
        // SCALED extents — at accessibility text sizes the text box
        // grows, so the tier a block qualifies for must grow with it.
        final textScaler = MediaQuery.textScalerOf(context);
        final lineHeight = textScaler.scale(
          tokens.typography.lineHeight.bodySmall,
        );
        final unscaledSliverLine = tokens.typography.lineHeight.caption;
        final sliverLineHeight = textScaler.scale(unscaledSliverLine);
        if (constraints.maxHeight < sliverLineHeight * 0.75) {
          // Even a fitted caption line would be illegibly small — fill +
          // stripe only (the Semantics label on DayBlock still carries
          // the title).
          return const SizedBox.shrink();
        }
        if (constraints.maxHeight < lineHeight + 2) {
          // Sliver tier: one caption line so short recorded sessions
          // (the unplanned incident!) stay information, not just color.
          // The line is FITTED to the available height via a clamped
          // linear scaler — a 22-minute block at default zoom (content
          // shorter than a full caption line) shrinks its glyphs to fit
          // instead of dropping the title or shearing it mid-x-height.
          final fittedScale =
              math.min(sliverLineHeight, constraints.maxHeight) /
              unscaledSliverLine;
          return Align(
            alignment: Alignment.centerLeft,
            child: Text(
              block.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textScaler: TextScaler.linear(fittedScale),
              style: tokens.typography.styles.others.caption.copyWith(
                color: tracked
                    ? tokens.colors.text.highEmphasis
                    : tokens.colors.text.mediumEmphasis,
              ),
            ),
          );
        }
        final compact = constraints.maxHeight < textScaler.scale(44);
        final showSubtitle = !isBuffer && !compact;
        final titleMaxLines = constraints.maxHeight >= textScaler.scale(64)
            ? 2
            : 1;
        // OverflowBox + ClipRect: duration-sized boxes clip content
        // gracefully at the block edge instead of throwing RenderFlex
        // overflows when a height lands between the visibility thresholds.
        return ClipRect(
          child: OverflowBox(
            alignment: compact ? Alignment.centerLeft : Alignment.topLeft,
            minHeight: 0,
            maxHeight: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isCal) ...[
                      Icon(
                        Icons.event_rounded,
                        size: 12,
                        color: tokens.colors.text.mediumEmphasis,
                      ),
                      SizedBox(width: tokens.spacing.step1),
                    ],
                    if (!tracked && isTaskLinked) ...[
                      Icon(
                        Icons.link_rounded,
                        size: 12,
                        color: tokens.colors.alert.info.defaultColor,
                      ),
                      SizedBox(width: tokens.spacing.step1),
                    ],
                    Expanded(
                      child: editable && !compact
                          ? EditableTitle(
                              value: block.title,
                              onSubmitted: onRename!,
                              style: titleStyle,
                            )
                          : Text(
                              block.title,
                              style: titleStyle,
                              maxLines: titleMaxLines,
                              overflow: TextOverflow.fade,
                              softWrap: true,
                            ),
                    ),
                    if (tracked && isDone) ...[
                      SizedBox(width: tokens.spacing.step1),
                      Icon(
                        Icons.check_rounded,
                        size: 12,
                        color: tokens.colors.alert.success.defaultColor,
                      ),
                    ],
                  ],
                ),
                if (showSubtitle)
                  Padding(
                    padding: EdgeInsets.only(top: tokens.spacing.step1),
                    child: Text(
                      _subTitle(context, block),
                      // One mono voice for time metadata in both lanes.
                      style: monoMetaStyle(
                        tokens,
                        tokens.colors,
                      ).copyWith(fontSize: 10),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _subTitle(BuildContext context, TimeBlock block) {
    final parts = <String>[_formatRange(block)];
    if (block.sessionIndex != null && block.sessionTotal != null) {
      parts.add(
        context.messages.dailyOsNextTimelineSessionOf(
          block.sessionIndex!,
          block.sessionTotal!,
        ),
      );
    }
    if (block.location != null) parts.add(block.location!);
    return parts.join(' · ');
  }

  String _formatRange(TimeBlock block) {
    return '${_clock(block.start)}–${_clock(block.end)}';
  }
}

class NowLine extends StatelessWidget {
  const NowLine({
    required this.windowStart,
    required this.now,
    required this.foldingState,
    required this.pxPerMinute,
    super.key,
  });

  final DateTime windowStart;
  final DateTime now;
  final TimelineFoldingState foldingState;
  final double pxPerMinute;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final red = tokens.colors.alert.error.defaultColor;
    final top = foldingState.positionForDate(
      now,
      windowStart: windowStart,
      pxPerMinute: pxPerMinute,
    );
    // Just the line — the single anchoring dot lives on the shared hour
    // rail so swipe mode's peeking page never shows a stray second dot.
    return Positioned(
      top: top - 0.75,
      left: 0,
      right: 0,
      height: 1.5,
      child: IgnorePointer(
        child: ColoredBox(color: red),
      ),
    );
  }
}
