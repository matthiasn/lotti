import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/sync/vector_clock.dart';

part 'sync_message.freezed.dart';
part 'sync_message.g.dart';

enum SyncEntryStatus { initial, update }

/// A single entry in a batched backfill request.
@freezed
abstract class BackfillRequestEntry with _$BackfillRequestEntry {
  const factory BackfillRequestEntry({
    /// The host UUID that originated the missing entry
    required String hostId,

    /// The monotonic counter for that host
    required int counter,
  }) = _BackfillRequestEntry;

  factory BackfillRequestEntry.fromJson(Map<String, dynamic> json) =>
      _$BackfillRequestEntryFromJson(json);
}

@freezed
sealed class SyncMessage with _$SyncMessage {
  const factory SyncMessage.journalEntity({
    required String id,
    required String jsonPath,
    required VectorClock? vectorClock,
    required SyncEntryStatus status,
    List<EntryLink>? entryLinks,

    /// The host UUID that created/modified this entry version.
    /// Used for sequence tracking to detect gaps in sync.
    String? originatingHostId,
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

  const factory SyncMessage.aiConfig({
    required AiConfig aiConfig,
    required SyncEntryStatus status,
  }) = SyncAiConfig;

  const factory SyncMessage.aiConfigDelete({
    required String id,
  }) = SyncAiConfigDelete;

  const factory SyncMessage.themingSelection({
    required String lightThemeName,
    required String darkThemeName,
    required String themeMode,
    required int updatedAt,
    required SyncEntryStatus status,
  }) = SyncThemingSelection;

  /// Request to backfill missing entries identified by host ID and counter.
  /// Broadcast to all devices; any device with the entries can respond.
  /// Batched to reduce message overhead (up to 100 entries per request).
  const factory SyncMessage.backfillRequest({
    /// List of missing entries to request, each with hostId and counter
    required List<BackfillRequestEntry> entries,

    /// The host UUID of the device requesting the backfill
    required String requesterId,
  }) = SyncBackfillRequest;

  /// Response to a backfill request.
  /// If deleted is true, the entry was purged and no longer exists.
  /// Otherwise, the actual entry will be sent via a separate SyncJournalEntity.
  const factory SyncMessage.backfillResponse({
    /// The host UUID that originated the entry
    required String hostId,

    /// The monotonic counter for that host
    required int counter,

    /// True if the entry was deleted/purged and cannot be backfilled
    required bool deleted,

    /// The entry ID if found (null if deleted)
    String? entryId,
  }) = SyncBackfillResponse;

  factory SyncMessage.fromJson(Map<String, dynamic> json) =>
      _$SyncMessageFromJson(json);
}
