import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/classes/checklist_data.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/event_data.dart';
import 'package:lotti/classes/geolocation.dart';
import 'package:lotti/classes/health.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:research_package/model.dart';

part 'journal_entities.freezed.dart';
part 'journal_entities.g.dart';

enum EntryFlag {
  none,
  import,
  followUpNeeded,
}

@freezed
class Metadata with _$Metadata {
  const factory Metadata({
    required String id,
    required DateTime createdAt,
    required DateTime updatedAt,
    required DateTime dateFrom,
    required DateTime dateTo,
    String? categoryId,
    List<String>? tags,
    List<String>? tagIds,
    int? utcOffset,
    String? timezone,
    VectorClock? vectorClock,
    DateTime? deletedAt,
    EntryFlag? flag,
    bool? starred,
    bool? private,
  }) = _Metadata;

  factory Metadata.fromJson(Map<String, dynamic> json) =>
      _$MetadataFromJson(json);
}

@freezed
class ImageData with _$ImageData {
  const factory ImageData({
    required DateTime capturedAt,
    required String imageId,
    required String imageFile,
    required String imageDirectory,
    Geolocation? geolocation,
  }) = _ImageData;

  factory ImageData.fromJson(Map<String, dynamic> json) =>
      _$ImageDataFromJson(json);
}

@freezed
class AudioData with _$AudioData {
  const factory AudioData({
    required DateTime dateFrom,
    required DateTime dateTo,
    required String audioFile,
    required String audioDirectory,
    required Duration duration,
    @Default(false) bool autoTranscribeWasActive,
    String? language,
    List<AudioTranscript>? transcripts,
  }) = _AudioData;

  factory AudioData.fromJson(Map<String, dynamic> json) =>
      _$AudioDataFromJson(json);
}

@freezed
class AudioTranscript with _$AudioTranscript {
  const factory AudioTranscript({
    required DateTime created,
    required String library,
    required String model,
    required String detectedLanguage,
    required String transcript,
    Duration? processingTime,
  }) = _AudioTranscript;

  factory AudioTranscript.fromJson(Map<String, dynamic> json) =>
      _$AudioTranscriptFromJson(json);
}

@freezed
class SurveyData with _$SurveyData {
  const factory SurveyData({
    required RPTaskResult taskResult,
    required Map<String, Set<String>> scoreDefinitions,
    required Map<String, int> calculatedScores,
  }) = _SurveyData;

  factory SurveyData.fromJson(Map<String, dynamic> json) =>
      _$SurveyDataFromJson(json);
}

@freezed
class JournalEntity with _$JournalEntity {
  const factory JournalEntity.journalEntry({
    required Metadata meta,
    EntryText? entryText,
    Geolocation? geolocation,
  }) = JournalEntry;

  const factory JournalEntity.journalImage({
    required Metadata meta,
    required ImageData data,
    EntryText? entryText,
    Geolocation? geolocation,
  }) = JournalImage;

  const factory JournalEntity.journalAudio({
    required Metadata meta,
    required AudioData data,
    EntryText? entryText,
    Geolocation? geolocation,
  }) = JournalAudio;

  const factory JournalEntity.task({
    required Metadata meta,
    required TaskData data,
    EntryText? entryText,
    Geolocation? geolocation,
  }) = Task;

  const factory JournalEntity.event({
    required Metadata meta,
    required EventData data,
    EntryText? entryText,
    Geolocation? geolocation,
  }) = JournalEvent;

  const factory JournalEntity.checklistItem({
    required Metadata meta,
    required ChecklistItemData data,
    EntryText? entryText,
    Geolocation? geolocation,
  }) = ChecklistItem;

  const factory JournalEntity.checklist({
    required Metadata meta,
    required ChecklistData data,
    EntryText? entryText,
    Geolocation? geolocation,
  }) = Checklist;

  const factory JournalEntity.quantitative({
    required Metadata meta,
    required QuantitativeData data,
    EntryText? entryText,
    Geolocation? geolocation,
  }) = QuantitativeEntry;

  const factory JournalEntity.measurement({
    required Metadata meta,
    required MeasurementData data,
    EntryText? entryText,
    Geolocation? geolocation,
  }) = MeasurementEntry;

  const factory JournalEntity.aiResponse({
    required Metadata meta,
    required AiResponseData data,
    EntryText? entryText,
    Geolocation? geolocation,
  }) = AiResponseEntry;

  const factory JournalEntity.workout({
    required Metadata meta,
    required WorkoutData data,
    EntryText? entryText,
    Geolocation? geolocation,
  }) = WorkoutEntry;

  const factory JournalEntity.habitCompletion({
    required Metadata meta,
    required HabitCompletionData data,
    EntryText? entryText,
    Geolocation? geolocation,
  }) = HabitCompletionEntry;

  const factory JournalEntity.survey({
    required Metadata meta,
    required SurveyData data,
    EntryText? entryText,
    Geolocation? geolocation,
  }) = SurveyEntry;

  factory JournalEntity.fromJson(Map<String, dynamic> json) =>
      _$JournalEntityFromJson(json);
}

extension JournalEntityExtension on JournalEntity {
  String get id => meta.id;
  String? get categoryId => meta.categoryId;
  bool get isDeleted => meta.deletedAt != null;

  Set<String> get affectedIds {
    final ids = <String>{id};

    switch (this) {
      case final HabitCompletionEntry habitCompletion:
        ids
          ..add(habitCompletion.data.habitId)
          ..add(habitCompletionNotification);

      case final Checklist checklist:
        ids
          ..addAll(checklist.data.linkedChecklistItems)
          ..addAll(checklist.data.linkedTasks);

      case final ChecklistItem checklistItem:
        ids.addAll(checklistItem.data.linkedChecklists);

      case final QuantitativeEntry quantitative:
        ids.add(quantitative.data.dataType);

      case SurveyEntry():
        ids.add(surveyNotification);

      case JournalEvent():
        ids.add(eventNotification);

      case JournalImage():
        ids.add(imageNotification);

      case JournalAudio():
        ids.add(audioNotification);

      case Task():
        ids.add(taskNotification);

      case AiResponseEntry():
        ids.add(aiResponseNotification);

      case JournalEntry():
        ids.add(textEntryNotification);

      case final WorkoutEntry workout:
        ids
          ..add(workoutNotification)
          ..add(workout.data.workoutType);

      case final MeasurementEntry measurement:
        ids.add(measurement.data.dataTypeId);
    }

    return ids;
  }
}
