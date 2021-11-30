import 'package:freezed_annotation/freezed_annotation.dart';

import 'journal_entities.dart';

part 'sync_message.freezed.dart';
part 'sync_message.g.dart';

enum SyncEntryStatus { initial, update }

@freezed
class SyncMessage with _$SyncMessage {
  factory SyncMessage.journalDbEntity({
    required JournalEntity journalEntity,
    required SyncEntryStatus status,
  }) = SyncJournalDbEntity;

  factory SyncMessage.fromJson(Map<String, dynamic> json) =>
      _$SyncMessageFromJson(json);
}
