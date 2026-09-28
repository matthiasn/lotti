import 'dart:io';

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/utils/audio_utils.dart';
import 'package:lotti/utils/image_utils.dart';

/// The file an image or audio entry carries: where this device keeps it, and
/// the documents-relative path it travels under.
typedef EntryMedia = ({File file, String relativePath});

/// The media of [entity], or null for entry types that carry none.
///
/// The one resolution every sync path shares — the enqueue, the upload, the
/// media request answer and the deep-backfill inventory — so the size a
/// device advertises is the size of the file it would send. Pure path
/// resolution: it neither checks that the file exists nor consults the
/// attachment policy.
EntryMedia? entryMedia(
  JournalEntity entity, {
  required Directory documentsDirectory,
}) => switch (entity) {
  JournalImage() => (
    file: File(
      getFullImagePath(entity, documentsDirectory: documentsDirectory.path),
    ),
    relativePath: getRelativeImagePath(entity),
  ),
  JournalAudio() => (
    file: File(AudioUtils.getAudioPath(entity, documentsDirectory)),
    relativePath: AudioUtils.getRelativeAudioPath(entity),
  ),
  _ => null,
};

/// The size of [file] in bytes, or 0 when it is missing or unreadable: sync
/// treats an empty file as no file, the signature of an interrupted write.
Future<int> mediaFileLength(File file) async {
  try {
    return await file.length();
  } on FileSystemException {
    return 0;
  }
}
