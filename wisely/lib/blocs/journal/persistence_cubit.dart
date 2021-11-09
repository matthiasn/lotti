import 'dart:async';
import 'dart:convert';

import 'package:bloc/bloc.dart';
import 'package:flutter_native_timezone/flutter_native_timezone.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:wisely/blocs/journal/persistence_db.dart';
import 'package:wisely/blocs/journal/persistence_state.dart';
import 'package:wisely/blocs/sync/outbound_queue_cubit.dart';
import 'package:wisely/blocs/sync/vector_clock_cubit.dart';
import 'package:wisely/classes/audio_note.dart';
import 'package:wisely/classes/health.dart';
import 'package:wisely/classes/journal_entities.dart';
import 'package:wisely/classes/sync_message.dart';
import 'package:wisely/sync/vector_clock.dart';

class PersistenceCubit extends Cubit<PersistenceState> {
  late final VectorClockCubit _vectorClockCubit;
  late final OutboundQueueCubit _outboundQueueCubit;
  late final PersistenceDb _db;
  final uuid = Uuid();

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

  Future<bool> createQuantitativeEntries(List<QuantitativeData> data) async {
    final transaction =
        Sentry.startTransaction('createQuantitativeEntries()', 'task');

    List<QuantitativeEntry> quantEntries = [];

    for (QuantitativeData item in data) {
      try {
        DateTime now = DateTime.now();
        VectorClock vc = _vectorClockCubit.getNextVectorClock();

        // avoid inserting the same external entity multiple times
        String id = uuid.v5(Uuid.NAMESPACE_NIL, json.encode(item));

        DateTime dateFrom = item.dateFrom;
        DateTime dateTo = item.dateTo;

        JournalEntity journalEntity = JournalEntity.quantitative(
          data: item,
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
        if (journalEntity is QuantitativeEntry) {
          quantEntries.add(journalEntity);
        }
      } catch (exception, stackTrace) {
        await Sentry.captureException(exception, stackTrace: stackTrace);
      }
    }

    addQuantitativeEntries(quantEntries);

    if (quantEntries.isNotEmpty) {
      _outboundQueueCubit.enqueueMessage(
          SyncMessage.syncQuantitativeEntries(entries: quantEntries));
    }

    await transaction.finish();
    return true;
  }

  Future<bool> addQuantitativeEntries(List<QuantitativeEntry> entries) async {
    final transaction =
        Sentry.startTransaction('addQuantitativeEntries()', 'task');

    for (QuantitativeEntry entry in entries) {
      try {
        await createDbEntity(entry, enqueueSync: false);
      } catch (exception, stackTrace) {
        await Sentry.captureException(exception, stackTrace: stackTrace);
      }
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

  Future<bool?> createDbEntity(JournalEntity journalEntity,
      {bool enqueueSync = false}) async {
    final transaction = Sentry.startTransaction('createDbEntity()', 'task');
    try {
      bool saved = await _db.insert(journalEntity);

      if (saved && enqueueSync) {
        _outboundQueueCubit.enqueueMessage(
            SyncMessage.syncJournalEntity(journalEntity: journalEntity));
      }
      await transaction.finish();

      await Future.delayed(const Duration(seconds: 1));
      queryJournal();
      return saved;
    } catch (exception, stackTrace) {
      await Sentry.captureException(exception, stackTrace: stackTrace);
      print('Exception $exception');
    }
  }
}
