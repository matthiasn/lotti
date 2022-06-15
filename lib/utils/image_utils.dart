import 'dart:io';
import 'dart:typed_data';

import 'package:exif/exif.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:path_provider/path_provider.dart';

Future<void> printGeolocation(Uint8List fileBytes) async {
  final data = await readExifFromBytes(fileBytes);

  if (data.isEmpty) {
    debugPrint('No EXIF information found');
    return;
  }

  final latRef = data['GPS GPSLatitudeRef']?.toString();
  var latVal = gpsValuesToFloat(data['GPS GPSLatitude']?.values);
  final lngRef = data['GPS GPSLongitudeRef']?.toString();
  var lngVal = gpsValuesToFloat(data['GPS GPSLongitude']?.values);

  if (latRef == null || latVal == null || lngRef == null || lngVal == null) {
    debugPrint('GPS information not found');
    return;
  }

  if (latRef == 'S') {
    latVal *= -1;
  }

  if (lngRef == 'W') {
    lngVal *= -1;
  }
}

double? gpsValuesToFloat(IfdValues? values) {
  if (values == null || values is! IfdRatios) {
    return null;
  }

  // ignore: omit_local_variable_types
  double sum = 0;
  // ignore: omit_local_variable_types
  double unit = 1;

  for (final v in values.ratios) {
    sum += v.toDouble() * unit;
    unit /= 60;
  }

  return sum;
}

Future<void> printExif(Uint8List bytes) async {
  final data = await readExifFromBytes(bytes);

  if (data.isEmpty) {
    debugPrint('No EXIF information found');
    return;
  }

  for (final entry in data.entries) {
    debugPrint('${entry.key}: ${entry.value}');
  }

  final created = data['EXIF DateTimeOriginal']?.toString();
  final offsetTime = data['EXIF OffsetTimeOriginal']?.toString();
  debugPrint('Image created: $created $offsetTime');
}

Future<void> printExifFromFile(File file) async {
  final data = await readExifFromFile(file);

  if (data.isEmpty) {
    debugPrint('No EXIF information found');
    return;
  }

  for (final entry in data.entries) {
    debugPrint('${entry.key}: ${entry.value}');
  }

  final created = data['EXIF DateTimeOriginal']?.toString();
  final offsetTime = data['EXIF OffsetTimeOriginal']?.toString();
  debugPrint('Image created: $created $offsetTime');
}

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
