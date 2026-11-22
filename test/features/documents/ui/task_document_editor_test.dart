import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task_document_data.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/documents/repository/task_document_repository.dart';
import 'package:lotti/features/documents/state/task_document_providers.dart';
import 'package:lotti/features/documents/ui/task_document_editor.dart';
import 'package:lotti/providers/task_focus_controller.dart';
import 'package:mocktail/mocktail.dart';

import '../../../classes/task_document_fixtures.dart';
import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  const taskId = 'task-1';
  late MockTaskDocumentRepository repository;

  final document = taskDocumentEntry(
    clock: {'a': 1},
    id: 'doc-brief',
    title: 'Launch brief',
    current: taskDocumentRef(3, id: 'version-3'),
  );
  final version3 = taskDocumentVersionEntry(
    number: 3,
    id: 'version-3',
    documentId: 'doc-brief',
    markdown: 'Old text',
  );

  TaskDocumentWriteResult result(
    TaskDocumentWriteStatus status, {
    TaskDocumentVersionEntry? version,
  }) => (status: status, version: version);

  void stubWrite(TaskDocumentWriteResult outcome) => when(
    () => repository.writeVersion(
      documentId: any(named: 'documentId'),
      markdown: any(named: 'markdown'),
      author: any(named: 'author'),
      baseVersionId: any(named: 'baseVersionId'),
    ),
  ).thenAnswer((_) async => outcome);

  setUp(() {
    repository = MockTaskDocumentRepository();
    when(() => repository.document('doc-brief')).thenAnswer(
      (_) async => document,
    );
    when(() => repository.currentVersion(document)).thenAnswer(
      (_) async => version3,
    );
    when(
      () => repository.rename(any(), any()),
    ).thenAnswer((_) async => true);
    stubWrite(
      result(TaskDocumentWriteStatus.written, version: version3),
    );
  });

  /// Pumps a button that opens the editor for [editing] (null: a new
  /// document), opens it, and returns the provider container.
  Future<ProviderContainer> open(
    WidgetTester tester, {
    TaskDocumentEntry? editing,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => unawaited(
              showTaskDocumentEditor(
                context,
                taskId: taskId,
                document: editing,
              ),
            ),
            child: const Text('open'),
          ),
        ),
        overrides: [
          taskDocumentRepositoryProvider.overrideWithValue(repository),
        ],
      ),
    );
    // Keep the focus intent alive past the editor, as the page would.
    final container = ProviderScope.containerOf(
      tester.element(find.text('open')),
    )..listen(taskFocusControllerProvider(taskId), (_, _) {});
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    return container;
  }

  Finder field(Key key) => find.descendant(
    of: find.byKey(key),
    matching: find.byType(EditableText),
  );

  Future<void> save(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(TaskDocumentEditorKeys.save));
    await tester.pump();
    await tester.tap(find.byKey(TaskDocumentEditorKeys.save));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  bool saveEnabled(WidgetTester tester) =>
      tester
          .widget<DesignSystemButton>(find.byKey(TaskDocumentEditorKeys.save))
          .onPressed !=
      null;

  group('a new document', () {
    testWidgets(
      'cannot be saved without a title; saving creates it with its text as '
      'the first version, scrolls the task to it and closes',
      (tester) async {
        final created = taskDocumentEntry(clock: {'a': 1}, id: 'doc-new');
        when(
          () => repository.create(taskId: taskId, title: 'Meeting summary'),
        ).thenAnswer((_) async => created);
        final container = await open(tester);

        expect(find.text('New document'), findsWidgets);
        expect(saveEnabled(tester), isFalse);

        await tester.enterText(
          field(TaskDocumentEditorKeys.titleField),
          '  Meeting summary  ',
        );
        await tester.enterText(
          field(TaskDocumentEditorKeys.textField),
          '# Summary',
        );
        await tester.pump();
        expect(saveEnabled(tester), isTrue);

        await save(tester);

        verify(
          () => repository.writeVersion(
            documentId: 'doc-new',
            markdown: '# Summary',
            author: TaskDocumentAuthor.user,
            baseVersionId: null,
          ),
        ).called(1);
        expect(
          container.read(taskFocusControllerProvider(taskId))?.target,
          TaskFocusTarget.documents,
        );
        expect(find.byType(TaskDocumentEditor), findsNothing);
      },
    );

    testWidgets('with no text, is created without a version', (tester) async {
      when(
        () => repository.create(taskId: taskId, title: 'Notes'),
      ).thenAnswer(
        (_) async => taskDocumentEntry(clock: {'a': 1}, id: 'doc-new'),
      );
      await open(tester);

      await tester.enterText(field(TaskDocumentEditorKeys.titleField), 'Notes');
      await tester.pump();
      await save(tester);

      verifyNever(
        () => repository.writeVersion(
          documentId: any(named: 'documentId'),
          markdown: any(named: 'markdown'),
          author: any(named: 'author'),
          baseVersionId: any(named: 'baseVersionId'),
        ),
      );
      expect(find.byType(TaskDocumentEditor), findsNothing);
    });

    testWidgets(
      'whose text failed to save is not created a second time on retry',
      (tester) async {
        final created = taskDocumentEntry(clock: {'a': 1}, id: 'doc-new');
        when(
          () => repository.create(taskId: taskId, title: 'Notes'),
        ).thenAnswer((_) async => created);
        stubWrite(result(TaskDocumentWriteStatus.failed));
        await open(tester);
        await tester.enterText(
          field(TaskDocumentEditorKeys.titleField),
          'Notes',
        );
        await tester.enterText(field(TaskDocumentEditorKeys.textField), 'Hi');
        await tester.pump();

        await save(tester);
        expect(find.text("That didn't save — please try again."), findsOne);
        expect(find.byType(TaskDocumentEditor), findsOneWidget);

        stubWrite(result(TaskDocumentWriteStatus.written));
        await save(tester);

        verify(
          () => repository.create(taskId: taskId, title: 'Notes'),
        ).called(1);
        expect(find.byType(TaskDocumentEditor), findsNothing);
      },
    );

    testWidgets('that could not be created says so and stays open', (
      tester,
    ) async {
      when(
        () => repository.create(taskId: taskId, title: 'Notes'),
      ).thenAnswer((_) async => null);
      await open(tester);
      await tester.enterText(field(TaskDocumentEditorKeys.titleField), 'Notes');
      await tester.pump();

      await save(tester);

      expect(find.text("That didn't save — please try again."), findsOne);
      expect(find.byType(TaskDocumentEditor), findsOneWidget);
    });
  });

  group('an existing document', () {
    testWidgets('opens on its current text', (tester) async {
      await open(tester, editing: document);

      expect(find.text('Edit document'), findsOneWidget);
      expect(find.text('Launch brief'), findsOneWidget);
      expect(find.text('Old text'), findsOneWidget);
    });

    testWidgets('with only a new title is renamed, and no version is written', (
      tester,
    ) async {
      await open(tester, editing: document);

      await tester.enterText(
        field(TaskDocumentEditorKeys.titleField),
        'Launch brief, final',
      );
      await tester.pump();
      await save(tester);

      verify(
        () => repository.rename('doc-brief', 'Launch brief, final'),
      ).called(1);
      verifyNever(
        () => repository.writeVersion(
          documentId: any(named: 'documentId'),
          markdown: any(named: 'markdown'),
          author: any(named: 'author'),
          baseVersionId: any(named: 'baseVersionId'),
        ),
      );
      expect(find.byType(TaskDocumentEditor), findsNothing);
    });

    testWidgets(
      'with new text writes a version over the one it opened on, by the user',
      (tester) async {
        await open(tester, editing: document);

        await tester.enterText(
          field(TaskDocumentEditorKeys.textField),
          'New text',
        );
        await tester.pump();
        await save(tester);

        verify(
          () => repository.writeVersion(
            documentId: 'doc-brief',
            markdown: 'New text',
            author: TaskDocumentAuthor.user,
            baseVersionId: 'version-3',
          ),
        ).called(1);
        verifyNever(() => repository.rename(any(), any()));
        expect(find.byType(TaskDocumentEditor), findsNothing);
      },
    );

    testWidgets(
      'that moved on meanwhile refuses the save and keeps the typed text',
      (tester) async {
        stubWrite(result(TaskDocumentWriteStatus.stale));
        await open(tester, editing: document);

        await tester.enterText(
          field(TaskDocumentEditorKeys.textField),
          'My edit',
        );
        await tester.pump();
        await save(tester);

        expect(
          find.text(
            'This document changed while you were editing. Copy your text, '
            'then close and open it again.',
          ),
          findsOneWidget,
        );
        expect(find.text('My edit'), findsOneWidget);
        expect(find.byType(TaskDocumentEditor), findsOneWidget);
      },
    );
  });
}
