import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:lotti/blocs/sync/outbox_state.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/utils/consts.dart';

class OutboxCubit extends Cubit<OutboxState> {
  OutboxCubit() : super(OutboxState.initial()) {
    getIt<JournalDb>().watchConfigFlag(enableSyncFlag).listen((enabled) async {
      if (enabled) {
        emit(OutboxState.online());
      } else {
        emit(OutboxState.disabled());
      }
    });
  }

  Future<void> toggleStatus() async {
    await getIt<JournalDb>().toggleConfigFlag(enableSyncFlag);
  }

  @override
  Future<void> close() async {
    await super.close();
  }
}
