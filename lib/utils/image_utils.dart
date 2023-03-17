import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/utils/file_utils.dart';

Future<File?> compressAndSave(File file, String targetPath) async {
  final sourcePath = file.absolute.path;
  final result = await FlutterImageCompress.compressAndGetFile(
    sourcePath,
    targetPath,
    quality: 90,
    keepExif: true,
  );
  return result;
}

String? getRelativeAssetPath(String? absolutePath) {
  if (Platform.isAndroid) {
    return absolutePath?.split('app_flutter').last;
  }
  return absolutePath?.split('Documents').last;
}

String getFullImagePath(JournalImage img) {
  final docDir = getDocumentsDirectory();
  return '${docDir.path}${img.data.imageDirectory}${img.data.imageFile}';
}
