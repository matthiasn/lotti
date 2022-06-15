import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/geolocation.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/location.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

Future<void> importImageAssets(
  BuildContext context, {
  JournalEntity? linked,
}) async {
  final persistenceLogic = getIt<PersistenceLogic>();

  final assets = await AssetPicker.pickAssets(
    context,
    pickerConfig: const AssetPickerConfig(
      maxAssets: 40,
      requestType: RequestType.image,
      textDelegate: EnglishAssetPickerTextDelegate(),
    ),
  );
  if (assets != null) {
    for (final asset in assets) {
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
          geohashString: DeviceLocation.getGeoHash(
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

        await persistenceLogic.createImageEntry(
          imageData,
          linkedId: linked?.meta.id,
        );
      }
    }
  }
}
