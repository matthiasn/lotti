import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/model/entry_state.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/state/save_button_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/editor_state_service.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

const _testId = 'test-entry-id';
final _testDate = DateTime(2024, 3, 15, 10, 30);

final _testEntry = JournalEntry(
  meta: Metadata(
    id: _testId,
    createdAt: _testDate,
    updatedAt: _testDate,
    dateFrom: _testDate,
    dateTo: _testDate,
  ),
  entryText: const EntryText(plainText: 'test entry'),
);

/// Fake EntryController that returns a saved state.
class _SavedEntryController extends EntryController {
  @override
  Future<EntryState?> build({required String id}) {
    final value = EntryState.saved(
      entryId: id,
      entry: _testEntry,
      showMap: false,
      isFocused: false,
      shouldShowEditorToolBar: false,
      formKey: GlobalKey<FormBuilderState>(),
    );
    state = AsyncData(value);
    return SynchronousFuture(value);
  }

  bool saveCalled = false;

  @override
  Future<void> save({
    Duration? estimate,
    String? title,
    DateTime? dueDate,
    bool clearDueDate = false,
    bool stopRecording = false,
  }) async {
    saveCalled = true;
  }
}

/// Fake EntryController that returns a dirty state.
class _DirtyEntryController extends EntryController {
  @override
  Future<EntryState?> build({required String id}) {
    final value = EntryState.dirty(
      entryId: id,
      entry: _testEntry,
      showMap: false,
      isFocused: false,
      shouldShowEditorToolBar: false,
      formKey: GlobalKey<FormBuilderState>(),
    );
    state = AsyncData(value);
    return SynchronousFuture(value);
  }
}

/// Fake EntryController that returns null (entity not yet loaded).
class _NullEntryController extends EntryController {
  @override
  Future<EntryState?> build({required String id}) {
    state = const AsyncData(null);
    return SynchronousFuture(null);
  }
}

/// Fake EntryController that tracks the estimate parameter passed to save.
class _EstimateTrackingEntryController extends EntryController {
  _EstimateTrackingEntryController({required this.onSave});

  final void Function(Duration?) onSave;

  @override
  Future<EntryState?> build({required String id}) {
    final value = EntryState.saved(
      entryId: id,
      entry: _testEntry,
      showMap: false,
      isFocused: false,
      shouldShowEditorToolBar: false,
      formKey: GlobalKey<FormBuilderState>(),
    );
    state = AsyncData(value);
    return SynchronousFuture(value);
  }

  @override
  Future<void> save({
    Duration? estimate,
    String? title,
    DateTime? dueDate,
    bool clearDueDate = false,
    bool stopRecording = false,
  }) async {
    onSave(estimate);
  }
}

void main() {
  setUp(() async {
    await setUpTestGetIt(
      additionalSetup: () {
        getIt.registerSingleton<EditorStateService>(
          MockEditorStateService(),
        );
      },
    );
  });

  tearDown(tearDownTestGetIt);

  group('SaveButtonController', () {
    test('returns true when entry state is dirty', () async {
      final container = ProviderContainer(
        overrides: [
          entryControllerProvider(id: _testId).overrideWith(
            _DirtyEntryController.new,
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        saveButtonControllerProvider(id: _testId).future,
      );

      expect(result, isTrue);
    });

    test('returns false when entry state is saved', () async {
      final container = ProviderContainer(
        overrides: [
          entryControllerProvider(id: _testId).overrideWith(
            _SavedEntryController.new,
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        saveButtonControllerProvider(id: _testId).future,
      );

      expect(result, isFalse);
    });

    test('returns null when entry state is not yet loaded', () async {
      final container = ProviderContainer(
        overrides: [
          entryControllerProvider(id: _testId).overrideWith(
            _NullEntryController.new,
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        saveButtonControllerProvider(id: _testId).future,
      );

      expect(result, isNull);
    });

    test('save delegates to entry controller notifier', () async {
      late _SavedEntryController entryController;
      final container = ProviderContainer(
        overrides: [
          entryControllerProvider(id: _testId).overrideWith(
            () => entryController = _SavedEntryController(),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Wait for initial build to complete
      await container.read(
        saveButtonControllerProvider(id: _testId).future,
      );

      final saveButtonNotifier = container.read(
        saveButtonControllerProvider(id: _testId).notifier,
      );

      await saveButtonNotifier.save();

      expect(entryController.saveCalled, isTrue);
    });

    test('save passes estimate to entry controller', () async {
      Duration? receivedEstimate;
      final container = ProviderContainer(
        overrides: [
          entryControllerProvider(id: _testId).overrideWith(() {
            return _EstimateTrackingEntryController(
              onSave: (estimate) => receivedEstimate = estimate,
            );
          }),
        ],
      );
      addTearDown(container.dispose);

      await container.read(
        saveButtonControllerProvider(id: _testId).future,
      );

      final saveButtonNotifier = container.read(
        saveButtonControllerProvider(id: _testId).notifier,
      );

      const testEstimate = Duration(hours: 2);
      await saveButtonNotifier.save(estimate: testEstimate);

      expect(receivedEstimate, testEstimate);
    });
  });
}
