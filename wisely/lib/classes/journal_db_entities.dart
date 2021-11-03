import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:wisely/classes/geolocation.dart';
import 'package:wisely/classes/task.dart';
import 'package:wisely/sync/vector_clock.dart';

import 'check_list_item.dart';
import 'entry_text.dart';

part 'journal_db_entities.freezed.dart';
part 'journal_db_entities.g.dart';

@freezed
class JournalDbEntityData with _$JournalDbEntityData {
  factory JournalDbEntityData.journalEntry() = JournalEntry;

  factory JournalDbEntityData.journalImage({
    required DateTime capturedAt,
    required String imageId,
    required String imageFile,
    required String imageDirectory,
  }) = JournalImage;

  factory JournalDbEntityData.audioNote({
    required DateTime dateFrom,
    required DateTime dateTo,
    required String audioFile,
    required String audioDirectory,
    required Duration duration,
    String? transcript,
  }) = AudioNote;

  factory JournalDbEntityData.loggedTime({
    required DateTime dateFrom,
    required DateTime dateTo,
  }) = LoggedTime;

  factory JournalDbEntityData.task({
    required TaskStatus status,
    required List<TaskStatus> statusHistory,
    required String title,
    List<CheckListItem>? checklist,
  }) = Task;

  factory JournalDbEntityData.cumulativeQuantity({
    required DateTime dateFrom,
    required DateTime dateTo,
    required num value,
    required String dataType,
    required String unit,
    String? deviceType,
    String? platformType,
  }) = CumulativeQuantity;

  factory JournalDbEntityData.discreteQuantity({
    required DateTime dateFrom,
    required DateTime dateTo,
    required num value,
    required String dataType,
    required String unit,
    String? deviceType,
    String? platformType,
    String? sourceName,
    String? sourceId,
    String? deviceId,
  }) = DiscreteQuantity;

  factory JournalDbEntityData.fromJson(Map<String, dynamic> json) =>
      _$JournalDbEntityDataFromJson(json);
}

@freezed
class JournalDbEntity with _$JournalDbEntity {
  factory JournalDbEntity.journalDbEntry({
    required String id,
    required DateTime createdAt,
    required JournalDbEntityData data,
    int? utcOffset,
    String? timezone,
    DateTime? updatedAt,
    Geolocation? geolocation,
    VectorClock? vectorClock,
    EntryText? entryText,
    List<String>? linked,
  }) = JournalDbEntry;

  factory JournalDbEntity.fromJson(Map<String, dynamic> json) =>
      _$JournalDbEntityFromJson(json);
}
