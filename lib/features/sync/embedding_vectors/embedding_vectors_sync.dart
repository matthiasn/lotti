import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/sync/sync_message.dart';
import 'package:lotti/classes/sync_sequence_payload_type.dart';
import 'package:lotti/classes/vector_clock.dart';
import 'package:lotti/features/ai/database/embedding_register.dart';
import 'package:lotti/features/ai/database/embedding_store.dart';
import 'package:lotti/features/ai/embedding_sync/embedding_share.dart';
import 'package:lotti/features/ai/embedding_sync/embedding_vectors_payload.dart';
import 'package:lotti/features/ai/embedding_sync/synced_embedding_sink.dart';
import 'package:lotti/features/ai/service/embedding_processor.dart';
import 'package:lotti/features/sync/queue/inbound_queue_models.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/outbox_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:path/path.dart' as p;

/// Reads a config flag.
typedef ConfigFlagReader = Future<bool> Function(String flag);

/// Reads a settings value, `null` when unset.
typedef SettingReader = Future<String?> Function(String key);

/// Writes a settings value.
typedef SettingWriter = Future<void> Function(String key, String value);

/// The settings key that records the catch-up for [modelId] ran.
String embeddingVectorsCaughtUpKey(String modelId) =>
    'embedding_vectors_caught_up.$modelId';

/// Sync's half of the embedding-vectors register
/// (`SyncMessage.embeddingVectors`, ADR 0149).
///
/// Created with the sync stack, which registers before the embedding
/// pipeline; the pipeline [attach]es its store and receiver once it is up.
/// Until then, and while `enable_embeddings` or `sync_embeddings` is off,
/// nothing is shared: [reserve] grants no version.
///
/// - **Sending.** As the [EmbeddingShare], it reserves the next clock of
///   this host for a register version, writes the version's attachment
///   (one file per version, never reused) and enqueues it.
/// - **Answering.** [heldVersion] and [resend] serve backfill, deep
///   backfill and Add Device from the store.
/// - **Receiving.** [sink] is where the apply path hands arriving versions.
class EmbeddingVectorsSync implements EmbeddingShare {
  EmbeddingVectorsSync({
    required this._vectorClockService,
    required this._outboxService,
    required this._readFlag,
    required this._documentsPath,
    required this._domainLogger,
    required this._expectsPipeline,
    required this._readSetting,
    required this._writeSetting,
  });

  static const _subDomain = 'embeddingVectors';

  final VectorClockService _vectorClockService;
  final OutboxService _outboxService;
  final ConfigFlagReader _readFlag;
  final String _documentsPath;
  final DomainLogger _domainLogger;

  /// Whether this platform runs the embedding pipeline at all.
  final bool _expectsPipeline;

  final SettingReader _readSetting;
  final SettingWriter _writeSetting;

  /// Runs a deep backfill round of the vectors alone. Set once the deep
  /// backfill service exists, which is built after this.
  Future<void> Function()? catchUpRound;

  StreamSubscription<void>? _flagSubscription;

  EmbeddingStore? _store;
  String? _modelId;
  SyncedEmbeddingSink? _sink;
  StreamSubscription<QueueDepthSignal>? _depthSubscription;
  bool _queueHadWork = false;

  /// Re-checks every held version each time the inbound queue drains: the
  /// backstop for a dependency no apply hook names. Called once, as the
  /// sync stack is built.
  void watchInboundQueue(Stream<QueueDepthSignal> depthChanges) {
    _depthSubscription = depthChanges.listen((signal) async {
      if (signal.total > 0) {
        _queueHadWork = true;
        return;
      }
      if (!_queueHadWork) return;
      _queueHadWork = false;
      final sink = _sink;
      if (sink == null) return;
      try {
        await sink.recheckAll();
      } on Object catch (error, stackTrace) {
        _domainLogger.error(
          LogDomain.sync,
          error,
          stackTrace: stackTrace,
          subDomain: _subDomain,
          message: 'held embedding versions could not be re-checked',
        );
      }
    });
  }

  /// Stops watching the inbound queue.
  Future<void> dispose() async {
    await _depthSubscription?.cancel();
    _depthSubscription = null;
    await _flagSubscription?.cancel();
    _flagSubscription = null;
  }

  /// Connects the embedding pipeline: its [store], the [modelId] it embeds
  /// with, and the [sink] that receives versions.
  ///
  /// Then, and whenever [flagChanges] fires, it runs the [catchUp].
  Future<void> attach({
    required EmbeddingStore store,
    required String modelId,
    required SyncedEmbeddingSink sink,
    Stream<void>? flagChanges,
  }) async {
    await _flagSubscription?.cancel();
    _store = store;
    _modelId = modelId;
    _sink = sink;
    _flagSubscription = flagChanges?.listen((_) async => catchUp());
    await catchUp();
  }

  /// Disconnects the pipeline, which is being disposed.
  Future<void> detach() async {
    await _flagSubscription?.cancel();
    _flagSubscription = null;
    _store = null;
    _modelId = null;
    _sink = null;
  }

  /// Makes up, once per model and device, for the versions this device
  /// dropped while it could not store them: their receipts are recorded, so
  /// the sequence log never asks for them again. The first time it can
  /// store for its model, it advertises its vectors alone in a deep
  /// backfill round, and its peers push what it lacks.
  ///
  /// A round that fails — no host yet, sync not connected — is tried again
  /// at the next attach or flag change. The marker records that the round
  /// went out, not that every peer answered; a manual deep backfill covers
  /// a peer that was offline.
  Future<void> catchUp() async {
    final run = catchUpRound;
    final modelId = _modelId;
    if (run == null || modelId == null || !await isSharing) return;
    final key = embeddingVectorsCaughtUpKey(modelId);
    if (await _readSetting(key) != null) return;
    try {
      await run();
      await _writeSetting(key, 'true');
    } on Object catch (error, stackTrace) {
      _domainLogger.error(
        LogDomain.sync,
        error,
        stackTrace: stackTrace,
        subDomain: _subDomain,
        message: 'the embedding-vectors catch-up round did not go out',
      );
    }
  }

  /// The receiver of arriving versions; `null` without the pipeline.
  SyncedEmbeddingSink? get sink => _sink;

  /// Whether the pipeline is attached.
  bool get isAttached => _store != null;

  /// Whether an arriving version must wait for the pipeline: it runs on
  /// this platform and both flags are on, but it has not attached yet (the
  /// app is starting). Dropping the version then, receipt and all, would
  /// lose it for good.
  Future<bool> get awaitsPipeline async =>
      _store == null &&
      _expectsPipeline &&
      await _readFlag(enableEmbeddingsFlag) &&
      await _readFlag(syncEmbeddingsFlag);

  /// Whether versions are shared now: the pipeline is attached and both
  /// `enable_embeddings` and `sync_embeddings` are on.
  Future<bool> get isSharing async =>
      _store != null &&
      await _readFlag(enableEmbeddingsFlag) &&
      await _readFlag(syncEmbeddingsFlag);

  @override
  Future<EmbeddingVersionTicket?> reserve({
    required String registerId,
    VectorClock? previous,
  }) async {
    if (!await isSharing) return null;
    final host = await _vectorClockService.getHost();
    if (host == null) return null;
    final reservation = await _vectorClockService.reserveNextVectorClock(
      previous: previous,
      payload: (id: registerId, type: SyncSequencePayloadType.embeddingVectors),
    );
    return _Ticket(this, reservation, host);
  }

  /// The version this device holds of register [registerId] — what a
  /// backfill request is answered with — or `null` when it holds none, or
  /// only one it never shared, or the register is of another model.
  Future<EmbeddingRegister?> heldVersion(String registerId) async {
    final store = _store;
    final ids = _splitRegisterId(registerId);
    if (store == null || ids == null || ids.modelId != _modelId) return null;
    final register = await store.getRegister(ids.entityId);
    return register != null && register.isShared ? register : null;
  }

  /// Every version this device holds and shared (tombstones included), in
  /// register-id order: what deep backfill advertises and Add Device sends.
  /// A version never shared is left out; no peer can know of it.
  Future<List<EmbeddingRegister>> sharedRegisters() async {
    final store = _store;
    if (store == null) return const [];
    final registers = [
      for (final register in await store.allRegisters())
        if (register.isShared && register.modelId == _modelId) register,
    ]..sort((a, b) => a.id.compareTo(b.id));
    return registers;
  }

  /// The register ids Add Device sends: every live version of this model
  /// the store holds, and every shared tombstone. A tombstone never shared
  /// says nothing a new device needs.
  Future<List<String>> registerIdsToSend() async {
    final store = _store;
    if (store == null) return const [];
    return [
      for (final register in await store.allRegisters())
        if (register.modelId == _modelId &&
            (register.isShared || !register.deleted))
          register.id,
    ]..sort();
  }

  /// Sends the current version of [registerId], versioning first one stored
  /// while sharing was off, so a new device receives every vector the store
  /// holds. Throws when it could not be enqueued; a register that is gone is
  /// skipped.
  Future<void> sendCurrent(String registerId) async {
    final store = _store;
    final ids = _splitRegisterId(registerId);
    if (store == null || ids == null) return;
    final register = await store.getRegister(ids.entityId);
    if (register == null) return;
    if (register.isShared) {
      await _resendOrThrow(registerId);
      return;
    }
    final lockKey = register.taskId.isNotEmpty
        ? register.taskId
        : register.entityId;
    await EmbeddingProcessor.runExclusive(lockKey, () async {
      final current = await store.getRegister(ids.entityId);
      if (current == null || current.isShared) return;
      final ticket = await reserve(registerId: registerId);
      if (ticket == null) return;
      final versioned = current.copyWith(
        vectorClock: ticket.vectorClock,
        originatingHostId: ticket.hostId,
      );
      try {
        await store.putRegister(versioned);
      } on Object {
        await ticket.release();
        rethrow;
      }
      await ticket.send(versioned, await store.chunkVectors(ids.entityId));
    });
  }

  Future<void> _resendOrThrow(String registerId) async {
    final message = await prepareResend(registerId);
    if (message != null) await _outboxService.enqueueMessageOrThrow(message);
  }

  /// The message that resends the version held of [registerId], its
  /// attachment written; `null` when this device holds none. What backfill
  /// enqueues.
  Future<SyncEmbeddingVectors?> prepareResend(String registerId) async {
    final held = await heldVersion(registerId);
    if (held == null) return null;
    final chunks = held.deleted
        ? const <Float32List>[]
        : await _store!.chunkVectors(held.entityId);
    if (!held.deleted && chunks.isEmpty) return null;
    return _prepare(held, chunks);
  }

  /// Enqueues the version held of [registerId] once more, with its chunks.
  /// Returns whether one was enqueued.
  Future<bool> resend(String registerId) async {
    final message = await prepareResend(registerId);
    if (message == null) return false;
    await _outboxService.enqueueMessageOrThrow(message);
    return true;
  }

  /// The message that carries [version], its attachment at [jsonPath].
  static SyncEmbeddingVectors messageFor(
    EmbeddingRegister version, {
    String? jsonPath,
  }) => SyncEmbeddingVectors(
    id: version.id,
    entityId: version.entityId,
    entityType: version.entityType,
    modelId: version.modelId,
    vectorClock: version.vectorClock!,
    originatingHostId: version.originatingHostId,
    contentHash: version.contentHash,
    deleted: version.deleted,
    sourceVectorClock: version.sourceVectorClock,
    jsonPath: jsonPath,
    taskId: version.taskId.isEmpty ? null : version.taskId,
    subtype: version.subtype.isEmpty ? null : version.subtype,
  );

  /// Writes [version]'s attachment, replacing the files of the register's
  /// earlier versions, and returns the message that carries it. A queued
  /// earlier version whose file is gone goes out without one, and receivers
  /// record only its receipt.
  Future<SyncEmbeddingVectors> _prepare(
    EmbeddingRegister version,
    List<Float32List> chunks,
  ) async {
    String? jsonPath;
    if (!version.deleted) {
      final hostId = version.originatingHostId;
      jsonPath = relativeEmbeddingVectorsPath(
        entityId: version.entityId,
        modelId: version.modelId,
        hostId: hostId,
        counter: version.vectorClock!.get(hostId),
      );
      final file = File(p.join(_documentsPath, p.joinAll(_segments(jsonPath))));
      await _deleteSiblings(file);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(encodeEmbeddingVectors(chunks), flush: true);
    }
    return messageFor(version, jsonPath: jsonPath);
  }

  Future<void> _deleteSiblings(File file) async {
    final directory = file.parent;
    if (!directory.existsSync()) return;
    await for (final entry in directory.list()) {
      if (entry is File && entry.path != file.path) {
        await entry.delete();
      }
    }
  }

  Future<void> _send(
    VcReservation reservation,
    EmbeddingRegister version,
    List<Float32List> chunks,
  ) async {
    try {
      await _outboxService.enqueueMessageOrThrow(
        await _prepare(version, chunks),
      );
      await reservation.commit();
    } on Object catch (error, stackTrace) {
      _domainLogger.error(
        LogDomain.sync,
        error,
        stackTrace: stackTrace,
        subDomain: _subDomain,
        message: 'could not enqueue an embedding-vectors version',
      );
      await reservation.release();
    }
  }

  static Iterable<String> _segments(String relativePath) =>
      relativePath.split('/').where((part) => part.isNotEmpty);
}

/// Sync's half of the embedding-vectors register; `null` without the sync
/// stack (a guest world, a test). Overridden by the composition root.
final embeddingVectorsSyncProvider = Provider<EmbeddingVectorsSync?>(
  (ref) => null,
  name: 'embeddingVectorsSyncProvider',
);

/// The entity and model ids of a register id, `null` when malformed.
({String entityId, String modelId})? _splitRegisterId(String registerId) {
  final at = registerId.lastIndexOf('|');
  if (at <= 0 || at == registerId.length - 1) return null;
  return (
    entityId: registerId.substring(0, at),
    modelId: registerId.substring(at + 1),
  );
}

class _Ticket implements EmbeddingVersionTicket {
  _Ticket(this._owner, this._reservation, this.hostId);

  final EmbeddingVectorsSync _owner;
  final VcReservation _reservation;

  @override
  final String hostId;

  @override
  VectorClock get vectorClock => _reservation.vc;

  @override
  Future<void> send(EmbeddingRegister version, List<Float32List> chunks) =>
      _owner._send(_reservation, version, chunks);

  @override
  Future<void> release() => _reservation.release();
}
