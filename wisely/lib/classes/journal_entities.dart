import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:wisely/classes/geolocation.dart';
import 'package:wisely/classes/task.dart';
import 'package:wisely/sync/vector_clock.dart';

import 'check_list_item.dart';
import 'entry_text.dart';

part 'journal_entities.freezed.dart';
part 'journal_entities.g.dart';

abstract class CommonJournalFields {
  String get id;
  DateTime get createdAt;
  DateTime get updatedAt;
  DateTime get dateFrom;
  DateTime get dateTo;
  int? get utcOffset;
  String? get timezone;
  VectorClock? get vectorClock;
}

abstract class TextJournalFields {
  EntryText? get entryText;
}

abstract class GeoJournalFields {
  Geolocation? get geolocation;
}

abstract class LinkedJournalFields {
  List<String> get linkedIds;
}

@freezed
class JournalEntity with _$JournalEntity {
  @Implements<CommonJournalFields>()
  @Implements<TextJournalFields>()
  @Implements<GeoJournalFields>()
  factory JournalEntity.journalEntry({
    // common fields:
    required String id,
    required DateTime createdAt,
    required DateTime updatedAt,
    required DateTime dateFrom,
    required DateTime dateTo,
    int? utcOffset,
    String? timezone,
    VectorClock? vectorClock,
    // shared fields:
    EntryText? entryText,
    Geolocation? geolocation,
    // end shared fields
  }) = JournalEntry;

  @Implements<CommonJournalFields>()
  @Implements<TextJournalFields>()
  @Implements<GeoJournalFields>()
  const factory JournalEntity.journalDbImage({
    // common fields:
    required String id,
    required DateTime createdAt,
    required DateTime updatedAt,
    required DateTime dateFrom,
    required DateTime dateTo,
    int? utcOffset,
    String? timezone,
    VectorClock? vectorClock,
    // shared fields:
    EntryText? entryText,
    Geolocation? geolocation,
    // end shared fields

    required DateTime capturedAt,
    required String imageId,
    required String imageFile,
    required String imageDirectory,
  }) = JournalDbImage;

  @Implements<CommonJournalFields>()
  @Implements<TextJournalFields>()
  @Implements<GeoJournalFields>()
  const factory JournalEntity.journalDbAudio({
    // common fields:
    required String id,
    required DateTime createdAt,
    required DateTime updatedAt,
    required DateTime dateFrom,
    required DateTime dateTo,
    int? utcOffset,
    String? timezone,
    VectorClock? vectorClock,
    // shared fields:
    EntryText? entryText,
    Geolocation? geolocation,
    // end shared fields

    required String audioFile,
    required String audioDirectory,
    required Duration duration,
    String? transcript,
  }) = JournalDbAudio;

  @Implements<CommonJournalFields>()
  @Implements<TextJournalFields>()
  @Implements<GeoJournalFields>()
  const factory JournalEntity.loggedTime({
    // common fields:
    required String id,
    required DateTime createdAt,
    required DateTime updatedAt,
    required DateTime dateFrom,
    required DateTime dateTo,
    int? utcOffset,
    String? timezone,
    VectorClock? vectorClock,
    // shared fields:
    EntryText? entryText,
    Geolocation? geolocation,
    // end shared fields
  }) = LoggedTime;

  @Implements<CommonJournalFields>()
  @Implements<TextJournalFields>()
  @Implements<GeoJournalFields>()
  const factory JournalEntity.task({
    // common fields:
    required String id,
    required DateTime createdAt,
    required DateTime updatedAt,
    required DateTime dateFrom,
    required DateTime dateTo,
    int? utcOffset,
    String? timezone,
    VectorClock? vectorClock,
    // shared fields:
    EntryText? entryText,
    Geolocation? geolocation,
    // end shared fields

    required TaskStatus status,
    required List<TaskStatus> statusHistory,
    required String title,
    List<CheckListItem>? checklist,
  }) = Task;

  @Implements<CommonJournalFields>()
  const factory JournalEntity.cumulativeQuantity({
    // common fields:
    required String id,
    required DateTime createdAt,
    required DateTime updatedAt,
    required DateTime dateFrom,
    required DateTime dateTo,
    int? utcOffset,
    String? timezone,
    VectorClock? vectorClock,
    // common fields end

    required num value,
    required String dataType,
    required String unit,
    String? deviceType,
    String? platformType,
  }) = CumulativeQuantity;

  @Implements<CommonJournalFields>()
  const factory JournalEntity.discreteQuantity({
    // common fields:
    required String id,
    required DateTime createdAt,
    required DateTime updatedAt,
    required DateTime dateFrom,
    required DateTime dateTo,
    int? utcOffset,
    String? timezone,
    VectorClock? vectorClock,
    // common fields end

    required num value,
    required String dataType,
    required String unit,
    String? deviceType,
    String? platformType,
    String? sourceName,
    String? sourceId,
    String? deviceId,
  }) = DiscreteQuantity;

  factory JournalEntity.fromJson(Map<String, dynamic> json) =>
      _$JournalEntityFromJson(json);
}
