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
  late final StreamController<JournalEntity?> _streamController;
  final PersistenceLogic _persistenceLogic = getIt<PersistenceLogic>();

  final editorStateById = <String, String>{};

  EditorStateService() {
    _streamController = StreamController<JournalEntity?>.broadcast();
  }

  Stream<JournalEntity?> getStream() {
    return _streamController.stream;
  }

  void saveTempState(String id, QuillController controller) {
    Delta delta = deltaFromController(controller);
    String json = quillJsonFromDelta(delta);
    editorStateById[id] = json;

    EasyDebounce.debounce(
      'tempSaveDelta-$id',
      const Duration(seconds: 10),
      () {
        debugPrint('saveTempState debounced $id ${editorStateById[id]}');
      },
    );
  }

  void saveState(String id, QuillController controller) async {
    EasyDebounce.cancel('tempSaveDelta-$id');
    EntryText entryText = entryTextFromController(controller);
    debugPrint('saveState $id ${entryText.toJson()}');
    await _persistenceLogic.updateJournalEntityText(id, entryText);
    HapticFeedback.heavyImpact();
  }
}
