import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/editable_title.dart';

import '../../../../widget_test_utils.dart';

Widget _wrap(Widget child) => makeTestableWidget2(
  Material(
    child: Center(child: SizedBox(width: 400, child: child)),
  ),
  mediaQueryData: const MediaQueryData(size: Size(800, 600)),
);

void main() {
  group('EditableTitle', () {
    testWidgets('tap starts editing; Enter submits the trimmed value', (
      tester,
    ) async {
      final submitted = <String>[];
      await tester.pumpWidget(
        _wrap(EditableTitle(value: 'Lunch', onSubmitted: submitted.add)),
      );

      await tester.tap(
        find.byKey(const Key('daily_os_editable_title_display')),
      );
      await tester.pump();

      final field = find.byKey(const Key('daily_os_editable_title_field'));
      expect(field, findsOneWidget);
      await tester.enterText(field, '  Lunch with Sarah  ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(submitted, ['Lunch with Sarah']);
      // Back in display mode.
      expect(field, findsNothing);
    });

    testWidgets('Escape cancels the edit without submitting', (tester) async {
      final submitted = <String>[];
      await tester.pumpWidget(
        _wrap(EditableTitle(value: 'Lunch', onSubmitted: submitted.add)),
      );

      await tester.tap(
        find.byKey(const Key('daily_os_editable_title_display')),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('daily_os_editable_title_field')),
        'Something else',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(submitted, isEmpty);
      expect(
        find.byKey(const Key('daily_os_editable_title_field')),
        findsNothing,
      );
      expect(find.text('Lunch'), findsOneWidget);
    });

    testWidgets('blur saves the pending edit', (tester) async {
      final submitted = <String>[];
      await tester.pumpWidget(
        _wrap(
          Column(
            children: [
              EditableTitle(value: 'Lunch', onSubmitted: submitted.add),
              const TextField(key: Key('other_field')),
            ],
          ),
        ),
      );

      await tester.tap(
        find.byKey(const Key('daily_os_editable_title_display')),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('daily_os_editable_title_field')),
        'Team lunch',
      );
      // Move focus elsewhere — blur must commit.
      await tester.tap(find.byKey(const Key('other_field')));
      await tester.pump();

      expect(submitted, ['Team lunch']);
    });

    testWidgets('unchanged or empty values are not submitted', (tester) async {
      final submitted = <String>[];
      await tester.pumpWidget(
        _wrap(EditableTitle(value: 'Lunch', onSubmitted: submitted.add)),
      );

      // Unchanged.
      await tester.tap(
        find.byKey(const Key('daily_os_editable_title_display')),
      );
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      // Whitespace-only.
      await tester.tap(
        find.byKey(const Key('daily_os_editable_title_display')),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('daily_os_editable_title_field')),
        '   ',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(submitted, isEmpty);
    });

    testWidgets('pencil affordance brightens on hover', (tester) async {
      await tester.pumpWidget(
        _wrap(EditableTitle(value: 'Lunch', onSubmitted: (_) {})),
      );

      AnimatedOpacity pencilOpacity() => tester.widget<AnimatedOpacity>(
        find.ancestor(
          of: find.byIcon(Icons.edit_outlined),
          matching: find.byType(AnimatedOpacity),
        ),
      );
      expect(pencilOpacity().opacity, 0.25);

      final gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(
        tester.getCenter(
          find.byKey(const Key('daily_os_editable_title_display')),
        ),
      );
      await tester.pump();

      expect(pencilOpacity().opacity, 0.6);

      // Leaving the title dims the pencil back to its resting state.
      await gesture.moveTo(Offset.zero);
      await tester.pump();
      expect(pencilOpacity().opacity, 0.25);
    });
  });
}
