import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/classes/geolocation.dart';

import 'check_list_item.dart';

part 'task.freezed.dart';
part 'task.g.dart';

@freezed
class TaskStatus with _$TaskStatus {
  factory TaskStatus.open({
    required String id,
    required DateTime createdAt,
    required int utcOffset,
    String? timezone,
    Geolocation? geolocation,
  }) = _TaskOpen;

  factory TaskStatus.started({
    required String id,
    required DateTime createdAt,
    required int utcOffset,
    String? timezone,
    Geolocation? geolocation,
  }) = _TaskStarted;

  factory TaskStatus.blocked({
    required String id,
    required DateTime createdAt,
    required int utcOffset,
    String? timezone,
    Geolocation? geolocation,
  }) = _TaskBlocked;

  factory TaskStatus.done({
    required String id,
    required DateTime createdAt,
    required int utcOffset,
    String? timezone,
    Geolocation? geolocation,
  }) = _TaskDone;

  factory TaskStatus.rejected({
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
class Task with _$Task {
  factory Task({
    required String id,
    required DateTime createdAt,
    required int utcOffset,
    required TaskStatus status,
    required List<TaskStatus> statusHistory,
    String? timezone,
    required String title,
    Geolocation? geolocation,
    DateTime? updatedAt,
    List<CheckListItem>? checklist,
  }) = _Task;

  factory Task.fromJson(Map<String, dynamic> json) => _$TaskFromJson(json);
}
