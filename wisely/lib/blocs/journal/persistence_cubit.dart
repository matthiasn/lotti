import 'dart:async';
import 'dart:convert';

import 'package:bloc/bloc.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:uuid/uuid.dart';
import 'package:wisely/blocs/journal/persistence_db.dart';
import 'package:wisely/blocs/journal/persistence_state.dart';
import 'package:wisely/blocs/sync/vector_clock_cubit.dart';
import 'package:wisely/classes/geolocation.dart';
import 'package:wisely/classes/journal_db_entities.dart';

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
    emit(PersistenceState.online());
  }

  Future<bool> create(
    JournalDbEntityData data, {
    Future<Geolocation>? geolocation,
  }) async {
    DateTime now = DateTime.now();

    // avoid inserting the same external entity multiple times
    String id = data.maybeMap(
      // create reproducible ID for imported health data
      cumulativeQuantity: (CumulativeQuantity cumulativeQuantity) => uuid.v5(
        Uuid.NAMESPACE_NIL,
        json.encode(cumulativeQuantity),
        options: {'randomNamespace': false},
      ),
      discreteQuantity: (DiscreteQuantity discreteQuantity) => uuid.v5(
        Uuid.NAMESPACE_NIL,
        json.encode(discreteQuantity),
        options: {'randomNamespace': false},
      ),
      // create reproducible ID for imported image
      journalImage: (JournalImage journalImage) =>
          uuid.v5('cumulativeQuantity', json.encode(journalImage)),
      // create random ID for user-created entries
      orElse: () => uuid.v1(),
    );
    DateTime dateFrom = data.maybeMap(
      cumulativeQuantity: (CumulativeQuantity v) => v.dateFrom,
      discreteQuantity: (DiscreteQuantity v) => v.dateFrom,
      journalImage: (JournalImage v) => v.capturedAt,
      audioNote: (AudioNote v) => v.dateFrom,
      orElse: () => now,
    );
    DateTime dateTo = data.maybeMap(
      cumulativeQuantity: (CumulativeQuantity v) => v.dateTo,
      discreteQuantity: (DiscreteQuantity v) => v.dateTo,
      journalImage: (JournalImage v) => v.capturedAt,
      audioNote: (AudioNote v) => v.dateTo,
      orElse: () => now,
    );
    JournalDbEntity journalDbEntity = JournalDbEntity.journalDbEntry(
      data: data,
      createdAt: now,
      updatedAt: now,
      dateFrom: dateFrom,
      dateTo: dateTo,
      id: id,
    );
    await _db.insert(journalDbEntity);
    return true;
  }
}
