import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task_document_data.dart';
import 'package:lotti/classes/task_document_merge.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/documents/state/task_document_providers.dart';
import 'package:lotti/features/documents/ui/task_document_editor.dart';
import 'package:lotti/features/documents/ui/task_document_history.dart';
import 'package:lotti/features/documents/ui/task_document_page.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart' show BackWidget;
import 'package:lotti/widgets/modal/confirmation_modal.dart';
import 'package:mocktail/mocktail.dart';

import '../../../classes/task_document_fixtures.dart';
import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  const key = (taskId: 'task-1', documentId: 'doc-brief');
  late MockTaskDocumentRepository repository;

  final version = taskDocumentVersionEntry(
    number: 2,
    id: 'version-2',
    documentId: 'doc-brief',
    markdown: '# Launch brief\n\nAll 37 penguins present.',
    author: TaskDocumentAuthor.agent,
  );
  final document = taskDocumentEntry(
    clock: {'a': 1},
    id: 'doc-brief',
    title: 'Launch brief for Mission Control',
    current: version.ref,
  );
  final empty = taskDocumentEntry(
    clock: {'a': 1},
    id: 'doc-brief',
    title: 'Roll-call summary',
  );

  setUp(() {
    repository = MockTaskDocumentRepository();
    when(() => repository.delete(any())).thenAnswer((_) async => true);
    when(() => repository.document(any())).thenAnswer((_) async => document);
    when(
      () => repository.currentVersion(document),
    ).thenAnswer((_) async => version);
  });

  Future<void> pump(
    WidgetTester tester, {
    TaskDocumentEntry? shown,
    bool gone = false,
    VoidCallback? onClose,
  }) async {
    final doc = gone ? null : (shown ?? document);
    await withClock(
      Clock.fixed(taskDocFixtureEpoch.add(const Duration(hours: 2))),
      () async {
        await tester.pumpWidget(
          makeTestableWidgetNoScroll(
            TaskDocumentPage(
              taskId: key.taskId,
              documentId: key.documentId,
              onClose: onClose,
            ),
            overrides: [
              taskDocumentRepositoryProvider.overrideWithValue(repository),
              taskDocumentProvider(key).overrideWith((ref) => doc),
              taskDocumentCurrentVersionProvider(key).overrideWith(
                (ref) async => doc?.data.current == null ? null : version,
              ),
              taskDocumentVersionsProvider(key).overrideWith(
                (ref) async => [version],
              ),
            ],
          ),
        );
        await tester.pump();
      },
    );
  }

  bool enabled(WidgetTester tester, Key key) =>
      tester.widget<DesignSystemButton>(find.byKey(key)).onPressed != null;

  testWidgets(
    'shows the title, where the version came from and its rendered text',
    (tester) async {
      await pump(tester);

      expect(find.text('Launch brief for Mission Control'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(TaskDocumentPageKeys.provenance)).data,
        'v2 · Drafted by the agent, confirmed by you · 2 h ago',
      );
      expect(find.text('All 37 penguins present.'), findsOneWidget);
      expect(enabled(tester, TaskDocumentPageKeys.copy), isTrue);
      expect(enabled(tester, TaskDocumentPageKeys.history), isTrue);
    },
  );

  testWidgets(
    'a document with no text yet says so, and has nothing to copy or look '
    'back on',
    (tester) async {
      await pump(tester, shown: empty);

      expect(find.text('No text yet'), findsOneWidget);
      expect(find.byKey(TaskDocumentPageKeys.provenance), findsNothing);
      expect(enabled(tester, TaskDocumentPageKeys.copy), isFalse);
      expect(enabled(tester, TaskDocumentPageKeys.history), isFalse);
      expect(enabled(tester, TaskDocumentPageKeys.edit), isTrue);
    },
  );

  testWidgets('a document deleted while open says so', (tester) async {
    await pump(tester, gone: true);

    expect(find.text('This document was deleted.'), findsOneWidget);
    expect(find.byKey(TaskDocumentPageKeys.edit), findsNothing);
  });

  testWidgets('Edit opens the editor on this document', (tester) async {
    await pump(tester);

    await tester.tap(find.byKey(TaskDocumentPageKeys.edit));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final editor = tester.widget<TaskDocumentEditor>(
      find.byType(TaskDocumentEditor),
    );
    expect(editor.document, document);
    expect(editor.taskId, key.taskId);
  });

  testWidgets('Copy puts the version on show on the clipboard', (
    tester,
  ) async {
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

    await tester.tap(find.byKey(TaskDocumentPageKeys.copy));
    await tester.pump();

    expect(copied, ['# Launch brief\n\nAll 37 penguins present.']);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('History lists the versions', (tester) async {
    await pump(tester);

    await tester.tap(find.byKey(TaskDocumentPageKeys.history));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(TaskDocumentHistory), findsOneWidget);
    expect(find.text('v2 · Current'), findsOneWidget);
  });

  testWidgets(
    'Delete asks first; confirmed, it deletes the document and leaves the '
    'page',
    (tester) async {
      var closed = 0;
      await pump(tester, onClose: () => closed++);

      await tester.tap(find.byKey(TaskDocumentPageKeys.delete));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(confirmationModalKey), findsOneWidget);
      expect(find.text('Delete this document?'), findsOneWidget);

      await tester.tap(find.text('Delete').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      verify(() => repository.delete('doc-brief')).called(1);
      expect(closed, 1);
    },
  );

  testWidgets('Delete cancelled deletes nothing and stays', (tester) async {
    var closed = 0;
    await pump(tester, onClose: () => closed++);

    await tester.tap(find.byKey(TaskDocumentPageKeys.delete));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    verifyNever(() => repository.delete(any()));
    expect(closed, 0);
  });

  testWidgets('the back arrow leaves through onClose when given', (
    tester,
  ) async {
    var closed = 0;
    await pump(tester, onClose: () => closed++);

    await tester.tap(find.byType(BackWidget));
    await tester.pump();

    expect(closed, 1);
  });
}
