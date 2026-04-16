import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/utils/audio_utils.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:path/path.dart' as p;

/// Describes a single file that a [SyncMessage] would upload individually via
/// `MatrixMessageSender._sendFile` when bundling is disabled.
///
/// When the file is the JSON payload the enumerator already read to discover
/// media paths, `bytes` is populated so downstream callers (e.g. the
/// bundler) can avoid re-reading the same file from disk. For media files
/// `bytes` is null and callers must load the contents themselves.
typedef AttachmentDescriptor = ({
  String fullPath,
  String relativePath,
  int size,
  Uint8List? bytes,
});

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
      return _forOptionalJsonPath(msg.jsonPath, documentsDirectory);
    case final SyncAgentLink msg:
      return _forOptionalJsonPath(msg.jsonPath, documentsDirectory);
    case _:
      return const [];
  }
}

Future<List<AttachmentDescriptor>> _forOptionalJsonPath(
  String? relativePath,
  Directory documentsDirectory,
) async {
  if (relativePath == null) return const [];
  return _forFile(
    relativePath: relativePath,
    documentsDirectory: documentsDirectory,
  );
}

Future<List<AttachmentDescriptor>> _forJournalEntity({
  required SyncJournalEntity message,
  required Directory documentsDirectory,
}) async {
  // Read once and cache: the same bytes feed the JournalEntity.fromJson pass
  // below (to discover audio/image paths) and any downstream consumer such as
  // the bundler, so subsequent reads can short-circuit.
  final jsonFullPath = p.join(
    documentsDirectory.path,
    p.joinAll(message.jsonPath.split('/').where((part) => part.isNotEmpty)),
  );
  Uint8List bytes;
  try {
    bytes = await File(jsonFullPath).readAsBytes();
  } on FileSystemException {
    return const [];
  }
  if (bytes.isEmpty) return const [];

  final base = (
    fullPath: jsonFullPath,
    relativePath: message.jsonPath,
    size: bytes.length,
    bytes: bytes,
  );

  try {
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
    return [base, ...media];
  } catch (_) {
    return [base];
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
  try {
    final size = await File(fullPath).length();
    if (size <= 0) return const [];
    return [
      (
        fullPath: fullPath,
        relativePath: relativePath,
        size: size,
        bytes: null,
      ),
    ];
  } on FileSystemException {
    return const [];
  }
}
