import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/components/toggles/design_system_toggle.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings/ui/widgets/settings_icon.dart';
import 'package:lotti/features/settings/ui/widgets/settings_toggle_list.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

void main() {
  late List<(String, bool)> changes;

  SettingsToggleRow row(
    String title, {
    bool value = false,
    bool enabled = true,
    IconData icon = LottiIcons.lock,
  }) => SettingsToggleRow(
    key: ValueKey(title),
    title: title,
    subtitle: '$title description',
    icon: icon,
    value: value,
    enabled: enabled,
    onChanged: (status) => changes.add((title, status)),
  );

  setUp(() => changes = []);

  Future<void> pump(WidgetTester tester, List<SettingsToggleRow> rows) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(SettingsToggleList(rows: rows)),
    );
    await tester.pump();
  }

  DesignSystemListItem itemFor(WidgetTester tester, String title) =>
      tester.widget(find.byKey(ValueKey(title)));

  DesignSystemToggle toggleFor(WidgetTester tester, String title) =>
      tester.widget(
        find.descendant(
          of: find.byKey(ValueKey(title)),
          matching: find.byType(DesignSystemToggle),
        ),
      );

  testWidgets('renders a title, description, icon and switch per row', (
    tester,
  ) async {
    await pump(tester, [
      row('One', value: true, icon: LottiIcons.map),
      row('Two'),
    ]);

    expect(find.text('One'), findsOneWidget);
    expect(find.text('One description'), findsOneWidget);
    expect(find.byIcon(LottiIcons.map), findsOneWidget);
    expect(find.byType(SettingsIcon), findsNWidgets(2));
    expect(toggleFor(tester, 'One').value, isTrue);
    expect(toggleFor(tester, 'Two').value, isFalse);
  });

  testWidgets('flipping the switch reports the new value', (tester) async {
    await pump(tester, [row('One')]);

    await tester.tap(find.byType(DesignSystemToggle));
    await tester.pump();

    expect(changes, [('One', true)]);
  });

  testWidgets('tapping the row flips it the same way', (tester) async {
    await pump(tester, [row('One', value: true)]);

    await tester.tap(find.text('One'));
    await tester.pump();

    expect(changes, [('One', false)]);
  });

  testWidgets('a disabled row greys its switch and ignores taps', (
    tester,
  ) async {
    await pump(tester, [row('One', enabled: false)]);

    expect(toggleFor(tester, 'One').enabled, isFalse);
    expect(itemFor(tester, 'One').onTap, isNull);
    await tester.tap(find.text('One'));
    await tester.tap(find.byType(DesignSystemToggle), warnIfMissed: false);
    await tester.pump();

    expect(changes, isEmpty);
  });

  testWidgets('every row but the last carries a divider', (tester) async {
    await pump(tester, [row('One'), row('Two'), row('Three')]);

    expect(itemFor(tester, 'One').showDivider, isTrue);
    expect(itemFor(tester, 'Two').showDivider, isTrue);
    expect(itemFor(tester, 'Three').showDivider, isFalse);
  });

  testWidgets('hovering a row fades the dividers bracketing it', (
    tester,
  ) async {
    await pump(tester, [row('One'), row('Two'), row('Three')]);
    expect(itemFor(tester, 'Two').dividerColor, isNull);

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(tester.getCenter(find.text('Two')));
    await tester.pump();

    // The hairline above the hovered row (under One) and the one under it
    // both go transparent; the unrelated last divider is untouched.
    expect(itemFor(tester, 'One').dividerColor, Colors.transparent);
    expect(itemFor(tester, 'Two').dividerColor, Colors.transparent);

    await gesture.moveTo(Offset.zero);
    await tester.pump();

    expect(itemFor(tester, 'One').dividerColor, isNull);
    expect(itemFor(tester, 'Two').dividerColor, isNull);
  });

  testWidgets('the list is a bordered, clipped card', (tester) async {
    await pump(tester, [row('One')]);

    expect(
      find.ancestor(
        of: find.byType(DesignSystemListItem),
        matching: find.byType(ClipRRect),
      ),
      findsOneWidget,
    );
    expect(
      find.ancestor(
        of: find.byType(ClipRRect),
        matching: find.byType(DecoratedBox),
      ),
      findsAtLeastNWidgets(1),
    );
  });
}
