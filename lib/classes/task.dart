import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/classes/geolocation.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/file_utils.dart';

part 'task.freezed.dart';
part 'task.g.dart';

@freezed
class TaskStatus with _$TaskStatus {
  const factory TaskStatus.open({
    required String id,
    required DateTime createdAt,
    required int utcOffset,
    String? timezone,
    Geolocation? geolocation,
  }) = _TaskOpen;

  const factory TaskStatus.inProgress({
    required String id,
    required DateTime createdAt,
    required int utcOffset,
    String? timezone,
    Geolocation? geolocation,
  }) = _TaskInProgress;

  const factory TaskStatus.groomed({
    required String id,
    required DateTime createdAt,
    required int utcOffset,
    String? timezone,
    Geolocation? geolocation,
  }) = _TaskGroomed;

  const factory TaskStatus.blocked({
    required String id,
    required DateTime createdAt,
    required int utcOffset,
    required String reason,
    String? timezone,
    Geolocation? geolocation,
  }) = _TaskBlocked;

  const factory TaskStatus.onHold({
    required String id,
    required DateTime createdAt,
    required int utcOffset,
    required String reason,
    String? timezone,
    Geolocation? geolocation,
  }) = _TaskOnHold;

  const factory TaskStatus.done({
    required String id,
    required DateTime createdAt,
    required int utcOffset,
    String? timezone,
    Geolocation? geolocation,
  }) = _TaskDone;

  const factory TaskStatus.rejected({
    required String id,
    required DateTime createdAt,
    required int utcOffset,
    String? timezone,
    Geolocation? geolocation,
  }) = _TaskRejected;

  factory TaskStatus.fromJson(Map<String, dynamic> json) =>
      _$TaskStatusFromJson(json);
}

@freezed
class TaskData with _$TaskData {
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
      _TaskOpen() => context.messages.taskStatusOpen,
      _TaskGroomed() => context.messages.taskStatusGroomed,
      _TaskInProgress() => context.messages.taskStatusInProgress,
      _TaskBlocked() => context.messages.taskStatusBlocked,
      _TaskOnHold() => context.messages.taskStatusOnHold,
      _TaskDone() => context.messages.taskStatusDone,
      _TaskRejected() => context.messages.taskStatusRejected,
      _ => 'Unknown',
    };
  }

  String get toDbString => map(
        open: (_) => 'OPEN',
        groomed: (_) => 'GROOMED',
        inProgress: (_) => 'IN PROGRESS',
        blocked: (_) => 'BLOCKED',
        onHold: (_) => 'ON HOLD',
        done: (_) => 'DONE',
        rejected: (_) => 'REJECTED',
      );

  Color get color {
    return map(
      open: (_) => Colors.orange,
      groomed: (_) => Colors.lightGreenAccent,
      inProgress: (_) => Colors.blue,
      blocked: (_) => Colors.red,
      onHold: (_) => Colors.red,
      done: (_) => Colors.green,
      rejected: (_) => Colors.red,
    );
  }
}
