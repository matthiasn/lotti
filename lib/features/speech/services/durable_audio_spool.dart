import 'dart:async';
import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:ffi/ffi.dart';
import 'package:lotti/features/speech/services/pcm_wav.dart';
import 'package:path/path.dart' as path;

/// PCM format owned by the durable speech spool.
const spoolSampleRate = 16000;
const spoolChannels = 1;
const spoolBitsPerSample = 16;

/// Two seconds of signed 16-bit, 16-kHz mono PCM.
const defaultSpoolChunkBytes = 64000;

/// Eight seconds of signed 16-bit, 16-kHz mono PCM.
const defaultSpoolPendingBytes = 256000;

Future<void> _syncPosixDirectory(Directory directory) async {
  final libc = ffi.DynamicLibrary.process();
  final open = libc
      .lookupFunction<
        ffi.Int32 Function(ffi.Pointer<Utf8> path, ffi.Int32 flags),
        int Function(ffi.Pointer<Utf8> path, int flags)
      >('open');
  final fsync = libc
      .lookupFunction<ffi.Int32 Function(ffi.Int32 fd), int Function(int fd)>(
        'fsync',
      );
  final close = libc
      .lookupFunction<ffi.Int32 Function(ffi.Int32 fd), int Function(int fd)>(
        'close',
      );
  final nativePath = directory.path.toNativeUtf8();
  var descriptor = -1;
  try {
    descriptor = open(nativePath, 0);
    if (descriptor < 0) {
      throw FileSystemException(
        'Unable to open directory for durability sync',
        directory.path,
      );
    }
    if (fsync(descriptor) != 0) {
      throw FileSystemException(
        'Unable to sync directory entry',
        directory.path,
      );
    }
  } finally {
    if (descriptor >= 0) close(descriptor);
    malloc.free(nativePath);
  }
}

/// Result of attempting to append a frame to a [DurableAudioSpool].
enum SpoolAppendResult {
  /// The complete frame is durable locally and may now be forwarded.
  persisted,

  /// The bounded local writer queue is full. The caller must stop or
  /// checkpoint capture instead of forwarding this frame.
  saturated,
}

/// Lifecycle state stored in every spool manifest generation.
enum DurableAudioSpoolState {
  recording,
  finalizing,
  published,
  committed,
  reclaimPrepared,
  recoveryRequired,
  quarantined,
  discarding,
  discarded,
}

/// Stable recovery classification for localized UI and diagnostics.
enum DurableAudioRecoveryReason {
  invalidChunkSequence,
  missingChunk,
  invalidChunkLength,
  chunkDigestMismatch,
  chunkGap,
  invalidOrphanChunk,
  multipleActiveChunks,
  activeChunkGap,
  activeChunkTooLarge,
  acknowledgedPrefixMissing,
  invalidReclaimedWav,
}

/// Observable persistence boundaries used by the deterministic crash harness.
enum AudioSpoolDurabilityBoundary {
  spoolRootPublished,
  sessionDirectoryPublished,
  assetDirectoryPublished,
  activeFileFlushed,
  activeFilePublished,
  chunkPublished,
  manifestFileFlushed,
  manifestPublished,
  ownerFileFlushed,
  ownerPublished,
  wavFileFlushed,
  wavPublished,
  pcmPurged,
  assetPurged,
  manifestsPruned,
}

/// Filesystem durability policy for spool publication boundaries.
///
/// Dart exposes file flushes directly. On POSIX, opening and flushing a
/// directory provides the corresponding directory-entry durability barrier.
/// Windows uses atomic/recoverable rename handling but has no portable Dart
/// directory handle, so directory sync is a documented no-op there.
class AudioSpoolDurability {
  const AudioSpoolDurability({this.onBoundary});

  final Future<void> Function(AudioSpoolDurabilityBoundary boundary)?
  onBoundary;

  Future<void> fileFlushed(AudioSpoolDurabilityBoundary boundary) async {
    await onBoundary?.call(boundary);
  }

  Future<void> entryPublished(
    Directory directory,
    AudioSpoolDurabilityBoundary boundary,
  ) async {
    if (Platform.isLinux ||
        Platform.isAndroid ||
        Platform.isMacOS ||
        Platform.isIOS) {
      await _syncPosixDirectory(directory);
    }
    await onBoundary?.call(boundary);
  }
}

/// Typed failure returned when finalization finds no complete PCM sample.
class DurableAudioSpoolNoAudioException implements Exception {
  const DurableAudioSpoolNoAudioException();

  @override
  String toString() => 'No complete PCM sample was captured';
}

/// Typed failure that keeps a partial spool recoverable after a write error.
class DurableAudioSpoolRecoveryRequiredException implements Exception {
  const DurableAudioSpoolRecoveryRequiredException({
    required this.acceptedPcmBytes,
    required this.cause,
  });

  final int acceptedPcmBytes;
  final Object cause;

  @override
  String toString() =>
      'Audio spool recovery required after $acceptedPcmBytes bytes: $cause';
}

/// Product surface that owns a durable microphone capture.
enum AudioCaptureOrigin { dailyOs, aiChat, journalAudio }

/// Immutable user intent bound before microphone capture starts.
enum AudioCaptureIntent { dayPlan, dayRefine, chatMessage, journalEntry }

/// Immutable identity allocated before microphone capture starts.
class DurableAudioSpoolContext {
  DurableAudioSpoolContext({
    required this.recordingSessionId,
    required this.activityEntryId,
    required this.createdAt,
    required this.assetRootPath,
    this.origin,
    this.intent,
    this.dayId,
    this.planDate,
    this.timeZoneOffsetMinutes,
    this.originHostId,
    this.continuationOperationId,
    this.baselineRevisionId,
    Map<String, String> metadata = const <String, String>{},
  }) : metadata = Map<String, String>.unmodifiable(
         Map<String, String>.of(metadata),
       );

  factory DurableAudioSpoolContext.fromJson(Map<String, Object?> json) {
    return DurableAudioSpoolContext(
      recordingSessionId: json['recordingSessionId']! as String,
      activityEntryId: json['activityEntryId']! as String,
      createdAt: DateTime.parse(json['createdAt']! as String),
      assetRootPath: json['assetRootPath']! as String,
      origin: json['origin'] == null
          ? null
          : AudioCaptureOrigin.values.byName(json['origin']! as String),
      intent: json['intent'] == null
          ? null
          : AudioCaptureIntent.values.byName(json['intent']! as String),
      dayId: json['dayId'] as String?,
      planDate: json['planDate'] == null
          ? null
          : DateTime.parse(json['planDate']! as String),
      timeZoneOffsetMinutes: json['timeZoneOffsetMinutes'] as int?,
      originHostId: json['originHostId'] as String?,
      continuationOperationId: json['continuationOperationId'] as String?,
      baselineRevisionId: json['baselineRevisionId'] as String?,
      metadata: (json['metadata'] as Map<String, Object?>? ?? const {}).map(
        (key, value) => MapEntry(key, value! as String),
      ),
    );
  }

  final String recordingSessionId;
  final String activityEntryId;
  final DateTime createdAt;
  final String assetRootPath;
  final AudioCaptureOrigin? origin;
  final AudioCaptureIntent? intent;
  final String? dayId;
  final DateTime? planDate;
  final int? timeZoneOffsetMinutes;
  final String? originHostId;
  final String? continuationOperationId;
  final String? baselineRevisionId;
  final Map<String, String> metadata;

  Map<String, Object?> toJson() => <String, Object?>{
    'recordingSessionId': recordingSessionId,
    'activityEntryId': activityEntryId,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'assetRootPath': assetRootPath,
    'origin': origin?.name,
    'intent': intent?.name,
    'dayId': dayId,
    'planDate': planDate?.toIso8601String(),
    'timeZoneOffsetMinutes': timeZoneOffsetMinutes,
    'originHostId': originHostId,
    'continuationOperationId': continuationOperationId,
    'baselineRevisionId': baselineRevisionId,
    'metadata': metadata,
  };
}

/// A complete independently recoverable PCM chunk.
class DurableAudioChunk {
  const DurableAudioChunk({
    required this.index,
    required this.fileName,
    required this.byteLength,
    required this.sha256Digest,
  });

  factory DurableAudioChunk.fromJson(Map<String, Object?> json) {
    return DurableAudioChunk(
      index: json['index']! as int,
      fileName: json['fileName']! as String,
      byteLength: json['byteLength']! as int,
      sha256Digest: json['sha256']! as String,
    );
  }

  final int index;
  final String fileName;
  final int byteLength;
  final String sha256Digest;

  Map<String, Object?> toJson() => <String, Object?>{
    'index': index,
    'fileName': fileName,
    'byteLength': byteLength,
    'sha256': sha256Digest,
  };
}

/// Persisted, checksummed description of one recording session.
class DurableAudioSpoolManifest {
  DurableAudioSpoolManifest({
    required this.generation,
    required this.context,
    required this.state,
    required List<DurableAudioChunk> chunks,
    required this.activeChunkBytes,
    required this.acceptedPcmBytes,
    required this.chunkBytes,
    this.finalWavPath,
    this.finalWavSha256,
    this.journalAudioId,
    this.pcmReclaimed = false,
    this.recoveryReason,
    this.recoveryDetail,
  }) : chunks = List<DurableAudioChunk>.unmodifiable(chunks);

  factory DurableAudioSpoolManifest.fromJson(Map<String, Object?> json) {
    if (json['schemaVersion'] != schemaVersion) {
      throw const FormatException('Unsupported audio spool manifest version');
    }
    return DurableAudioSpoolManifest(
      generation: json['generation']! as int,
      context: DurableAudioSpoolContext.fromJson(
        json['context']! as Map<String, Object?>,
      ),
      state: DurableAudioSpoolState.values.byName(json['state']! as String),
      chunks: (json['chunks']! as List<Object?>)
          .map(
            (item) => DurableAudioChunk.fromJson(
              item! as Map<String, Object?>,
            ),
          )
          .toList(growable: false),
      activeChunkBytes: json['activeChunkBytes']! as int,
      acceptedPcmBytes: json['acceptedPcmBytes']! as int,
      chunkBytes: json['chunkBytes']! as int,
      finalWavPath: json['finalWavPath'] as String?,
      finalWavSha256: json['finalWavSha256'] as String?,
      journalAudioId: json['journalAudioId'] as String?,
      pcmReclaimed: json['pcmReclaimed'] as bool? ?? false,
      recoveryReason: json['recoveryReason'] == null
          ? null
          : DurableAudioRecoveryReason.values.byName(
              json['recoveryReason']! as String,
            ),
      recoveryDetail: json['recoveryDetail'] as String?,
    );
  }

  static const schemaVersion = 1;

  final int generation;
  final DurableAudioSpoolContext context;
  final DurableAudioSpoolState state;
  final List<DurableAudioChunk> chunks;
  final int activeChunkBytes;
  final int acceptedPcmBytes;
  final int chunkBytes;
  final String? finalWavPath;
  final String? finalWavSha256;
  final String? journalAudioId;
  final bool pcmReclaimed;
  final DurableAudioRecoveryReason? recoveryReason;
  final String? recoveryDetail;

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': schemaVersion,
    'generation': generation,
    'context': context.toJson(),
    'state': state.name,
    'chunks': chunks.map((chunk) => chunk.toJson()).toList(),
    'activeChunkBytes': activeChunkBytes,
    'acceptedPcmBytes': acceptedPcmBytes,
    'chunkBytes': chunkBytes,
    'finalWavPath': finalWavPath,
    'finalWavSha256': finalWavSha256,
    'journalAudioId': journalAudioId,
    'pcmReclaimed': pcmReclaimed,
    'recoveryReason': recoveryReason?.name,
    'recoveryDetail': recoveryDetail,
  };
}

/// A finalized local recording suitable for journal attachment persistence.
class DurableAudioSpoolFinalization {
  const DurableAudioSpoolFinalization({
    required this.context,
    required this.wavPath,
    required this.wavSha256,
    required this.pcmBytes,
    required this.duration,
  });

  final DurableAudioSpoolContext context;
  final String wavPath;
  final String wavSha256;
  final int pcmBytes;
  final Duration duration;
}

/// Result of reconciling a session directory after startup.
class DurableAudioSpoolRecovery {
  const DurableAudioSpoolRecovery({
    required this.manifest,
    required this.spool,
  });

  final DurableAudioSpoolManifest manifest;

  /// Non-null when the reconciled recording can be finalized or inspected.
  final DurableAudioSpool? spool;

  bool get isQuarantined =>
      manifest.state == DurableAudioSpoolState.quarantined;
}

/// A bounded write-before-send PCM spool with crash-recoverable manifests.
///
/// [append] resolves with [SpoolAppendResult.persisted] only after the bytes
/// have been flushed to a local chunk. The initial manifest already owns the
/// immutable session identity, and chunk/finalization boundaries publish
/// checksummed manifest generations. Callers may forward a realtime frame only
/// after receiving that result.
class DurableAudioSpool {
  DurableAudioSpool._(
    this._sessionDirectory,
    this._manifest,
    this._maxPendingBytes, [
    this._persistBarrier,
    this._acceptingFrames = false,
    int? nextManifestGeneration,
    this._durability = const AudioSpoolDurability(),
  ]) : _nextManifestGeneration =
           nextManifestGeneration ?? _manifest.generation + 1;

  static final _safeSessionId = RegExp(r'^[A-Za-z0-9_-]+$');
  static final _manifestPattern = RegExp(r'^manifest-(\d{8})\.json$');
  static final _chunkPattern = RegExp(r'^chunk-(\d{8})\.pcm$');
  static final _activePattern = RegExp(r'^active-(\d{8})\.part$');
  static const _ownerFileName = 'owner.json';
  static const _wavOwnerSuffix = '.lotti-audio-owner';

  final Directory _sessionDirectory;
  final int _maxPendingBytes;
  final Future<void> Function()? _persistBarrier;
  final AudioSpoolDurability _durability;
  DurableAudioSpoolManifest _manifest;
  Future<void> _writeTail = Future<void>.value();
  Future<void> _lifecycleTail = Future<void>.value();
  int _pendingBytes = 0;
  int _nextManifestGeneration;
  bool _acceptingFrames;
  Object? _writeFailure;
  Future<DurableAudioSpoolFinalization>? _finalizationFuture;
  String? _finalizationPath;

  DurableAudioSpoolManifest get manifest => _manifest;
  Directory get sessionDirectory => _sessionDirectory;

  /// Creates and publishes the initial manifest before accepting audio.
  static Future<DurableAudioSpool> start({
    required Directory rootDirectory,
    required DurableAudioSpoolContext context,
    int chunkBytes = defaultSpoolChunkBytes,
    int maxPendingBytes = defaultSpoolPendingBytes,
    Future<void> Function()? persistBarrier,
    AudioSpoolDurability durability = const AudioSpoolDurability(),
  }) async {
    if (!_safeSessionId.hasMatch(context.recordingSessionId)) {
      throw ArgumentError.value(
        context.recordingSessionId,
        'context.recordingSessionId',
        'Only letters, digits, underscores, and hyphens are allowed',
      );
    }
    if (chunkBytes <= 0 || chunkBytes.isOdd) {
      throw ArgumentError.value(
        chunkBytes,
        'chunkBytes',
        'Must be a positive even PCM byte count',
      );
    }
    if (maxPendingBytes <= 0) {
      throw ArgumentError.value(maxPendingBytes, 'maxPendingBytes');
    }
    if (context.activityEntryId.trim().isEmpty) {
      throw ArgumentError.value(
        context.activityEntryId,
        'context.activityEntryId',
      );
    }
    final normalizedAssetRoot = path.normalize(
      Directory(context.assetRootPath).absolute.path,
    );
    if (context.assetRootPath.trim().isEmpty ||
        normalizedAssetRoot != path.normalize(context.assetRootPath)) {
      throw ArgumentError.value(
        context.assetRootPath,
        'context.assetRootPath',
        'Must be an absolute normalized asset root',
      );
    }

    if (!rootDirectory.existsSync()) {
      final rootParent = rootDirectory.parent;
      if (!rootParent.existsSync()) {
        throw FileSystemException(
          'Audio spool root parent must already exist',
          rootParent.path,
        );
      }
      await rootDirectory.create();
      await durability.entryPublished(
        rootParent,
        AudioSpoolDurabilityBoundary.spoolRootPublished,
      );
    }
    final directory = Directory(
      path.join(rootDirectory.path, context.recordingSessionId),
    );
    await directory.create();
    await durability.entryPublished(
      rootDirectory,
      AudioSpoolDurabilityBoundary.sessionDirectoryPublished,
    );
    if (directory.listSync().isNotEmpty) {
      throw StateError('Audio spool session already exists: ${directory.path}');
    }

    final spool = DurableAudioSpool._(
      directory,
      DurableAudioSpoolManifest(
        generation: 0,
        context: context,
        state: DurableAudioSpoolState.recording,
        chunks: const <DurableAudioChunk>[],
        activeChunkBytes: 0,
        acceptedPcmBytes: 0,
        chunkBytes: chunkBytes,
      ),
      maxPendingBytes,
      persistBarrier,
      true,
      null,
      durability,
    );
    await spool._publishManifest();
    return spool;
  }

  /// Recovers the newest valid manifest and reconciles flushed PCM files.
  static Future<DurableAudioSpoolRecovery> recover({
    required Directory sessionDirectory,
    int maxPendingBytes = defaultSpoolPendingBytes,
    AudioSpoolDurability durability = const AudioSpoolDurability(),
  }) async {
    final recoveredManifest = await _readLatestValidManifest(sessionDirectory);
    final manifest = recoveredManifest.manifest;
    final spool = DurableAudioSpool._(
      sessionDirectory,
      manifest,
      maxPendingBytes,
      null,
      false,
      recoveredManifest.maxGeneration + 1,
      durability,
    );
    final ownerId = await spool._readOwnerMarker();
    if (ownerId != null) {
      if (manifest.journalAudioId != null &&
          manifest.journalAudioId != ownerId) {
        throw const FormatException('Conflicting audio spool owner markers');
      }
      spool._manifest = spool._copyManifest(journalAudioId: ownerId);
    }
    if (manifest.state == DurableAudioSpoolState.discarding ||
        manifest.state == DurableAudioSpoolState.discarded) {
      await spool._purgeOwnedFiles();
      if (manifest.state != DurableAudioSpoolState.discarded) {
        await spool._replaceManifest(state: DurableAudioSpoolState.discarded);
      }
      return DurableAudioSpoolRecovery(manifest: spool.manifest, spool: null);
    }
    if (manifest.state == DurableAudioSpoolState.reclaimPrepared) {
      if (await spool._finalWavIsValid()) {
        return DurableAudioSpoolRecovery(
          manifest: spool.manifest,
          spool: spool,
        );
      }
      final issue = await spool._reconcileFiles();
      if (issue != null) {
        await spool._replaceManifest(
          state: DurableAudioSpoolState.quarantined,
          recoveryReason: issue.reason,
          recoveryDetail: issue.detail,
        );
        return DurableAudioSpoolRecovery(
          manifest: spool.manifest,
          spool: null,
        );
      }
      await spool._replaceManifest(
        state: DurableAudioSpoolState.recoveryRequired,
      );
      return DurableAudioSpoolRecovery(
        manifest: spool.manifest,
        spool: spool,
      );
    }
    if (manifest.pcmReclaimed) {
      if (manifest.state == DurableAudioSpoolState.quarantined) {
        await spool._purgePcmFiles();
        return DurableAudioSpoolRecovery(manifest: spool.manifest, spool: null);
      }
      if (manifest.state == DurableAudioSpoolState.committed &&
          await spool._finalWavIsValid()) {
        await spool._purgePcmFiles();
        return DurableAudioSpoolRecovery(manifest: manifest, spool: spool);
      }
      await spool._replaceManifest(
        state: DurableAudioSpoolState.quarantined,
        recoveryReason: DurableAudioRecoveryReason.invalidReclaimedWav,
        recoveryDetail: 'Reclaimed PCM has no valid committed WAV',
      );
      return DurableAudioSpoolRecovery(manifest: spool.manifest, spool: null);
    }
    final issue = await spool._reconcileFiles();
    if (issue != null) {
      await spool._replaceManifest(
        state: DurableAudioSpoolState.quarantined,
        recoveryReason: issue.reason,
        recoveryDetail: issue.detail,
      );
      return DurableAudioSpoolRecovery(
        manifest: spool.manifest,
        spool: null,
      );
    }

    if ((spool.manifest.state == DurableAudioSpoolState.published ||
            spool.manifest.state == DurableAudioSpoolState.committed) &&
        await spool._finalWavIsValid()) {
      return DurableAudioSpoolRecovery(
        manifest: spool.manifest,
        spool: spool,
      );
    }

    await spool._replaceManifest(
      state: DurableAudioSpoolState.recoveryRequired,
    );
    return DurableAudioSpoolRecovery(
      manifest: spool.manifest,
      spool: spool,
    );
  }

  /// Adds [pcmFrame] to the bounded durable queue.
  ///
  /// Empty frames are accepted without creating a manifest generation.
  Future<SpoolAppendResult> append(Uint8List pcmFrame) {
    if (!_acceptingFrames ||
        _manifest.state != DurableAudioSpoolState.recording) {
      return Future<SpoolAppendResult>.error(
        StateError('Cannot append in ${_manifest.state.name} state'),
      );
    }
    if (pcmFrame.isEmpty) {
      return Future<SpoolAppendResult>.value(SpoolAppendResult.persisted);
    }
    if (pcmFrame.length.isOdd) {
      return Future<SpoolAppendResult>.error(
        ArgumentError.value(
          pcmFrame.length,
          'pcmFrame.length',
          'PCM16 frames must contain complete two-byte samples',
        ),
      );
    }
    if (_pendingBytes + pcmFrame.length > _maxPendingBytes) {
      return Future<SpoolAppendResult>.value(SpoolAppendResult.saturated);
    }

    final ownedFrame = Uint8List.fromList(pcmFrame);
    _pendingBytes += ownedFrame.length;
    final operation = _writeTail.then((_) async {
      final priorFailure = _writeFailure;
      if (priorFailure != null) {
        throw DurableAudioSpoolRecoveryRequiredException(
          acceptedPcmBytes: _manifest.acceptedPcmBytes,
          cause: priorFailure,
        );
      }
      try {
        await _persistFrame(ownedFrame);
      } catch (error) {
        _writeFailure ??= error;
        _acceptingFrames = false;
        _manifest = _copyManifest(
          state: DurableAudioSpoolState.recoveryRequired,
        );
        rethrow;
      }
    });
    _writeTail = operation.then<void>((_) {}, onError: (_, _) {});
    return operation
        .whenComplete(() {
          _pendingBytes -= ownedFrame.length;
        })
        .then((_) => SpoolAppendResult.persisted);
  }

  /// Consolidates all durable chunks into [destinationFile].
  ///
  /// Frame admission closes synchronously. Repeated calls for the same path
  /// share one in-flight result; a different destination is rejected.
  Future<DurableAudioSpoolFinalization> finalize({
    required File destinationFile,
  }) {
    final destination = destinationFile.absolute.path;
    if (!_isApprovedAssetPath(destination)) {
      return Future<DurableAudioSpoolFinalization>.error(
        ArgumentError.value(
          destination,
          'destinationFile',
          'Must be inside the session asset root',
        ),
      );
    }
    final existing = _finalizationFuture;
    if (existing != null) {
      if (_finalizationPath != destination) {
        return Future<DurableAudioSpoolFinalization>.error(
          StateError('Finalization already targets $_finalizationPath'),
        );
      }
      return existing;
    }
    final intendedPath = _manifest.finalWavPath;
    if (intendedPath != null && intendedPath != destination) {
      return Future<DurableAudioSpoolFinalization>.error(
        StateError('Recording already targets another path'),
      );
    }
    _acceptingFrames = false;
    _finalizationPath = destination;
    return _finalizationFuture = _runFinalization(destinationFile.absolute);
  }

  Future<DurableAudioSpoolFinalization> _runFinalization(
    File destinationFile,
  ) async {
    try {
      return await _enqueueLifecycle(
        () => _finalize(destinationFile),
      );
    } catch (_) {
      if (_manifest.state == DurableAudioSpoolState.finalizing) {
        _manifest = _copyManifest(
          state: DurableAudioSpoolState.recoveryRequired,
        );
      }
      _finalizationFuture = null;
      _finalizationPath = null;
      rethrow;
    }
  }

  Future<DurableAudioSpoolFinalization> _finalize(File destinationFile) async {
    await _writeTail;
    final writeFailure = _writeFailure;
    if (writeFailure != null) {
      throw DurableAudioSpoolRecoveryRequiredException(
        acceptedPcmBytes: _manifest.acceptedPcmBytes,
        cause: writeFailure,
      );
    }
    if ((_manifest.state == DurableAudioSpoolState.published ||
            _manifest.state == DurableAudioSpoolState.committed) &&
        await _finalWavIsValid()) {
      return _finalizationFromManifest();
    }
    if (_manifest.state != DurableAudioSpoolState.recording &&
        _manifest.state != DurableAudioSpoolState.recoveryRequired) {
      throw StateError('Cannot finalize in ${_manifest.state.name} state');
    }
    if (_manifest.acceptedPcmBytes == 0) {
      throw const DurableAudioSpoolNoAudioException();
    }

    await _publishActiveChunkIfPresent();
    await _replaceManifest(
      state: DurableAudioSpoolState.finalizing,
      finalWavPath: destinationFile.path,
    );

    final wavFile = destinationFile;
    await _ensureDurableDirectory(wavFile.parent);
    await _claimWavDestination(wavFile);
    await _repairInterruptedWavPublication(wavFile);
    final partialFile = File('${wavFile.path}.part');
    if (partialFile.existsSync()) await partialFile.delete();

    final wavHandle = await partialFile.open(mode: FileMode.write);
    try {
      await wavHandle.writeFrom(
        buildWavHeader(dataSize: _manifest.acceptedPcmBytes),
      );
      for (final chunk in _manifest.chunks) {
        await wavHandle.writeFrom(
          await File(
            path.join(_sessionDirectory.path, chunk.fileName),
          ).readAsBytes(),
        );
      }
      await wavHandle.flush();
      await _durability.fileFlushed(
        AudioSpoolDurabilityBoundary.wavFileFlushed,
      );
    } finally {
      await wavHandle.close();
    }
    await _publishWav(partialFile: partialFile, destinationFile: wavFile);

    final wavDigest = await _digestFile(wavFile);
    await _replaceManifest(
      state: DurableAudioSpoolState.published,
      finalWavPath: wavFile.path,
      finalWavSha256: wavDigest,
    );
    return _finalizationFromManifest();
  }

  /// Marks a published recording as owned by a durable journal row.
  Future<void> markCommitted({required String journalAudioId}) {
    return _enqueueLifecycle(() async {
      if (journalAudioId.trim().isEmpty) {
        throw ArgumentError.value(journalAudioId, 'journalAudioId');
      }
      final existingOwner = _manifest.journalAudioId;
      if (existingOwner != null && existingOwner != journalAudioId) {
        throw StateError('Recording is committed to another journal row');
      }
      if (_manifest.state == DurableAudioSpoolState.committed) {
        return;
      }
      if (_manifest.state != DurableAudioSpoolState.published ||
          !await _finalWavIsValid()) {
        throw StateError('Only a valid published recording can be committed');
      }
      await _publishOwnerMarker(journalAudioId);
      await _replaceManifest(
        state: DurableAudioSpoolState.committed,
        journalAudioId: journalAudioId,
      );
    });
  }

  /// Records an explicit user discard before deleting recoverable source data.
  Future<void> discard() {
    _acceptingFrames = false;
    return _enqueueLifecycle(() async {
      await _writeTail;
      if (_manifest.journalAudioId != null) {
        throw StateError(
          'Journal-owned recording cannot be discarded by spool',
        );
      }
      if (_manifest.state == DurableAudioSpoolState.discarded) return;
      if (_manifest.state != DurableAudioSpoolState.recording &&
          _manifest.state != DurableAudioSpoolState.recoveryRequired &&
          _manifest.state != DurableAudioSpoolState.quarantined &&
          _manifest.state != DurableAudioSpoolState.discarding) {
        throw StateError('Cannot discard in ${_manifest.state.name} state');
      }
      if (_manifest.state != DurableAudioSpoolState.discarding) {
        await _replaceManifest(state: DurableAudioSpoolState.discarding);
      }
      await _purgeOwnedFiles();
      await _replaceManifest(state: DurableAudioSpoolState.discarded);
    });
  }

  /// Deletes a finalized, unowned transient recording after its transcript
  /// has been durably accepted by the caller.
  ///
  /// This is intentionally separate from [discard]: a user cancel may only
  /// delete an active/recovery capture, while transient consumption may only
  /// delete a valid published WAV with no journal owner.
  Future<void> consumeTransient() {
    _acceptingFrames = false;
    return _enqueueLifecycle(() async {
      await _writeTail;
      if (_manifest.journalAudioId != null) {
        throw StateError(
          'Journal-owned recording cannot be consumed as transient',
        );
      }
      if (_manifest.state == DurableAudioSpoolState.discarded) return;
      if (_manifest.state != DurableAudioSpoolState.published &&
          _manifest.state != DurableAudioSpoolState.discarding) {
        throw StateError(
          'Only a published transient recording can be consumed',
        );
      }
      if (_manifest.state == DurableAudioSpoolState.published) {
        if (!await _finalWavIsValid()) {
          throw StateError('Published transient WAV is not valid');
        }
        await _replaceManifest(state: DurableAudioSpoolState.discarding);
      }
      await _purgeOwnedFiles();
      await _replaceManifest(state: DurableAudioSpoolState.discarded);
    });
  }

  /// Reclaims redundant PCM chunks after the committed grace period.
  Future<void> reclaimCommittedPcm() {
    return _enqueueLifecycle(() async {
      if ((_manifest.state != DurableAudioSpoolState.committed &&
              _manifest.state != DurableAudioSpoolState.reclaimPrepared) ||
          _manifest.journalAudioId == null ||
          !await _finalWavIsValid()) {
        throw StateError('Only a valid committed recording can reclaim PCM');
      }
      if (_manifest.pcmReclaimed) {
        await _purgePcmFiles();
        return;
      }
      if (_manifest.state == DurableAudioSpoolState.committed) {
        final prepared = _copyManifest(
          state: DurableAudioSpoolState.reclaimPrepared,
        );
        await _publishManifest(prepared);
      }
      final compacted = _copyManifest(
        state: DurableAudioSpoolState.committed,
        chunks: const <DurableAudioChunk>[],
        activeChunkBytes: 0,
        pcmReclaimed: true,
      );
      await _publishManifest(compacted);
      await _purgePcmFiles();
    });
  }

  Future<void> _ensureDurableDirectory(Directory directory) async {
    if (directory.existsSync()) return;
    final missing = <Directory>[];
    var current = directory.absolute;
    while (!current.existsSync()) {
      missing.add(current);
      final parent = current.parent;
      if (parent.path == current.path) {
        throw FileSystemException(
          'Unable to find an existing asset directory ancestor',
          directory.path,
        );
      }
      current = parent;
    }
    for (final child in missing.reversed) {
      await child.create();
      await _durability.entryPublished(
        child.parent,
        AudioSpoolDurabilityBoundary.assetDirectoryPublished,
      );
    }
  }

  Future<void> _purgeOwnedFiles() async {
    await _purgePcmFiles();
    final finalPath = _manifest.finalWavPath;
    if (finalPath != null && _isApprovedAssetPath(finalPath)) {
      var deleted = false;
      for (final candidate in <File>[
        File(finalPath),
        File('$finalPath.part'),
        File('$finalPath.previous'),
        File('$finalPath$_wavOwnerSuffix'),
      ]) {
        if (candidate.existsSync()) {
          await candidate.delete();
          deleted = true;
        }
      }
      if (deleted) {
        await _durability.entryPublished(
          File(finalPath).parent,
          AudioSpoolDurabilityBoundary.assetPurged,
        );
      }
    }
  }

  Future<void> _purgePcmFiles() async {
    var deleted = false;
    for (final entry in _sessionDirectory.listSync()) {
      final name = path.basename(entry.path);
      if (_chunkPattern.hasMatch(name) || _activePattern.hasMatch(name)) {
        await entry.delete();
        deleted = true;
      }
    }
    if (deleted) {
      await _durability.entryPublished(
        _sessionDirectory,
        AudioSpoolDurabilityBoundary.pcmPurged,
      );
    }
  }

  Future<void> _publishOwnerMarker(String journalAudioId) async {
    final existing = await _readOwnerMarker();
    if (existing != null) {
      if (existing != journalAudioId) {
        throw StateError('Recording is committed to another journal row');
      }
      return;
    }
    final payload = jsonEncode(<String, Object?>{
      'schemaVersion': 1,
      'journalAudioId': journalAudioId,
    });
    final envelope = jsonEncode(<String, Object?>{
      'payload': payload,
      'sha256': sha256.convert(utf8.encode(payload)).toString(),
    });
    final destination = File(
      path.join(_sessionDirectory.path, _ownerFileName),
    );
    final partial = File('${destination.path}.part');
    await partial.writeAsString(envelope, flush: true);
    await _durability.fileFlushed(
      AudioSpoolDurabilityBoundary.ownerFileFlushed,
    );
    await partial.rename(destination.path);
    await _durability.entryPublished(
      _sessionDirectory,
      AudioSpoolDurabilityBoundary.ownerPublished,
    );
  }

  Future<String?> _readOwnerMarker() async {
    final file = File(path.join(_sessionDirectory.path, _ownerFileName));
    if (!file.existsSync()) return null;
    final envelope =
        jsonDecode(await file.readAsString())! as Map<String, Object?>;
    final payload = envelope['payload']! as String;
    if (sha256.convert(utf8.encode(payload)).toString() != envelope['sha256']) {
      throw const FormatException('Invalid audio spool owner marker');
    }
    final json = jsonDecode(payload)! as Map<String, Object?>;
    if (json['schemaVersion'] != 1) {
      throw const FormatException('Invalid audio spool owner marker version');
    }
    final journalAudioId = json['journalAudioId']! as String;
    if (journalAudioId.trim().isEmpty) {
      throw const FormatException('Empty audio spool owner marker');
    }
    return journalAudioId;
  }

  Future<void> _repairInterruptedWavPublication(File destinationFile) async {
    final previous = File('${destinationFile.path}.previous');
    if (!destinationFile.existsSync() && previous.existsSync()) {
      await previous.rename(destinationFile.path);
      await _durability.entryPublished(
        destinationFile.parent,
        AudioSpoolDurabilityBoundary.wavPublished,
      );
    } else if (destinationFile.existsSync() && previous.existsSync()) {
      await previous.delete();
    }
  }

  Future<void> _claimWavDestination(File destinationFile) async {
    final ownerFile = File('${destinationFile.path}$_wavOwnerSuffix');
    if (ownerFile.existsSync()) {
      final owner = await ownerFile.readAsString();
      if (owner != _manifest.context.recordingSessionId) {
        throw FileSystemException(
          'Audio destination belongs to another recording session',
          destinationFile.path,
        );
      }
      return;
    }
    if (destinationFile.existsSync()) {
      throw FileSystemException(
        'Refusing to replace an unowned audio destination',
        destinationFile.path,
      );
    }
    final partial = File('${ownerFile.path}.part');
    await partial.writeAsString(
      _manifest.context.recordingSessionId,
      flush: true,
    );
    await _durability.fileFlushed(
      AudioSpoolDurabilityBoundary.ownerFileFlushed,
    );
    await partial.rename(ownerFile.path);
    await _durability.entryPublished(
      destinationFile.parent,
      AudioSpoolDurabilityBoundary.ownerPublished,
    );
  }

  Future<void> _publishWav({
    required File partialFile,
    required File destinationFile,
  }) async {
    try {
      await partialFile.rename(destinationFile.path);
      await _durability.entryPublished(
        destinationFile.parent,
        AudioSpoolDurabilityBoundary.wavPublished,
      );
      return;
    } on FileSystemException {
      if (!destinationFile.existsSync()) rethrow;
    }

    final previous = File('${destinationFile.path}.previous');
    if (previous.existsSync()) await previous.delete();
    await destinationFile.rename(previous.path);
    await _durability.entryPublished(
      destinationFile.parent,
      AudioSpoolDurabilityBoundary.wavPublished,
    );
    try {
      await partialFile.rename(destinationFile.path);
      await _durability.entryPublished(
        destinationFile.parent,
        AudioSpoolDurabilityBoundary.wavPublished,
      );
      await previous.delete();
    } catch (_) {
      if (!destinationFile.existsSync() && previous.existsSync()) {
        await previous.rename(destinationFile.path);
        await _durability.entryPublished(
          destinationFile.parent,
          AudioSpoolDurabilityBoundary.wavPublished,
        );
      }
      rethrow;
    }
  }

  bool _isApprovedAssetPath(String candidatePath) {
    final assetRoot = path.normalize(_manifest.context.assetRootPath);
    final candidate = path.normalize(File(candidatePath).absolute.path);
    return path.isWithin(assetRoot, candidate);
  }

  Future<T> _enqueueLifecycle<T>(Future<T> Function() operation) {
    final completer = Completer<T>();
    _lifecycleTail = _lifecycleTail.then((_) async {
      try {
        completer.complete(await operation());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<void> _persistFrame(Uint8List frame) async {
    await _persistBarrier?.call();
    var offset = 0;
    while (offset < frame.length) {
      final remainingCapacity =
          _manifest.chunkBytes - _manifest.activeChunkBytes;
      final writeLength = (frame.length - offset) < remainingCapacity
          ? frame.length - offset
          : remainingCapacity;
      final activeFile = File(_activePath(_manifest.chunks.length));
      final isNewActiveFile = !activeFile.existsSync();
      final handle = await activeFile.open(mode: FileMode.append);
      try {
        await handle.writeFrom(frame, offset, offset + writeLength);
        await handle.flush();
      } finally {
        await handle.close();
      }
      await _durability.fileFlushed(
        AudioSpoolDurabilityBoundary.activeFileFlushed,
      );
      if (isNewActiveFile) {
        await _durability.entryPublished(
          _sessionDirectory,
          AudioSpoolDurabilityBoundary.activeFilePublished,
        );
      }
      offset += writeLength;
      _manifest = _copyManifest(
        activeChunkBytes: _manifest.activeChunkBytes + writeLength,
        acceptedPcmBytes: _manifest.acceptedPcmBytes + writeLength,
      );
      if (_manifest.activeChunkBytes == _manifest.chunkBytes) {
        await _publishActiveChunkIfPresent();
      }
    }
  }

  Future<void> _publishActiveChunkIfPresent({
    bool publishManifest = true,
  }) async {
    if (_manifest.activeChunkBytes == 0) return;
    final index = _manifest.chunks.length;
    final activeFile = File(_activePath(index));
    final chunkName = _chunkName(index);
    final chunkFile = await activeFile.rename(
      path.join(_sessionDirectory.path, chunkName),
    );
    await _durability.entryPublished(
      _sessionDirectory,
      AudioSpoolDurabilityBoundary.chunkPublished,
    );
    final length = await chunkFile.length();
    final chunk = DurableAudioChunk(
      index: index,
      fileName: chunkName,
      byteLength: length,
      sha256Digest: await _digestFile(chunkFile),
    );
    _manifest = _copyManifest(
      chunks: <DurableAudioChunk>[..._manifest.chunks, chunk],
      activeChunkBytes: 0,
    );
    if (publishManifest) await _publishManifest();
  }

  Future<({DurableAudioRecoveryReason reason, String detail})?>
  _reconcileFiles() async {
    final minimumAcceptedBytes = _manifest.acceptedPcmBytes;
    final reconciled = <DurableAudioChunk>[];
    for (var index = 0; index < _manifest.chunks.length; index++) {
      final chunk = _manifest.chunks[index];
      if (chunk.index != index || chunk.fileName != _chunkName(index)) {
        return (
          reason: DurableAudioRecoveryReason.invalidChunkSequence,
          detail: 'Manifest chunk sequence is not contiguous at index $index',
        );
      }
      final file = File(path.join(_sessionDirectory.path, chunk.fileName));
      if (!file.existsSync()) {
        return (
          reason: DurableAudioRecoveryReason.missingChunk,
          detail: 'Missing ${chunk.fileName}',
        );
      }
      final length = await file.length();
      if (length != chunk.byteLength || length.isOdd) {
        return (
          reason: DurableAudioRecoveryReason.invalidChunkLength,
          detail: 'Invalid byte length for ${chunk.fileName}',
        );
      }
      if (await _digestFile(file) != chunk.sha256Digest) {
        return (
          reason: DurableAudioRecoveryReason.chunkDigestMismatch,
          detail: 'Digest mismatch for ${chunk.fileName}',
        );
      }
      reconciled.add(chunk);
    }

    final entries = _sessionDirectory.listSync();
    final unlistedChunkIndexes = <int>[];
    final activeIndexes = <int>[];
    for (final entry in entries) {
      final name = path.basename(entry.path);
      final chunkMatch = _chunkPattern.firstMatch(name);
      if (chunkMatch != null) {
        final index = int.parse(chunkMatch.group(1)!);
        if (index >= reconciled.length) unlistedChunkIndexes.add(index);
      }
      final activeMatch = _activePattern.firstMatch(name);
      if (activeMatch != null) {
        activeIndexes.add(int.parse(activeMatch.group(1)!));
      }
    }
    unlistedChunkIndexes.sort();
    activeIndexes.sort();

    for (var position = 0; position < unlistedChunkIndexes.length; position++) {
      final index = unlistedChunkIndexes[position];
      if (index != reconciled.length) {
        return (
          reason: DurableAudioRecoveryReason.chunkGap,
          detail: 'PCM chunk gap before index $index',
        );
      }
      final file = File(path.join(_sessionDirectory.path, _chunkName(index)));
      final length = await file.length();
      if (length == 0 || length.isOdd || length > _manifest.chunkBytes) {
        return (
          reason: DurableAudioRecoveryReason.invalidOrphanChunk,
          detail: 'Invalid orphan chunk ${path.basename(file.path)}',
        );
      }
      final isTerminalPhysicalChunk =
          position == unlistedChunkIndexes.length - 1 && activeIndexes.isEmpty;
      if (length < _manifest.chunkBytes && !isTerminalPhysicalChunk) {
        return (
          reason: DurableAudioRecoveryReason.invalidOrphanChunk,
          detail: 'Short orphan chunk is not terminal at index $index',
        );
      }
      reconciled.add(
        DurableAudioChunk(
          index: index,
          fileName: path.basename(file.path),
          byteLength: length,
          sha256Digest: await _digestFile(file),
        ),
      );
    }

    if (activeIndexes.length > 1) {
      return (
        reason: DurableAudioRecoveryReason.multipleActiveChunks,
        detail: 'Multiple active PCM chunks',
      );
    }
    var activeBytes = 0;
    File? recoveredActiveFile;
    if (activeIndexes.isNotEmpty) {
      final activeIndex = activeIndexes.single;
      if (activeIndex != reconciled.length) {
        return (
          reason: DurableAudioRecoveryReason.activeChunkGap,
          detail: 'Active PCM chunk gap before index $activeIndex',
        );
      }
      final activeFile = File(_activePath(activeIndex));
      recoveredActiveFile = activeFile;
      activeBytes = await activeFile.length();
      if (activeBytes > _manifest.chunkBytes) {
        return (
          reason: DurableAudioRecoveryReason.activeChunkTooLarge,
          detail: 'Active PCM chunk exceeds configured chunk size',
        );
      }
      if (activeBytes.isOdd) {
        activeBytes -= 1;
        final handle = await activeFile.open(mode: FileMode.append);
        try {
          await handle.truncate(activeBytes);
          await handle.flush();
        } finally {
          await handle.close();
        }
      }
      if (activeBytes == 0) await activeFile.delete();
    }

    final physicalBytes =
        reconciled.fold<int>(0, (sum, chunk) => sum + chunk.byteLength) +
        activeBytes;
    if (physicalBytes < minimumAcceptedBytes) {
      return (
        reason: DurableAudioRecoveryReason.acknowledgedPrefixMissing,
        detail: 'Durable PCM is shorter than the acknowledged manifest prefix',
      );
    }

    if (recoveredActiveFile != null && activeBytes > 0) {
      final index = reconciled.length;
      final chunkName = _chunkName(index);
      final chunkFile = await recoveredActiveFile.rename(
        path.join(_sessionDirectory.path, chunkName),
      );
      reconciled.add(
        DurableAudioChunk(
          index: index,
          fileName: chunkName,
          byteLength: activeBytes,
          sha256Digest: await _digestFile(chunkFile),
        ),
      );
      activeBytes = 0;
    }

    _manifest = _copyManifest(
      chunks: reconciled,
      activeChunkBytes: activeBytes,
      acceptedPcmBytes: physicalBytes,
    );
    return null;
  }

  Future<bool> _finalWavIsValid() async {
    final name = _manifest.finalWavPath;
    final expectedDigest = _manifest.finalWavSha256;
    if (name == null || expectedDigest == null) return false;
    final file = File(name);
    if (!file.existsSync()) return false;
    if (await file.length() != 44 + _manifest.acceptedPcmBytes) return false;
    final wavHandle = await file.open();
    try {
      final header = await wavHandle.read(44);
      if (!isCanonicalPcmWavHeader(
        header,
        dataSize: _manifest.acceptedPcmBytes,
      )) {
        return false;
      }
      if (!_manifest.pcmReclaimed &&
          _manifest.state != DurableAudioSpoolState.reclaimPrepared) {
        for (final chunk in _manifest.chunks) {
          final expected = await File(
            path.join(_sessionDirectory.path, chunk.fileName),
          ).readAsBytes();
          final actual = await wavHandle.read(expected.length);
          if (!_bytesEqual(actual, expected)) return false;
        }
        if ((await wavHandle.read(1)).isNotEmpty) return false;
      }
    } finally {
      await wavHandle.close();
    }
    return await _digestFile(file) == expectedDigest;
  }

  DurableAudioSpoolFinalization _finalizationFromManifest() {
    final name = _manifest.finalWavPath!;
    return DurableAudioSpoolFinalization(
      context: _manifest.context,
      wavPath: name,
      wavSha256: _manifest.finalWavSha256!,
      pcmBytes: _manifest.acceptedPcmBytes,
      duration: Duration(
        microseconds:
            _manifest.acceptedPcmBytes *
            Duration.microsecondsPerSecond ~/
            (spoolSampleRate * spoolChannels * spoolBitsPerSample ~/ 8),
      ),
    );
  }

  Future<void> _replaceManifest({
    required DurableAudioSpoolState state,
    String? finalWavPath,
    String? finalWavSha256,
    String? journalAudioId,
    DurableAudioRecoveryReason? recoveryReason,
    String? recoveryDetail,
  }) async {
    final candidate = _copyManifest(
      state: state,
      finalWavPath: finalWavPath,
      finalWavSha256: finalWavSha256,
      journalAudioId: journalAudioId,
      recoveryReason: recoveryReason,
      recoveryDetail: recoveryDetail,
      clearRecovery:
          recoveryReason == null && state != DurableAudioSpoolState.quarantined,
    );
    await _publishManifest(candidate);
  }

  DurableAudioSpoolManifest _copyManifest({
    DurableAudioSpoolState? state,
    List<DurableAudioChunk>? chunks,
    int? activeChunkBytes,
    int? acceptedPcmBytes,
    String? finalWavPath,
    String? finalWavSha256,
    String? journalAudioId,
    DurableAudioRecoveryReason? recoveryReason,
    String? recoveryDetail,
    bool? pcmReclaimed,
    bool clearRecovery = false,
  }) {
    return DurableAudioSpoolManifest(
      generation: _manifest.generation,
      context: _manifest.context,
      state: state ?? _manifest.state,
      chunks: chunks ?? _manifest.chunks,
      activeChunkBytes: activeChunkBytes ?? _manifest.activeChunkBytes,
      acceptedPcmBytes: acceptedPcmBytes ?? _manifest.acceptedPcmBytes,
      chunkBytes: _manifest.chunkBytes,
      finalWavPath: finalWavPath ?? _manifest.finalWavPath,
      finalWavSha256: finalWavSha256 ?? _manifest.finalWavSha256,
      journalAudioId: journalAudioId ?? _manifest.journalAudioId,
      pcmReclaimed: pcmReclaimed ?? _manifest.pcmReclaimed,
      recoveryReason: clearRecovery
          ? null
          : recoveryReason ?? _manifest.recoveryReason,
      recoveryDetail: clearRecovery
          ? null
          : recoveryDetail ?? _manifest.recoveryDetail,
    );
  }

  Future<void> _publishManifest([
    DurableAudioSpoolManifest? current,
  ]) async {
    final source = current ?? _manifest;
    final next = DurableAudioSpoolManifest(
      generation: _nextManifestGeneration,
      context: source.context,
      state: source.state,
      chunks: source.chunks,
      activeChunkBytes: source.activeChunkBytes,
      acceptedPcmBytes: source.acceptedPcmBytes,
      chunkBytes: source.chunkBytes,
      finalWavPath: source.finalWavPath,
      finalWavSha256: source.finalWavSha256,
      journalAudioId: source.journalAudioId,
      pcmReclaimed: source.pcmReclaimed,
      recoveryReason: source.recoveryReason,
      recoveryDetail: source.recoveryDetail,
    );
    final payload = jsonEncode(next.toJson());
    final envelope = jsonEncode(<String, Object?>{
      'payload': payload,
      'sha256': sha256.convert(utf8.encode(payload)).toString(),
    });
    final destination = File(
      path.join(_sessionDirectory.path, _manifestName(next.generation)),
    );
    final partial = File('${destination.path}.part');
    await partial.writeAsString(envelope, flush: true);
    await _durability.fileFlushed(
      AudioSpoolDurabilityBoundary.manifestFileFlushed,
    );
    await partial.rename(destination.path);
    await _durability.entryPublished(
      _sessionDirectory,
      AudioSpoolDurabilityBoundary.manifestPublished,
    );
    _manifest = next;
    _nextManifestGeneration += 1;
    await _pruneManifestGenerations();
  }

  static Future<({DurableAudioSpoolManifest manifest, int maxGeneration})>
  _readLatestValidManifest(
    Directory directory,
  ) async {
    final candidates = <({int generation, File file})>[];
    for (final entry in directory.listSync()) {
      if (entry is! File) continue;
      final match = _manifestPattern.firstMatch(path.basename(entry.path));
      if (match != null) {
        candidates.add((generation: int.parse(match.group(1)!), file: entry));
      }
    }
    candidates.sort((a, b) => b.generation.compareTo(a.generation));
    for (final candidate in candidates) {
      try {
        final envelope =
            jsonDecode(await candidate.file.readAsString())!
                as Map<String, Object?>;
        final payload = envelope['payload']! as String;
        if (sha256.convert(utf8.encode(payload)).toString() !=
            envelope['sha256']) {
          continue;
        }
        final manifest = DurableAudioSpoolManifest.fromJson(
          jsonDecode(payload)! as Map<String, Object?>,
        );
        if (manifest.generation == candidate.generation &&
            _manifestIsValid(manifest)) {
          return (
            manifest: manifest,
            maxGeneration: candidates.first.generation,
          );
        }
      } catch (_) {
        // Try the preceding immutable generation.
      }
    }
    throw const FormatException('No valid audio spool manifest');
  }

  Future<void> _pruneManifestGenerations() async {
    final manifests = <({int generation, File file})>[];
    for (final entry in _sessionDirectory.listSync()) {
      if (entry is! File) continue;
      final match = _manifestPattern.firstMatch(path.basename(entry.path));
      if (match != null) {
        manifests.add((generation: int.parse(match.group(1)!), file: entry));
      }
    }
    manifests.sort((a, b) => b.generation.compareTo(a.generation));
    // Keep one extra slot so a corrupt newest generation never causes cleanup
    // to remove the preceding known-good fallback before recovery runs.
    var deleted = false;
    for (final stale in manifests.skip(3)) {
      try {
        await stale.file.delete();
        deleted = true;
      } catch (_) {
        // Bounded cleanup is retried at the next publication.
      }
    }
    if (deleted) {
      await _durability.entryPublished(
        _sessionDirectory,
        AudioSpoolDurabilityBoundary.manifestsPruned,
      );
    }
  }

  static bool _manifestIsValid(DurableAudioSpoolManifest manifest) {
    if (!_safeSessionId.hasMatch(manifest.context.recordingSessionId) ||
        manifest.context.activityEntryId.trim().isEmpty ||
        !path.isAbsolute(manifest.context.assetRootPath) ||
        path.normalize(manifest.context.assetRootPath) !=
            manifest.context.assetRootPath ||
        manifest.chunkBytes <= 0 ||
        manifest.chunkBytes.isOdd ||
        manifest.activeChunkBytes < 0 ||
        manifest.activeChunkBytes > manifest.chunkBytes ||
        manifest.activeChunkBytes.isOdd ||
        manifest.acceptedPcmBytes < 0 ||
        manifest.acceptedPcmBytes.isOdd) {
      return false;
    }
    var describedBytes = manifest.activeChunkBytes;
    for (var index = 0; index < manifest.chunks.length; index++) {
      final chunk = manifest.chunks[index];
      if (chunk.index != index ||
          chunk.fileName != _chunkName(index) ||
          chunk.byteLength <= 0 ||
          chunk.byteLength > manifest.chunkBytes ||
          chunk.byteLength.isOdd ||
          chunk.sha256Digest.length != 64) {
        return false;
      }
      describedBytes += chunk.byteLength;
    }
    if (manifest.pcmReclaimed) {
      final validReclaimedState =
          manifest.state == DurableAudioSpoolState.committed ||
          manifest.state == DurableAudioSpoolState.quarantined ||
          manifest.state == DurableAudioSpoolState.recoveryRequired;
      if (!validReclaimedState ||
          manifest.chunks.isNotEmpty ||
          manifest.activeChunkBytes != 0 ||
          (manifest.journalAudioId?.trim().isEmpty ?? true) ||
          manifest.finalWavPath == null ||
          manifest.finalWavSha256?.length != 64 ||
          !path.isWithin(
            manifest.context.assetRootPath,
            manifest.finalWavPath!,
          )) {
        return false;
      }
    } else if (describedBytes != manifest.acceptedPcmBytes) {
      return false;
    }
    if (manifest.state == DurableAudioSpoolState.published ||
        manifest.state == DurableAudioSpoolState.committed ||
        manifest.state == DurableAudioSpoolState.reclaimPrepared) {
      if (manifest.finalWavPath == null ||
          manifest.finalWavSha256?.length != 64 ||
          !path.isWithin(
            manifest.context.assetRootPath,
            manifest.finalWavPath!,
          )) {
        return false;
      }
    }
    if ((manifest.state == DurableAudioSpoolState.committed ||
            manifest.state == DurableAudioSpoolState.reclaimPrepared) &&
        (manifest.journalAudioId?.trim().isEmpty ?? true)) {
      return false;
    }
    return true;
  }

  static bool _bytesEqual(List<int> left, List<int> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }

  String _activePath(int index) =>
      path.join(_sessionDirectory.path, 'active-${_formatIndex(index)}.part');

  static String _chunkName(int index) => 'chunk-${_formatIndex(index)}.pcm';

  static String _manifestName(int generation) =>
      'manifest-${_formatIndex(generation)}.json';

  static String _formatIndex(int value) => value.toString().padLeft(8, '0');

  static Future<String> _digestFile(File file) async =>
      (await sha256.bind(file.openRead()).first).toString();
}
