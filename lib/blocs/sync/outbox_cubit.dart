import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:lotti/blocs/sync/outbox_state.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/utils/consts.dart';

class OutboxCubit extends Cubit<OutboxState> {
  OutboxCubit() : super(OutboxState.initial()) {
    getIt<JournalDb>()
        .watchConfigFlag(enableMatrixFlag)
        .listen((enabled) async {
      if (enabled) {
        emit(OutboxState.online());
      } else {
        emit(OutboxState.disabled());
      }
    });
  }

  @override
  Future<void> close() async {
    await super.close();
  }
}
