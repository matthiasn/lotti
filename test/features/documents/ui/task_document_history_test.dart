import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/task_document_merge.dart';
import 'package:lotti/features/documents/repository/task_document_repository.dart';
import 'package:lotti/features/documents/state/task_document_providers.dart';
import 'package:lotti/features/documents/ui/task_document_history.dart';
import 'package:mocktail/mocktail.dart';

import '../../../classes/task_document_fixtures.dart';
import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  const key = (taskId: 'task-1', documentId: 'doc-brief');
  late MockTaskDocumentRepository repository;

  final v1 = taskDocumentVersionEntry(
    id: 'version-1',
    documentId: 'doc-brief',
    markdown: 'The first draft.',
  );
  final v2 = taskDocumentVersionEntry(
    number: 2,
    id: 'version-2',
    documentId: 'doc-brief',
    markdown: 'The second draft.',
  );
  final document = taskDocumentEntry(
    clock: {'a': 1},
    id: 'doc-brief',
    current: v2.ref,
  );

  void stubRestore(TaskDocumentWriteStatus status) => when(
    () => repository.restore(
      versionId: any(named: 'versionId'),
      baseVersionId: any(named: 'baseVersionId'),
    ),
  ).thenAnswer((_) async => (status: status, version: null));

  setUp(() {
    repository = MockTaskDocumentRepository();
    stubRestore(TaskDocumentWriteStatus.written);
  });

  Future<void> openHistory(
    WidgetTester tester, {
    bool documentGone = false,
  }) async {
    await withClock(
      Clock.fixed(taskDocFixtureEpoch.add(const Duration(hours: 2))),
      () async {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    unawaited(showTaskDocumentHistory(context, key)),
                child: const Text('open'),
              ),
            ),
            overrides: [
              taskDocumentRepositoryProvider.overrideWithValue(repository),
              taskDocumentProvider(
                key,
              ).overrideWith((ref) => documentGone ? null : document),
              taskDocumentVersionsProvider(
                key,
              ).overrideWith((ref) async => [v2, v1]),
            ],
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
      },
    );
  }

  Future<void> openVersion(WidgetTester tester, String versionId) async {
    await tester.tap(find.byKey(TaskDocumentHistoryKeys.row(versionId)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets(
    'lists the versions newest first, the one the document shows marked',
    (tester) async {
      await openHistory(tester);

      // Which and when lead each row; who wrote it is under them.
      final current = tester.getTopLeft(find.text('v2 · 2 h ago')).dy;
      final older = tester.getTopLeft(find.text('v1 · 2 h ago')).dy;
      expect(current, lessThan(older));
      // The current one is marked by its own pill, on its own row.
      expect(
        tester.getTopLeft(find.byKey(TaskDocumentHistoryKeys.current)).dy,
        lessThan(older),
      );
      expect(find.text('Current'), findsOneWidget);
      expect(find.text('Written by you'), findsNWidgets(2));
    },
  );

  testWidgets('the version on show offers no restore', (tester) async {
    await openHistory(tester);
    await openVersion(tester, 'version-2');

    expect(find.text('The second draft.'), findsOneWidget);
    expect(find.byKey(TaskDocumentHistoryKeys.restore), findsNothing);
  });

  testWidgets(
    'an older version restores over the version on show, says so and '
    'closes back to the page',
    (tester) async {
      await openHistory(tester);
      await openVersion(tester, 'version-1');
      expect(find.text('The first draft.'), findsOneWidget);

      await tester.tap(find.byKey(TaskDocumentHistoryKeys.restore));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      verify(
        () => repository.restore(
          versionId: 'version-1',
          baseVersionId: 'version-2',
        ),
      ).called(1);
      expect(find.text('Version restored'), findsWidgets);
      expect(find.byType(TaskDocumentVersionView), findsNothing);
      // Past the History sheet too, onto what opened it — the page, which
      // shows the restored text.
      expect(find.byType(TaskDocumentHistory), findsNothing);
      expect(find.text('open'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
    },
  );

  testWidgets(
    'a restore refused because a newer version arrived says so and stays',
    (tester) async {
      stubRestore(TaskDocumentWriteStatus.stale);
      await openHistory(tester);
      await openVersion(tester, 'version-1');

      await tester.tap(find.byKey(TaskDocumentHistoryKeys.restore));
      await tester.pump();

      expect(
        find.text(
          'A newer version arrived meanwhile. Look at it, then restore again.',
        ),
        findsWidgets,
      );
      expect(find.byType(TaskDocumentVersionView), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
    },
  );

  testWidgets(
    'a restore that could not be stored, or whose document went, says to '
    'try again and stays',
    (tester) async {
      for (final status in [
        TaskDocumentWriteStatus.missing,
        TaskDocumentWriteStatus.failed,
      ]) {
        stubRestore(status);
        await openHistory(tester);
        await openVersion(tester, 'version-1');

        await tester.tap(find.byKey(TaskDocumentHistoryKeys.restore));
        await tester.pump();

        expect(
          find.text("That didn't save — please try again."),
          findsWidgets,
        );
        expect(find.byType(TaskDocumentVersionView), findsOneWidget);
        await tester.pump(const Duration(seconds: 4));
      }
    },
  );

  testWidgets('a version is titled by its document and its number', (
    tester,
  ) async {
    await openHistory(tester);
    await openVersion(tester, 'version-1');

    expect(find.text('Client one-pager · v1'), findsOneWidget);
  });

  testWidgets('a version whose document is gone is titled by its number', (
    tester,
  ) async {
    await openHistory(tester, documentGone: true);
    await openVersion(tester, 'version-1');

    expect(find.text('Client one-pager · v1'), findsNothing);
    expect(find.text('v1'), findsOneWidget);
  });
}
