import 'dart:async';

import 'package:lotti/features/journal/model/entry_state.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'save_button_controller.g.dart';

@riverpod
class SaveButtonController extends _$SaveButtonController {
  SaveButtonController();
  String _id = '';

  @override
  Future<bool?> build({required String id}) async {
    final state = ref.watch(entryControllerProvider(id: id)).value;
    _id = id;
    final unsaved = state?.when(
      dirty: (entryId, entry, showMap, isFocused, shouldShowEditorToolBar,
              formKey) =>
          true,
      saved: (entryId, entry, showMap, isFocused, shouldShowEditorToolBar,
              formKey) =>
          false,
    );

    return unsaved;
  }

  Future<void> save({Duration? estimate}) async {
    final state = ref.read(entryControllerProvider(id: _id).notifier);
    await state.save(estimate: estimate);
  }
}
