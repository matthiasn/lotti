import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/ui/agent_editor_scaffold.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/glass_strip.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:material_ui/material_ui.dart';

import '../../../widget_test_utils.dart';

void main() {
  late List<String> calls;

  setUp(() => calls = []);

  const saveKey = ValueKey('save');
  const cancelKey = ValueKey('cancel');

  Future<void> pump(
    WidgetTester tester, {
    bool withCancel = true,
    bool canSave = true,
    bool busy = false,
    Widget? header,
    int fields = 1,
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
          cancelKey: cancelKey,
          busy: busy,
          header: header,
          primaryKey: saveKey,
          primaryLabel: 'Save new version',
          onPrimary: canSave ? () => calls.add('save') : null,
          body: [
            for (var i = 0; i < fields; i++)
              SizedBox(
                height: 120,
                child: ElevatedButton(
                  key: ValueKey('field-$i'),
                  onPressed: () => calls.add('field-$i'),
                  child: Text('Field $i'),
                ),
              ),
          ],
        ),
      ),
    );
    // A busy primary spins for as long as the save runs, so it never settles.
    busy ? await tester.pump() : await tester.pumpAndSettle();
  }

  DesignSystemButton button(WidgetTester tester, Key key) =>
      tester.widget<DesignSystemButton>(find.byKey(key));

  testWidgets('a page: its title in the app bar, its back, Cancel and the '
      'primary in the action bar, each doing their own thing', (tester) async {
    await pump(tester);

    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Edit goal'),
      ),
      findsOneWidget,
    );
    expect(find.text('Save new version'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.tap(find.byKey(cancelKey));
    await tester.tap(find.byKey(saveKey));
    await tester.tap(find.byKey(const ValueKey('field-0')));

    expect(calls, ['back', 'cancel', 'save', 'field-0']);
  });

  testWidgets('the action bar is the app sticky bar: large design-system '
      'buttons on glass, Cancel leading and the primary trailing', (
    tester,
  ) async {
    await pump(tester);

    // The size every other action bar in the app uses — the editor once
    // rendered the default small size, a size smaller than everywhere else.
    expect(button(tester, saveKey).size, DesignSystemButtonSize.large);
    expect(button(tester, cancelKey).size, DesignSystemButtonSize.large);
    expect(
      button(tester, cancelKey).variant,
      DesignSystemButtonVariant.secondary,
    );
    expect(button(tester, saveKey).variant, DesignSystemButtonVariant.primary);
    for (final key in [saveKey, cancelKey]) {
      expect(
        find.ancestor(
          of: find.byKey(key),
          matching: find.byType(DesignSystemGlassStrip),
        ),
        findsOneWidget,
      );
    }
    expect(
      tester.getCenter(find.byKey(cancelKey)).dx,
      lessThan(tester.getCenter(find.byKey(saveKey)).dx),
    );
  });

  testWidgets('the body scrolls behind the bar, and its last field can '
      'always be scrolled clear of it', (tester) async {
    await pump(tester, fields: 12);

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.extendBody, isTrue);
    final barTop = tester.getRect(find.byType(DesignSystemGlassStrip)).top;
    // The list runs under the glass, so the blur has something behind it.
    expect(tester.getRect(find.byType(ListView)).bottom, greaterThan(barTop));

    await tester.drag(find.byType(ListView), const Offset(0, -5000));
    await tester.pumpAndSettle();

    expect(
      tester.getRect(find.byKey(const ValueKey('field-11'))).bottom,
      lessThanOrEqualTo(barTop),
    );
    await tester.tap(find.byKey(const ValueKey('field-11')));
    expect(calls, ['field-11']);
  });

  testWidgets('without a way out the bar holds the primary alone', (
    tester,
  ) async {
    await pump(tester, withCancel: false);

    expect(find.byKey(cancelKey), findsNothing);
    expect(find.text('Cancel'), findsNothing);
    expect(find.byKey(saveKey), findsOneWidget);
  });

  testWidgets('a primary with nothing to save is shown disabled', (
    tester,
  ) async {
    await pump(tester, canSave: false);

    expect(button(tester, saveKey).onPressed, isNull);
    await tester.tap(find.byKey(saveKey));
    expect(calls, isEmpty);
  });

  testWidgets('while busy the body holds still and the primary shows the '
      'save in flight', (tester) async {
    await pump(tester, busy: true);

    expect(button(tester, saveKey).isLoading, isTrue);
    await tester.tap(
      find.byKey(const ValueKey('field-0')),
      warnIfMissed: false,
    );
    await tester.tap(find.byKey(saveKey), warnIfMissed: false);

    expect(calls, isEmpty);
  });

  testWidgets('a header is pinned above the body', (tester) async {
    await pump(tester, header: const Text('Step 1 of 3'));

    expect(
      tester.getRect(find.text('Step 1 of 3')).bottom,
      lessThanOrEqualTo(tester.getRect(find.byType(ListView)).top),
    );
  });

  testWidgets('a wide window keeps the editor to the reading measure, and '
      'the bar to the same column', (tester) async {
    await pump(tester, size: const Size(2000, 1000));

    final list = tester.getRect(find.byType(ListView));
    expect(list.width, lessThanOrEqualTo(kActionListContentMaxWidth));
    // The buttons line up with the fields, not with the window's edges.
    expect(tester.getRect(find.byKey(saveKey)).right, list.right);
    expect(tester.getRect(find.byKey(cancelKey)).left, list.left);
  });
}
