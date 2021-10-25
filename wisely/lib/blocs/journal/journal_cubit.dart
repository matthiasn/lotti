import 'dart:async';
import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:flutter/widgets.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:intl/intl.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import 'package:wisely/classes/geolocation.dart';
import 'package:wisely/classes/journal_image.dart';
import 'package:wisely/utils/audio_utils.dart';
import 'package:wisely/utils/image_utils.dart';

import 'journal_state.dart';

class JournalCubit extends Cubit<JournalState> {
  JournalCubit() : super(JournalState()) {
    print('Hello from JournalCubit');
  }

  Future<void> pickImageAssets(BuildContext context) async {
    final List<AssetEntity>? assets = await AssetPicker.pickAssets(
      context,
      textDelegate: EnglishTextDelegate(),
      routeDuration: const Duration(seconds: 0),
    );
    if (assets != null) {
      for (final AssetEntity asset in assets) {
        print('pickAssets $asset');
        print('pickAssets createDateTime ${asset.createDateTime}');
        print('pickAssets id ${asset.id}');
        print('pickAssets file ${await asset.file}');

        Geolocation? geolocation;
        if (asset.latitude != null && asset.longitude != null) {
          geolocation = Geolocation(
            createdAt: asset.createDateTime,
            latitude: asset.latitude,
            longitude: asset.longitude,
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
          if (originalName.contains('.PNG')) {
            await compressAndSave(
              originFile,
              '${targetFilePath}',
            );
          } else {
            await File(targetFilePath)
                .writeAsBytes(await originFile.readAsBytes());
          }
          JournalImage journalImage = JournalImage(
            imageId: asset.id,
            geolocation: geolocation,
            imageFile: imageFileName,
            imageDirectory: relativePath,
            createdAt: asset.createDateTime,
          );
          print(journalImage);
        }
      }
    }
  }
}
