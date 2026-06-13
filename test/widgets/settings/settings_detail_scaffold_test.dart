import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/widgets/settings/settings_delete_row.dart';
import 'package:lotti/widgets/settings/settings_detail_scaffold.dart';
import 'package:lotti/widgets/settings/settings_form_action_bar.dart';

import '../../test_helper.dart';

void main() {
  Future<void> pumpScaffold(
    WidgetTester tester, {
    required SettingsDetailScaffold scaffold,
  }) async {
    await tester.pumpWidget(WidgetTestBench(child: scaffold));
    // The header's back affordance fades in over one second
    // (flutter_animate); advance past it so no timer outlives the test.
    await tester.pump(const Duration(milliseconds: 1100));
  }

  testWidgets('renders title, content, and the action bar', (tester) async {
    await pumpScaffold(
      tester,
      scaffold: SettingsDetailScaffold(
        title: 'Edit label',
        onBack: () {},
        actionBar: SettingsFormActionBar(
          primaryLabel: 'Save',
          onPrimary: () {},
        ),
        children: const [Text('form content')],
      ),
    );

    expect(find.text('Edit label'), findsOneWidget);
    expect(find.text('form content'), findsOneWidget);
    expect(find.byType(SettingsFormActionBar), findsOneWidget);

    // The inner page Scaffold extends its body behind the glass bar so
    // the backdrop blur has content to work with.
    final scaffolds = tester
        .widgetList<Scaffold>(find.byType(Scaffold))
        .toList();
    expect(scaffolds.any((s) => s.extendBody), isTrue);
  });

  testWidgets('back affordance invokes onBack', (tester) async {
    var backed = false;
    await pumpScaffold(
      tester,
      scaffold: SettingsDetailScaffold(
        title: 'Edit label',
        onBack: () => backed = true,
        children: const [SizedBox.shrink()],
      ),
    );

    await tester.tap(find.byIcon(Icons.chevron_left));
    expect(backed, isTrue);
  });

  testWidgets('Cmd+S and Ctrl+S trigger onSaveShortcut', (tester) async {
    var saves = 0;
    await pumpScaffold(
      tester,
      scaffold: SettingsDetailScaffold(
        title: 'Edit label',
        onBack: () {},
        onSaveShortcut: () => saves++,
        children: const [
          // Shortcut dispatch needs a focused descendant.
          Focus(autofocus: true, child: SizedBox.shrink()),
        ],
      ),
    );
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    expect(saves, 1);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(saves, 2);
  });

  testWidgets('renders custom slivers when provided', (tester) async {
    await pumpScaffold(
      tester,
      scaffold: SettingsDetailScaffold(
        title: 'Dashboard',
        onBack: () {},
        slivers: const [
          SliverToBoxAdapter(child: Text('sliver content')),
        ],
      ),
    );

    expect(find.text('sliver content'), findsOneWidget);
  });

  test('asserts exactly one of children or slivers', () {
    expect(
      () => SettingsDetailScaffold(
        title: 'x',
        onBack: () {},
        slivers: const [],
        children: const [],
      ),
      throwsAssertionError,
    );
    expect(
      () => SettingsDetailScaffold(title: 'x', onBack: () {}),
      throwsAssertionError,
    );
  });
  testWidgets('renders the delete row after the form content', (
    tester,
  ) async {
    var deleted = false;
    await pumpScaffold(
      tester,
      scaffold: SettingsDetailScaffold(
        title: 'Edit label',
        onBack: () {},
        deleteLabel: 'Delete',
        onDelete: () => deleted = true,
        children: const [Text('form content')],
      ),
    );

    final row = find.byType(SettingsDeleteRow);
    expect(row, findsOneWidget);
    // Below the form content, at the end of the scroll body.
    expect(
      tester.getTopLeft(row).dy,
      greaterThan(tester.getTopLeft(find.text('form content')).dy),
    );

    await tester.tap(find.text('Delete'));
    expect(deleted, isTrue);
  });
}
