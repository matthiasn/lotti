import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/tasks/ui/widgets/desktop_task_detail_view.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/entities_cache_service.dart';

import '../../../../helpers/fake_entry_controller.dart';
import '../../../../mocks/mocks.dart';
import '../../../../test_data/test_data.dart';
import '../../../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await setUpTestGetIt(
      additionalSetup: () {
        getIt
          ..registerSingleton<EditorStateService>(MockEditorStateService())
          ..registerSingleton<EntitiesCacheService>(
            MockEntitiesCacheService(),
          );
      },
    );
  });

  tearDown(tearDownTestGetIt);

  testWidgets('shows empty state when entry is not a Task', (tester) async {
    final override = createEntryControllerOverride(testTextEntry);

    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        DesktopTaskDetailView(taskId: testTextEntry.meta.id),
        overrides: [override],
      ),
    );
    await tester.pump();

    // Non-Task entry should not render the detail content
    expect(find.text(testTextEntry.entryText!.plainText), findsNothing);
  });

  test('FakeEntryController resolves Task correctly', () async {
    final container = ProviderContainer(
      overrides: [
        entryControllerProvider(id: testTask.meta.id).overrideWith(
          () => FakeEntryController(testTask),
        ),
      ],
    );

    final state = await container.read(
      entryControllerProvider(id: testTask.meta.id).future,
    );

    expect(state?.entry, isA<Task>());
    expect((state!.entry! as Task).data.title, testTask.data.title);

    container.dispose();
  });
}
