import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/tag_type_definitions.dart';

part 'sync_message.freezed.dart';
part 'sync_message.g.dart';

enum SyncEntryStatus { initial, update }

@freezed
class SyncMessage with _$SyncMessage {
  const factory SyncMessage.journalEntity({
    required JournalEntity journalEntity,
    required SyncEntryStatus status,
  }) = SyncJournalEntity;

  const factory SyncMessage.entityDefinition({
    required EntityDefinition entityDefinition,
    required SyncEntryStatus status,
  }) = SyncEntityDefinition;

  const factory SyncMessage.tagEntity({
    required TagEntity tagEntity,
    required SyncEntryStatus status,
  }) = SyncTagEntity;

  const factory SyncMessage.entryLink({
    required EntryLink entryLink,
    required SyncEntryStatus status,
  }) = SyncEntryLink;

  factory SyncMessage.fromJson(Map<String, dynamic> json) =>
      _$SyncMessageFromJson(json);
}
