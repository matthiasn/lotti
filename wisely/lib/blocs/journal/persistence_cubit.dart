import 'dart:async';
import 'dart:convert';

import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_native_timezone/flutter_native_timezone.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:wisely/blocs/journal/persistence_db.dart';
import 'package:wisely/blocs/journal/persistence_state.dart';
import 'package:wisely/blocs/sync/outbound_queue_cubit.dart';
import 'package:wisely/blocs/sync/vector_clock_cubit.dart';
import 'package:wisely/classes/audio_note.dart';
import 'package:wisely/classes/entry_text.dart';
import 'package:wisely/classes/geolocation.dart';
import 'package:wisely/classes/health.dart';
import 'package:wisely/classes/journal_entities.dart';
import 'package:wisely/classes/sync_message.dart';
import 'package:wisely/location.dart';
import 'package:wisely/sync/vector_clock.dart';
import 'package:wisely/utils/file_utils.dart';

class PersistenceCubit extends Cubit<PersistenceState> {
  late final VectorClockCubit _vectorClockCubit;
  late final OutboundQueueCubit _outboundQueueCubit;
  late final PersistenceDb _db;
  final uuid = const Uuid();
  DeviceLocation location = DeviceLocation();
  Timer? timer;

  PersistenceCubit({
    required VectorClockCubit vectorClockCubit,
    required OutboundQueueCubit outboundQueueCubit,
  }) : super(PersistenceState.initial()) {
    _vectorClockCubit = vectorClockCubit;
    _outboundQueueCubit = outboundQueueCubit;
    _db = PersistenceDb();
    init();
  }

  Future<void> init() async {
    await _db.openDb();
    emit(PersistenceState.online(entries: []));
    queryJournal();
  }

  Future<void> queryJournal() async {
    final transaction = Sentry.startTransaction('queryJournal()', 'task');
    try {
      List<JournalRecord> records = await _db.journalEntries(100);
      List<JournalEntity> entries = records
          .map((JournalRecord r) =>
              JournalEntity.fromJson(json.decode(r.serialized)))
          .toList();
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
      VectorClock vc = _vectorClockCubit.getNextVectorClock();

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
      VectorClock vc = _vectorClockCubit.getNextVectorClock();
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

  Future<bool> createImageEntry(ImageData imageData) async {
    final transaction = Sentry.startTransaction('createImageEntry()', 'task');
    try {
      DateTime now = DateTime.now();
      VectorClock vc = _vectorClockCubit.getNextVectorClock();

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
      VectorClock vc = _vectorClockCubit.getNextVectorClock();

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
      VectorClock vc = _vectorClockCubit.getNextVectorClock();
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

      if (journalEntity is JournalEntry) {
        await saveJournalEntryJson(journalEntity);
      }
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
      bool saved = await _db.insert(journalEntity);

      if (saved && enqueueSync) {
        await _outboundQueueCubit.enqueueMessage(SyncMessage.journalDbEntity(
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
      VectorClock vc = _vectorClockCubit.getNextVectorClock(
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
        await saveJournalEntryJson(newJournalEntry);
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
      bool saved = await _db.update(journalEntity);

      if (saved && enqueueSync) {
        await _outboundQueueCubit.enqueueMessage(SyncMessage.journalDbEntity(
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
}
