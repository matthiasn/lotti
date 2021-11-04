// ignore_for_file: unnecessary_null_comparison

import 'dart:async';
import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:flutter/widgets.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:intl/intl.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import 'package:wisely/blocs/journal/persistence_cubit.dart';
import 'package:wisely/blocs/journal_entities_cubit.dart';
import 'package:wisely/blocs/sync/outbound_queue_cubit.dart';
import 'package:wisely/blocs/sync/vector_clock_cubit.dart';
import 'package:wisely/classes/geolocation.dart';
import 'package:wisely/classes/journal_db_entities.dart';
import 'package:wisely/classes/journal_entities.dart';
import 'package:wisely/classes/sync_message.dart';
import 'package:wisely/location.dart';
import 'package:wisely/sync/vector_clock.dart';
import 'package:wisely/utils/audio_utils.dart';
import 'package:wisely/utils/image_utils.dart';

import 'journal_image_state.dart';

class JournalImageCubit extends Cubit<JournalImageState> {
  late final VectorClockCubit _vectorClockCubit;
  late final JournalEntitiesCubit _journalEntitiesCubit;
  late final OutboundQueueCubit _outboundQueueCubit;
  late final PersistenceCubit _persistenceCubit;

  JournalImageCubit({
    required VectorClockCubit vectorClockCubit,
    required JournalEntitiesCubit journalEntitiesCubit,
    required OutboundQueueCubit outboundQueueCubit,
    required PersistenceCubit persistenceCubit,
  }) : super(JournalImageState()) {
    debugPrint('Hello from JournalImageCubit');
    _vectorClockCubit = vectorClockCubit;
    _journalEntitiesCubit = journalEntitiesCubit;
    _outboundQueueCubit = outboundQueueCubit;
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
        debugPrint('pickAssets $asset');
        debugPrint('pickAssets createDateTime ${asset.createDateTime}');
        debugPrint('pickAssets id ${asset.id}');
        debugPrint('pickAssets file ${await asset.file}');

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

          VectorClock getNextVectorClock() {
            String host = _vectorClockCubit.state.host;
            int nextAvailableCounter =
                _vectorClockCubit.state.nextAvailableCounter;
            _vectorClockCubit.increment();
            return VectorClock(<String, int>{host: nextAvailableCounter});
          }

          VectorClock vectorClock = getNextVectorClock();
          DateTime created = asset.createDateTime;

          JournalImage journalImage = JournalImage(
            id: idNamePart,
            timestamp: created.millisecondsSinceEpoch,
            imageId: asset.id,
            geolocation: geolocation,
            imageFile: imageFileName,
            imageDirectory: relativePath,
            createdAt: created,
            vectorClock: vectorClock,
          );
          debugPrint(journalImage.toString());
          await saveJournalImageJson(journalImage);
          _journalEntitiesCubit.save(journalImage);

          JournalDbImage journalDbImage = JournalDbImage(
            imageId: asset.id,
            imageFile: imageFileName,
            imageDirectory: relativePath,
            capturedAt: created,
          );

          _persistenceCubit.create(journalDbImage, geolocation: geolocation);

          await _outboundQueueCubit.enqueueMessage(
            SyncMessage.journalEntity(
              journalEntity: journalImage,
              vectorClock: vectorClock,
            ),
            attachment: targetFile,
          );
        }
      }
    }
  }
}
