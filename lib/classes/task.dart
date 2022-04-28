import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/classes/check_list_item.dart';
import 'package:lotti/classes/geolocation.dart';
import 'package:lotti/utils/file_utils.dart';

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

  factory TaskStatus.inProgress({
    required String id,
    required DateTime createdAt,
    required int utcOffset,
    String? timezone,
    Geolocation? geolocation,
  }) = _TaskInProgress;

  factory TaskStatus.groomed({
    required String id,
    required DateTime createdAt,
    required int utcOffset,
    String? timezone,
    Geolocation? geolocation,
  }) = _TaskGroomed;

  factory TaskStatus.blocked({
    required String id,
    required DateTime createdAt,
    required int utcOffset,
    required String reason,
    String? timezone,
    Geolocation? geolocation,
  }) = _TaskBlocked;

  factory TaskStatus.onHold({
    required String id,
    required DateTime createdAt,
    required int utcOffset,
    required String reason,
    String? timezone,
    Geolocation? geolocation,
  }) = _TaskOnHold;

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
    required DateTime dateFrom,
    required DateTime dateTo,
    required List<TaskStatus> statusHistory,
    required String title,
    DateTime? due,
    Duration? estimate,
    List<CheckListItem>? checklist,
  }) = _TaskData;

  factory TaskData.fromJson(Map<String, dynamic> json) =>
      _$TaskDataFromJson(json);
}

TaskStatus taskStatusFromString(String status) {
  TaskStatus newStatus;
  DateTime now = DateTime.now();

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
