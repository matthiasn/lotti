import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:lotti/blocs/sync/outbox_state.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/sync/outbox.dart';

class OutboxCubit extends Cubit<OutboxState> {
  final OutboxService _outbox = getIt<OutboxService>();

  OutboxCubit() : super(OutboxState.initial()) {
    _outbox.init();
  }

  Future<void> toggleStatus() async {
    if (state is OutboxDisabled) {
      _outbox.enabled = true;
      emit(OutboxState.online());
      _outbox.startPolling();
    } else {
      _outbox.enabled = false;
      emit(OutboxState.disabled());
      _outbox.stopPolling();
    }
  }

  @override
  Future<void> close() async {
    super.close();
  }
}
