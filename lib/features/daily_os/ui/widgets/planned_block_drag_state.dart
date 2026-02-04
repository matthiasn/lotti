import 'package:flutter/foundation.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/features/daily_os/util/drag_position_utils.dart';

/// Mode for planned block drag operations.
enum PlannedBlockDragMode {
  /// No drag in progress.
  none,

  /// Moving the entire block (body zone drag).
  move,

  /// Resizing by dragging the top edge (changes start time).
  resizeTop,

  /// Resizing by dragging the bottom edge (changes end time).
  resizeBottom,
}

/// State for an in-progress drag operation on a planned block.
///
/// Tracks the original block state and current drag position in minutes
/// from midnight. Provides helpers for DateTime conversion for persistence.
@immutable
class PlannedBlockDragState {
  const PlannedBlockDragState({
    required this.mode,
    required this.originalBlock,
    required this.currentStartMinutes,
    required this.currentEndMinutes,
    required this.date,
  });

  /// The type of drag operation.
  final PlannedBlockDragMode mode;

  /// The block's state before drag started (for cancel/restore).
  final PlannedBlock originalBlock;

  /// Current start time in minutes from midnight (0-1440).
  final int currentStartMinutes;

  /// Current end time in minutes from midnight (0-1440).
  final int currentEndMinutes;

  /// The date for DateTime reconstruction.
  final DateTime date;

  /// Current duration based on drag state.
  Duration get currentDuration =>
      Duration(minutes: currentEndMinutes - currentStartMinutes);

  /// Converts current start minutes to DateTime for persistence.
  DateTime get startDateTime => DateTime(
        date.year,
        date.month,
        date.day,
      ).add(Duration(minutes: currentStartMinutes));

  /// Converts current end minutes to DateTime for persistence.
  DateTime get endDateTime => DateTime(
        date.year,
        date.month,
        date.day,
      ).add(Duration(minutes: currentEndMinutes));

  /// Whether the drag state has changed from the original.
  bool get hasChanged =>
      currentStartMinutes != _originalStartMinutes ||
      currentEndMinutes != _originalEndMinutes;

  int get _originalStartMinutes =>
      minutesFromDate(date, originalBlock.startTime);

  int get _originalEndMinutes => minutesFromDate(date, originalBlock.endTime);

  /// Creates a copy with updated fields.
  PlannedBlockDragState copyWith({
    PlannedBlockDragMode? mode,
    int? currentStartMinutes,
    int? currentEndMinutes,
  }) =>
      PlannedBlockDragState(
        mode: mode ?? this.mode,
        originalBlock: originalBlock,
        currentStartMinutes: currentStartMinutes ?? this.currentStartMinutes,
        currentEndMinutes: currentEndMinutes ?? this.currentEndMinutes,
        date: date,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlannedBlockDragState &&
          runtimeType == other.runtimeType &&
          mode == other.mode &&
          originalBlock == other.originalBlock &&
          currentStartMinutes == other.currentStartMinutes &&
          currentEndMinutes == other.currentEndMinutes &&
          date == other.date;

  @override
  int get hashCode =>
      mode.hashCode ^
      originalBlock.hashCode ^
      currentStartMinutes.hashCode ^
      currentEndMinutes.hashCode ^
      date.hashCode;

  @override
  String toString() =>
      'PlannedBlockDragState(mode: $mode, start: $currentStartMinutes, end: $currentEndMinutes)';
}
