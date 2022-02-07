import 'dart:async';
import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:lotti/blocs/journal/persistence_cubit.dart';
import 'package:lotti/classes/geolocation.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/location.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

import 'journal_image_state.dart';

class JournalImageCubit extends Cubit<JournalImageState> {
  late final PersistenceCubit _persistenceCubit;

  JournalImageCubit({
    required PersistenceCubit persistenceCubit,
  }) : super(JournalImageState()) {
    _persistenceCubit = persistenceCubit;
  }

  Future<void> pickImageAssets(
    BuildContext context, {
    JournalEntity? linked,
  }) async {
    final List<AssetEntity>? assets = await AssetPicker.pickAssets(
      context,
      maxAssets: 40,
      textDelegate: EnglishTextDelegate(),
      routeDuration: const Duration(seconds: 0),
    );
    if (assets != null) {
      for (final AssetEntity asset in assets) {
        Geolocation? geolocation;
        if (asset.latitude != 0.0 && asset.longitude != 0.0) {
          geolocation = Geolocation(
            createdAt: asset.createDateTime,
            latitude: asset.latitude,
            longitude: asset.longitude,
            geohashString: DeviceLocation.getGeoHash(
              latitude: asset.latitude,
              longitude: asset.longitude,
            ),
          );
        }

        DateTime createdAt = asset.createDateTime;
        File? file = await asset.file;

        if (file != null) {
          String idNamePart = asset.id.split('/').first;
          String originalName = file.path.split('/').last;
          String imageFileName = '$idNamePart.$originalName'
              .replaceAll(
                'HEIC',
                'JPG',
              )
              .replaceAll(
                'PNG',
                'JPG',
              );
          String day = DateFormat('yyyy-MM-dd').format(createdAt);
          String relativePath = '/images/$day/';
          String directory = await createAssetDirectory(relativePath);
          String targetFilePath = '$directory$imageFileName';
          await compressAndSave(file, targetFilePath);
          DateTime created = asset.createDateTime;

          ImageData imageData = ImageData(
            imageId: asset.id,
            imageFile: imageFileName,
            imageDirectory: relativePath,
            capturedAt: created,
            geolocation: geolocation,
          );

          _persistenceCubit.createImageEntry(imageData, linked: linked);
        }
      }
    }
  }
}
