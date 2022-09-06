import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:path_provider/path_provider.dart';

Future<File?> compressAndGetFile(File file) async {
  final sourcePath = file.absolute.path;
  final result = await FlutterImageCompress.compressAndGetFile(
    sourcePath,
    '$sourcePath.heic',
    format: CompressFormat.heic,
  );
  debugPrint('In: ${file.lengthSync()} out: ${result?.lengthSync()}');
  return result;
}

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

Future<String> getFullAssetPath(String relativePath) async {
  final docDir = await getApplicationDocumentsDirectory();
  return '${docDir.path}$relativePath';
}

String? getRelativeAssetPath(String? absolutePath) {
  if (Platform.isAndroid) {
    return absolutePath?.split('app_flutter').last;
  }
  return absolutePath?.split('Documents').last;
}

Future<String> getFullImagePath(JournalImage img) async {
  final docDir = await getApplicationDocumentsDirectory();
  return '${docDir.path}${img.data.imageDirectory}${img.data.imageFile}';
}

String getFullImagePathWithDocDir(JournalImage img, Directory docDir) {
  return '${docDir.path}${img.data.imageDirectory}${img.data.imageFile}';
}
