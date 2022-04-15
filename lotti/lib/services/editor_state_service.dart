import 'dart:async';

import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/widgets/journal/editor_tools.dart';

class EditorStateService {
  late final StreamController<JournalEntity?> _controller;
  final PersistenceLogic _persistenceLogic = getIt<PersistenceLogic>();

  EditorStateService() {
    _controller = StreamController<JournalEntity?>.broadcast();
  }

  Stream<JournalEntity?> getStream() {
    return _controller.stream;
  }

  void saveTempState(String id, QuillController controller) {
    Delta delta = deltaFromController(controller);
    String json = quillJsonFromDelta(delta);
    debugPrint('saveTempState not debounced $id');

    EasyDebounce.debounce(
      'tempSaveDelta-$id',
      const Duration(seconds: 2),
      () {
        debugPrint('saveTempState debounced $id $json');
      },
    );
  }

  void saveState(String id, QuillController controller) async {
    EntryText entryText = entryTextFromController(controller);
    debugPrint('saveState $id ${entryText.toJson()}');
    await _persistenceLogic.updateJournalEntityText(id, entryText);
    HapticFeedback.heavyImpact();
  }
}
