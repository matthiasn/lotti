import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/settings/ui/pages/advanced/celebration_settings_page.dart';
import 'package:lotti/features/settings/ui/widgets/celebration_preview_stage.dart';
import 'package:lotti/features/settings/ui/widgets/celebration_variant_picker.dart';
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

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      // The body is a Column meant to live inside a scroll host (the real page
      // wraps it in SliverBoxAdapterPage); give it one so it isn't height-capped.
      makeTestableWidgetWithScaffold(
        const SingleChildScrollView(child: CelebrationSettingsBody()),
      ),
    );
    await tester.pump();
  }

  List<SettingsSwitchRow> rows(WidgetTester tester) => tester
      .widgetList<SettingsSwitchRow>(find.byType(SettingsSwitchRow))
      .toList();

  Map<String, SettingsSwitchRow> byTitle(WidgetTester tester) => {
    for (final r in rows(tester)) r.title: r,
  };

  // The style section's surface selector reuses the same labels ("Tasks", …),
  // so scope the tap to the switch row's own text to stay unambiguous.
  Future<void> tapRow(WidgetTester tester, String title) => tester.tap(
    find
        .ancestor(
          of: find.descendant(
            of: find.byType(SettingsSwitchRow),
            matching: find.text(title),
          ),
          matching: find.byType(InkWell),
        )
        .first,
  );

  const masterTitle = 'Celebration animations';
  const hapticsTitle = 'Completion haptics';

  testWidgets('renders master, three event switches and a haptics switch', (
    tester,
  ) async {
    await pump(tester);

    final titles = byTitle(tester);
    expect(
      titles.keys,
      containsAll(<String>[
        masterTitle,
        'Habits',
        'Checklist items',
        'Tasks',
        hapticsTitle,
      ]),
    );
    // All five default on.
    expect(rows(tester).every((r) => r.value), isTrue);
  });

  testWidgets('renders the style picker and the preview stage', (tester) async {
    await pump(tester);
    expect(find.byType(CelebrationVariantPicker), findsOneWidget);
    expect(find.byType(CelebrationPreviewStage), findsOneWidget);
  });

  testWidgets(
    'event switches and the style/preview are enabled while the master is on',
    (tester) async {
      await pump(tester);

      final titles = byTitle(tester);
      expect(titles['Habits']!.enabled, isTrue);
      expect(titles['Checklist items']!.enabled, isTrue);
      expect(titles['Tasks']!.enabled, isTrue);
      expect(
        tester
            .widget<CelebrationVariantPicker>(
              find.byType(CelebrationVariantPicker),
            )
            .enabled,
        isTrue,
      );
      expect(
        tester
            .widget<CelebrationPreviewStage>(
              find.byType(CelebrationPreviewStage),
            )
            .enabled,
        isTrue,
      );
    },
  );

  testWidgets(
    'turning the master off persists it and greys the event switches + '
    'style/preview, but leaves haptics live',
    (tester) async {
      await pump(tester);

      await tapRow(tester, masterTitle);
      await tester.pump();

      final titles = byTitle(tester);
      expect(titles[masterTitle]!.value, isFalse);
      // The per-event switches keep their on value but go inert.
      expect(titles['Habits']!.enabled, isFalse);
      expect(titles['Checklist items']!.enabled, isFalse);
      expect(titles['Tasks']!.enabled, isFalse);
      expect(titles['Habits']!.value, isTrue);
      // Haptics is independent of the visual master — still interactive.
      expect(titles[hapticsTitle]!.enabled, isTrue);
      // Style + preview grey out.
      expect(
        tester
            .widget<CelebrationVariantPicker>(
              find.byType(CelebrationVariantPicker),
            )
            .enabled,
        isFalse,
      );
      expect(
        tester
            .widget<CelebrationPreviewStage>(
              find.byType(CelebrationPreviewStage),
            )
            .enabled,
        isFalse,
      );
      verify(
        () =>
            getIt<SettingsDb>().saveSettingsItem('CELEBRATE_ENABLED', 'false'),
      ).called(1);
    },
  );

  testWidgets('turning haptics off persists it without touching visuals', (
    tester,
  ) async {
    await pump(tester);

    await tapRow(tester, hapticsTitle);
    await tester.pump();

    final titles = byTitle(tester);
    expect(titles[hapticsTitle]!.value, isFalse);
    // The master + event switches are unaffected and stay interactive.
    expect(titles[masterTitle]!.value, isTrue);
    expect(titles['Tasks']!.enabled, isTrue);
    verify(
      () => getIt<SettingsDb>().saveSettingsItem('CELEBRATE_HAPTICS', 'false'),
    ).called(1);
  });

  testWidgets('toggling Tasks off updates the row and persists "false"', (
    tester,
  ) async {
    await pump(tester);

    await tapRow(tester, 'Tasks');
    await tester.pump();

    final titles = byTitle(tester);
    expect(titles['Tasks']!.value, isFalse);
    expect(titles['Habits']!.value, isTrue);
    expect(titles['Checklist items']!.value, isTrue);
    verify(
      () => getIt<SettingsDb>().saveSettingsItem('CELEBRATE_TASKS', 'false'),
    ).called(1);
  });

  testWidgets('each event switch persists its own key', (tester) async {
    await pump(tester);

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
