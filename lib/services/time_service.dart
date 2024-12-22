import 'dart:async';

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';

class TimeService {
  TimeService() {
    _controller = StreamController<JournalEntity?>.broadcast();
  }

  late final StreamController<JournalEntity?> _controller;
  JournalEntity? _current;
  JournalEntity? linkedFrom;
  Stream<int>? _periodicStream;

  Future<void> start(JournalEntity journalEntity, JournalEntity? linked) async {
    if (_current != null) {
      await stop();
    }

    _current = journalEntity;
    linkedFrom = linked;

    const interval = Duration(seconds: 1);

    int callback(int value) {
      return value;
    }

    _periodicStream = Stream<int>.periodic(interval, callback);
    if (_periodicStream != null) {
      // ignore: unused_local_variable
      await for (final int i in _periodicStream!) {
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

  JournalEntity? getCurrent() {
    return _current;
  }

  Future<void> stop() async {
    if (_current != null) {
      await JournalRepository.updateJournalEntityDate(
        _current!.meta.id,
        dateFrom: _current!.meta.dateFrom,
        dateTo: DateTime.now(),
      );

      _current = null;
      linkedFrom = null;
      _controller.add(null);
    }
  }

  Stream<JournalEntity?> getStream() {
    return _controller.stream;
  }
}
