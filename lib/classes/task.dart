import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/classes/geolocation.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/file_utils.dart';

part 'task.freezed.dart';
part 'task.g.dart';

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
    return switch (this) {
      TaskOpen() => Colors.orange,
      TaskGroomed() => Colors.lightGreenAccent,
      TaskInProgress() => Colors.blue,
      TaskBlocked() => Colors.red,
      TaskOnHold() => Colors.red,
      TaskDone() => Colors.green,
      TaskRejected() => Colors.red,
    };
  }
}
