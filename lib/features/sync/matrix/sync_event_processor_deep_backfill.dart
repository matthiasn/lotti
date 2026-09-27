part of 'sync_event_processor.dart';

/// Resolves the record lists of a deep-backfill message sent on its own,
/// which travel in a gzipped attachment (`MatrixPayloadSender`
/// `.sendDeepBackfillPayload`). Inside an outbox bundle the lists ride inline
/// and the message needs nothing.
extension _DeepBackfillResolution on SyncEventProcessor {
  /// Returns [message] with its record lists filled from the attachment it
  /// names and the attachment cleared, or unchanged when it names none.
  /// Throws the queue's retriable "descriptor not yet available" error until
  /// the attachment event has arrived. A malformed path or document, which
  /// no retry can repair, returns [message] unchanged: it still names its
  /// attachment, and `DeepBackfillService` ignores a message whose lists were
  /// never loaded — an empty inventory would read as "the advertiser holds
  /// nothing in this range".
  Future<SyncMessage> _resolveDeepBackfillMessage(SyncMessage message) async {
    final (jsonPath, attachmentEventId) = switch (message) {
      SyncDeepBackfillInventory(:final jsonPath, :final attachmentEventId) ||
      SyncDeepBackfillRequest(:final jsonPath, :final attachmentEventId) => (
        jsonPath,
        attachmentEventId,
      ),
      _ => (null, null),
    };
    if (jsonPath == null || attachmentEventId == null) return message;

    final File targetFile;
    try {
      targetFile = _resolveJsonCandidateFile(jsonPath);
    } on FileSystemException catch (error, stackTrace) {
      _loggingService.error(
        LogDomain.sync,
        error,
        stackTrace: stackTrace,
        subDomain: 'processor.resolve.deepBackfill.invalidPath',
      );
      return message;
    }

    final json = await _fetchFromDescriptor(
      jsonPath: jsonPath,
      targetFile: targetFile,
      typeName: 'deepBackfill',
      attachmentEventId: attachmentEventId,
      // The lists are applied once and never read again.
      writeToDisk: false,
    );
    if (json == null) {
      throw FileSystemException(
        'attachment descriptor not yet available',
        jsonPath,
      );
    }

    try {
      final document =
          (await decodeJsonStringMaybeIsolate(json))! as Map<String, dynamic>;
      List<Map<String, dynamic>> list(String key) => [
        for (final item in (document[key] as List<dynamic>? ?? const []))
          item as Map<String, dynamic>,
      ];
      return switch (message) {
        final SyncDeepBackfillInventory m => m.copyWith(
          records: list('records').map(DeepBackfillRecord.fromJson).toList(),
          conflicts: list(
            'conflicts',
          ).map(DeepBackfillRecord.fromJson).toList(),
          unclocked: [
            for (final id in (document['unclocked'] as List<dynamic>? ?? []))
              id as String,
          ],
          unclockedMediaSizes: {
            for (final MapEntry(:key, :value)
                in (document['unclockedMediaSizes'] as Map<String, dynamic>? ??
                        const <String, dynamic>{})
                    .entries)
              key: value as int,
          },
          jsonPath: null,
          attachmentEventId: null,
        ),
        final SyncDeepBackfillRequest m => m.copyWith(
          records: list(
            'records',
          ).map(DeepBackfillRequestRecord.fromJson).toList(),
          jsonPath: null,
          attachmentEventId: null,
        ),
        _ => message,
      };
    } catch (error, stackTrace) {
      _loggingService.error(
        LogDomain.sync,
        error,
        stackTrace: stackTrace,
        subDomain: 'processor.resolve.deepBackfill.parse',
      );
      return message;
    }
  }
}
