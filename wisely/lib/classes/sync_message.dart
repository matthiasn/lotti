import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:wisely/classes/journal_db_entities.dart';

part 'sync_message.freezed.dart';
part 'sync_message.g.dart';

@freezed
class SyncMessage with _$SyncMessage {
  factory SyncMessage.journalDbEntity({
    required JournalDbEntity journalEntity,
  }) = SyncJournalDbEntity;

  factory SyncMessage.fromJson(Map<String, dynamic> json) =>
      _$SyncMessageFromJson(json);
}
