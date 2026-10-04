import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/model/entry_state.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';

/// Entry-controller double shared by the speech-modal widget tests: serves
/// a fixed entry synchronously and records `setLanguage` calls.
///
/// File-local controller subclasses cannot be centralized as mocktail mocks
/// (riverpod instantiates the notifier itself), so the shared fake lives in
/// this feature-level helper instead.
class FakeEntryController extends EntryController {
  FakeEntryController(this._entry);

  final JournalEntity? _entry;
  final List<String> setLanguageCalls = [];

  @override
  Future<EntryState?> build() {
    final value = _entry == null
        ? null
        : EntryState.saved(
            entryId: id,
            entry: _entry,
            showMap: false,
            isFocused: false,
            shouldShowEditorToolBar: false,
          );
    if (value != null) {
      state = AsyncData(value);
    }
    return SynchronousFuture(value);
  }

  @override
  Future<void> setLanguage(String language) async {
    setLanguageCalls.add(language);
  }
}
