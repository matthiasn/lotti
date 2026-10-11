import 'package:lotti/classes/sync_sequence_payload_type.dart';
import 'package:lotti/classes/vector_clock.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/sync/deep_backfill/deep_backfill_store.dart';
import 'package:lotti/services/outbox_service.dart';

/// AI configurations — providers, models, prompts, inference profiles and
/// skills — read from `ai_config_versions`, the one row per id that holds the
/// stamp and the clock of the version this device keeps (ADR 0136). A hard
/// deletion has no config row but keeps its version row, so it is listed and
/// resent like a live one. Versions are ordered by their stamp, not their
/// clock; a resend carries both, and the receiver keeps whichever wins.
class AiConfigDeepBackfillStore extends DeepBackfillStore {
  AiConfigDeepBackfillStore({
    required AiConfigRepository aiConfigRepository,
    required this._outboxService,
  }) : _repository = aiConfigRepository,
       _queries = DeepBackfillTableQueries(
         db: aiConfigRepository.configDb,
         table: 'ai_config_versions',
         clockSql: 'vector_clock',
       );

  final AiConfigRepository _repository;
  final OutboxService _outboxService;
  final DeepBackfillTableQueries _queries;

  @override
  SyncSequencePayloadType get payloadType => SyncSequencePayloadType.aiConfig;

  @override
  Future<int> count() => _queries.count();

  @override
  Stream<void> get changes => _queries.changes;

  @override
  Future<List<DeepBackfillRow>> page({
    required String? after,
    required int limit,
  }) => _queries.page(after: after, limit: limit);

  @override
  Future<Map<String, VectorClock?>> range({
    required String? start,
    required String? end,
  }) => _queries.range(start: start, end: end);

  /// Sends the version each id holds now, a provider with its key from this
  /// device's keychain, or its hard deletion.
  @override
  Future<int> enqueueCurrent(
    Set<String> ids, {
    required Set<String> withMedia,
  }) async {
    var sent = 0;
    for (final id in ids) {
      final held = await _repository.heldVersion(id);
      if (held == null) continue;
      await _outboxService.enqueueMessage(held.toSyncMessage());
      sent++;
    }
    return sent;
  }
}
