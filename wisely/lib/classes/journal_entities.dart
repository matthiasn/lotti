import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:wisely/classes/geolocation.dart';
import 'package:wisely/classes/task.dart';
import 'package:wisely/sync/vector_clock.dart';

import 'entry_text.dart';

part 'journal_entities.freezed.dart';
part 'journal_entities.g.dart';

@freezed
class JournalEntity with _$JournalEntity {
  factory JournalEntity.journalEntry({
    required String id,
    required int timestamp,
    required DateTime createdAt,
    int? utcOffset,
    String? timezone,
    DateTime? updatedAt,
    Geolocation? geolocation,
    VectorClock? vectorClock,
    EntryText? entryText,
    List<String>? linkedImageIds,
    List<String>? linkedAudioNoteIds,
    Task? task,
  }) = JournalEntry;

  factory JournalEntity.journalImage({
    required String id,
    required String imageId,
    required String imageFile,
    required String imageDirectory,
    required DateTime createdAt,
    int? utcOffset,
    String? timezone,
    EntryText? entryText,
    Geolocation? geolocation,
    VectorClock? vectorClock,
  }) = JournalImage;

  factory JournalEntity.audioNote({
    required String id,
    required int timestamp,
    required DateTime createdAt,
    required String audioFile,
    required String audioDirectory,
    required Duration duration,
    int? utcOffset,
    String? timezone,
    DateTime? updatedAt,
    String? transcript,
    EntryText? entryText,
    Geolocation? geolocation,
    VectorClock? vectorClock,
  }) = AudioNote;

  factory JournalEntity.fromJson(Map<String, dynamic> json) =>
      _$JournalEntityFromJson(json);
}
