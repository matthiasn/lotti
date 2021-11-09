import 'package:freezed_annotation/freezed_annotation.dart';

import 'journal_entities.dart';

part 'sync_message.freezed.dart';
part 'sync_message.g.dart';

@freezed
class SyncMessage with _$SyncMessage {
  factory SyncMessage.syncJournalEntity({
    required JournalEntity journalEntity,
  }) = SyncJournalEntity;

  factory SyncMessage.syncQuantitativeEntries({
    required List<QuantitativeEntry> entries,
  }) = SyncQuantitativeEntries;

  factory SyncMessage.fromJson(Map<String, dynamic> json) =>
      _$SyncMessageFromJson(json);
}
