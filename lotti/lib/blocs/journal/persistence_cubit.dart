import 'dart:async';
import 'dart:convert';

import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_native_timezone/flutter_native_timezone.dart';
import 'package:lotti/blocs/journal/persistence_state.dart';
import 'package:lotti/blocs/sync/outbox_cubit.dart';
import 'package:lotti/classes/audio_note.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/geolocation.dart';
import 'package:lotti/classes/health.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/measurables.dart';
import 'package:lotti/classes/sync_message.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/location.dart';
import 'package:lotti/main.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:lotti/sync/vector_clock.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:uuid/uuid.dart';

class PersistenceCubit extends Cubit<PersistenceState> {
  late final OutboxCubit _outboundQueueCubit;
  final JournalDb _journalDb = getIt<JournalDb>();
  late final VectorClockService _vectorClockService;

  final uuid = const Uuid();
  DeviceLocation location = DeviceLocation();
  Timer? timer;

  PersistenceCubit({
    required OutboxCubit outboundQueueCubit,
  }) : super(PersistenceState.initial()) {
    _outboundQueueCubit = outboundQueueCubit;
    _vectorClockService = getIt<VectorClockService>();
    init();
  }

  Future<void> init() async {
    emit(PersistenceState.online(entries: []));
    queryJournal();
  }

  Future<void> queryJournal() async {
    final transaction = Sentry.startTransaction('queryJournal()', 'task');
    try {
      List<JournalEntity> entries = await _journalDb.latestJournalEntities(100);
      emit(PersistenceState.online(entries: entries));
    } catch (exception, stackTrace) {
      await Sentry.captureException(exception, stackTrace: stackTrace);
    }

    await transaction.finish();
  }

  Future<void> queryFilteredJournal(List<String> types) async {
    final transaction = Sentry.startTransaction('queryJournal()', 'task');
    try {
      debugPrint(types.toString());
      List<JournalEntity> entries = await _journalDb.filteredJournalEntities(
        types: types,
        limit: 100,
      );

      emit(PersistenceState.online(entries: entries));
    } catch (exception, stackTrace) {
      await Sentry.captureException(exception, stackTrace: stackTrace);
    }

    await transaction.finish();
  }

  void queryJournalDelayed(int seconds) {
    timer ??= Timer(Duration(seconds: seconds), () {
      queryJournal();
      timer = null;
    });
  }

  Future<bool> createQuantitativeEntry(QuantitativeData data) async {
    final transaction =
        Sentry.startTransaction('createQuantitativeEntry()', 'task');
    try {
      DateTime now = DateTime.now();
      VectorClock vc = await _vectorClockService.getNextVectorClock();

      // avoid inserting the same external entity multiple times
      String id = uuid.v5(Uuid.NAMESPACE_NIL, json.encode(data));

      DateTime dateFrom = data.dateFrom;
      DateTime dateTo = data.dateTo;

      JournalEntity journalEntity = JournalEntity.quantitative(
        data: data,
        meta: Metadata(
          createdAt: now,
          updatedAt: now,
          dateFrom: dateFrom,
          dateTo: dateTo,
          id: id,
          vectorClock: vc,
          timezone: await FlutterNativeTimezone.getLocalTimezone(),
          utcOffset: now.timeZoneOffset.inMinutes,
        ),
      );
      await createDbEntity(journalEntity, enqueueSync: true);
    } catch (exception, stackTrace) {
      await Sentry.captureException(exception, stackTrace: stackTrace);
    }

    await transaction.finish();
    return true;
  }

  Future<bool> createSurveyEntry({
    required SurveyData data,
  }) async {
    final transaction = Sentry.startTransaction('createSurveyEntry()', 'task');
    try {
      DateTime now = DateTime.now();
      VectorClock vc = await _vectorClockService.getNextVectorClock();
      String id = uuid.v5(Uuid.NAMESPACE_NIL, json.encode(data));

      Geolocation? geolocation = await location.getCurrentGeoLocation().timeout(
            const Duration(seconds: 5),
            onTimeout: () => null, // TODO: report timeout in Sentry
          );

      JournalEntity journalEntity = JournalEntity.survey(
        data: data,
        geolocation: geolocation,
        meta: Metadata(
          createdAt: now,
          updatedAt: now,
          dateFrom: data.taskResult.startDate ?? now,
          dateTo: data.taskResult.endDate ?? now,
          id: id,
          vectorClock: vc,
          timezone: await FlutterNativeTimezone.getLocalTimezone(),
          utcOffset: now.timeZoneOffset.inMinutes,
        ),
      );

      await createDbEntity(journalEntity, enqueueSync: true);
    } catch (exception, stackTrace) {
      await Sentry.captureException(exception, stackTrace: stackTrace);
    }

    await transaction.finish();
    return true;
  }

  Future<bool> createMeasurementEntry({
    required MeasurementData data,
  }) async {
    final transaction = Sentry.startTransaction('createSurveyEntry()', 'task');
    try {
      DateTime now = DateTime.now();
      VectorClock vc = await _vectorClockService.getNextVectorClock();
      String id = uuid.v5(Uuid.NAMESPACE_NIL, json.encode(data));

      Geolocation? geolocation = await location.getCurrentGeoLocation().timeout(
            const Duration(seconds: 5),
            onTimeout: () => null, // TODO: report timeout in Sentry
          );

      JournalEntity journalEntity = JournalEntity.measurement(
        data: data,
        geolocation: geolocation,
        meta: Metadata(
          createdAt: now,
          updatedAt: now,
          dateFrom: data.dateFrom,
          dateTo: data.dateTo,
          id: id,
          vectorClock: vc,
          timezone: await FlutterNativeTimezone.getLocalTimezone(),
          utcOffset: now.timeZoneOffset.inMinutes,
        ),
      );

      await createDbEntity(journalEntity, enqueueSync: true);
    } catch (exception, stackTrace) {
      await Sentry.captureException(exception, stackTrace: stackTrace);
    }

    await transaction.finish();
    return true;
  }

  Future<bool> createImageEntry(ImageData imageData) async {
    final transaction = Sentry.startTransaction('createImageEntry()', 'task');
    try {
      DateTime now = DateTime.now();
      VectorClock vc = await _vectorClockService.getNextVectorClock();

      // avoid inserting the same external entity multiple times
      String id = uuid.v5(Uuid.NAMESPACE_NIL, json.encode(imageData));

      DateTime dateFrom = imageData.capturedAt;
      DateTime dateTo = imageData.capturedAt;
      JournalEntity journalEntity = JournalEntity.journalImage(
        data: imageData,
        meta: Metadata(
          createdAt: now,
          updatedAt: now,
          dateFrom: dateFrom,
          dateTo: dateTo,
          id: id,
          vectorClock: vc,
          timezone: await FlutterNativeTimezone.getLocalTimezone(),
          utcOffset: now.timeZoneOffset.inMinutes,
        ),
        // TODO: should this be geolocation at capture or insertion?
        geolocation: imageData.geolocation,
      );
      await createDbEntity(journalEntity, enqueueSync: true);
    } catch (exception, stackTrace) {
      await Sentry.captureException(exception, stackTrace: stackTrace);
    }

    await transaction.finish();
    return true;
  }

  Future<bool> createAudioEntry(AudioNote audioNote) async {
    final transaction = Sentry.startTransaction('createImageEntry()', 'task');
    try {
      AudioData audioData = AudioData(
        audioDirectory: audioNote.audioDirectory,
        duration: audioNote.duration,
        audioFile: audioNote.audioFile,
        dateTo: audioNote.createdAt.add(audioNote.duration),
        dateFrom: audioNote.createdAt,
      );

      DateTime now = DateTime.now();
      VectorClock vc = await _vectorClockService.getNextVectorClock();

      // avoid inserting the same external entity multiple times
      String id = uuid.v5(Uuid.NAMESPACE_NIL, json.encode(audioData));

      DateTime dateFrom = audioData.dateFrom;
      DateTime dateTo = audioData.dateTo;
      JournalEntity journalEntity = JournalEntity.journalAudio(
        data: audioData,
        meta: Metadata(
          createdAt: now,
          updatedAt: now,
          dateFrom: dateFrom,
          dateTo: dateTo,
          id: id,
          vectorClock: vc,
          timezone: await FlutterNativeTimezone.getLocalTimezone(),
          utcOffset: now.timeZoneOffset.inMinutes,
        ),
        // TODO: should this be geolocation at capture or insertion?
        geolocation: audioNote.geolocation,
      );
      await createDbEntity(journalEntity, enqueueSync: true);
    } catch (exception, stackTrace) {
      await Sentry.captureException(exception, stackTrace: stackTrace);
    }

    await transaction.finish();
    return true;
  }

  Future<bool> createTextEntry(EntryText entryText) async {
    final transaction = Sentry.startTransaction('createTextEntry()', 'task');
    try {
      DateTime now = DateTime.now();
      VectorClock vc = await _vectorClockService.getNextVectorClock();
      String id = uuid.v1();
      Geolocation? geolocation = await location.getCurrentGeoLocation().timeout(
            const Duration(seconds: 5),
            onTimeout: () => null,
          );

      JournalEntity journalEntity = JournalEntity.journalEntry(
        entryText: entryText,
        meta: Metadata(
          createdAt: now,
          updatedAt: now,
          dateFrom: now,
          dateTo: now,
          id: id,
          vectorClock: vc,
          timezone: await FlutterNativeTimezone.getLocalTimezone(),
          utcOffset: now.timeZoneOffset.inMinutes,
        ),
        geolocation: geolocation,
      );
      await createDbEntity(journalEntity, enqueueSync: true);
    } catch (exception, stackTrace) {
      await Sentry.captureException(exception, stackTrace: stackTrace);
    }

    await transaction.finish();
    return true;
  }

  Future<bool?> createDbEntity(JournalEntity journalEntity,
      {bool enqueueSync = false}) async {
    final transaction = Sentry.startTransaction('createDbEntity()', 'task');
    try {
      int? res = await _journalDb.addJournalEntity(journalEntity);
      debugPrint('createDbEntity res $res');
      bool saved = (res != 0);
      await saveJournalEntityJson(journalEntity);
      debugPrint('createDbEntity saved $saved');

      if (saved && enqueueSync) {
        await _outboundQueueCubit.enqueueMessage(SyncMessage.journalEntity(
          journalEntity: journalEntity,
          status: SyncEntryStatus.initial,
        ));
      }
      await transaction.finish();

      queryJournalDelayed(1);
      return saved;
    } catch (exception, stackTrace) {
      await Sentry.captureException(exception, stackTrace: stackTrace);
      debugPrint('Exception $exception');
    }
  }

  Future<bool> updateJournalEntity(
    JournalEntity journalEntity,
    EntryText entryText,
  ) async {
    final transaction =
        Sentry.startTransaction('updateJournalEntity()', 'task');
    try {
      DateTime now = DateTime.now();
      VectorClock vc = await _vectorClockService.getNextVectorClock(
          previous: journalEntity.meta.vectorClock);

      Metadata newMeta = journalEntity.meta.copyWith(
        updatedAt: now,
        vectorClock: vc,
      );

      if (journalEntity is JournalEntry) {
        JournalEntry newJournalEntry = journalEntity.copyWith(
          meta: newMeta,
          entryText: entryText,
        );

        await updateDbEntity(newJournalEntry, enqueueSync: true);
      }

      if (journalEntity is JournalAudio) {
        JournalAudio newJournalAudio = journalEntity.copyWith(
          meta: newMeta,
          entryText: entryText,
        );

        await updateDbEntity(newJournalAudio, enqueueSync: true);
      }

      if (journalEntity is JournalImage) {
        JournalImage newJournalImage = journalEntity.copyWith(
          meta: newMeta,
          entryText: entryText,
        );

        await updateDbEntity(newJournalImage, enqueueSync: true);
      }

      if (journalEntity is MeasurementEntry) {
        MeasurementEntry newEntry = journalEntity.copyWith(
          meta: newMeta,
          entryText: entryText,
        );

        await updateDbEntity(newEntry, enqueueSync: true);
      }
    } catch (exception, stackTrace) {
      await Sentry.captureException(exception, stackTrace: stackTrace);
    }

    await transaction.finish();
    return true;
  }

  Future<bool?> updateDbEntity(
    JournalEntity journalEntity, {
    bool enqueueSync = false,
  }) async {
    final transaction = Sentry.startTransaction('updateDbEntity()', 'task');
    try {
      int res = await _journalDb.updateJournalEntity(journalEntity);
      bool saved = (res != 0);
      await saveJournalEntityJson(journalEntity);

      if (saved && enqueueSync) {
        await _outboundQueueCubit.enqueueMessage(SyncMessage.journalEntity(
          journalEntity: journalEntity,
          status: SyncEntryStatus.update,
        ));
      }
      await transaction.finish();

      queryJournalDelayed(1);
      return saved;
    } catch (exception, stackTrace) {
      await Sentry.captureException(exception, stackTrace: stackTrace);
      debugPrint('Exception $exception');
    }
  }

  Future<int> upsertEntityDefinition(EntityDefinition definition) async {
    int linesAffected = await _journalDb.upsertEntityDefinition(definition);
    await _outboundQueueCubit.enqueueMessage(SyncMessage.entityDefinition(
      entityDefinition: definition,
      status: SyncEntryStatus.update,
    ));
    return linesAffected;
  }
}
