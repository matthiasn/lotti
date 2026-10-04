import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/beamer/ai_skill_wiring.dart';
import 'package:lotti/features/ai/state/skill_entity_provider.dart';
import 'package:lotti/features/journal/model/entry_state.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/editor_state_service.dart';

import '../helpers/fake_entry_controller.dart';
import '../helpers/test_get_it.dart';
import '../mocks/mocks.dart';
import '../test_data/test_data.dart';

/// An entry controller whose load never completes.
class _LoadingEntryController extends EntryController {
  @override
  Future<EntryState?> build() => Completer<EntryState?>().future;
}

/// An entry controller that found no entry.
class _MissingEntryController extends EntryController {
  @override
  Future<EntryState?> build() async => null;
}

void main() {
  group('skillEntityFromJournal', () {
    final entityId = testTask.meta.id;

    // Every EntryController resolves the editor state service on construction.
    setUp(
      () => setUpTestGetIt(
        additionalSetup: () => getIt.registerSingleton<EditorStateService>(
          MockEditorStateService(),
        ),
      ),
    );
    tearDown(tearDownTestGetIt);

    ProviderContainer containerWith(EntryController Function() controller) {
      final container = ProviderContainer(
        overrides: [
          skillEntityProvider.overrideWith(skillEntityFromJournal),
          entryControllerProvider(entityId).overrideWith(controller),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('serves the entry the journal controller holds', () {
      final container = containerWith(() => FakeEntryController(testTask));

      expect(container.read(skillEntityProvider(entityId)), testTask);
    });

    test('is null while the journal controller is still loading', () {
      final container = containerWith(_LoadingEntryController.new);

      expect(container.read(skillEntityProvider(entityId)), isNull);
    });

    test('is null when the journal controller finds no entry', () async {
      final container = containerWith(_MissingEntryController.new);
      final subscription = container.listen(
        skillEntityProvider(entityId),
        (_, _) {},
      );
      addTearDown(subscription.close);
      await container.read(entryControllerProvider(entityId).future);

      expect(subscription.read(), isNull);
      expect(
        container.read(entryControllerProvider(entityId)).hasValue,
        isTrue,
      );
    });
  });
}
