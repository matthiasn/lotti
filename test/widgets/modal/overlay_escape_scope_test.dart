import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/widgets/modal/overlay_escape_scope.dart';
import 'package:material_ui/material_ui.dart';

import '../../widget_test_utils.dart';

/// A page with a text field, and an in-page overlay toggled by [showing].
class _Bench extends StatelessWidget {
  const _Bench({
    required this.showing,
    required this.onDismiss,
    required this.pageField,
  });

  final bool showing;
  final VoidCallback onDismiss;
  final FocusNode pageField;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      TextField(focusNode: pageField),
      OverlayEscapeScope(
        active: showing,
        onDismiss: onDismiss,
        child: SizedBox(
          height: 100,
          child: showing ? const Text('overlay') : null,
        ),
      ),
    ],
  );
}

void main() {
  group('OverlayEscapeScope', () {
    late FocusNode pageField;
    late int dismissals;

    setUp(() {
      pageField = FocusNode();
      dismissals = 0;
    });
    tearDown(() => pageField.dispose());

    Future<void> pump(WidgetTester tester, {required bool showing}) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          _Bench(
            showing: showing,
            onDismiss: () => dismissals++,
            pageField: pageField,
          ),
        ),
      );
      // The scope claims focus after the frame that activates it.
      await tester.pump();
    }

    testWidgets('Escape calls onDismiss while active', (tester) async {
      await pump(tester, showing: true);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);

      expect(dismissals, 1);
    });

    testWidgets('Escape does nothing while inactive', (tester) async {
      await pump(tester, showing: false);
      pageField.requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);

      expect(dismissals, 0);
    });

    testWidgets('takes focus on activation and hands it back on release', (
      tester,
    ) async {
      await pump(tester, showing: false);
      pageField.requestFocus();
      await tester.pump();
      expect(pageField.hasFocus, isTrue);

      await pump(tester, showing: true);
      expect(pageField.hasFocus, isFalse);

      await pump(tester, showing: false);
      expect(pageField.hasFocus, isTrue);
    });

    testWidgets('is no Tab stop: Tab from the page skips the inactive scope', (
      tester,
    ) async {
      final after = FocusNode();
      addTearDown(after.dispose);
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Column(
            children: [
              TextField(focusNode: pageField),
              OverlayEscapeScope(
                active: false,
                onDismiss: () => dismissals++,
                child: const SizedBox(height: 40),
              ),
              TextField(focusNode: after),
            ],
          ),
        ),
      );
      pageField.requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      expect(after.hasPrimaryFocus, isTrue);
    });

    testWidgets('leaves focus alone on release when it has moved on', (
      tester,
    ) async {
      final elsewhere = FocusNode();
      addTearDown(elsewhere.dispose);
      await pump(tester, showing: false);
      pageField.requestFocus();
      await tester.pump();
      await pump(tester, showing: true);

      // Something else takes focus while the overlay shows, e.g. a field
      // inside it the user tabbed to.
      pageField.unfocus();
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Column(
            children: [
              _Bench(
                showing: true,
                onDismiss: () => dismissals++,
                pageField: pageField,
              ),
              Focus(focusNode: elsewhere, child: const SizedBox()),
            ],
          ),
        ),
      );
      elsewhere.requestFocus();
      await tester.pump();

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Column(
            children: [
              _Bench(
                showing: false,
                onDismiss: () => dismissals++,
                pageField: pageField,
              ),
              Focus(focusNode: elsewhere, child: const SizedBox()),
            ],
          ),
        ),
      );
      await tester.pump();

      expect(elsewhere.hasFocus, isTrue);
      expect(pageField.hasFocus, isFalse);
    });
  });
}
