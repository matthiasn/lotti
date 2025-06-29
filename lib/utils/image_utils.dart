import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/utils/file_utils.dart';

Future<XFile?> compressAndSave(File file, String targetPath) async {
  final sourcePath = file.absolute.path;
  final result = await FlutterImageCompress.compressAndGetFile(
    sourcePath,
    targetPath,
    minHeight: 10000,
    minWidth: 10000,
    quality: 90,
    keepExif: true,
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

String getFullImagePath(
  JournalImage img, {
  String? documentsDirectory,
}) {
  final docDir = documentsDirectory ?? getDocumentsDirectory().path;
  return '$docDir${getRelativeImagePath(img)}';
}
