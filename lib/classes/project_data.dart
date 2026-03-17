import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/classes/geolocation.dart';

part 'project_data.freezed.dart';
part 'project_data.g.dart';

@freezed
sealed class ProjectStatus with _$ProjectStatus {
  const factory ProjectStatus.open({
    required String id,
    required DateTime createdAt,
    required int utcOffset,
    String? timezone,
    Geolocation? geolocation,
  }) = ProjectOpen;

  const factory ProjectStatus.active({
    required String id,
    required DateTime createdAt,
    required int utcOffset,
    String? timezone,
    Geolocation? geolocation,
  }) = ProjectActive;

  const factory ProjectStatus.onHold({
    required String id,
    required DateTime createdAt,
    required int utcOffset,
    required String reason,
    String? timezone,
    Geolocation? geolocation,
  }) = ProjectOnHold;

  const factory ProjectStatus.completed({
    required String id,
    required DateTime createdAt,
    required int utcOffset,
    String? timezone,
    Geolocation? geolocation,
  }) = ProjectCompleted;

  const factory ProjectStatus.archived({
    required String id,
    required DateTime createdAt,
    required int utcOffset,
    String? timezone,
    Geolocation? geolocation,
  }) = ProjectArchived;

  factory ProjectStatus.fromJson(Map<String, dynamic> json) =>
      _$ProjectStatusFromJson(json);
}

@freezed
abstract class ProjectData with _$ProjectData {
  const factory ProjectData({
    required String title,
    required ProjectStatus status,
    required DateTime dateFrom,
    required DateTime dateTo,
    @Default([]) List<ProjectStatus> statusHistory,
    DateTime? targetDate,

    /// Inference profile ID for the project agent.
    String? profileId,

    /// ID of a linked JournalImage to use as cover art.
    String? coverArtId,

    /// Horizontal offset for square thumbnail crop from 2:1 cover art.
    @Default(0.5) double coverArtCropX,
  }) = _ProjectData;

  factory ProjectData.fromJson(Map<String, dynamic> json) =>
      _$ProjectDataFromJson(json);
}

extension ProjectStatusExtension on ProjectStatus {
  String get toDbString => switch (this) {
    ProjectOpen() => 'OPEN',
    ProjectActive() => 'ACTIVE',
    ProjectOnHold() => 'ON HOLD',
    ProjectCompleted() => 'COMPLETED',
    ProjectArchived() => 'ARCHIVED',
  };
}
