import 'package:clock/clock.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/documents/state/task_document_providers.dart';
import 'package:lotti/features/documents/ui/task_document_editor.dart';
import 'package:lotti/features/documents/ui/task_documents_section.dart';
import 'package:mocktail/mocktail.dart';

import '../../../classes/task_document_fixtures.dart';
import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  const taskId = 'task-1';
  late MockTaskDocumentRepository repository;

  final withVersion = taskDocumentEntry(
    clock: {'a': 1},
    id: 'doc-brief',
    title: 'Launch brief',
    current: taskDocumentRef(3, id: 'version-3'),
  );
  final empty = taskDocumentEntry(
    clock: {'a': 1},
    id: 'doc-empty',
    title: 'Roll-call summary',
  );
  final version3 = taskDocumentVersionEntry(
    number: 3,
    id: 'version-3',
    documentId: 'doc-brief',
    markdown: '# Launch brief\n\nAll 37 penguins present.',
  );

  setUp(() {
    repository = MockTaskDocumentRepository();
    when(() => repository.currentVersion(withVersion)).thenAnswer(
      (_) async => version3,
    );
    when(() => repository.document('doc-brief')).thenAnswer(
      (_) async => withVersion,
    );
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const TaskDocumentsSection(taskId: taskId),
        overrides: [
          taskDocumentRepositoryProvider.overrideWithValue(repository),
          taskDocumentsProvider(taskId).overrideWith(
            (ref) => [withVersion, empty],
          ),
        ],
      ),
    );
    await tester.pump();
  }

  testWidgets(
    'lists each document with its version and age, or that it has no text '
    'yet, and offers Copy only where there is text',
    (tester) async {
      await withClock(
        // Two hours after the fixture version was written.
        Clock.fixed(taskDocFixtureEpoch.add(const Duration(hours: 2))),
        () => pump(tester),
      );

      expect(find.byKey(TaskDocumentsSectionKeys.title), findsOneWidget);
      expect(find.text('Documents'), findsOneWidget);
      expect(find.text('Launch brief'), findsOneWidget);
      expect(find.text('v3 · 2 h ago'), findsOneWidget);
      expect(find.text('Roll-call summary'), findsOneWidget);
      expect(find.text('No text yet'), findsOneWidget);
      expect(
        find.byKey(TaskDocumentsSectionKeys.copy('doc-brief')),
        findsOneWidget,
      );
      expect(
        find.byKey(TaskDocumentsSectionKeys.copy('doc-empty')),
        findsNothing,
      );
    },
  );

  testWidgets(
    "Copy puts the current version's markdown on the clipboard and says so",
    (tester) async {
      final copied = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await pump(tester);

      await tester.tap(find.byKey(TaskDocumentsSectionKeys.copy('doc-brief')));
      await tester.pump();

      expect(copied, ['# Launch brief\n\nAll 37 penguins present.']);
      expect(find.text('Markdown copied'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    },
  );

  testWidgets('tapping a document opens it in the editor', (tester) async {
    await pump(tester);

    await tester.tap(find.byKey(TaskDocumentsSectionKeys.row('doc-brief')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Edit document'), findsOneWidget);
    expect(find.byType(TaskDocumentEditor), findsOneWidget);
    expect(
      find.text('# Launch brief\n\nAll 37 penguins present.'),
      findsOneWidget,
    );
  });

  testWidgets('the add button opens the editor for a new document', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.byKey(TaskDocumentsSectionKeys.add));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('New document'), findsWidgets);
    final editor = tester.widget<TaskDocumentEditor>(
      find.byType(TaskDocumentEditor),
    );
    expect(editor.document, isNull);
    expect(editor.taskId, taskId);
  });
}
