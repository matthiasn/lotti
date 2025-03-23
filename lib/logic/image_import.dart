import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/geolocation.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:lotti/utils/location.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

Future<void> importImageAssets(
  BuildContext context, {
  String? linkedId,
  String? categoryId,
}) async {
  final ps = await PhotoManager.requestPermissionExtend();
  if (!ps.isAuth) {
    return;
  }

  if (!context.mounted) {
    return;
  }

  final assets = await AssetPicker.pickAssets(
    context,
    pickerConfig: const AssetPickerConfig(
      maxAssets: 50,
      requestType: RequestType.image,
      textDelegate: EnglishAssetPickerTextDelegate(),
    ),
  );

  if (assets != null) {
    for (final asset in assets.toList(growable: false)) {
      Geolocation? geolocation;
      final latLng = await asset.latlngAsync();
      final latitude = latLng.latitude ?? asset.latitude;
      final longitude = latLng.longitude ?? asset.longitude;

      if (latitude != null &&
          longitude != null &&
          latitude != 0 &&
          longitude != 0) {
        geolocation = Geolocation(
          createdAt: asset.createDateTime,
          latitude: latitude,
          longitude: longitude,
          geohashString: getGeoHash(
            latitude: latitude,
            longitude: longitude,
          ),
        );
      }

      final createdAt = asset.createDateTime;
      final file = await asset.file;

      if (file != null) {
        final idNamePart = asset.id.split('/').first;
        final originalName = file.path.split('/').last;
        final imageFileName = '$idNamePart.$originalName'
            .replaceAll(
              'HEIC',
              'JPG',
            )
            .replaceAll(
              'PNG',
              'JPG',
            );
        final day = DateFormat('yyyy-MM-dd').format(createdAt);
        final relativePath = '/images/$day/';
        final directory = await createAssetDirectory(relativePath);
        final targetFilePath = '$directory$imageFileName';
        await compressAndSave(file, targetFilePath);
        final created = asset.createDateTime;

        final imageData = ImageData(
          imageId: asset.id,
          imageFile: imageFileName,
          imageDirectory: relativePath,
          capturedAt: created,
          geolocation: geolocation,
        );

        await JournalRepository.createImageEntry(
          imageData,
          linkedId: linkedId,
          categoryId: categoryId,
        );
      }
    }
  }
}

Future<void> importDroppedImages({
  required DropDoneDetails data,
  String? linkedId,
  String? categoryId,
}) async {
  for (final file in data.files) {
    final lastModified = await file.lastModified();
    final id = uuid.v1();
    final srcPath = file.path;
    final fileExtension = file.name.split('.').last.toLowerCase();

    if (!{'jpg', 'jpeg', 'png'}.contains(fileExtension)) {
      return;
    }

    final day = DateFormat('yyyy-MM-dd').format(lastModified);
    final relativePath = '/images/$day/';
    final directory = await createAssetDirectory(relativePath);
    final targetFileName = '$id.$fileExtension';
    final targetFilePath = '$directory$targetFileName';

    await File(srcPath).copy(targetFilePath);

    final imageData = ImageData(
      imageId: id,
      imageFile: targetFileName,
      imageDirectory: relativePath,
      capturedAt: lastModified,
    );

    await JournalRepository.createImageEntry(
      imageData,
      linkedId: linkedId,
      categoryId: categoryId,
    );
  }
}

Future<void> importPastedImages({
  required Uint8List data,
  required String fileExtension,
  String? linkedId,
  String? categoryId,
}) async {
  final capturedAt = DateTime.now();
  final id = uuid.v1();

  final day = DateFormat('yyyy-MM-dd').format(capturedAt);
  final relativePath = '/images/$day/';
  final directory = await createAssetDirectory(relativePath);
  final targetFileName = '$id.$fileExtension';
  final targetFilePath = '$directory$targetFileName';

  final file = await File(targetFilePath).create(recursive: true);
  await file.writeAsBytes(data);

  final imageData = ImageData(
    imageId: id,
    imageFile: targetFileName,
    imageDirectory: relativePath,
    capturedAt: capturedAt,
  );

  await JournalRepository.createImageEntry(
    imageData,
    linkedId: linkedId,
    categoryId: categoryId,
  );
}
