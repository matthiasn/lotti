import 'dart:async';

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';

class TimeService {
  TimeService() {
    _controller = StreamController<JournalEntity?>.broadcast();
  }

  late final StreamController<JournalEntity?> _controller;
  JournalEntity? _current;
  JournalEntity? linkedFrom;
  StreamSubscription<int>? _periodicSubscription;

  Future<void> start(JournalEntity journalEntity, JournalEntity? linked) async {
    if (_current != null) {
      await stop();
    }

    _current = journalEntity;
    linkedFrom = linked;
    const interval = Duration(seconds: 1);

    unawaited(
      getIt<JournalDb>()
          .watchJournalEntityById(journalEntity.id)
          .forEach((entry) {
        _current = entry;
      }),
    );

    int callback(int value) {
      return value;
    }

    _periodicSubscription =
        Stream<int>.periodic(interval, callback).listen((i) {
      if (_current != null) {
        _controller.add(
          _current!.copyWith(
            meta: _current!.meta.copyWith(dateTo: DateTime.now()),
          ),
        );
      }
    });
  }

  JournalEntity? getCurrent() {
    return _current;
  }

  Future<void> stop() async {
    if (_current != null) {
      _current = null;
      linkedFrom = null;
      _controller.add(null);
      await _periodicSubscription?.cancel();
    }
  }

  Stream<JournalEntity?> getStream() {
    return _controller.stream;
  }
}
