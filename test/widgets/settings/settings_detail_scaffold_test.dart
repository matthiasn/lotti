import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/keyboard/domain/app_command.dart';
import 'package:lotti/features/keyboard/domain/app_command_handler.dart';
import 'package:lotti/features/keyboard/ui/app_command_controller.dart';
import 'package:lotti/features/keyboard/ui/app_command_host.dart';
import 'package:lotti/widgets/settings/settings_delete_row.dart';
import 'package:lotti/widgets/settings/settings_detail_scaffold.dart';
import 'package:lotti/widgets/settings/settings_form_action_bar.dart';

import '../../test_helper.dart';

void main() {
  Future<void> pumpScaffold(
    WidgetTester tester, {
    required SettingsDetailScaffold scaffold,
    TargetPlatform platform = TargetPlatform.windows,
  }) async {
    await tester.pumpWidget(
      WidgetTestBench(
        child: AppCommandHost(
          handlers: const <AppCommandId, AppCommandHandler>{},
          platform: platform,
          child: scaffold,
        ),
      ),
    );
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

  for (final (platform, primaryKey) in [
    (TargetPlatform.windows, LogicalKeyboardKey.control),
    (TargetPlatform.macOS, LogicalKeyboardKey.meta),
  ]) {
    testWidgets('Primary+S invokes scoped save on ${platform.name}', (
      tester,
    ) async {
      var saves = 0;
      await pumpScaffold(
        tester,
        platform: platform,
        scaffold: SettingsDetailScaffold(
          title: 'Edit label',
          onBack: () {},
          onSaveShortcut: () => saves++,
          children: const [
            Focus(autofocus: true, child: SizedBox.shrink()),
          ],
        ),
      );
      await tester.pump();

      final focusedContext = FocusManager.instance.primaryFocus!.context!;
      final controller = AppCommandControllerProvider.of(focusedContext);
      expect(
        controller.isAvailable(focusedContext, AppCommandId.save),
        isTrue,
      );

      await tester.sendKeyDownEvent(primaryKey);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      await tester.sendKeyUpEvent(primaryKey);
      expect(saves, 1);
    });
  }

  testWidgets('live save availability controls Primary+S', (
    tester,
  ) async {
    var saves = 0;
    var saveEnabled = false;
    await pumpScaffold(
      tester,
      scaffold: SettingsDetailScaffold(
        title: 'Edit label',
        onBack: () {},
        onSaveShortcut: () => saves++,
        saveShortcutEnabled: () => saveEnabled,
        children: const [
          Focus(autofocus: true, child: SizedBox.shrink()),
        ],
      ),
    );
    await tester.pump();

    final focusedContext = FocusManager.instance.primaryFocus!.context!;
    final controller = AppCommandControllerProvider.of(focusedContext);
    expect(controller.isAvailable(focusedContext, AppCommandId.save), isFalse);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    expect(saves, 0);

    saveEnabled = true;
    expect(controller.isAvailable(focusedContext, AppCommandId.save), isTrue);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    expect(saves, 1);
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
