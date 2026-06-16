import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/sync/model/sync_node_profile.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_payload_type.dart';
import 'package:lotti/features/sync/vector_clock.dart';

part 'sync_message.freezed.dart';
part 'sync_message.g.dart';

/// Whether a journal entity sync payload is the entry's first appearance
/// ([initial]) or a later revision ([update]). [initial] forces attachments to
/// be (re)sent; [update] sends them only when the resend flag is set.
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

/// The sealed envelope for every message that crosses the wire between
/// devices.
///
/// One variant per payload kind — journal entities, entry links, agent
/// entities/links, AI config, entity definitions, config flags, theming,
/// notifications and their state updates, sync-node profiles, backfill
/// request/response, and the dequeue-time `outboxBundle` that packs several of
/// the above into one Matrix event. The outbox enqueues these, the
/// `OutboxProcessor` sends them, and the inbound pipeline pattern-matches on
/// the variant to apply each one. Serialised to/from JSON via the generated
/// `fromJson`/`toJson`.
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

    /// Vector clocks covered by this payload, including the current vector
    /// clock and superseded outbox entries. Receivers should pre-mark
    /// superseded counters as covered/received to prevent false gap detection;
    /// the current vector clock is ignored for pre-marking.
    List<VectorClock>? coveredVectorClocks,
  }) = SyncJournalEntity;

  const factory SyncMessage.entityDefinition({
    required EntityDefinition entityDefinition,
    required SyncEntryStatus status,
  }) = SyncEntityDefinition;

  const factory SyncMessage.entryLink({
    required EntryLink entryLink,
    required SyncEntryStatus status,

    /// The host UUID that created/modified this entry link version.
    /// Used for sequence tracking to detect gaps in sync.
    String? originatingHostId,

    /// Vector clocks covered by this payload, including the current vector
    /// clock and superseded outbox entries. Receivers should pre-mark
    /// superseded counters as covered/received to prevent false gap detection;
    /// the current vector clock is ignored for pre-marking.
    List<VectorClock>? coveredVectorClocks,
  }) = SyncEntryLink;

  const factory SyncMessage.aiConfig({
    required AiConfig aiConfig,
    required SyncEntryStatus status,
  }) = SyncAiConfig;

  /// A node's self-description (name, platform, capabilities).
  ///
  /// Carries no vector clock — receivers upsert by `profile.hostId` and use
  /// `profile.updatedAt` for last-write-wins. Profiles are presence-style
  /// state, not journal data, so they don't participate in gap detection.
  const factory SyncMessage.syncNodeProfile({
    required SyncNodeProfile profile,
  }) = SyncSyncNodeProfile;

  const factory SyncMessage.aiConfigDelete({
    required String id,
  }) = SyncAiConfigDelete;

  const factory SyncMessage.configFlag({
    required String name,
    required String description,
    required bool status,
    String? originatingHostId,
  }) = SyncConfigFlag;

  const factory SyncMessage.themingSelection({
    required String lightThemeName,
    required String darkThemeName,
    required String themeMode,
    required int updatedAt,
    required SyncEntryStatus status,
  }) = SyncThemingSelection;

  const factory SyncMessage.notification({
    required String id,
    required String jsonPath,
    required VectorClock vectorClock,
    required String originatingHostId,
    List<VectorClock>? coveredVectorClocks,
  }) = SyncNotification;

  const factory SyncMessage.notificationStateUpdate({
    required String id,
    required VectorClock vectorClock,
    required String originatingHostId,
    DateTime? seenAt,
    DateTime? actedOnAt,
    DateTime? deletedAt,
  }) = SyncNotificationStateUpdate;

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
  /// If unresolvable is true, the originating host cannot resolve its own
  /// counter (e.g., it was superseded before being recorded).
  /// Otherwise, the actual entry will be sent via a separate SyncJournalEntity.
  const factory SyncMessage.backfillResponse({
    /// The host UUID that originated the entry
    required String hostId,

    /// The monotonic counter for that host
    required int counter,

    /// True if the entry was deleted/purged and cannot be backfilled
    required bool deleted,

    /// True if the originating host cannot resolve its own counter.
    /// This happens when a counter was superseded before being recorded
    /// (e.g., rapid edits where intermediate versions were never persisted).
    /// Receivers should mark this counter as permanently unresolvable.
    bool? unresolvable,

    /// Legacy: The journal entry ID if found (null if deleted).
    ///
    /// For newer clients, prefer `payloadType` + `payloadId`.
    String? entryId,

    /// Identifies what kind of payload this backfill response refers to.
    /// If omitted, defaults to `SyncSequencePayloadType.journalEntity`.
    SyncSequencePayloadType? payloadType,

    /// The payload ID if found (null if deleted). For journal entities this is
    /// the journal entry ID, for entry links it's the link ID.
    String? payloadId,
  }) = SyncBackfillResponse;

  const factory SyncMessage.agentEntity({
    required SyncEntryStatus status,
    AgentDomainEntity? agentEntity,
    String? jsonPath,

    /// The host UUID that created/modified this agent entity version.
    /// Used for sequence tracking to detect gaps in sync.
    String? originatingHostId,

    /// Vector clocks covered by this payload, including the current vector
    /// clock and superseded outbox entries.
    List<VectorClock>? coveredVectorClocks,
  }) = SyncAgentEntity;

  const factory SyncMessage.agentLink({
    required SyncEntryStatus status,
    AgentLink? agentLink,
    String? jsonPath,

    /// The host UUID that created/modified this agent link version.
    /// Used for sequence tracking to detect gaps in sync.
    String? originatingHostId,

    /// Vector clocks covered by this payload, including the current vector
    /// clock and superseded outbox entries.
    List<VectorClock>? coveredVectorClocks,
  }) = SyncAgentLink;

  /// A wake-scoped bundle of agent entity/link mutations.
  ///
  /// Outbound wake runs write many agent entities and links in one logical
  /// cycle. The bundle keeps the per-item sync semantics intact while allowing
  /// the outbox to send a single sync envelope for the completed wake.
  const factory SyncMessage.agentBundle({
    required String agentId,
    required String wakeRunKey,
    @Default(<SyncAgentEntity>[]) List<SyncAgentEntity> entities,
    @Default(<SyncAgentLink>[]) List<SyncAgentLink> links,
    String? jsonPath,
    String? originatingHostId,
  }) = SyncAgentBundle;

  /// A dequeue-time bundle of text-only outbox rows.
  ///
  /// Built by `OutboxProcessor` to ship up to `SyncTuning.outboxBundleMaxSize`
  /// pending text rows in a single Matrix envelope. Children are applied in
  /// order on the receiver, exactly as if delivered individually. Children
  /// must not themselves be `SyncOutboxBundle` (no nesting) and must not carry
  /// media attachments — attachments always travel alone.
  const factory SyncMessage.outboxBundle({
    required List<SyncMessage> children,
    String? jsonPath,
    String? originatingHostId,
  }) = SyncOutboxBundle;

  factory SyncMessage.fromJson(Map<String, dynamic> json) =>
      _$SyncMessageFromJson(json);
}
