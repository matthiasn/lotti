import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:lotti/classes/journal_entities.dart';

class EditorStateService {
  late final StreamController<JournalEntity?> _controller;

  EditorStateService() {
    _controller = StreamController<JournalEntity?>.broadcast();
  }

  Stream<JournalEntity?> getStream() {
    return _controller.stream;
  }

  void saveTempState(String id, Delta delta) {
    debugPrint('saveTempState $id $delta');
  }
}
