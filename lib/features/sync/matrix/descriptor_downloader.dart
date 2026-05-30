import 'dart:convert';
import 'dart:io';

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/sync/matrix/utils/attachment_decoding.dart';
import 'package:lotti/features/sync/matrix/vector_clock_validator.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:matrix/matrix.dart';

class DescriptorDownloadResult {
  const DescriptorDownloadResult({
    required this.json,
    required this.bytesLength,
  });

  final String json;
  final int bytesLength;
}

class DescriptorDownloader {
  DescriptorDownloader({
    required DomainLogger loggingService,
    required this._validator,
    this.onCachePurge,
  }) : _logging = loggingService;

  static const int maxDescriptorDownloadAttempts = 2;

  final DomainLogger _logging;
  final VectorClockValidator _validator;
  void Function()? onCachePurge;

  Future<DescriptorDownloadResult> download({
    required Event descriptorEvent,
    required VectorClock incomingVectorClock,
    required String jsonPath,
  }) async {
    for (var attempt = 0; attempt < maxDescriptorDownloadAttempts; attempt++) {
      final matrixFile = await downloadAttachmentWithTimeout(
        descriptorEvent,
        pathForError: jsonPath,
      );
      final downloadedBytes = matrixFile.bytes;
      if (downloadedBytes.isEmpty) {
        final purged = await _maybePurgeCachedDescriptor(
          descriptorEvent,
          jsonPath,
        );
        if (purged && attempt + 1 < maxDescriptorDownloadAttempts) {
          onCachePurge?.call();
          _logging.log(
            LogDomain.sync,
            'smart.fetch.empty_bytes.refresh path=$jsonPath',
            subDomain: 'SmartLoader.fetch',
          );
          continue;
        }
        throw const FileSystemException('empty attachment bytes');
      }
      final bytes = await decodeAttachmentBytes(
        event: descriptorEvent,
        downloadedBytes: downloadedBytes,
        relativePath: jsonPath,
        logging: _logging,
      );
      final candidateJson = utf8.decode(bytes);
      final decoded =
          (await decodeJsonStringMaybeIsolate(candidateJson))!
              as Map<String, dynamic>;
      final candidate = JournalEntity.fromJson(decoded);
      final decision = _validator.evaluate(
        jsonPath: jsonPath,
        incomingVectorClock: incomingVectorClock,
        candidate: candidate,
        attempt: attempt,
      );
      switch (decision) {
        case VectorClockDecision.accept:
          _validator.reset(jsonPath);
          return DescriptorDownloadResult(
            json: candidateJson,
            bytesLength: bytes.length,
          );
        case VectorClockDecision.retryAfterPurge:
          final purged = await _maybePurgeCachedDescriptor(
            descriptorEvent,
            jsonPath,
          );
          if (purged) {
            onCachePurge?.call();
          }
          _logging.log(
            LogDomain.sync,
            'smart.fetch.stale_vc.refresh path=$jsonPath',
            subDomain: 'SmartLoader.fetch',
          );
          continue;
        case VectorClockDecision.staleAfterRefresh:
          throw const FileSystemException(
            'stale attachment json after refresh',
          );
        case VectorClockDecision.circuitBreaker:
          throw const FileSystemException(
            'stale attachment json (circuit breaker)',
          );
        case VectorClockDecision.missingVectorClock:
          throw const FileSystemException('missing attachment vector clock');
      }
    }

    throw const FileSystemException('stale attachment json');
  }

  Future<bool> _maybePurgeCachedDescriptor(
    Event event,
    String jsonPath,
  ) async {
    try {
      final uri = event.attachmentOrThumbnailMxcUrl();
      if (uri == null) {
        _logging.log(
          LogDomain.sync,
          'smart.fetch.stale_vc.purge.skipped path=$jsonPath reason=no_mxc',
          subDomain: 'SmartLoader.fetch',
        );
        return false;
      }
      await event.room.client.database.deleteFile(uri);
      _logging.log(
        LogDomain.sync,
        'smart.fetch.stale_vc.purge path=$jsonPath mxc=$uri',
        subDomain: 'SmartLoader.fetch',
      );
      return true;
    } catch (e, st) {
      _logging.error(
        LogDomain.sync,
        e,
        stackTrace: st,
        subDomain: 'SmartLoader.purge',
      );
      return false;
    }
  }
}
