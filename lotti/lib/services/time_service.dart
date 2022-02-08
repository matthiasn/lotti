import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:lotti/classes/journal_entities.dart';

class TimeService {
  late final StreamController<JournalEntity?> _controller;
  JournalEntity? _current;
  Stream<int>? _periodicStream;

  TimeService() {
    _controller = StreamController<JournalEntity?>.broadcast();
  }

  void start(JournalEntity journalEntity) async {
    debugPrint('Start ${journalEntity.meta.id}');

    if (_current != null) {
      return;
    }

    _current = journalEntity;

    Duration interval = const Duration(seconds: 1);

    int callback(int value) {
      return value;
    }

    _periodicStream = Stream<int>.periodic(interval, callback);
    if (_periodicStream != null) {
      await for (int _ in _periodicStream!) {
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

  void stop(JournalEntity journalEntity) {
    if (_current?.meta.id == journalEntity.meta.id) {
      _current = null;
      _controller.add(null);
    }
  }

  Stream<JournalEntity?> getStream() {
    return _controller.stream;
  }
}
