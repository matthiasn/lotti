import 'dart:async';
import 'dart:developer' as developer;

import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/database/embeddings_db.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/ollama_embedding_repository.dart';
import 'package:lotti/features/ai/service/embedding_content_extractor.dart';
import 'package:lotti/features/ai/state/consts.dart';
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
    required this.embeddingsDb,
    required this.embeddingRepository,
    required this.journalDb,
    required this.updateNotifications,
    required this.aiConfigRepository,
  });

  final EmbeddingsDb embeddingsDb;
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
    _inFlightProcessing = _processNext();
    unawaited(_inFlightProcessing);
  }

  Future<void> _processNext() async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      while (_pendingEntityIds.isNotEmpty && !_stopped) {
        final entityId = _pendingEntityIds.first;
        _pendingEntityIds.remove(entityId);

        await _processEntity(entityId);
      }
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> _processEntity(String entityId) async {
    try {
      // Check config flag before each entity (user may toggle mid-processing).
      final enabled = await journalDb.getConfigFlag(enableEmbeddingsFlag);
      if (!enabled) return;

      // Load entity from DB.
      final entity = await journalDb.journalEntityById(entityId);
      if (entity == null) return;

      // Extract embeddable text.
      final text = EmbeddingContentExtractor.extractText(entity);
      if (text == null) return;

      // Determine entity type.
      final type = EmbeddingContentExtractor.entityType(entity);
      if (type == null) return;

      // Check content hash — skip if unchanged.
      final hash = EmbeddingContentExtractor.contentHash(text);
      final existingHash = embeddingsDb.getContentHash(entityId);
      if (existingHash == hash) return;

      // Resolve Ollama base URL.
      final baseUrl = await _resolveOllamaBaseUrl();
      if (baseUrl == null) {
        developer.log(
          'No Ollama provider configured — skipping embedding for $entityId',
          name: 'EmbeddingService',
        );
        return;
      }

      // Generate embedding via Ollama.
      final embedding = await embeddingRepository.embed(
        input: text,
        baseUrl: baseUrl,
      );

      // Store in embeddings DB.
      embeddingsDb.upsertEmbedding(
        entityId: entityId,
        entityType: type,
        modelId: ollamaEmbedDefaultModel,
        embedding: embedding,
        contentHash: hash,
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

  /// Resolves the base URL of the first configured Ollama provider.
  ///
  /// Returns `null` if no Ollama provider is configured.
  Future<String?> _resolveOllamaBaseUrl() async {
    final providers = await aiConfigRepository
        .getConfigsByType(AiConfigType.inferenceProvider);
    final ollamaProvider = providers
        .whereType<AiConfigInferenceProvider>()
        .where(
          (p) => p.inferenceProviderType == InferenceProviderType.ollama,
        )
        .firstOrNull;
    return ollamaProvider?.baseUrl;
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
