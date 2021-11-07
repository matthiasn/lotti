import 'dart:async';
import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:flutter/widgets.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:intl/intl.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import 'package:wisely/blocs/journal/persistence_cubit.dart';
import 'package:wisely/blocs/sync/vector_clock_cubit.dart';
import 'package:wisely/classes/geolocation.dart';
import 'package:wisely/classes/journal_entities.dart';
import 'package:wisely/location.dart';
import 'package:wisely/sync/vector_clock.dart';
import 'package:wisely/utils/audio_utils.dart';
import 'package:wisely/utils/image_utils.dart';

import 'journal_image_state.dart';

class JournalImageCubit extends Cubit<JournalImageState> {
  late final VectorClockCubit _vectorClockCubit;
  late final PersistenceCubit _persistenceCubit;

  JournalImageCubit({
    required VectorClockCubit vectorClockCubit,
    required PersistenceCubit persistenceCubit,
  }) : super(JournalImageState()) {
    _vectorClockCubit = vectorClockCubit;
    _persistenceCubit = persistenceCubit;
  }

  Future<void> pickImageAssets(BuildContext context) async {
    final List<AssetEntity>? assets = await AssetPicker.pickAssets(
      context,
      textDelegate: EnglishTextDelegate(),
      routeDuration: const Duration(seconds: 0),
    );
    if (assets != null) {
      for (final AssetEntity asset in assets) {
        Geolocation? geolocation;
        if (asset.latitude != null && asset.longitude != null) {
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
        File? originFile = await asset.originFile;

        if (originFile != null) {
          String idNamePart = asset.id.split('/').first;
          String originalName = originFile.path.split('/').last;
          String imageFileName = '$idNamePart.$originalName'.replaceAll(
            'PNG',
            'HEIC',
          );
          String day = DateFormat('yyyy-MM-dd').format(createdAt);
          String relativePath = '/images/$day/';
          String directory =
              await AudioUtils.createAssetDirectory(relativePath);
          String targetFilePath = '$directory$imageFileName';
          File? targetFile;
          if (originalName.contains('.PNG')) {
            targetFile = await compressAndSave(originFile, targetFilePath);
          } else {
            targetFile = await File(targetFilePath)
                .writeAsBytes(await originFile.readAsBytes());
          }

          VectorClock vectorClock = _vectorClockCubit.getNextVectorClock();
          DateTime created = asset.createDateTime;

          ImageData imageData = ImageData(
            imageId: asset.id,
            imageFile: imageFileName,
            imageDirectory: relativePath,
            capturedAt: created,
            geolocation: geolocation,
          );

          _persistenceCubit.createImageEntry(imageData);
        }
      }
    }
  }
}
