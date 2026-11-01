import 'dart:async';

import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/database/embedding_store.dart';
import 'package:lotti/features/ai/on_device_embedding/on_device_embedding_repository.dart';
import 'package:lotti/features/ai/service/embedding_processor.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/utils/consts.dart';

/// Background embedding generation service.
///
/// Listens to [UpdateNotifications.localUpdateStream] for entity changes
/// and generates embeddings for text-rich entries with the on-device model.
///
/// Respects the [enableEmbeddingsFlag] config flag — when disabled, the
/// service silently drops all notifications — and does nothing while the
/// model is not downloaded: the backfill after the download is the repair.
///
/// Uses content hashing (SHA-256) to skip re-embedding unchanged content.
/// Processing is single-flight: only one embedding request runs at a time,
/// with a set for pending entity IDs.
///
/// **A failed id is retried, not dropped.** An id whose processing throws is
/// kept and queued again once [retryDelay] has passed. It is dropped after
/// [maxFailedAttempts] failures in a row, so an entity that fails the same
/// way every time — a store that rejects it, a model that cannot read it —
/// is given up on rather than retried for as long as the app runs; its next
/// edit starts again. The retry set lives in memory: a restart loses it, and
/// the manual backfill is the repair.
class EmbeddingService {
  EmbeddingService({
    required this.embeddingStore,
    required this.embeddingRepository,
    required this.journalDb,
    required this.updateNotifications,
    required this._domainLogger,
  });

  static const _subDomain = 'EmbeddingService';

  final EmbeddingStore embeddingStore;
  final OnDeviceEmbeddingRepository embeddingRepository;
  final JournalDb journalDb;
  final UpdateNotifications updateNotifications;

  /// Receives the failures of a batch and of each entity in it.
  final DomainLogger _domainLogger;

  /// How long a failed id waits before it is retried.
  static const Duration retryDelay = Duration(minutes: 5);

  /// After this many failures in a row an id is dropped instead of retried.
  static const int maxFailedAttempts = 3;

  StreamSubscription<Set<String>>? _subscription;
  final _pendingEntityIds = <String>{};
  final _retryEntityIds = <String>{};
  final _failedAttempts = <String, int>{};
  Timer? _retryTimer;
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

  /// Starts listening to local update notifications, and queues the tasks
  /// that carry a private label (see [_queuePrivateLabelledTasks]) as the
  /// first batch that finds embeddings on and the model downloaded.
  ///
  /// Idempotent — calling while already started is a no-op.
  void start() {
    if (_subscription != null) return;
    _stopped = false;
    _subscription = updateNotifications.localUpdateStream.listen(_onBatch);
    _privateLabelledTasksDue = true;
    _enqueue(const {});
  }

  /// Whether the tasks that carry a private label still need queueing in
  /// this run of the service.
  bool _privateLabelledTasksDue = false;

  /// Adds every task that carries a private label to the pending batch.
  ///
  /// A device hiding private items used to leave those labels out of a
  /// task's text, so its vectors hashed differently from a peer's, and the
  /// peer held them for good. Every device now builds the text with them;
  /// this re-embeds the tasks embedded the old way, and the content hash
  /// skips the rest without a model call. A failed query is logged and not
  /// retried before the next start; a [stop] while it runs queues nothing.
  Future<void> _queuePrivateLabelledTasks() async {
    _privateLabelledTasksDue = false;
    try {
      final ids = await journalDb.taskIdsWithPrivateLabels();
      if (!_stopped) _pendingEntityIds.addAll(ids);
    } on Object catch (e, stackTrace) {
      _domainLogger.error(
        LogDomain.ai,
        e,
        stackTrace: stackTrace,
        subDomain: _subDomain,
        message: 'Failed to queue the tasks that carry private labels',
      );
    }
  }

  /// Stops listening, clears pending and retry work, and awaits any in-flight
  /// processing.
  ///
  /// Sets the [_stopped] flag so the processing loop exits after the current
  /// entity completes. In-flight work is awaited to ensure clean shutdown.
  Future<void> stop() async {
    _stopped = true;
    await _subscription?.cancel();
    _subscription = null;
    _retryTimer?.cancel();
    _retryTimer = null;
    _retryEntityIds.clear();
    _failedAttempts.clear();
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

    _enqueue(entityIds);
  }

  void _enqueue(Set<String> entityIds) {
    _pendingEntityIds.addAll(entityIds);
    // Only start a new processing future if one isn't already running.
    // Overwriting _inFlightProcessing while _isProcessing is true would
    // cause stop() to await a completed no-op instead of the real work.
    if (!_isProcessing) {
      _inFlightProcessing = _processNext();
      unawaited(_inFlightProcessing);
    }
  }

  /// Keeps [entityId] for a later attempt and arms the retry timer; at
  /// [maxFailedAttempts] failures the id is dropped instead.
  void _retryLater(String entityId) {
    final attempts = (_failedAttempts[entityId] ?? 0) + 1;
    if (attempts >= maxFailedAttempts) {
      // Also out of the retry set: an earlier failure may have parked it
      // there, and the timer would otherwise try it once more.
      _failedAttempts.remove(entityId);
      _retryEntityIds.remove(entityId);
      return;
    }
    _failedAttempts[entityId] = attempts;
    _retryEntityIds.add(entityId);
    _retryTimer ??= Timer(retryDelay, _retryNow);
  }

  void _retryNow() {
    _retryTimer = null;
    if (_stopped || _retryEntityIds.isEmpty) return;
    final ids = {..._retryEntityIds};
    _retryEntityIds.clear();
    _enqueue(ids);
  }

  Future<void> _processNext() async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      // Checked once per batch: the flag, and that the model is downloaded.
      final enabled = await journalDb.getConfigFlag(enableEmbeddingsFlag);
      if (!enabled || !await embeddingRepository.isInstalled()) {
        _pendingEntityIds.clear();
        return;
      }
      if (_privateLabelledTasksDue) await _queuePrivateLabelledTasks();

      // Cache label definitions for the batch to avoid one DB query per entity.
      // Best-effort: label resolution failures should not block core embeddings.
      LabelNameResolver? labelResolver;
      try {
        labelResolver = await EmbeddingProcessor.buildLabelResolver(journalDb);
      } on Object catch (e, stackTrace) {
        _domainLogger.error(
          LogDomain.ai,
          e,
          stackTrace: stackTrace,
          subDomain: _subDomain,
          message: 'Failed to build label resolver; continuing without labels',
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
            labelNameResolver: labelResolver,
          );
          _failedAttempts.remove(entityId);
        } on EmbeddingModelNotInstalledException {
          // Removed while the batch ran: like a batch that found it missing.
          _pendingEntityIds.clear();
          return;
        } catch (e, stackTrace) {
          _domainLogger.error(
            LogDomain.ai,
            DomainLogger.withoutSource(e),
            errorType: e.runtimeType,
            stackTrace: stackTrace,
            subDomain: _subDomain,
            message: 'Failed to generate embedding for $entityId',
          );
          // Don't block other entities, but don't lose this one either.
          _retryLater(entityId);
        }
      }
    } on Object catch (e, stackTrace) {
      _domainLogger.error(
        LogDomain.ai,
        e,
        stackTrace: stackTrace,
        subDomain: _subDomain,
        message: 'Embedding batch preflight failed',
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
