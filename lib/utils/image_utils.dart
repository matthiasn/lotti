import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:path/path.dart' as p;

Future<XFile?> compressAndSave(
  File file,
  String targetPath, {
  CompressFormat format = CompressFormat.jpeg,
}) async {
  final sourcePath = file.absolute.path;
  final result = await FlutterImageCompress.compressAndGetFile(
    sourcePath,
    targetPath,
    minHeight: 10000,
    minWidth: 10000,
    quality: 90,
    format: format,
    keepExif: format == CompressFormat.jpeg,
  );
  return result;
}

String? getRelativeAssetPath(
  String? absolutePath, {
  bool isAndroid = false,
}) {
  if (isAndroid) {
    return absolutePath?.split('app_flutter').last;
  }
  return absolutePath?.split('Documents').last;
}

String getRelativeImagePath(JournalImage img) {
  return '${img.data.imageDirectory}${img.data.imageFile}';
}

/// Returns the canonical documents-relative directory for an image.
///
/// Image paths are persisted with forward slashes and a leading/trailing
/// separator. Keeping that representation platform-neutral lets sync payloads
/// move between operating systems while physical paths are built with
/// [p.join].
String canonicalImageDirectory(String imageDirectory) {
  final normalized = imageDirectory.replaceAll(r'\', '/');
  final withoutLeading = normalized.replaceFirst(RegExp('^/+'), '');
  final withoutTrailing = withoutLeading.replaceFirst(RegExp(r'/+$'), '');
  return withoutTrailing.isEmpty ? '/' : '/$withoutTrailing/';
}

/// Resolves [img] to its canonical location inside [documentsDirectory].
String getCanonicalImagePath(
  JournalImage img, {
  String? documentsDirectory,
}) {
  final docDir = documentsDirectory ?? getDocumentsDirectory().path;
  final directory = canonicalImageDirectory(img.data.imageDirectory);
  final relativeDirectory = directory.replaceFirst(RegExp('^/+'), '');
  return p.normalize(p.join(docDir, relativeDirectory, img.data.imageFile));
}

/// Reconstructs the path produced by the legacy missing-separator bug.
///
/// Before the screenshot fix, `images/...` was appended directly to the
/// documents root, producing a sibling such as `Documentsimages/...`.
/// This helper exists only for recovery and must never be used for new writes.
String getLegacyMalformedImagePath(
  JournalImage img, {
  String? documentsDirectory,
}) {
  final docDir = documentsDirectory ?? getDocumentsDirectory().path;
  final directory = canonicalImageDirectory(img.data.imageDirectory);
  final segments = p.posix
      .split(directory)
      .where((segment) => segment != '/')
      .toList(growable: false);
  if (segments.isEmpty) {
    return p.join(docDir, img.data.imageFile);
  }

  final legacyRoot = '${p.basename(docDir)}${segments.first}';
  return p.normalize(
    p.joinAll([
      p.dirname(docDir),
      legacyRoot,
      ...segments.skip(1),
      img.data.imageFile,
    ]),
  );
}

String getFullImagePath(
  JournalImage img, {
  String? documentsDirectory,
}) {
  final canonicalPath = getCanonicalImagePath(
    img,
    documentsDirectory: documentsDirectory,
  );
  if (File(canonicalPath).existsSync()) {
    return canonicalPath;
  }

  // Preserve inline display for screenshots created by the legacy bug until
  // the user runs the centralized maintenance repair.
  final legacyPath = getLegacyMalformedImagePath(
    img,
    documentsDirectory: documentsDirectory,
  );
  return File(legacyPath).existsSync() ? legacyPath : canonicalPath;
}
