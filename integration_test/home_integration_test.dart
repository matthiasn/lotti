import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lotti/main.dart' as app;
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

const debug = false;

Future<void> waitSeconds(int s) async {
  if (debug) {
    await Future.delayed(Duration(seconds: s), () {});
  }
}

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

          await waitSeconds(1);

          expect(find.text('Search...'), findsWidgets);

          final add = find.byIcon(Icons.add).first;
          await tester.tap(add);
          await tester.pumpAndSettle();

          final addText = find.byIcon(MdiIcons.textLong).first;
          await tester.tap(addText);
          await tester.pumpAndSettle();

          final editor = find.byType(QuillEditor);
          debugPrint(editor.toString());

          // TODO: figure out how to enter text in flutter_quill
          // String testText = 'test text: ${DateTime.now()}';
          // await tester.enterText(editor, testText);

          await waitSeconds(1);

          final saveIcon = find.byIcon(Icons.save);
          await tester.tap(saveIcon);
          await tester.pumpAndSettle();

          //expect(find.text(testText), findsOneWidget);

          await waitSeconds(1);

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

          await tester.tap(find.byIcon(MdiIcons.tag));
          await tester.pumpAndSettle();

          await waitSeconds(1);

          await tester.tap(find.byKey(const Key('add_tag_action')));
          await tester.pumpAndSettle();

          await waitSeconds(1);

          await tester.tap(find.byIcon(MdiIcons.tagPlusOutline));
          await tester.pumpAndSettle();

          await waitSeconds(1);

          final testTag = DateTime.now().toString();

          await tester.enterText(
            find.byKey(const Key('tag_name_field')),
            testTag,
          );
          await Future.delayed(const Duration(seconds: 1), () {});

          await tester.tap(find.byKey(const Key('tag_save')));
          await tester.pumpAndSettle();

          expect(find.text(testTag), findsOneWidget);
          await waitSeconds(1);

          await tester.tap(find.text(testTag));
          await tester.pumpAndSettle();

          await tester.tap(find.byIcon(MdiIcons.trashCanOutline));
          await tester.pumpAndSettle();

          expect(find.text(testTag), findsNothing);

          await waitSeconds(2);
        },
      );
    },
  );
}
