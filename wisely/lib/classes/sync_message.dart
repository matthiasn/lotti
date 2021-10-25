import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:wisely/classes/audio_note.dart';
import 'package:wisely/classes/journal_entry.dart';
import 'package:wisely/classes/journal_image.dart';
import 'package:wisely/sync/vector_clock.dart';

part 'sync_message.freezed.dart';
part 'sync_message.g.dart';

@freezed
class SyncMessage with _$SyncMessage {
  factory SyncMessage.audioNote({
    required AudioNote audioNote,
    required VectorClock vectorClock,
  }) = SyncAudioNote;

  factory SyncMessage.image({
    required JournalImage journalImage,
    required VectorClock vectorClock,
  }) = SyncImage;

  factory SyncMessage.journalEntry({
    required JournalEntry journalEntry,
    required VectorClock vectorClock,
  }) = SyncJournalEntry;

  factory SyncMessage.fromJson(Map<String, dynamic> json) =>
      _$SyncMessageFromJson(json);
}
