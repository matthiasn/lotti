import 'dart:async';
import 'dart:developer' as developer;

import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/database/embedding_store.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/ollama_embedding_repository.dart';
import 'package:lotti/features/ai/service/embedding_processor.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/utils/consts.dart';

/// Background embedding generation service.
///
/// Listens to [UpdateNotifications.localUpdateStream] for entity changes
/// and generates embeddings for text-rich entries using Ollama's `/api/embed`.
///
/// Respects the [enableEmbeddingsFlag] config flag — when disabled, the
/// service silently drops all notifications.
///
/// Uses content hashing (SHA-256) to skip re-embedding unchanged content.
/// Processing is single-flight: only one embedding request runs at a time,
/// with a set for pending entity IDs.
class EmbeddingService {
  EmbeddingService({
    required this.embeddingStore,
    required this.embeddingRepository,
    required this.journalDb,
    required this.updateNotifications,
    required this.aiConfigRepository,
  });

  final EmbeddingStore embeddingStore;
  final OllamaEmbeddingRepository embeddingRepository;
  final JournalDb journalDb;
  final UpdateNotifications updateNotifications;
  final AiConfigRepository aiConfigRepository;

  StreamSubscription<Set<String>>? _subscription;
  final _pendingEntityIds = <String>{};
  bool _isProcessing = false;
  bool _stopped = false;
  Future<void>? _inFlightProcessing;

  /// The notification tokens that indicate an embeddable entity was changed.
  static const Set<String> _relevantTokens = {
    textEntryNotification,
    taskNotification,
    audioNotification,
    aiResponseNotification,
  };

  /// Starts listening to local update notifications.
  ///
  /// Idempotent — calling while already started is a no-op.
  void start() {
    if (_subscription != null) return;
    _stopped = false;
    _subscription = updateNotifications.localUpdateStream.listen(_onBatch);
  }

  /// Stops listening, clears pending work, and awaits any in-flight processing.
  ///
  /// Sets the [_stopped] flag so the processing loop exits after the current
  /// entity completes. In-flight work is awaited to ensure clean shutdown.
  Future<void> stop() async {
    _stopped = true;
    await _subscription?.cancel();
    _subscription = null;
    _pendingEntityIds.clear();
    final inFlight = _inFlightProcessing;
    _inFlightProcessing = null;
    if (inFlight != null) {
      // Ignore errors — _processEntity already handles them internally.
      await inFlight.catchError((_) {});
    }
  }

  void _onBatch(Set<String> tokens) {
    // Only process if the batch contains at least one relevant type token.
    final hasRelevantType = tokens.any(_relevantTokens.contains);
    if (!hasRelevantType) return;

    // Extract entity UUIDs from the batch (filter out type tokens).
    final entityIds = tokens.where(_isEntityId).toSet();
    if (entityIds.isEmpty) return;

    _pendingEntityIds.addAll(entityIds);
    // Only start a new processing future if one isn't already running.
    // Overwriting _inFlightProcessing while _isProcessing is true would
    // cause stop() to await a completed no-op instead of the real work.
    if (!_isProcessing) {
      _inFlightProcessing = _processNext();
      unawaited(_inFlightProcessing);
    }
  }

  Future<void> _processNext() async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      // Resolve config flag and base URL once per batch to avoid
      // redundant DB queries for each entity.
      final enabled = await journalDb.getConfigFlag(enableEmbeddingsFlag);
      if (!enabled) {
        _pendingEntityIds.clear();
        return;
      }

      final baseUrl = await aiConfigRepository.resolveOllamaBaseUrl();
      if (baseUrl == null) {
        _pendingEntityIds.clear();
        return;
      }

      // Cache label definitions for the batch to avoid one DB query per entity.
      // Best-effort: label resolution failures should not block core embeddings.
      LabelNameResolver? labelResolver;
      try {
        labelResolver = await EmbeddingProcessor.buildLabelResolver(journalDb);
      } on Object catch (e, stackTrace) {
        developer.log(
          'Failed to build label resolver; continuing without labels: $e',
          error: e,
          stackTrace: stackTrace,
          name: 'EmbeddingService',
        );
      }

      while (_pendingEntityIds.isNotEmpty && !_stopped) {
        final entityId = _pendingEntityIds.first;
        _pendingEntityIds.remove(entityId);

        try {
          await EmbeddingProcessor.processEntity(
            entityId: entityId,
            journalDb: journalDb,
            embeddingStore: embeddingStore,
            embeddingRepository: embeddingRepository,
            baseUrl: baseUrl,
            labelNameResolver: labelResolver,
          );
        } catch (e, stackTrace) {
          developer.log(
            'Failed to generate embedding for $entityId: $e',
            error: e,
            stackTrace: stackTrace,
            name: 'EmbeddingService',
          );
          // Swallow error — don't block other entities.
        }
      }
    } on Object catch (e, stackTrace) {
      developer.log(
        'Embedding batch preflight failed: $e',
        error: e,
        stackTrace: stackTrace,
        name: 'EmbeddingService',
      );
      _pendingEntityIds.clear();
    } finally {
      _isProcessing = false;
    }
  }

  /// Matches UUID format (8-4-4-4-12 hex digits) used for entity IDs.
  ///
  /// Notification type tokens are UPPER_SNAKE_CASE and never match this
  /// pattern, so this cleanly separates entity IDs from type markers.
  static final _uuidPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  static bool _isEntityId(String token) => _uuidPattern.hasMatch(token);
}
