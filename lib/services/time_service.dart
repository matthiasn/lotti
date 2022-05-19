import 'dart:async';

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';

class TimeService {
  late final StreamController<JournalEntity?> _controller;

  JournalEntity? _current;
  Stream<int>? _periodicStream;

  TimeService() {
    _controller = StreamController<JournalEntity?>.broadcast();
  }

  void start(JournalEntity journalEntity) async {
    if (_current != null) {
      await stop();
    }

    _current = journalEntity;

    Duration interval = const Duration(seconds: 1);

    int callback(int value) {
      return value;
    }

    _periodicStream = Stream<int>.periodic(interval, callback);
    if (_periodicStream != null) {
      // ignore: unused_local_variable
      await for (int i in _periodicStream!) {
        if (_current != null) {
          _controller.add(
            _current!.copyWith(
              meta: _current!.meta.copyWith(
                dateTo: DateTime.now(),
              ),
            ),
          );
        }
      }
    }
  }

  Future<void> stop() async {
    final PersistenceLogic persistenceLogic = getIt<PersistenceLogic>();

    if (_current != null) {
      await persistenceLogic.updateJournalEntityDate(
        _current!.meta.id,
        dateFrom: _current!.meta.dateFrom,
        dateTo: DateTime.now(),
      );

      _current = null;
      _controller.add(null);
    }
  }

  Stream<JournalEntity?> getStream() {
    return _controller.stream;
  }
}
