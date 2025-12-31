import 'package:flutter/widgets.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/model/entry_state.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';

export 'package:lotti/features/journal/state/entry_controller.dart'
    show entryControllerProvider;

/// Fake EntryController that returns a fixed entity state.
/// Used for testing providers that depend on entryControllerProvider.
class FakeEntryController extends EntryController {
  FakeEntryController(this._entity);

  final JournalEntity _entity;

  @override
  Future<EntryState?> build({required String id}) async {
    return EntryState.saved(
      entryId: id,
      entry: _entity,
      showMap: false,
      isFocused: false,
      shouldShowEditorToolBar: false,
      formKey: GlobalKey<FormBuilderState>(),
    );
  }
}

/// Helper to create entry controller override that returns a fixed entity.
Override createEntryControllerOverride(JournalEntity entity) {
  return entryControllerProvider(id: entity.id).overrideWith(
    () => FakeEntryController(entity),
  );
}
