import 'dart:convert';
import 'dart:io';

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/utils/audio_utils.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:path/path.dart' as p;

/// Describes a single file that a [SyncMessage] would upload individually via
/// `MatrixMessageSender._sendFile` when bundling is disabled.
class AttachmentDescriptor {
  const AttachmentDescriptor({
    required this.fullPath,
    required this.relativePath,
    required this.size,
  });

  /// Absolute path to the file on disk.
  final String fullPath;

  /// Logical relative path used as the sync-side file identifier. This is the
  /// value read by receivers to decide where to write the file locally.
  final String relativePath;

  /// File size in bytes at enumeration time.
  final int size;
}

/// Enumerates the on-disk files a [message] would upload individually.
///
/// Files that are missing or empty are silently omitted. A message that
/// carries no file attachments returns an empty list. Callers should treat
/// a partial enumeration (e.g. the JSON is readable but the media file is
/// missing) as a signal to fall back to the solo send path, where the
/// existing error handling applies.
///
/// This helper never throws; it returns an empty list on any I/O failure.
Future<List<AttachmentDescriptor>> enumerateAttachments({
  required SyncMessage message,
  required Directory documentsDirectory,
}) async {
  switch (message) {
    case final SyncJournalEntity msg:
      return _forJournalEntity(
        message: msg,
        documentsDirectory: documentsDirectory,
      );
    case final SyncAgentEntity msg:
      final path = msg.jsonPath;
      if (path == null) return const [];
      return _forFile(
        relativePath: path,
        documentsDirectory: documentsDirectory,
      );
    case final SyncAgentLink msg:
      final path = msg.jsonPath;
      if (path == null) return const [];
      return _forFile(
        relativePath: path,
        documentsDirectory: documentsDirectory,
      );
    case _:
      return const [];
  }
}

Future<List<AttachmentDescriptor>> _forJournalEntity({
  required SyncJournalEntity message,
  required Directory documentsDirectory,
}) async {
  final base = await _forFile(
    relativePath: message.jsonPath,
    documentsDirectory: documentsDirectory,
  );
  if (base.isEmpty) return const [];

  try {
    final bytes = await File(base.first.fullPath).readAsBytes();
    final entity = JournalEntity.fromJson(
      json.decode(utf8.decode(bytes)) as Map<String, dynamic>,
    );
    final media = await entity.maybeMap(
      journalAudio: (JournalAudio audio) async => _forFile(
        relativePath: AudioUtils.getRelativeAudioPath(audio),
        documentsDirectory: documentsDirectory,
      ),
      journalImage: (JournalImage image) async => _forFile(
        relativePath: getRelativeImagePath(image),
        documentsDirectory: documentsDirectory,
      ),
      orElse: () async => const <AttachmentDescriptor>[],
    );
    return [...base, ...media];
  } catch (_) {
    return base;
  }
}

Future<List<AttachmentDescriptor>> _forFile({
  required String relativePath,
  required Directory documentsDirectory,
}) async {
  final joined = p.joinAll(
    relativePath.split('/').where((part) => part.isNotEmpty),
  );
  final fullPath = p.join(documentsDirectory.path, joined);
  final file = File(fullPath);
  try {
    // ignore: avoid_slow_async_io
    if (!await file.exists()) return const [];
    final size = await file.length();
    if (size <= 0) return const [];
    return [
      AttachmentDescriptor(
        fullPath: fullPath,
        relativePath: relativePath,
        size: size,
      ),
    ];
  } catch (_) {
    return const [];
  }
}
