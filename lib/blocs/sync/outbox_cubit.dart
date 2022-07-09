import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:lotti/blocs/sync/outbox_state.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/sync/outbox_service.dart';
import 'package:lotti/utils/consts.dart';

class OutboxCubit extends Cubit<OutboxState> {
  OutboxCubit() : super(OutboxState.initial()) {
    _outbox.init();

    getIt<JournalDb>()
        .watchConfigFlag(enableSyncOutboxFlag)
        .listen((enabled) async {
      if (enabled) {
        emit(OutboxState.online());
      } else {
        emit(OutboxState.disabled());
      }
    });
  }

  final OutboxService _outbox = getIt<OutboxService>();

  Future<void> toggleStatus() async {
    await getIt<JournalDb>().toggleConfigFlag(enableSyncOutboxFlag);
  }

  @override
  Future<void> close() async {
    await super.close();
  }
}
