import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/settings/ui/pages/advanced/celebration_settings_page.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/widgets/settings/settings_switch_row.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../widget_test_utils.dart';

void main() {
  setUp(() async {
    final mocks = await setUpTestGetIt();
    when(
      () => mocks.settingsDb.saveSettingsItem(any(), any()),
    ).thenAnswer((_) async => 1);
  });
  tearDown(tearDownTestGetIt);

  List<SettingsSwitchRow> rows(WidgetTester tester) => tester
      .widgetList<SettingsSwitchRow>(find.byType(SettingsSwitchRow))
      .toList();

  Future<void> tapRow(WidgetTester tester, String title) => tester.tap(
    find.ancestor(of: find.text(title), matching: find.byType(InkWell)).first,
  );

  testWidgets('renders one switch per completion event, all on by default', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(const CelebrationSettingsBody()),
    );
    await tester.pump();

    final switches = rows(tester);
    expect(switches.length, 3);
    expect(switches.every((r) => r.value), isTrue);
  });

  testWidgets('toggling Tasks off updates the row and persists "false"', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(const CelebrationSettingsBody()),
    );
    await tester.pump();

    await tapRow(tester, 'Tasks');
    await tester.pump();

    final byTitle = {for (final r in rows(tester)) r.title: r.value};
    expect(byTitle['Tasks'], isFalse);
    // The other two are untouched.
    expect(byTitle['Habits'], isTrue);
    expect(byTitle['Checklist items'], isTrue);
    verify(
      () => getIt<SettingsDb>().saveSettingsItem('CELEBRATE_TASKS', 'false'),
    ).called(1);
  });

  testWidgets('each switch persists its own key', (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(const CelebrationSettingsBody()),
    );
    await tester.pump();

    await tapRow(tester, 'Habits');
    await tester.pump();
    await tapRow(tester, 'Checklist items');
    await tester.pump();

    verify(
      () => getIt<SettingsDb>().saveSettingsItem('CELEBRATE_HABITS', 'false'),
    ).called(1);
    verify(
      () => getIt<SettingsDb>().saveSettingsItem(
        'CELEBRATE_CHECKLIST_ITEMS',
        'false',
      ),
    ).called(1);
  });
}
