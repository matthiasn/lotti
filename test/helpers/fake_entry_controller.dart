import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/classes/journal_entities.dart';
// ignore: unused_import
import 'package:lotti/classes/task.dart';
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
  Future<EntryState?> build({required String id}) {
    // Create the state value
    final value = EntryState.saved(
      entryId: id,
      entry: _entity,
      showMap: false,
      isFocused: false,
      shouldShowEditorToolBar: false,
      formKey: GlobalKey<FormBuilderState>(),
    );
    // Set state immediately so it's available synchronously for widget builds
    state = AsyncData(value);
    return SynchronousFuture(value);
  }
}

/// Helper to create entry controller override that returns a fixed entity.
Override createEntryControllerOverride(JournalEntity entity) {
  return entryControllerProvider(id: entity.id).overrideWith(
    () => FakeEntryController(entity),
  );
}

/// Tracks calls to setCoverArt for testing.
class CoverArtCallTracker {
  final List<String?> calls = [];
}

/// Fake EntryController that tracks setCoverArt calls and updates state.
/// Used for behavioral testing of cover art functionality.
class TrackingFakeEntryController extends FakeEntryController {
  // ignore: use_super_parameters, parent uses private `_entity` field
  TrackingFakeEntryController(JournalEntity entity, this._tracker)
      : super(entity);

  final CoverArtCallTracker _tracker;
  JournalEntity? _currentEntity;

  @override
  Future<EntryState?> build({required String id}) {
    _currentEntity = super._entity;
    return super.build(id: id);
  }

  @override
  Future<void> setCoverArt(String? imageId) async {
    _tracker.calls.add(imageId);

    // Update state if it's a task
    final entity = _currentEntity ?? super._entity;
    if (entity is Task) {
      _currentEntity = entity.copyWith(
        data: entity.data.copyWith(coverArtId: imageId),
      );
      state = AsyncData(
        EntryState.saved(
          entryId: id,
          entry: _currentEntity,
          showMap: false,
          isFocused: false,
          shouldShowEditorToolBar: false,
          formKey: GlobalKey<FormBuilderState>(),
        ),
      );
    }
  }
}

/// Helper to create a tracking entry controller override.
/// Returns a tuple of the override and a tracker for assertions.
(Override, CoverArtCallTracker) createTrackingEntryControllerOverride(
  JournalEntity entity,
) {
  final tracker = CoverArtCallTracker();
  final override = entryControllerProvider(id: entity.id).overrideWith(
    () => TrackingFakeEntryController(entity, tracker),
  );
  return (override, tracker);
}
