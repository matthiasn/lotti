import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/documents/state/task_document_providers.dart';
import 'package:lotti/features/documents/ui/new_document_item.dart';
import 'package:lotti/features/documents/ui/task_document_editor.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

import '../../../widget_test_utils.dart';

void main() {
  const taskId = 'task-1';

  testWidgets(
    'closes the Add sheet and opens the editor for a new document on the task',
    (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => unawaited(
                ModalUtils.showSinglePageModal<void>(
                  context: context,
                  title: 'Add',
                  builder: (_) => const NewDocumentItem(taskId),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Write a document'), findsOneWidget);
      expect(
        find.text('Adds a markdown document you can revise and copy out.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Write a document'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(NewDocumentItem), findsNothing);
      final editor = tester.widget<TaskDocumentEditor>(
        find.byType(TaskDocumentEditor),
      );
      expect(editor.taskId, taskId);
      expect(editor.document, isNull);
    },
  );

  Future<void> pumpAction(WidgetTester tester, {required bool enabled}) =>
      tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Consumer(
            builder: (context, ref, _) =>
                newDocumentAction(ref, taskId) ?? const Text('no row'),
          ),
          overrides: [taskDocumentsEnabledProvider.overrideWithValue(enabled)],
        ),
      );

  testWidgets('the task create action offers the row for that task while '
      'task documents are switched on', (tester) async {
    await pumpAction(tester, enabled: true);

    expect(
      tester.widget<NewDocumentItem>(find.byType(NewDocumentItem)).taskId,
      taskId,
    );
  });

  testWidgets('the task create action offers no row while task documents '
      'are switched off', (tester) async {
    await pumpAction(tester, enabled: false);

    expect(find.byType(NewDocumentItem), findsNothing);
    expect(find.text('no row'), findsOneWidget);
  });
}
