import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/classes/check_list_item.dart';
import 'package:lotti/classes/geolocation.dart';

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
    required String reason,
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
class TaskData with _$TaskData {
  factory TaskData({
    required TaskStatus status,
    required List<TaskStatus> statusHistory,
    required String title,
    double? estimatedMinutes,
    List<CheckListItem>? checklist,
  }) = _TaskData;

  factory TaskData.fromJson(Map<String, dynamic> json) =>
      _$TaskDataFromJson(json);
}
