import 'dart:async';
import 'dart:convert';

import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:uuid/uuid.dart';
import 'package:wisely/blocs/journal/persistence_db.dart';
import 'package:wisely/blocs/journal/persistence_state.dart';
import 'package:wisely/blocs/sync/vector_clock_cubit.dart';
import 'package:wisely/classes/geolocation.dart';
import 'package:wisely/classes/journal_db_entities.dart';
import 'package:wisely/sync/vector_clock.dart';

class PersistenceCubit extends Cubit<PersistenceState> {
  late final VectorClockCubit _vectorClockCubit;
  late final PersistenceDb _db;
  final uuid = Uuid();

  PersistenceCubit({
    required VectorClockCubit vectorClockCubit,
  }) : super(PersistenceState.initial()) {
    _vectorClockCubit = vectorClockCubit;
    _db = PersistenceDb();
    init();
  }

  Future<void> init() async {
    await _db.openDb();
    emit(PersistenceState.online(entries: []));
    query();
  }

  Future<void> query() async {
    List<JournalRecord> records = await _db.journalEntries(100);
    List<JournalDbEntity> entries = records
        .map((JournalRecord r) =>
            JournalDbEntry.fromJson(json.decode(r.serialized)))
        .toList();
    emit(PersistenceState.online(entries: entries));
    debugPrint('Query done ${entries.first}');
  }

  Future<bool> create(
    JournalDbEntityData data, {
    Geolocation? geolocation,
    VectorClock? vectorClock,
  }) async {
    DateTime now = DateTime.now();
    VectorClock vc = vectorClock ?? _vectorClockCubit.getNextVectorClock();

    // avoid inserting the same external entity multiple times
    String id = data.maybeMap(
      // create reproducible ID for imported health data
      cumulativeQuantity: (CumulativeQuantity cumulativeQuantity) =>
          uuid.v5(Uuid.NAMESPACE_NIL, json.encode(cumulativeQuantity)),
      discreteQuantity: (DiscreteQuantity discreteQuantity) =>
          uuid.v5(Uuid.NAMESPACE_NIL, json.encode(discreteQuantity)),
      // create reproducible ID for imported image
      journalDbImage: (JournalDbImage journalImage) =>
          uuid.v5(Uuid.NAMESPACE_NIL, json.encode(journalImage)),
      // create random ID for user-created entries
      orElse: () => uuid.v1(),
    );
    DateTime dateFrom = data.maybeMap(
      cumulativeQuantity: (CumulativeQuantity v) => v.dateFrom,
      discreteQuantity: (DiscreteQuantity v) => v.dateFrom,
      journalDbImage: (JournalDbImage v) => v.capturedAt,
      journalDbAudio: (JournalDbAudio v) => v.dateFrom,
      orElse: () => now,
    );
    DateTime dateTo = data.maybeMap(
      cumulativeQuantity: (CumulativeQuantity v) => v.dateTo,
      discreteQuantity: (DiscreteQuantity v) => v.dateTo,
      journalDbImage: (JournalDbImage v) => v.capturedAt,
      journalDbAudio: (JournalDbAudio v) => v.dateTo,
      orElse: () => now,
    );
    JournalDbEntity journalDbEntity = JournalDbEntity.journalDbEntry(
      data: data,
      createdAt: now,
      updatedAt: now,
      dateFrom: dateFrom,
      dateTo: dateTo,
      id: id,
      geolocation: geolocation,
      vectorClock: vc,
    );
    debugPrint(json.encode(journalDbEntity));
    await _db.insert(journalDbEntity);
    query();
    return true;
  }
}
