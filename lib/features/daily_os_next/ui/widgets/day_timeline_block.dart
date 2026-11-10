import 'dart:math' as math;

import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/ui/category_color.dart';
import 'package:lotti/features/daily_os_next/ui/time_format.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_row_scaffold.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_timeline_folding.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/editable_title.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/live_task_metadata.dart';
import 'package:lotti/features/design_system/components/ds_dashed_border.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/task_focus_controller.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:material_ui/material_ui.dart';

part 'day_timeline_block_content.dart';

/// The shortest block that can still show one title line: a `bodySmall`
/// line at the user's text scale plus the card's vertical padding. Below it
/// a block carves no inter-block gap, and a block that starts closer than
/// this (in minutes at the current zoom) to one it overlaps cannot sit on
/// top of it without hiding that title — see `layoutTimelineBlocks`. The
/// line grows with [textScaler] exactly as `_BlockContent` lays it out, so
/// large accessibility text widens the window rather than letting a raised
/// block shear the title beneath it.
double minimumReadableBlockHeight(
  DsTokens tokens, {
  required TextScaler textScaler,
}) =>
    textScaler.scale(tokens.typography.lineHeight.bodySmall) +
    tokens.spacing.step2 * 2;

/// Positions a [DayBlock] absolutely within the timeline stack. Converts the
/// block's start/end through the [foldingState] (which collapses idle gaps) to
/// pixel offsets, then carves a small inter-block gap out of tall enough blocks
/// so adjacent blocks read as distinct without overlapping. Across the lane
/// it sits where [horizontal] says: the pane resolves that from the block's
/// overlap slot, so concurrent blocks share the width instead of the same
/// pixels.
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
    required this.horizontal,
    this.raised = false,
    this.redacted = false,
    this.past = false,
    super.key,
  });

  final TimeBlock block;

  /// See [DayBlock.past].
  final bool past;

  /// Insets from the lane's left and right edges, in px, from
  /// `TimelineBlockSlot.horizontalInsets`.
  final ({double left, double right}) horizontal;

  /// See [DayBlock.raised].
  final bool raised;

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

  /// See [DayBlock.redacted]. A redacted block can be neither moved nor
  /// resized.
  final bool redacted;

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
  bool _rescheduleInFlight = false;

  TimeBlock get _block => _preview ?? widget.block;

  @override
  void didUpdateWidget(covariant BlockPosition oldWidget) {
    super.didUpdateWidget(oldWidget);
    final boundsChanged =
        oldWidget.block.start != widget.block.start ||
        oldWidget.block.end != widget.block.end;
    if (!_rescheduleInFlight && (boundsChanged || !widget.arrangeMode)) {
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
    final minimumReadableHeight = minimumReadableBlockHeight(
      tokens,
      textScaler: MediaQuery.textScalerOf(context),
    );
    final preferredGap = tokens.spacing.step1;
    final blockGap = rawHeight > minimumReadableHeight + preferredGap
        ? math.min(preferredGap, rawHeight / 3)
        : 0.0;
    final height = math.max(0, rawHeight - blockGap).toDouble();
    final canArrange =
        widget.arrangeMode &&
        !_rescheduleInFlight &&
        !widget.redacted &&
        !widget.tracked &&
        block.type != TimeBlockType.cal &&
        widget.onReschedule != null;
    final dayBlock = DayBlock(
      key: Key('daily_os_day_block_${block.id}'),
      block: block,
      tracked: widget.tracked,
      onRename: widget.onRename,
      onEdit: widget.onEdit,
      raised: widget.raised,
      redacted: widget.redacted,
      past: widget.past,
    );
    return Positioned(
      top: top + blockGap / 2,
      left: widget.horizontal.left,
      right: widget.horizontal.right,
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
    if (_rescheduleInFlight) return;
    _dragKind = kind;
    _dragOrigin = _block;
    _dragDelta = 0;
  }

  void _updateDrag(DragUpdateDetails details) {
    if (_rescheduleInFlight) return;
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
    if (_rescheduleInFlight) return;
    final origin = _dragOrigin;
    final preview = _preview;
    final onReschedule = widget.onReschedule;
    _dragKind = null;
    _dragOrigin = null;
    _dragDelta = 0;
    if (origin == null ||
        preview == null ||
        onReschedule == null ||
        (preview.start == origin.start && preview.end == origin.end)) {
      return;
    }
    setState(() => _rescheduleInFlight = true);
    var success = false;
    try {
      success = await onReschedule(widget.block, preview.start, preview.end);
    } finally {
      if (mounted) {
        setState(() {
          final sourceChanged =
              widget.block.start != origin.start ||
              widget.block.end != origin.end;
          if (sourceChanged) {
            _preview = null;
          } else if (!success && _preview == preview) {
            _preview = origin;
          }
          _rescheduleInFlight = false;
        });
      }
    }
  }

  void _cancelDrag() {
    if (_rescheduleInFlight) return;
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
    this.raised = false,
    this.redacted = false,
    this.past = false,
    super.key,
  });

  final TimeBlock block;
  final bool tracked;

  /// Whether the block ended before now. A planned block still to come is
  /// what "Looks good" approves, so its title reads at full strength; one
  /// already past recedes a step. Recorded blocks read at full strength
  /// either way.
  final bool past;

  /// Whether the block is painted on top of another block it overlaps in
  /// time. Fills are opaque, so without a seam two tinted cards on the same
  /// pixels read as one shape; a raised block draws a hairline in the canvas
  /// colour around itself to keep its edge.
  final bool raised;

  /// Draws the block as a plain neutral slab: right time and height, but no
  /// title, no category colour, no live task projection and no tap, edit or
  /// rename. Lockdown uses it for blocks outside the locked category so the
  /// day keeps its shape without revealing what filled it.
  final bool redacted;

  /// Inline rename for standalone blocks. Ignored for task-linked,
  /// calendar, buffer, and tracked blocks.
  final ValueChanged<String>? onRename;

  /// Opens the complete block editor. The callback receives the block after
  /// live task title/category projection so the modal never starts stale.
  final ValueChanged<TimeBlock>? onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    if (redacted) {
      return _RedactedBlock(block: block, tracked: tracked, raised: raised);
    }
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
    // A tracked calendar block projects a Lotti event, and an event has one
    // destination: its own page. Nothing else on the lane routes there.
    final eventId = tracked && effectiveBlock.type == TimeBlockType.cal
        ? effectiveBlock.trackedEntryId
        : null;
    // A tracked check-in has no task; its page is its person's, on the
    // People tab, as from the journal list. With People off, NavService
    // would drop that route onto another tab, so the block stays inert.
    final relationshipId = effectiveBlock.relationshipId;
    final peopleEnabled =
        tracked &&
        relationshipId != null &&
        (ref.watch(configFlagProvider(enableRelationshipsFlag)).value ?? false);
    final checkInId = peopleEnabled ? effectiveBlock.trackedEntryId : null;
    final onTap = eventId != null
        ? () => beamToNamed('/events/$eventId')
        : checkInId != null
        ? () => beamToNamed('/people/$relationshipId/check-ins/$checkInId')
        : taskId == null || taskId.isEmpty
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
    // The stripe is the block's category at full strength, planned or
    // recorded, so the briefing legend's hues can be found in either lane;
    // a planned block's dashed outline is what says it is provisional.
    final leftStripeColor = isBuffer
        ? tokens.colors.text.lowEmphasis.withValues(alpha: 0.32)
        : category;

    final borderRadius = BorderRadius.circular(tokens.radii.m);
    final seam = _raisedSeam(tokens, raised: raised);
    final card = Ink(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: borderRadius,
        border: seam,
      ),
      // The card's rounded shape clips its content, so the stripe follows
      // the corner arc instead of poking past it as a loose bar. `Ink`
      // already insets its child by the seam's width when the decoration
      // carries a border, so the stripe starts right inside the hairline
      // without a padding of its own; the clip runs along the seam's inner
      // edge so the stripe's arc stays concentric with it.
      child: ClipRRect(
        borderRadius: _contentRadius(tokens, seam),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CategoryStripe(blockId: block.id, color: leftStripeColor),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: tokens.spacing.step3,
                  vertical: tokens.spacing.step2,
                ),
                child: _BlockContent(
                  block: effectiveBlock,
                  tracked: tracked,
                  past: past,
                  onRename: onRename,
                  showsEdit: openEditor != null,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    // Drafted blocks read provisional via a dashed outline; committed
    // and tracked blocks read solid.
    final outlined = isDrafted
        ? DsDashedBorder(
            color: category.withValues(
              alpha: timelinePlannedOutlineAlpha(isLight: isLight),
            ),
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
      formatClockRange(context, effectiveBlock.start, effectiveBlock.end),
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
        child: Stack(
          children: [
            InkWell(
              onTap: primaryTap,
              onLongPress: onTap == null ? null : openEditor,
              borderRadius: borderRadius,
              child: outlined,
            ),
            // The pencil drawn in the title row is a glyph; this is its
            // target — a full tap target tall, bounded by the block, over
            // the pencil's column at the block's top-end corner: the card's
            // inset, the glyph and the gap before it. It stops short of the
            // agent's spark beside it, which keeps its own tap.
            if (openEditor != null)
              PositionedDirectional(
                top: 0,
                end: 0,
                width:
                    tokens.spacing.step3 +
                    tokens.typography.size.bodySmall +
                    tokens.spacing.step1,
                height: TapTargets.minimum,
                // Screen readers reach the editor as the block's own custom
                // action, so the corner adds no node of its own.
                child: ExcludeSemantics(
                  child: Tooltip(
                    message: context.messages.dailyOsNextBlockEditTooltip,
                    child: InkWell(
                      key: Key('daily_os_edit_block_${block.id}'),
                      borderRadius: borderRadius,
                      onTap: openEditor,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _categoryColor(TimeBlock block) =>
      categoryColorFromHex(block.category.colorHex);
}

/// The hairline a raised block draws around itself, in the canvas colour, so
/// its edge survives against the opaque fill it sits on. `null` for a block
/// on the lane floor.
Border? _raisedSeam(DsTokens tokens, {required bool raised}) => raised
    ? Border.all(
        color: tokens.colors.background.level01,
        width: tokens.spacing.step1 / 2,
      )
    : null;

/// The redacted rendering of a [DayBlock]: the buffer block's neutral stripe
/// on a plain `background.level03` fill, the same radius as a real block, and
/// nothing inside. Not a button — there is nothing to open — and its
/// accessible name carries only the time range and whether it was tracked or
/// planned, never the title. A raised slab keeps its seam: two redacted
/// blocks share one fill, so without it the day's layering would vanish.
class _RedactedBlock extends StatelessWidget {
  const _RedactedBlock({
    required this.block,
    required this.tracked,
    required this.raised,
  });

  final TimeBlock block;
  final bool tracked;
  final bool raised;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final seam = _raisedSeam(tokens, raised: raised);
    final semanticsLabel = [
      formatClockRange(context, block.start, block.end),
      if (tracked)
        context.messages.dailyOsNextTimelineTracked
      else
        context.messages.dailyOsNextTimelinePlanned,
    ].join(', ');
    final borderRadius = BorderRadius.circular(tokens.radii.m);
    return Semantics(
      label: semanticsLabel,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.colors.background.level03,
          borderRadius: borderRadius,
          border: seam,
        ),
        // Unlike `Ink`, a `DecoratedBox` does not inset its child by its
        // border, so the seam's width is kept clear here by hand — outside
        // the clip, so the clip runs along the seam's inner edge as it does
        // on a live block.
        child: Padding(
          padding: EdgeInsets.all(seam?.top.width ?? 0),
          child: ClipRRect(
            borderRadius: _contentRadius(tokens, seam),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _CategoryStripe(
                  blockId: block.id,
                  color: tokens.colors.text.lowEmphasis.withValues(
                    alpha: 0.32,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The radius a block's content is clipped to: the card's corner radius,
/// less the seam when there is one. A uniform border's inner edge has the
/// outer radius minus the border width, so clipping the content — already
/// inset by that width — at this radius keeps the stripe's corner arc
/// concentric with the hairline instead of bending tighter than it.
BorderRadius _contentRadius(DsTokens tokens, Border? seam) =>
    BorderRadius.circular(tokens.radii.m - (seam?.top.width ?? 0));

/// The category key down a block's left edge: one spacing step of colour,
/// the same stripe the agenda card and the live card draw. It carries no
/// shape of its own — the card's `ClipRRect` cuts it to the corner arc — so
/// it reads as the edge of the card rather than a bar laid on top of it.
class _CategoryStripe extends StatelessWidget {
  const _CategoryStripe({required this.blockId, required this.color});

  final String blockId;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: Key('daily_os_block_stripe_$blockId'),
      color: color,
      child: SizedBox(width: context.designTokens.spacing.step1),
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
    // Teal, like every other "you are here" on the page (the selected day,
    // the selected tab): the now-line is position, not an alarm.
    final ink = tokens.colors.interactive.enabled;
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
        child: ColoredBox(color: ink),
      ),
    );
  }
}
