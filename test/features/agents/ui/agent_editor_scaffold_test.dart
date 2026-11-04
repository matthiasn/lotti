import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/ui/agent_editor_scaffold.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:material_ui/material_ui.dart';

import '../../../widget_test_utils.dart';

void main() {
  late List<String> calls;

  setUp(() => calls = []);

  Future<void> pump(
    WidgetTester tester, {
    bool withCancel = true,
    bool busy = false,
    Widget? header,
    Size size = const Size(400, 800),
  }) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        AgentEditorScaffold(
          title: 'Edit goal',
          onBack: () => calls.add('back'),
          onCancel: withCancel ? () => calls.add('cancel') : null,
          cancelKey: const ValueKey('cancel'),
          busy: busy,
          header: header,
          primary: DesignSystemButton(
            key: const ValueKey('save'),
            label: 'Save',
            onPressed: () => calls.add('save'),
          ),
          body: [
            ElevatedButton(
              key: const ValueKey('field'),
              onPressed: () => calls.add('field'),
              child: const Text('A field'),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a page: its title in the app bar, its back, Cancel and the '
      'primary in the footer, each doing their own thing', (tester) async {
    await pump(tester);

    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Edit goal'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byType(BackButton));
    await tester.tap(find.byKey(const ValueKey('cancel')));
    await tester.tap(find.byKey(const ValueKey('save')));
    await tester.tap(find.byKey(const ValueKey('field')));

    expect(calls, ['back', 'cancel', 'save', 'field']);
    // The footer sits below the scrolling body, not over it.
    expect(
      tester.getRect(find.byKey(const ValueKey('save'))).top,
      greaterThan(tester.getRect(find.byType(ListView)).bottom - 1),
    );
  });

  testWidgets('without a way out the footer holds the primary alone', (
    tester,
  ) async {
    await pump(tester, withCancel: false);

    expect(find.byKey(const ValueKey('cancel')), findsNothing);
    expect(find.text('Cancel'), findsNothing);
    expect(find.byKey(const ValueKey('save')), findsOneWidget);
  });

  testWidgets('while busy the body holds still, the footer does not', (
    tester,
  ) async {
    await pump(tester, busy: true);

    await tester.tap(find.byKey(const ValueKey('field')), warnIfMissed: false);
    await tester.tap(find.byKey(const ValueKey('save')));

    expect(calls, ['save']);
  });

  testWidgets('a header is pinned above the body', (tester) async {
    await pump(tester, header: const Text('Step 1 of 3'));

    expect(
      tester.getRect(find.text('Step 1 of 3')).bottom,
      lessThanOrEqualTo(tester.getRect(find.byType(ListView)).top),
    );
  });

  testWidgets('a wide window keeps the editor to the reading measure', (
    tester,
  ) async {
    await pump(tester, size: const Size(2000, 1000));

    expect(
      tester.getSize(find.byType(ListView)).width,
      lessThanOrEqualTo(kActionListContentMaxWidth),
    );
  });
}
