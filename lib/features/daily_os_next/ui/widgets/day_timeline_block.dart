import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/ui/category_color.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_timeline_folding.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/editable_title.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/live_task_metadata.dart';
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
class BlockPosition extends StatefulWidget {
  const BlockPosition({
    required this.block,
    required this.windowStart,
    required this.foldingState,
    required this.pxPerMinute,
    required this.tracked,
    required this.onRename,
    required this.onEdit,
    required this.arrangeMode,
    required this.onReschedule,
    super.key,
  });

  final TimeBlock block;
  final DateTime windowStart;
  final TimelineFoldingState foldingState;
  final double pxPerMinute;
  final bool tracked;
  final ValueChanged<String>? onRename;
  final ValueChanged<TimeBlock>? onEdit;
  final bool arrangeMode;
  final Future<bool> Function(
    TimeBlock block,
    DateTime start,
    DateTime end,
  )?
  onReschedule;

  @override
  State<BlockPosition> createState() => _BlockPositionState();
}

enum _BlockDragKind { move, resizeStart, resizeEnd }

class _BlockPositionState extends State<BlockPosition> {
  static const _snapInterval = Duration(minutes: 15);

  TimeBlock? _preview;
  TimeBlock? _dragOrigin;
  _BlockDragKind? _dragKind;
  double _dragDelta = 0;

  TimeBlock get _block => _preview ?? widget.block;

  @override
  void didUpdateWidget(covariant BlockPosition oldWidget) {
    super.didUpdateWidget(oldWidget);
    final boundsChanged =
        oldWidget.block.start != widget.block.start ||
        oldWidget.block.end != widget.block.end;
    if (boundsChanged || !widget.arrangeMode) {
      _preview = null;
      _dragOrigin = null;
      _dragKind = null;
      _dragDelta = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final block = _block;
    final top = widget.foldingState.positionForDate(
      block.start,
      windowStart: widget.windowStart,
      pxPerMinute: widget.pxPerMinute,
    );
    final end = widget.foldingState.positionForDate(
      block.end,
      windowStart: widget.windowStart,
      pxPerMinute: widget.pxPerMinute,
    );
    final rawHeight = math.max(0, end - top).toDouble();
    final minimumReadableHeight =
        tokens.typography.lineHeight.bodySmall + tokens.spacing.step2 * 2;
    final preferredGap = tokens.spacing.step1;
    final blockGap = rawHeight > minimumReadableHeight + preferredGap
        ? math.min(preferredGap, rawHeight / 3)
        : 0.0;
    final height = math.max(0, rawHeight - blockGap).toDouble();
    final canArrange =
        widget.arrangeMode &&
        !widget.tracked &&
        block.type != TimeBlockType.cal &&
        widget.onReschedule != null;
    final dayBlock = DayBlock(
      key: Key('daily_os_day_block_${block.id}'),
      block: block,
      tracked: widget.tracked,
      onRename: widget.onRename,
      onEdit: widget.onEdit,
    );
    return Positioned(
      top: top + blockGap / 2,
      left: tokens.spacing.step3,
      right: tokens.spacing.step3,
      height: height,
      child: canArrange
          ? Stack(
              fit: StackFit.expand,
              clipBehavior: Clip.none,
              children: [
                Tooltip(
                  message: context.messages.dailyOsNextBlockMoveTooltip,
                  child: GestureDetector(
                    key: Key('daily_os_move_block_${block.id}'),
                    behavior: HitTestBehavior.translucent,
                    onVerticalDragStart: (_) => _startDrag(_BlockDragKind.move),
                    onVerticalDragUpdate: _updateDrag,
                    onVerticalDragEnd: (_) => _finishDrag(),
                    onVerticalDragCancel: _cancelDrag,
                    child: dayBlock,
                  ),
                ),
                _ResizeHandle(
                  handleKey: Key('daily_os_resize_start_${block.id}'),
                  alignment: Alignment.topCenter,
                  tooltip: context.messages.dailyOsNextBlockResizeStartTooltip,
                  onStart: () => _startDrag(_BlockDragKind.resizeStart),
                  onUpdate: _updateDrag,
                  onEnd: _finishDrag,
                  onCancel: _cancelDrag,
                ),
                _ResizeHandle(
                  handleKey: Key('daily_os_resize_end_${block.id}'),
                  alignment: Alignment.bottomCenter,
                  tooltip: context.messages.dailyOsNextBlockResizeEndTooltip,
                  onStart: () => _startDrag(_BlockDragKind.resizeEnd),
                  onUpdate: _updateDrag,
                  onEnd: _finishDrag,
                  onCancel: _cancelDrag,
                ),
              ],
            )
          : dayBlock,
    );
  }

  void _startDrag(_BlockDragKind kind) {
    _dragKind = kind;
    _dragOrigin = _block;
    _dragDelta = 0;
  }

  void _updateDrag(DragUpdateDetails details) {
    final origin = _dragOrigin;
    final kind = _dragKind;
    if (origin == null || kind == null) return;
    _dragDelta += details.primaryDelta ?? 0;
    const minimumDuration = _snapInterval;
    final windowEnd = widget.windowStart.add(
      Duration(
        hours: widget.foldingState.endHour - widget.foldingState.startHour,
      ),
    );

    DateTime shifted(DateTime value) {
      final originPosition = widget.foldingState.positionForDate(
        value,
        windowStart: widget.windowStart,
        pxPerMinute: widget.pxPerMinute,
      );
      return _snap(
        widget.foldingState.dateForPosition(
          originPosition + _dragDelta,
          windowStart: widget.windowStart,
          pxPerMinute: widget.pxPerMinute,
        ),
      );
    }

    final next = switch (kind) {
      _BlockDragKind.move => () {
        final duration = origin.duration;
        final latestStart = windowEnd.subtract(duration);
        final start = _clampDate(
          shifted(origin.start),
          widget.windowStart,
          latestStart,
        );
        return origin.copyWith(start: start, end: start.add(duration));
      }(),
      _BlockDragKind.resizeStart => origin.copyWith(
        start: _clampDate(
          shifted(origin.start),
          widget.windowStart,
          origin.end.subtract(minimumDuration),
        ),
      ),
      _BlockDragKind.resizeEnd => origin.copyWith(
        end: _clampDate(
          shifted(origin.end),
          origin.start.add(minimumDuration),
          windowEnd,
        ),
      ),
    };
    setState(() => _preview = next);
  }

  Future<void> _finishDrag() async {
    final origin = _dragOrigin;
    final preview = _preview;
    _dragKind = null;
    _dragOrigin = null;
    _dragDelta = 0;
    if (origin == null ||
        preview == null ||
        (preview.start == origin.start && preview.end == origin.end)) {
      return;
    }
    final success = await widget.onReschedule!(
      widget.block,
      preview.start,
      preview.end,
    );
    if (!success && mounted) setState(() => _preview = origin);
  }

  void _cancelDrag() {
    final origin = _dragOrigin;
    setState(() {
      _preview = origin;
      _dragKind = null;
      _dragOrigin = null;
      _dragDelta = 0;
    });
  }

  DateTime _snap(DateTime value) {
    final offset = value.difference(widget.windowStart).inMicroseconds;
    final step = _snapInterval.inMicroseconds;
    final snapped = (offset / step).round() * step;
    return widget.windowStart.add(Duration(microseconds: snapped));
  }

  DateTime _clampDate(DateTime value, DateTime minimum, DateTime maximum) {
    if (value.isBefore(minimum)) return minimum;
    if (value.isAfter(maximum)) return maximum;
    return value;
  }
}

class _ResizeHandle extends StatelessWidget {
  const _ResizeHandle({
    required this.handleKey,
    required this.alignment,
    required this.tooltip,
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
    required this.onCancel,
  });

  final Alignment alignment;
  final Key handleKey;
  final String tooltip;
  final VoidCallback onStart;
  final ValueChanged<DragUpdateDetails> onUpdate;
  final VoidCallback onEnd;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Align(
      alignment: alignment,
      child: Tooltip(
        message: tooltip,
        child: GestureDetector(
          key: handleKey,
          behavior: HitTestBehavior.opaque,
          onVerticalDragStart: (_) => onStart(),
          onVerticalDragUpdate: onUpdate,
          onVerticalDragEnd: (_) => onEnd(),
          onVerticalDragCancel: onCancel,
          child: SizedBox(
            height: tokens.spacing.step4,
            width: double.infinity,
            child: Center(
              child: Container(
                width: tokens.spacing.step8,
                height: tokens.spacing.step1,
                decoration: BoxDecoration(
                  color: tokens.colors.interactive.enabled,
                  borderRadius: BorderRadius.circular(
                    tokens.radii.badgesPills,
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
    this.onEdit,
    super.key,
  });

  final TimeBlock block;
  final bool tracked;

  /// Inline rename for standalone blocks. Ignored for task-linked,
  /// calendar, buffer, and tracked blocks.
  final ValueChanged<String>? onRename;

  /// Opens the complete block editor. The callback receives the block after
  /// live task title/category projection so the modal never starts stale.
  final ValueChanged<TimeBlock>? onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final taskId = block.taskId?.trim();
    final liveTask = watchLiveTaskMetadata(ref, taskId);
    final effectiveTitle = liveTask.missing
        ? context.messages.conflictDetailEntryNotFoundTitle
        : liveTask.title;
    final effectiveBlock = block.copyWith(
      title: effectiveTitle ?? block.title,
      category: liveTask.categoryOr(block.category),
    );
    final category = _categoryColor(effectiveBlock);
    final isBuffer = effectiveBlock.type == TimeBlockType.buffer;
    final canEdit =
        !tracked && effectiveBlock.type != TimeBlockType.cal && onEdit != null;
    final openEditor = canEdit ? () => onEdit!(effectiveBlock) : null;
    final isDrafted =
        !tracked && effectiveBlock.state == TimeBlockState.drafted;
    final onTap = taskId == null || taskId.isEmpty
        ? null
        : () {
            // Tracked blocks project a real time recording. Publish the
            // focus intent before navigating so the task detail page
            // scrolls to (and highlights) that exact recording, matching
            // the old calendar behaviour. Drafted/agent blocks have no
            // backing entry, so they just open the task at the top.
            final entryId = effectiveBlock.trackedEntryId;
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
                block: effectiveBlock,
                tracked: tracked,
                onRename: onRename,
                onEdit: openEditor,
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
      effectiveBlock.title,
      '${_clock(effectiveBlock.start)}–${_clock(effectiveBlock.end)}',
      if (!tracked && _reasonFor(effectiveBlock) != null)
        _reasonFor(effectiveBlock)!,
      if (tracked)
        context.messages.dailyOsNextTimelineTracked
      else
        context.messages.dailyOsNextTimelinePlanned,
    ].join(', ');

    final primaryTap = onTap ?? openEditor;
    if (primaryTap == null && openEditor == null) {
      return Semantics(
        label: semanticsLabel,
        child: Material(
          type: MaterialType.transparency,
          child: outlined,
        ),
      );
    }

    return Semantics(
      button: primaryTap != null,
      label: semanticsLabel,
      customSemanticsActions: openEditor == null
          ? null
          : {
              CustomSemanticsAction(
                label: context.messages.dailyOsNextBlockEditTooltip,
              ): openEditor,
            },
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: primaryTap,
          onLongPress: onTap == null ? null : openEditor,
          borderRadius: borderRadius,
          child: outlined,
        ),
      ),
    );
  }

  Color _categoryColor(TimeBlock block) =>
      categoryColorFromHex(block.category.colorHex);
}

String _clock(DateTime t) {
  final h = t.hour.toString().padLeft(2, '0');
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

String? _reasonFor(TimeBlock block) {
  final reason = block.reason?.trim();
  return reason == null || reason.isEmpty ? null : reason;
}

class _BlockContent extends StatelessWidget {
  const _BlockContent({
    required this.block,
    required this.tracked,
    required this.onRename,
    required this.onEdit,
  });

  final TimeBlock block;
  final bool tracked;
  final ValueChanged<String>? onRename;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final isBuffer = block.type == TimeBlockType.buffer;
    final isCal = block.type == TimeBlockType.cal;
    final isTaskLinked =
        block.taskId != null && block.taskId!.trim().isNotEmpty;
    final isDone = block.state == TimeBlockState.completed;
    final reason = tracked ? null : _reasonFor(block);
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
                    if (reason != null && !compact) ...[
                      SizedBox(width: tokens.spacing.step1),
                      _BlockReasonIcon(reason: reason),
                    ],
                    if (onEdit != null) ...[
                      SizedBox(width: tokens.spacing.step1),
                      SizedBox.square(
                        dimension: compact
                            ? tokens.spacing.step5
                            : tokens.spacing.step7,
                        child: IconButton(
                          key: Key('daily_os_edit_block_${block.id}'),
                          tooltip: context.messages.dailyOsNextBlockEditTooltip,
                          padding: EdgeInsets.zero,
                          iconSize: compact
                              ? tokens.spacing.step4
                              : tokens.spacing.step5,
                          onPressed: onEdit,
                          icon: const Icon(Icons.edit_rounded),
                        ),
                      ),
                    ],
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

class _BlockReasonIcon extends StatelessWidget {
  const _BlockReasonIcon({required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Tooltip(
      message: reason,
      child: Semantics(
        label: context.messages.dailyOsNextDayWhyChipLabel,
        child: Icon(
          Icons.auto_awesome_rounded,
          size: tokens.typography.size.caption,
          color: tokens.colors.aiCard.accent.withValues(alpha: 0.8),
        ),
      ),
    );
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
