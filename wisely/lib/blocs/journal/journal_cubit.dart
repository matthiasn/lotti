import 'dart:async';
import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:flutter/widgets.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
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

  Future<void> importPhoto() async {
    final ImagePicker _picker = ImagePicker();
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
    );
    _processImage(image);
  }

  Future<void> importPhotos() async {
    final ImagePicker _picker = ImagePicker();
    final List<XFile>? images = await _picker.pickMultiImage(
      imageQuality: 88,
    );
    if (images != null) {
      for (final image in images) {
        _processImage(image);
      }
    }
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

  Future<void> _processImage(XFile? image) async {
    if (image != null) {
      print('JournalCubit importPhoto $image');
      print('JournalCubit importPhoto path ${image.path}');
      print('JournalCubit importPhoto name ${image.name}');
      print(
          'JournalCubit importPhoto lastModified ${await image.lastModified()}');
      print('JournalCubit importPhoto mimeType ${image.mimeType}');
      print('JournalCubit importPhoto length ${await image.length()}');

      final docDir = await getApplicationDocumentsDirectory();
      const String directory = 'images';
      final File imageFile = File('${docDir.path}/$directory/${image.name}');
      await imageFile.parent.create(recursive: true);
      await image.saveTo(imageFile.path);
      await printExif(await image.readAsBytes());
      await printGeolocation(await image.readAsBytes());
      if (imageFile.path.contains('.png')) {
        await compressAndGetFile(imageFile);
      }
    }
  }
}
