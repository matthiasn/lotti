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

/// Tracks calls to various toggle methods for testing.
class ToggleCallTracker {
  final List<String> toggleStarredCalls = [];
  final List<String> togglePrivateCalls = [];
  final List<String> toggleFlaggedCalls = [];
  final List<String> toggleMapVisibleCalls = [];
}

/// Fake EntryController that returns a fixed entity state.
/// Used for testing providers that depend on entryControllerProvider.
class FakeEntryController extends EntryController {
  FakeEntryController(
    this._entity, {
    ToggleCallTracker? tracker,
    bool showMap = false,
  })  : _tracker = tracker,
        _showMap = showMap;

  final JournalEntity _entity;
  final ToggleCallTracker? _tracker;
  final bool _showMap;

  @override
  Future<EntryState?> build({required String id}) {
    // Create the state value
    final value = EntryState.saved(
      entryId: id,
      entry: _entity,
      showMap: _showMap,
      isFocused: false,
      shouldShowEditorToolBar: false,
      formKey: GlobalKey<FormBuilderState>(),
    );
    // Set state immediately so it's available synchronously for widget builds
    state = AsyncData(value);
    return SynchronousFuture(value);
  }

  @override
  Future<void> toggleStarred() async {
    _tracker?.toggleStarredCalls.add(_entity.id);
  }

  @override
  Future<void> togglePrivate() async {
    _tracker?.togglePrivateCalls.add(_entity.id);
  }

  @override
  Future<void> toggleFlagged() async {
    _tracker?.toggleFlaggedCalls.add(_entity.id);
  }

  @override
  void toggleMapVisible() {
    _tracker?.toggleMapVisibleCalls.add(_entity.id);
  }
}

/// Helper to create entry controller override that returns a fixed entity.
Override createEntryControllerOverride(JournalEntity entity) {
  return entryControllerProvider(id: entity.id).overrideWith(
    () => FakeEntryController(entity),
  );
}

/// Helper to create entry controller override with toggle call tracking.
/// Returns a tuple of the override and a tracker for assertions.
(Override, ToggleCallTracker) createEntryControllerOverrideWithTracker(
  JournalEntity entity, {
  bool showMap = false,
}) {
  final tracker = ToggleCallTracker();
  final override = entryControllerProvider(id: entity.id).overrideWith(
    () => FakeEntryController(entity, tracker: tracker, showMap: showMap),
  );
  return (override, tracker);
}

/// Tracks calls to setCoverArt for testing.
class CoverArtCallTracker {
  final List<String?> calls = [];
}

/// Fake EntryController that tracks setCoverArt calls and updates state.
/// Used for behavioral testing of cover art functionality.
class TrackingFakeEntryController extends FakeEntryController {
  // ignore: use_super_parameters, parent uses private `_entity` field
  TrackingFakeEntryController(JournalEntity entity, this._coverArtTracker)
      : super(entity);

  final CoverArtCallTracker _coverArtTracker;
  JournalEntity? _currentEntity;

  @override
  Future<EntryState?> build({required String id}) {
    _currentEntity = super._entity;
    return super.build(id: id);
  }

  @override
  Future<void> setCoverArt(String? imageId) async {
    _coverArtTracker.calls.add(imageId);

    // Update state if it's a task, preserving existing form state
    final entity = _currentEntity ?? super._entity;
    if (entity is Task) {
      _currentEntity = entity.copyWith(
        data: entity.data.copyWith(coverArtId: imageId),
      );
      final currentState = state.value;
      if (currentState != null) {
        state = AsyncData(currentState.copyWith(entry: _currentEntity));
      }
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
