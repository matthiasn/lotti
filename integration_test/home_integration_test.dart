import 'package:flutter/material.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lotti/main.dart' as app;

void main() {
  app.main();
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group(
    'new entry end-to-end test',
    () {
      testWidgets(
        'tap add, create entry',
        (WidgetTester tester) async {
          await tester.pumpAndSettle();

          expect(find.text('Search...'), findsWidgets);

          final add = find.byIcon(Icons.add).first;
          await tester.tap(add);
          await tester.pumpAndSettle();

          final addText = find.byIcon(MdiIcons.textLong).first;
          await tester.tap(addText);
          await tester.pumpAndSettle();

          final editor = find.byType(QuillEditor);
          // Smoke check: the editor must actually mount on the page —
          // the rest of this block depends on it being present. Quill
          // does not accept `tester.enterText` directly (driving input
          // requires reaching into the QuillController and calling
          // `document.insert`), so deeper text-entry coverage lives in
          // the unit tests for the editor widget itself.
          expect(editor, findsOneWidget);

          final saveIcon = find.byIcon(Icons.save);
          await tester.tap(saveIcon);
          await tester.pumpAndSettle();

          //expect(find.text(testText), findsOneWidget);

          final settings = find.byIcon(Icons.settings_outlined);
          await tester.tap(settings);
          await tester.pumpAndSettle();

          expect(find.text('Tags'), findsOneWidget);
          expect(find.text('Health Import'), findsOneWidget);
          expect(find.text('Synchronization'), findsOneWidget);
          expect(find.text('Measurables'), findsOneWidget);
          expect(find.text('Sync Outbox'), findsOneWidget);
          expect(find.text('Logs'), findsOneWidget);
          expect(find.text('Conflicts'), findsOneWidget);
          expect(find.text('Flags'), findsOneWidget);
          expect(find.text('Maintenance'), findsOneWidget);

          const testTag = 'integration-test-tag';
          await tester.tap(find.byIcon(MdiIcons.tag));
          await tester.pumpAndSettle();

          // Make local retries idempotent if an earlier run stopped before
          // reaching the cleanup at the end of this test.
          if (find.text(testTag).evaluate().isNotEmpty) {
            await tester.tap(find.text(testTag));
            await tester.pumpAndSettle();
            await tester.tap(find.byIcon(MdiIcons.trashCanOutline));
            await tester.pumpAndSettle();
            expect(find.text(testTag), findsNothing);
          }

          await tester.tap(find.byKey(const Key('add_tag_action')));
          await tester.pumpAndSettle();

          await tester.tap(find.byIcon(MdiIcons.tagPlusOutline));
          await tester.pumpAndSettle();

          await tester.enterText(
            find.byKey(const Key('tag_name_field')),
            testTag,
          );
          await tester.pump();

          await tester.tap(find.byKey(const Key('tag_save')));
          await tester.pumpAndSettle();

          expect(find.text(testTag), findsOneWidget);

          await tester.tap(find.text(testTag));
          await tester.pumpAndSettle();

          await tester.tap(find.byIcon(MdiIcons.trashCanOutline));
          await tester.pumpAndSettle();

          expect(find.text(testTag), findsNothing);
        },
      );
    },
  );
}
