import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/classes/geolocation.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/utils/file_utils.dart';

part 'task.freezed.dart';
part 'task.g.dart';

/// Priority levels for tasks, aligned with Linear-style P0..P3
enum TaskPriority {
  p0Urgent,
  p1High,
  p2Medium,
  p3Low,
}

/// Parse a DB/display string (e.g., 'P0', 'P1', 'P2', 'P3') to TaskPriority.
TaskPriority taskPriorityFromString(
  String value, {
  TaskPriority fallback = TaskPriority.p2Medium,
}) {
  switch (value.trim().toUpperCase()) {
    case 'P0':
      return TaskPriority.p0Urgent;
    case 'P1':
      return TaskPriority.p1High;
    case 'P2':
      return TaskPriority.p2Medium;
    case 'P3':
      return TaskPriority.p3Low;
    default:
      return fallback;
  }
}

extension TaskPriorityExt on TaskPriority {
  /// Short label used in compact UI, e.g., 'P0'.
  String get short => 'P$rank';

  /// Numerical rank used for ordering (lower is higher priority).
  int get rank => index; // 0..3

  /// Human-readable label (non-localized) for use in fallback UI.
  String get label => switch (this) {
        TaskPriority.p0Urgent => 'Urgent',
        TaskPriority.p1High => 'High',
        TaskPriority.p2Medium => 'Medium',
        TaskPriority.p3Low => 'Low',
      };

  /// Color aligned with task status theme tokens.
  Color colorForBrightness(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    return switch (this) {
      TaskPriority.p0Urgent => isLight ? taskStatusDarkRed : taskStatusRed,
      TaskPriority.p1High => isLight ? taskStatusDarkOrange : taskStatusOrange,
      TaskPriority.p2Medium => isLight ? taskStatusDarkBlue : taskStatusBlue,
      TaskPriority.p3Low => Colors.grey,
    };
  }
}

@freezed
sealed class TaskStatus with _$TaskStatus {
  const factory TaskStatus.open({
    required String id,
    required DateTime createdAt,
    required int utcOffset,
    String? timezone,
    Geolocation? geolocation,
  }) = TaskOpen;

  const factory TaskStatus.inProgress({
    required String id,
    required DateTime createdAt,
    required int utcOffset,
    String? timezone,
    Geolocation? geolocation,
  }) = TaskInProgress;

  const factory TaskStatus.groomed({
    required String id,
    required DateTime createdAt,
    required int utcOffset,
    String? timezone,
    Geolocation? geolocation,
  }) = TaskGroomed;

  const factory TaskStatus.blocked({
    required String id,
    required DateTime createdAt,
    required int utcOffset,
    required String reason,
    String? timezone,
    Geolocation? geolocation,
  }) = TaskBlocked;

  const factory TaskStatus.onHold({
    required String id,
    required DateTime createdAt,
    required int utcOffset,
    required String reason,
    String? timezone,
    Geolocation? geolocation,
  }) = TaskOnHold;

  const factory TaskStatus.done({
    required String id,
    required DateTime createdAt,
    required int utcOffset,
    String? timezone,
    Geolocation? geolocation,
  }) = TaskDone;

  const factory TaskStatus.rejected({
    required String id,
    required DateTime createdAt,
    required int utcOffset,
    String? timezone,
    Geolocation? geolocation,
  }) = TaskRejected;

  factory TaskStatus.fromJson(Map<String, dynamic> json) =>
      _$TaskStatusFromJson(json);
}

@freezed
abstract class TaskData with _$TaskData {
  const factory TaskData({
    required TaskStatus status,
    required DateTime dateFrom,
    required DateTime dateTo,
    required List<TaskStatus> statusHistory,
    required String title,
    DateTime? due,
    Duration? estimate,
    List<String>? checklistIds,
    String? languageCode,

    /// Set of label IDs the user explicitly removed and does not want suggested by AI.
    /// Stored as a Set in memory; serialized as an array in JSON.
    Set<String>? aiSuppressedLabelIds,
    @Default(TaskPriority.p2Medium) TaskPriority priority,

    /// ID of a linked JournalImage to use as visual mnemonic / cover art.
    /// Displayed in task list thumbnails and detail view SliverAppBar.
    String? coverArtId,

    /// Horizontal offset for square thumbnail crop from 2:1 cover art.
    /// 0.0 = left edge, 0.5 = center (default), 1.0 = right edge.
    @Default(0.5) double coverArtCropX,
  }) = _TaskData;

  factory TaskData.fromJson(Map<String, dynamic> json) =>
      _$TaskDataFromJson(json);
}

TaskStatus taskStatusFromString(String status) {
  TaskStatus newStatus;
  final now = DateTime.now();

  if (status == 'DONE') {
    newStatus = TaskStatus.done(
      id: uuid.v1(),
      createdAt: now,
      utcOffset: now.timeZoneOffset.inMinutes,
    );
  } else if (status == 'GROOMED') {
    newStatus = TaskStatus.groomed(
      id: uuid.v1(),
      createdAt: now,
      utcOffset: now.timeZoneOffset.inMinutes,
    );
  } else if (status == 'IN PROGRESS') {
    newStatus = TaskStatus.inProgress(
      id: uuid.v1(),
      createdAt: now,
      utcOffset: now.timeZoneOffset.inMinutes,
    );
  } else if (status == 'BLOCKED') {
    newStatus = TaskStatus.blocked(
      id: uuid.v1(),
      createdAt: now,
      reason: 'needs a reason',
      utcOffset: now.timeZoneOffset.inMinutes,
    );
  } else if (status == 'ON HOLD') {
    newStatus = TaskStatus.onHold(
      id: uuid.v1(),
      createdAt: now,
      reason: 'needs a reason',
      utcOffset: now.timeZoneOffset.inMinutes,
    );
  } else if (status == 'REJECTED') {
    newStatus = TaskStatus.rejected(
      id: uuid.v1(),
      createdAt: now,
      utcOffset: now.timeZoneOffset.inMinutes,
    );
  } else {
    newStatus = TaskStatus.open(
      id: uuid.v1(),
      createdAt: now,
      utcOffset: now.timeZoneOffset.inMinutes,
    );
  }
  return newStatus;
}

extension TaskStatusExtension on TaskStatus {
  String localizedLabel(BuildContext context) {
    return switch (this) {
      TaskOpen() => context.messages.taskStatusOpen,
      TaskGroomed() => context.messages.taskStatusGroomed,
      TaskInProgress() => context.messages.taskStatusInProgress,
      TaskBlocked() => context.messages.taskStatusBlocked,
      TaskOnHold() => context.messages.taskStatusOnHold,
      TaskDone() => context.messages.taskStatusDone,
      TaskRejected() => context.messages.taskStatusRejected,
    };
  }

  String get toDbString => switch (this) {
        TaskOpen() => 'OPEN',
        TaskGroomed() => 'GROOMED',
        TaskInProgress() => 'IN PROGRESS',
        TaskBlocked() => 'BLOCKED',
        TaskOnHold() => 'ON HOLD',
        TaskDone() => 'DONE',
        TaskRejected() => 'REJECTED',
      };

  Color get color {
    return colorForBrightness(Brightness.dark);
  }

  Color colorForBrightness(Brightness brightness) {
    final isLight = brightness == Brightness.light;

    return switch (this) {
      TaskOpen() => isLight ? taskStatusDarkOrange : taskStatusOrange,
      TaskGroomed() =>
        isLight ? taskStatusDarkGreen : taskStatusLightGreenAccent,
      TaskInProgress() => isLight ? taskStatusDarkBlue : taskStatusBlue,
      TaskBlocked() => isLight ? taskStatusDarkRed : taskStatusRed,
      TaskOnHold() => isLight ? taskStatusDarkRed : taskStatusRed,
      TaskDone() => isLight ? taskStatusDarkGreen : taskStatusGreen,
      TaskRejected() => isLight ? taskStatusDarkRed : taskStatusRed,
    };
  }
}
