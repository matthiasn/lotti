import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/widgets/modal/modal_escape_scope.dart';
import 'package:material_ui/material_ui.dart';

import '../../widget_test_utils.dart';

/// A modal whose content sits inside its own [Scaffold] — the shape of every
/// Wolt sheet — with a focused text field, which is what used to swallow
/// Escape.
Widget _scaffoldedField({required bool withScope, bool vetoPop = false}) {
  const field = Center(
    child: SizedBox(
      width: 300,
      child: Material(child: TextField(autofocus: true, key: _fieldKey)),
    ),
  );
  const scaffold = Scaffold(backgroundColor: Colors.transparent, body: field);
  // Around the scaffold, as a route that hosts a whole page wraps it: the
  // scope must not depend on sitting inside every scaffold.
  final content = withScope
      ? const ModalEscapeScope(child: scaffold)
      : scaffold;
  return vetoPop ? PopScope<Object?>(canPop: false, child: content) : content;
}

const ValueKey<String> _fieldKey = ValueKey('modal-field');

/// Pumps a host app and opens a dialog route around [content], returning the
/// route's result future.
Future<Future<Object?>> _open(
  WidgetTester tester,
  Widget content, {
  bool barrierDismissible = true,
}) async {
  late BuildContext hostContext;
  await tester.pumpWidget(
    makeTestableWidgetNoScroll(
      Builder(
        builder: (context) {
          hostContext = context;
          return const SizedBox.expand();
        },
      ),
    ),
  );
  final result = showGeneralDialog<Object?>(
    context: hostContext,
    barrierDismissible: barrierDismissible,
    barrierLabel: 'dismiss',
    pageBuilder: (_, _, _) => content,
  );
  await tester.pumpAndSettle();
  expect(
    FocusManager.instance.primaryFocus?.context
        ?.findAncestorWidgetOfExactType<TextField>(),
    isNotNull,
    reason:
        'the field inside the modal must hold focus for this to test '
        'the trap',
  );
  return result;
}

void main() {
  group('ModalEscapeScope', () {
    testWidgets(
      'without it, a Scaffold inside a dismissible modal swallows Escape '
      'from a focused field',
      (tester) async {
        await _open(tester, _scaffoldedField(withScope: false));

        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();

        // The framework trap this widget exists for: the Scaffold's disabled
        // drawer-dismiss action ends the lookup before the route's own.
        expect(find.byKey(_fieldKey), findsOneWidget);
      },
    );

    testWidgets('Escape closes the modal with the barrier tap result (null)', (
      tester,
    ) async {
      final result = await _open(tester, _scaffoldedField(withScope: true));
      Object? popped = 'not popped';
      result.then((value) => popped = value).ignore();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byKey(_fieldKey), findsNothing);
      expect(popped, isNull);
    });

    testWidgets('Escape leaves a non-barrier-dismissible modal open', (
      tester,
    ) async {
      await _open(
        tester,
        _scaffoldedField(withScope: true),
        barrierDismissible: false,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byKey(_fieldKey), findsOneWidget);
    });

    testWidgets('a PopScope inside the modal can still veto the Escape pop', (
      tester,
    ) async {
      await _open(
        tester,
        _scaffoldedField(withScope: true, vetoPop: true),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byKey(_fieldKey), findsOneWidget);
    });

    testWidgets('does nothing for a route that is no longer on top', (
      tester,
    ) async {
      await _open(tester, _scaffoldedField(withScope: true));
      final lowerContext = tester.element(find.byKey(_fieldKey));
      final navigator = Navigator.of(lowerContext);
      navigator
          .push(
            MaterialPageRoute<void>(
              builder: (_) => const Text('page on top'),
            ),
          )
          .ignore();
      await tester.pumpAndSettle();

      // Pull focus back into the covered modal, so the key travels through
      // its scope. Were the scope still enabled, its maybePop would take the
      // page on top off the navigator.
      final field = tester.widget<TextField>(
        find.byKey(_fieldKey, skipOffstage: false),
      );
      final fieldFocus = tester
          .state<EditableTextState>(
            find.byType(EditableText, skipOffstage: false),
          )
          .widget
          .focusNode;
      expect(field.key, _fieldKey);
      fieldFocus.requestFocus();
      await tester.pump();
      expect(fieldFocus.hasPrimaryFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.text('page on top'), findsOneWidget);
      expect(find.byKey(_fieldKey, skipOffstage: false), findsOneWidget);
    });
  });
}
