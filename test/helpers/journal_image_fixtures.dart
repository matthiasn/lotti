/// A `JournalImage` and, when a test wants one, its file on disk — for the
/// surfaces that draw an image entry and have to cope with the file arriving
/// after the entry (`JournalImageResolver` and its hosts).
///
/// Pair with a temp `Directory` registered in `getIt`, which is what
/// `getFullImagePath` resolves against; [createImageFile] writes to exactly
/// the path the widget under test will compute.
library;

import 'dart:io';

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/utils/image_utils.dart';

/// A `JournalImage` entry. The defaults give one whose file is *not* on disk;
/// call [createImageFile] to put it there.
JournalImage buildJournalImage({
  String id = 'image-1',
  String imageFile = 'test.jpg',
  String imageDirectory = '/images/',
  String? thumbHash,
}) {
  final now = DateTime(2025, 12, 31, 12);
  return JournalImage(
    meta: Metadata(
      id: id,
      createdAt: now,
      updatedAt: now,
      dateFrom: now,
      dateTo: now,
    ),
    data: ImageData(
      imageId: 'img-uuid-$id',
      imageFile: imageFile,
      imageDirectory: imageDirectory,
      capturedAt: now,
      thumbHash: thumbHash,
    ),
  );
}

/// Writes [image]'s file where `getFullImagePath` will look for it and
/// returns that path. [bytes] default to a JPEG magic prefix — enough for
/// "the file exists", which is all a structure test needs; a capture that
/// has to *decode* the picture passes a real image instead.
String createImageFile(JournalImage image, {List<int>? bytes}) {
  final fullPath = getFullImagePath(image);
  Directory(
    fullPath.substring(0, fullPath.lastIndexOf('/')),
  ).createSync(recursive: true);
  File(fullPath).writeAsBytesSync(bytes ?? const [0xFF, 0xD8, 0xFF, 0xE0]);
  return fullPath;
}
