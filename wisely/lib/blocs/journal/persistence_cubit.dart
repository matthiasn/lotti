import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:wisely/blocs/journal/persistence_db.dart';
import 'package:wisely/blocs/journal/persistence_state.dart';
import 'package:wisely/blocs/sync/vector_clock_cubit.dart';

class PersistenceCubit extends Cubit<PersistenceState> {
  late final VectorClockCubit _vectorClockCubit;
  late final PersistenceDb _db;

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
}
