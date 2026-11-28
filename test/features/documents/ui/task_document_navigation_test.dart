import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/documents/state/task_document_providers.dart';
import 'package:lotti/features/documents/ui/task_document_navigation.dart';
import 'package:lotti/features/documents/ui/task_document_page.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../classes/task_document_fixtures.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

void main() {
  const key = (taskId: 'task-1', documentId: 'doc-1');
  late ValueNotifier<({String taskId, String documentId})?> desktopDocument;

  setUp(() async {
    desktopDocument = ValueNotifier(null);
    final nav = MockNavService();
    when(() => nav.desktopTaskDocument).thenReturn(desktopDocument);
    await setUpTestGetIt(
      additionalSetup: () => getIt.registerSingleton<NavService>(nav),
    );
  });

  tearDown(() async {
    desktopDocument.dispose();
    await tearDownTestGetIt();
  });

  Future<void> pumpAndOpen(
    WidgetTester tester, {
    required MediaQueryData media,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => openTaskDocument(
              context,
              taskId: key.taskId,
              documentId: key.documentId,
            ),
            child: const Text('open'),
          ),
        ),
        mediaQueryData: media,
        overrides: [
          taskDocumentProvider(key).overrideWith(
            (ref) => taskDocumentEntry(clock: {'a': 1}, id: key.documentId),
          ),
          taskDocumentCurrentVersionProvider(
            key,
          ).overrideWith((ref) async => null),
        ],
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets(
    'on a desktop layout, opens the document over its task in the detail '
    'pane, pushing nothing',
    (tester) async {
      await pumpAndOpen(tester, media: desktopLayoutMediaQueryData);

      expect(desktopDocument.value, key);
      expect(find.byType(TaskDocumentPage), findsNothing);
    },
  );

  testWidgets('on a phone, pushes the document page', (tester) async {
    await pumpAndOpen(tester, media: phoneMediaQueryData);

    expect(desktopDocument.value, isNull);
    final page = tester.widget<TaskDocumentPage>(
      find.byType(TaskDocumentPage),
    );
    expect(page.taskId, key.taskId);
    expect(page.documentId, key.documentId);
  });
}
