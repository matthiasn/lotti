// ignore_for_file: avoid_setters_without_getters

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/sync/matrix/descriptor_downloader.dart';
import 'package:lotti/features/sync/matrix/pipeline/attachment_index.dart';
import 'package:lotti/features/sync/matrix/sync_journal_entity_loader.dart';
import 'package:lotti/features/sync/matrix/utils/atomic_write.dart';
import 'package:lotti/features/sync/matrix/utils/attachment_decoding.dart';
import 'package:lotti/features/sync/matrix/vector_clock_validator.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/utils/audio_utils.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:matrix/matrix.dart' show Event;

/// Smart loader that ensures JSON presence/currency based on an incoming vector
/// clock. It uses the AttachmentIndex to fetch missing/stale JSON and writes
/// atomically before parsing.
class SmartJournalEntityLoader implements SyncJournalEntityLoader {
  SmartJournalEntityLoader({
    required this._attachmentIndex,
    required DomainLogger loggingService,
    void Function()? onCachePurge,
  }) : _logging = loggingService {
    _vectorClockValidator = VectorClockValidator(
      loggingService: loggingService,
    );
    _descriptorDownloader = DescriptorDownloader(
      loggingService: loggingService,
      validator: _vectorClockValidator,
      onCachePurge: onCachePurge,
    );
  }

  final AttachmentIndex _attachmentIndex;
  final DomainLogger _logging;
  late final VectorClockValidator _vectorClockValidator;
  late final DescriptorDownloader _descriptorDownloader;

  set onCachePurge(void Function()? listener) {
    _descriptorDownloader.onCachePurge = listener;
  }

  void Function(String path)? _onMissingDescriptorPath;

  set onMissingDescriptorPath(void Function(String path)? listener) {
    _onMissingDescriptorPath = listener;
  }

  @override
  Future<JournalEntity> load({
    required String jsonPath,
    VectorClock? incomingVectorClock,
  }) async {
    final targetFile = resolveJsonCandidateFile(jsonPath);
    // Build a canonical index key once and reuse it to avoid inconsistencies
    // across platforms (Windows vs. POSIX). The key always uses forward slashes
    // and has a single leading '/'. Any leading '/' or '\\' characters are trimmed.
    final indexKey = _buildIndexKey(jsonPath);
    // If we have an incoming vector clock, decide whether a fetch is needed.
    if (incomingVectorClock != null) {
      try {
        final local = await const FileSyncJournalEntityLoader().load(
          jsonPath: jsonPath,
        );
        final localVc = local.meta.vectorClock;
        if (localVc != null) {
          final status = VectorClock.compare(localVc, incomingVectorClock);
          if (status == VclockStatus.a_gt_b || status == VclockStatus.equal) {
            // Repair any missing media even when JSON is current.
            await _ensureMediaOnMissing(local);
            return local; // local is current or newer; no fetch
          }
        }
      } on FileSystemException {
        // Expected when text arrives before the descriptor: treat as a local miss.
        // We fetch via AttachmentIndex below; log as an info event rather than exception.
        _logging.log(
          LogDomain.sync,
          'smart.local.miss path=$jsonPath',
          subDomain: 'SmartLoader.localMiss',
        );
      } catch (e, st) {
        // Unexpected read failure – keep as exception for diagnostics.
        _logging.error(
          LogDomain.sync,
          e,
          stackTrace: st,
          subDomain: 'SmartLoader.localRead',
        );
      }

      // Resolve descriptor via AttachmentIndex
      final eventForPath = _attachmentIndex.find(indexKey);
      if (eventForPath == null) {
        // Descriptor not yet available; let caller retry later.
        _logging.log(
          LogDomain.sync,
          'smart.fetch.miss path=$jsonPath key=$indexKey',
          subDomain: 'SmartLoader.fetch',
        );
        throw FileSystemException(
          'attachment descriptor not yet available',
          jsonPath,
        );
      }
      try {
        final descriptor = await _descriptorDownloader.download(
          descriptorEvent: eventForPath,
          incomingVectorClock: incomingVectorClock,
          jsonPath: jsonPath,
        );
        await saveJson(targetFile.path, descriptor.json);
        _logging.log(
          LogDomain.sync,
          'smart.json.written path=$jsonPath bytes=${descriptor.bytesLength}',
          subDomain: 'SmartLoader.fetch',
        );
      } catch (e, st) {
        _logging.error(
          LogDomain.sync,
          e,
          stackTrace: st,
          subDomain: 'SmartLoader.fetchJson',
        );
        rethrow;
      }
    } else {
      // No incoming vector clock: fetch if file is missing/empty, else read.
      var needsFetch = false;
      try {
        if (!targetFile.existsSync()) {
          needsFetch = true;
        } else {
          needsFetch = targetFile.lengthSync() == 0;
        }
      } catch (_) {
        needsFetch = true;
      }
      if (needsFetch) {
        final eventForPath = _attachmentIndex.find(indexKey);
        if (eventForPath == null) {
          _logging.log(
            LogDomain.sync,
            'smart.fetch.miss(noVc) path=$jsonPath key=$indexKey',
            subDomain: 'SmartLoader.fetch',
          );
          throw FileSystemException(
            'attachment descriptor not yet available',
            jsonPath,
          );
        }
        try {
          final matrixFile = await downloadAttachmentWithTimeout(
            eventForPath,
            pathForError: jsonPath,
          );
          final downloadedBytes = matrixFile.bytes;
          if (downloadedBytes.isEmpty) {
            throw const FileSystemException('empty attachment bytes');
          }
          final bytes = await decodeAttachmentBytes(
            event: eventForPath,
            downloadedBytes: downloadedBytes,
            relativePath: jsonPath,
            logging: _logging,
          );
          final jsonString = utf8.decode(bytes);
          await saveJson(targetFile.path, jsonString);
          _logging.log(
            LogDomain.sync,
            'smart.json.written(noVc) path=$jsonPath bytes=${bytes.length}',
            subDomain: 'SmartLoader.fetch',
          );
        } catch (e, st) {
          _logging.error(
            LogDomain.sync,
            e,
            stackTrace: st,
            subDomain: 'SmartLoader.fetchJson.noVc',
          );
          rethrow;
        }
      }
    }

    // Read and return the entity from disk (either pre-existing or freshly written).
    final entity = await const FileSyncJournalEntityLoader().load(
      jsonPath: jsonPath,
    );

    // Missing media must not block entity application. The JSON payload is the
    // authoritative state; referenced audio/image files can arrive later via
    // the attachment pipeline or descriptor catch-up.
    await _ensureMediaOnMissing(entity);
    return entity;
  }

  String _buildIndexKey(String rawPath) => normalizeAttachmentIndexKey(rawPath);

  Future<void> _ensureMediaOnMissing(JournalEntity e) async {
    switch (e) {
      case JournalImage():
        await _ensureMediaFile(getRelativeImagePath(e), mediaType: 'image');
      case JournalAudio():
        await _ensureMediaFile(
          AudioUtils.getRelativeAudioPath(e),
          mediaType: 'audio',
        );
      default:
        return; // No media to ensure
    }
  }

  Future<void> _ensureMediaFile(
    String relativePath, {
    String? mediaType,
  }) async {
    final rp = relativePath;
    // Centralized resolution + sandbox enforcement (rejects path traversal).
    final f = resolveJsonCandidateFile(rp);
    final fp = f.path;
    try {
      if (f.existsSync()) {
        if (f.lengthSync() > 0) return; // present
      }
    } catch (e, st) {
      _logging.error(
        LogDomain.sync,
        e,
        stackTrace: st,
        subDomain: 'SmartLoader.pathCheck',
      );
    }

    final descriptorKey = _buildIndexKey(rp);
    final ev = _attachmentIndex.find(descriptorKey);
    if (ev == null) {
      _logging.log(
        LogDomain.sync,
        'smart.media.miss path=$rp key=$descriptorKey',
        subDomain: 'SmartLoader.fetchMedia',
      );
      _onMissingDescriptorPath?.call(descriptorKey);
      return;
    }
    try {
      Uint8List? downloadedBytes;
      for (var attempt = 0; attempt < 2; attempt++) {
        final file = await downloadAttachmentWithTimeout(ev, pathForError: rp);
        if (file.bytes.isNotEmpty) {
          downloadedBytes = file.bytes;
          break;
        }
        final purged = await _maybePurgeCachedAttachment(ev, rp);
        if (!purged || attempt == 1) {
          throw const FileSystemException('empty attachment bytes');
        }
        _logging.log(
          LogDomain.sync,
          'smart.media.empty_bytes.refresh path=$rp',
          subDomain: 'SmartLoader.fetchMedia',
        );
      }
      final bytes = await decodeAttachmentBytes(
        event: ev,
        downloadedBytes: downloadedBytes!,
        relativePath: rp,
        logging: _logging,
      );
      await atomicWriteBytes(
        bytes: bytes,
        filePath: fp,
        logging: _logging,
        subDomain: 'SmartLoader.writeMedia',
      );
    } catch (e, st) {
      _logging.error(
        LogDomain.sync,
        e,
        stackTrace: st,
        subDomain: 'SmartLoader.fetchMedia',
      );
      _onMissingDescriptorPath?.call(descriptorKey);
    }
  }

  Future<bool> _maybePurgeCachedAttachment(Event event, String path) async {
    try {
      final uri = event.attachmentOrThumbnailMxcUrl();
      if (uri == null) return false;
      await event.room.client.database.deleteFile(uri);
      _logging.log(
        LogDomain.sync,
        'smart.media.empty_bytes.purge path=$path mxc=$uri',
        subDomain: 'SmartLoader.fetchMedia',
      );
      return true;
    } catch (e, st) {
      _logging.error(
        LogDomain.sync,
        e,
        stackTrace: st,
        subDomain: 'SmartLoader.fetchMedia.purge',
      );
      return false;
    }
  }
}
