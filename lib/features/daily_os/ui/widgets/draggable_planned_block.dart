import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/daily_os/state/daily_os_controller.dart';
import 'package:lotti/features/daily_os/state/timeline_data_controller.dart';
import 'package:lotti/features/daily_os/state/unified_daily_os_data_controller.dart';
import 'package:lotti/features/daily_os/ui/widgets/planned_block_drag_state.dart';
import 'package:lotti/features/daily_os/ui/widgets/planned_block_edit_modal.dart';
import 'package:lotti/features/daily_os/util/drag_position_utils.dart';
import 'package:lotti/features/daily_os/util/timeline_folding_utils.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/color.dart';

/// A draggable planned time block widget with support for move and resize.
///
/// Supports three drag modes:
/// - Move: drag the body to move the entire block
/// - Resize top: drag the top edge to change start time
/// - Resize bottom: drag the bottom edge to change end time
///
/// Drag is disabled for blocks that overlap compressed timeline regions.
/// Drag is section-bounded - blocks cannot be dragged beyond their section.
class DraggablePlannedBlock extends ConsumerStatefulWidget {
  const DraggablePlannedBlock({
    required this.slot,
    required this.sectionStartHour,
    required this.sectionEndHour,
    required this.date,
    required this.foldingState,
    required this.expandedRegions,
    super.key,
    this.onDragActiveChanged,
  });

  final PlannedTimeSlot slot;
  final int sectionStartHour;
  final int sectionEndHour;
  final DateTime date;
  final TimelineFoldingState foldingState;
  final Set<int> expandedRegions;
  final DragActiveChangedCallback? onDragActiveChanged;

  @override
  ConsumerState<DraggablePlannedBlock> createState() =>
      _DraggablePlannedBlockState();
}

class _DraggablePlannedBlockState extends ConsumerState<DraggablePlannedBlock> {
  PlannedBlockDragState? _dragState;
  int _originalStartMinutes = 0;
  int _originalEndMinutes = 0;
  bool _hasShownBoundaryHint = false;
  int? _lastHapticMinute; // De-dupe haptic feedback

  /// Whether we're on a touch device (larger hit zones).
  bool get _isTouch {
    final platform = Theme.of(context).platform;
    return platform == TargetPlatform.iOS || platform == TargetPlatform.android;
  }

  /// Get the appropriate resize handle height for the platform.
  double get _resizeHandleHeight =>
      _isTouch ? kResizeHandleHeightTouch : kResizeHandleHeightDesktop;

  /// Calculate the block height in pixels.
  double get _blockHeight {
    final durationMinutes = widget.slot.duration.inMinutes;
    return durationMinutes * kHourHeight / 60;
  }

  /// Check if drag is disabled (block overlaps compressed region).
  bool get _dragDisabled => blockOverlapsCompressedRegion(
        block: widget.slot.block,
        foldingState: widget.foldingState,
        expandedRegions: widget.expandedRegions,
      );

  /// Check if block is too small for resize (move-only mode).
  bool get _isMoveOnly => _blockHeight < kMinimumBlockHeightForResize;

  /// Get the contiguous drag bounds (section + adjacent expanded regions).
  ({int startHour, int endHour}) get _dragBounds =>
      calculateContiguousDragBounds(
        sectionStartHour: widget.sectionStartHour,
        sectionEndHour: widget.sectionEndHour,
        foldingState: widget.foldingState,
        expandedRegions: widget.expandedRegions,
      );

  @override
  Widget build(BuildContext context) {
    // Calculate position - use drag state if active, otherwise use slot values
    final effectiveStartMinutes = _dragState?.currentStartMinutes ??
        minutesFromDate(widget.date, widget.slot.startTime);
    final effectiveEndMinutes = _dragState?.currentEndMinutes ??
        minutesFromDate(widget.date, widget.slot.endTime);

    final startMinutesFromSection =
        effectiveStartMinutes - (widget.sectionStartHour * 60);
    final durationMinutes = effectiveEndMinutes - effectiveStartMinutes;

    final top = startMinutesFromSection * kHourHeight / 60;
    final height = durationMinutes * kHourHeight / 60;

    final category = widget.slot.category;
    final categoryId = category?.id;
    final categoryColor = category != null
        ? colorFromCssHex(category.color)
        : context.colorScheme.primary;

    final highlightedId = ref.watch(highlightedCategoryIdProvider);
    final isHighlighted = categoryId != null && highlightedId == categoryId;
    final isDragging = _dragState != null;

    return Positioned(
      top: top,
      left: 4,
      right: 4,
      height: height,
      child: GestureDetector(
        onTap: _handleTap,
        onDoubleTap: _handleDoubleTap,
        onLongPressStart: _handleLongPressStart,
        onLongPressMoveUpdate: _handleLongPressMoveUpdate,
        onLongPressEnd: _handleLongPressEnd,
        onLongPressCancel: _handleLongPressCancel,
        child: RepaintBoundary(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: categoryColor.withValues(
                alpha: isDragging ? 0.5 : (isHighlighted ? 0.4 : 0.2),
              ),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: categoryColor.withValues(
                  alpha: isDragging ? 1.0 : (isHighlighted ? 0.9 : 0.4),
                ),
                width: isDragging ? 2 : (isHighlighted ? 2 : 1),
              ),
              boxShadow: isDragging
                  ? [
                      BoxShadow(
                        color: categoryColor.withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            transform:
                isDragging ? Matrix4.diagonal3Values(1.02, 1.02, 1) : null,
            transformAlignment: Alignment.center,
            padding: const EdgeInsets.all(4),
            child: Stack(
              children: [
                // Category name
                Text(
                  category?.name ?? context.messages.dailyOsPlanned,
                  style: context.textTheme.labelSmall?.copyWith(
                    color: categoryColor.withValues(alpha: 0.9),
                    fontWeight:
                        isHighlighted ? FontWeight.w700 : FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                // Time indicator during drag
                if (isDragging) ...[
                  Positioned(
                    top: 0,
                    right: 0,
                    child: _TimeLabel(
                      time: formatMinutesAsTime(effectiveStartMinutes),
                      color: categoryColor,
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: _TimeLabel(
                      time: formatMinutesAsTime(effectiveEndMinutes),
                      color: categoryColor,
                    ),
                  ),
                  // Duration in center for move mode
                  if (_dragState?.mode == PlannedBlockDragMode.move)
                    Center(
                      child: _TimeLabel(
                        time: formatDurationMinutes(durationMinutes),
                        color: categoryColor,
                      ),
                    ),
                ],

                // Resize handles (visual affordance)
                if (!_isMoveOnly && !isDragging) ...[
                  // Top handle
                  Positioned(
                    top: 2,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        width: 24,
                        height: 3,
                        decoration: BoxDecoration(
                          color: categoryColor.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                  // Bottom handle
                  Positioned(
                    bottom: 2,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        width: 24,
                        height: 3,
                        decoration: BoxDecoration(
                          color: categoryColor.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleTap() {
    final categoryId = widget.slot.category?.id;
    if (categoryId != null) {
      ref
          .read(dailyOsControllerProvider.notifier)
          .highlightCategory(categoryId);
    }
  }

  void _handleDoubleTap() {
    PlannedBlockEditModal.show(context, widget.slot.block, widget.date);
  }

  void _handleLongPressStart(LongPressStartDetails details) {
    if (_dragDisabled) {
      // Show tooltip explaining drag is disabled
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.messages.dailyOsExpandToMove),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    // Detect zone
    final mode = _detectZone(details.localPosition.dy);

    // Initialize drag state
    final block = widget.slot.block;
    _originalStartMinutes = minutesFromDate(widget.date, block.startTime);
    _originalEndMinutes = minutesFromDate(widget.date, block.endTime);

    setState(() {
      _dragState = PlannedBlockDragState(
        mode: mode,
        originalBlock: block,
        currentStartMinutes: _originalStartMinutes,
        currentEndMinutes: _originalEndMinutes,
        date: widget.date,
      );
      _hasShownBoundaryHint = false;
      _lastHapticMinute = null;
    });

    // Haptic feedback
    unawaited(HapticFeedback.mediumImpact());

    // Notify parent to lock scroll
    widget.onDragActiveChanged?.call(isDragging: true);
  }

  void _handleLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    if (_dragState == null) return;

    final deltaMinutes = deltaToMinutes(details.offsetFromOrigin.dy);

    switch (_dragState!.mode) {
      case PlannedBlockDragMode.move:
        _updateMovePosition(deltaMinutes);
      case PlannedBlockDragMode.resizeTop:
        _updateResizeTop(deltaMinutes);
      case PlannedBlockDragMode.resizeBottom:
        _updateResizeBottom(deltaMinutes);
      case PlannedBlockDragMode.none:
        break;
    }
  }

  Future<void> _handleLongPressEnd(LongPressEndDetails details) async {
    if (_dragState == null) return;

    // Commit the drag if changed - await to prevent visual jump-back
    if (_dragState!.hasChanged) {
      await _commitDrag();
    }

    if (!mounted) return;

    setState(() {
      _dragState = null;
    });

    // Notify parent to unlock scroll
    widget.onDragActiveChanged?.call(isDragging: false);
  }

  void _handleLongPressCancel() {
    if (_dragState == null) return;

    setState(() {
      _dragState = null;
    });

    // Notify parent to unlock scroll
    widget.onDragActiveChanged?.call(isDragging: false);
  }

  PlannedBlockDragMode _detectZone(double localY) {
    // Small blocks: move only
    if (_isMoveOnly) {
      return PlannedBlockDragMode.move;
    }

    final handleHeight = _resizeHandleHeight;

    if (localY < handleHeight) {
      return PlannedBlockDragMode.resizeTop;
    } else if (localY > _blockHeight - handleHeight) {
      return PlannedBlockDragMode.resizeBottom;
    } else {
      return PlannedBlockDragMode.move;
    }
  }

  void _updateMovePosition(int deltaMinutes) {
    final duration = _originalEndMinutes - _originalStartMinutes;
    final bounds = _dragBounds;

    var newStartMinutes = _originalStartMinutes + deltaMinutes;
    newStartMinutes = snapToGrid(newStartMinutes);

    // Clamp to contiguous drag bounds (section + adjacent expanded regions)
    final boundsStartMinutes = bounds.startHour * 60;
    final boundsEndMinutes = bounds.endHour * 60;
    newStartMinutes = newStartMinutes.clamp(
      boundsStartMinutes,
      boundsEndMinutes - duration,
    );

    final newEndMinutes = newStartMinutes + duration;

    // Detect if at boundary (only show hint if hitting a collapsed region)
    final atBoundary = newStartMinutes == boundsStartMinutes ||
        newEndMinutes == boundsEndMinutes;

    setState(() {
      _dragState = _dragState!.copyWith(
        currentStartMinutes: newStartMinutes,
        currentEndMinutes: newEndMinutes,
      );
    });

    // Show boundary hint once (only if there's actually a collapsed region)
    if (atBoundary && !_hasShownBoundaryHint && _hasAdjacentCollapsedRegion()) {
      _showBoundaryHint();
      _hasShownBoundaryHint = true;
    }

    // Haptic feedback on snap (de-duped)
    _maybeHapticFeedback(newStartMinutes);
  }

  void _updateResizeTop(int deltaMinutes) {
    final bounds = _dragBounds;
    var newStartMinutes = _originalStartMinutes + deltaMinutes;
    newStartMinutes = snapToGrid(newStartMinutes);

    // Enforce minimum duration AND contiguous drag bounds
    final minStart = bounds.startHour * 60;
    final maxStart = _dragState!.currentEndMinutes - kMinimumBlockMinutes;
    newStartMinutes = newStartMinutes.clamp(minStart, maxStart);

    final atBoundary = newStartMinutes == minStart;

    setState(() {
      _dragState = _dragState!.copyWith(currentStartMinutes: newStartMinutes);
    });

    if (atBoundary && !_hasShownBoundaryHint && _hasAdjacentCollapsedRegion()) {
      _showBoundaryHint();
      _hasShownBoundaryHint = true;
    }

    // Haptic feedback on snap (de-duped)
    _maybeHapticFeedback(newStartMinutes);
  }

  void _updateResizeBottom(int deltaMinutes) {
    final bounds = _dragBounds;
    var newEndMinutes = _originalEndMinutes + deltaMinutes;
    newEndMinutes = snapToGrid(newEndMinutes);

    // Enforce minimum duration AND contiguous drag bounds
    final minEnd = _dragState!.currentStartMinutes + kMinimumBlockMinutes;
    final maxEnd = bounds.endHour * 60;
    newEndMinutes = newEndMinutes.clamp(minEnd, maxEnd);

    final atBoundary = newEndMinutes == maxEnd;

    setState(() {
      _dragState = _dragState!.copyWith(currentEndMinutes: newEndMinutes);
    });

    if (atBoundary && !_hasShownBoundaryHint && _hasAdjacentCollapsedRegion()) {
      _showBoundaryHint();
      _hasShownBoundaryHint = true;
    }

    // Haptic feedback on snap (de-duped)
    _maybeHapticFeedback(newEndMinutes);
  }

  /// Checks if there's any collapsed region adjacent to the drag bounds.
  bool _hasAdjacentCollapsedRegion() {
    final bounds = _dragBounds;
    for (final region in widget.foldingState.compressedRegions) {
      if (widget.expandedRegions.contains(region.startHour)) continue;
      // Check if collapsed region is adjacent to bounds
      if (region.endHour == bounds.startHour ||
          region.startHour == bounds.endHour) {
        return true;
      }
    }
    return false;
  }

  /// Fires haptic feedback when crossing a [kHapticFeedbackMinutes] boundary,
  /// de-duped to avoid repeated feedback at the same position.
  void _maybeHapticFeedback(int minutes) {
    if (minutes % kHapticFeedbackMinutes == 0 && _lastHapticMinute != minutes) {
      _lastHapticMinute = minutes;
      unawaited(HapticFeedback.selectionClick());
    }
  }

  void _showBoundaryHint() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.messages.dailyOsExpandToMoveMore),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _commitDrag() async {
    if (_dragState == null) return;

    final updatedBlock = _dragState!.originalBlock.copyWith(
      startTime: _dragState!.startDateTime,
      endTime: _dragState!.endDateTime,
    );

    await ref
        .read(
          unifiedDailyOsDataControllerProvider(date: widget.date).notifier,
        )
        .updatePlannedBlock(updatedBlock);

    // Haptic feedback on commit
    unawaited(HapticFeedback.mediumImpact());
  }
}

/// Small time label widget shown during drag.
class _TimeLabel extends StatelessWidget {
  const _TimeLabel({
    required this.time,
    required this.color,
  });

  final String time;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        time,
        style: context.textTheme.labelSmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 10,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
