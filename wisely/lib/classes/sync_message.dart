import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:wisely/classes/journal_entities.dart';
import 'package:wisely/sync/vector_clock.dart';

part 'sync_message.freezed.dart';
part 'sync_message.g.dart';

@freezed
class SyncMessage with _$SyncMessage {
  factory SyncMessage.journalEntity({
    required JournalEntity journalEntity,
    required VectorClock vectorClock,
  }) = SyncJournalEntity;

  factory SyncMessage.fromJson(Map<String, dynamic> json) =>
      _$SyncMessageFromJson(json);
}
