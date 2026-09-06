import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings/ui/pages/outbox/sync_queue_counts.dart';
import 'package:lotti/features/sync/state/outbox_state_controller.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/widgets/misc/contact_support_row.dart';
import 'package:lotti/widgets/nav_bar/mobile_nav_sheet.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

import '../../mocks/mocks.dart';
import '../../mocks/sync_config_test_mocks.dart';
import '../../widget_test_utils.dart';

void main() {
  Future<void> pumpAndOpenSheet(
    WidgetTester tester, {
    required List<MobileNavSheetItem> items,
    List<Override> overrides = const [],
    MediaQueryData? mediaQueryData,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showMobileNavSheet(
              context: context,
              items: items,
            ),
            child: const Text('open'),
          ),
        ),
        theme: DesignSystemTheme.light(),
        overrides: overrides,
        mediaQueryData: mediaQueryData,
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('arranges destinations in two columns in reading order', (
    tester,
  ) async {
    await pumpAndOpenSheet(
      tester,
      items: [
        for (final label in [
          'Tasks',
          'DailyOS',
          'Projects',
          'Goals',
          'Settings',
        ])
          MobileNavSheetItem(
            label: label,
            icon: const Icon(LottiIcons.folder),
            onSelected: () {},
          ),
      ],
    );
    final tasks = tester.getRect(find.text('Tasks'));
    final daily = tester.getRect(find.text('DailyOS'));
    final projects = tester.getRect(find.text('Projects'));
    final goals = tester.getRect(find.text('Goals'));
    expect(tasks.top, daily.top);
    expect(tasks.left, lessThan(daily.left));
    expect(projects.top, goals.top);
    expect(projects.top, greaterThan(tasks.bottom));
    expect(projects.left, tasks.left);
    expect(tester.getRect(find.text('Settings')).left, tasks.left);
  });

  testWidgets(
    'large text keeps two columns and scrolls to the final destination',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final selected = <String>[];
      await pumpAndOpenSheet(
        tester,
        mediaQueryData: const MediaQueryData(
          size: Size(320, 640),
          textScaler: TextScaler.linear(2),
        ),
        items: [
          for (final label in [
            'Tasks',
            'DailyOS',
            'Projects',
            'Goals',
            'Habits',
            'Insights',
            'People',
            'Logbook',
            'Events',
            'Settings',
          ])
            MobileNavSheetItem(
              label: label,
              icon: const Icon(LottiIcons.folder),
              onSelected: () => selected.add(label),
            ),
        ],
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getRect(find.text('Tasks')).left,
        lessThan(tester.getRect(find.text('DailyOS')).left),
      );
      await tester.ensureVisible(find.text('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(selected, ['Settings']);
      expect(find.byType(WoltModalSheet), findsNothing);
    },
  );

  group('showMobileNavSheet', () {
    testWidgets('lists every destination with icon and label', (
      tester,
    ) async {
      await pumpAndOpenSheet(
        tester,
        items: [
          MobileNavSheetItem(
            label: 'Projects',
            icon: const Icon(LottiIcons.folder),
            onSelected: () {},
          ),
          MobileNavSheetItem(
            label: 'Habits',
            icon: const Icon(LottiIcons.checkAll),
            onSelected: () {},
          ),
        ],
      );

      expect(find.text('Projects'), findsOneWidget);
      expect(find.byIcon(LottiIcons.folder), findsOneWidget);
      expect(find.text('Habits'), findsOneWidget);
      expect(find.byIcon(LottiIcons.checkAll), findsOneWidget);
    });

    testWidgets('selecting a tile dismisses the sheet, then navigates', (
      tester,
    ) async {
      final selections = <String>[];
      await pumpAndOpenSheet(
        tester,
        items: [
          MobileNavSheetItem(
            label: 'Projects',
            icon: const Icon(LottiIcons.folder),
            onSelected: () => selections.add('projects'),
          ),
          MobileNavSheetItem(
            label: 'Habits',
            icon: const Icon(LottiIcons.checkAll),
            onSelected: () => selections.add('habits'),
          ),
        ],
      );

      await tester.tap(find.text('Habits'));
      await tester.pumpAndSettle();

      expect(selections, ['habits']);
      expect(find.byType(WoltModalSheet), findsNothing);
    });

    testWidgets('keeps a trailing count below the label within its tile', (
      tester,
    ) async {
      await pumpAndOpenSheet(
        tester,
        items: [
          MobileNavSheetItem(
            label: 'Settings',
            icon: const Icon(LottiIcons.settings),
            trailing: const Text('42', key: Key('trailing-badge')),
            onSelected: () {},
          ),
          MobileNavSheetItem(
            label: 'Habits',
            icon: const Icon(LottiIcons.checkAll),
            onSelected: () {},
          ),
        ],
      );
      final badge = tester.getRect(find.byKey(const Key('trailing-badge')));
      final label = tester.getRect(find.text('Settings'));
      expect(badge.top, greaterThanOrEqualTo(label.bottom));
      expect(badge.left, label.left);
      expect(badge.right, lessThan(tester.getRect(find.text('Habits')).left));
    });

    testWidgets('gives each row room to breathe, not just a tap target', (
      tester,
    ) async {
      await pumpAndOpenSheet(
        tester,
        items: [
          for (final label in ['Projects', 'Habits', 'Calendar'])
            MobileNavSheetItem(
              label: label,
              icon: const Icon(LottiIcons.folder),
              onSelected: () {},
            ),
        ],
      );

      // Grid cells retain the mobile touch-target floor and equal row heights.
      final heights = [
        for (final label in ['Projects', 'Habits', 'Calendar'])
          tester
              .getSize(
                find
                    .ancestor(
                      of: find.text(label),
                      matching: find.byType(InkWell),
                    )
                    .first,
              )
              .height,
      ];
      for (final height in heights) {
        expect(height, greaterThanOrEqualTo(TapTargets.minimum));
      }
      // And every row is the same height, so the list keeps an even rhythm.
      expect(heights.toSet(), hasLength(1));
    });

    testWidgets('highlights the active destination with the accent tint', (
      tester,
    ) async {
      await pumpAndOpenSheet(
        tester,
        items: [
          MobileNavSheetItem(
            label: 'Projects',
            icon: const Icon(LottiIcons.folder),
            active: true,
            onSelected: () {},
          ),
          MobileNavSheetItem(
            label: 'Habits',
            icon: const Icon(LottiIcons.checkAll),
            onSelected: () {},
          ),
        ],
      );

      final activeLabel = tester.widget<Text>(find.text('Projects'));
      final inactiveLabel = tester.widget<Text>(find.text('Habits'));
      expect(
        activeLabel.style!.color,
        dsTokensLight.colors.interactive.enabled,
      );
      expect(
        inactiveLabel.style!.color,
        dsTokensLight.colors.text.highEmphasis,
      );

      final activeIcon = IconTheme.of(
        tester.element(find.byIcon(LottiIcons.folder)),
      );
      expect(activeIcon.color, dsTokensLight.colors.interactive.enabled);
    });
  });

  group('showMobileNavSheet contact footer', () {
    testWidgets('closes the sheet with the Contact Us footer', (tester) async {
      await pumpAndOpenSheet(
        tester,
        items: [
          MobileNavSheetItem(
            label: 'Projects',
            icon: const Icon(LottiIcons.folder),
            onSelected: () {},
          ),
        ],
      );

      expect(find.byType(ContactSupportRow), findsOneWidget);
    });

    testWidgets('places the footer below every destination row', (
      tester,
    ) async {
      await pumpAndOpenSheet(
        tester,
        items: [
          for (final label in ['Projects', 'Habits', 'Calendar'])
            MobileNavSheetItem(
              label: label,
              icon: const Icon(LottiIcons.folder),
              onSelected: () {},
            ),
        ],
      );

      // Mobile has no persistent chrome to pin the footer to, so the sheet is
      // where it lands — but below the destinations, never among them.
      final footerTop = tester.getRect(find.byType(ContactSupportRow)).top;
      for (final label in ['Projects', 'Habits', 'Calendar']) {
        expect(
          tester.getRect(find.text(label)).bottom,
          lessThanOrEqualTo(footerTop),
        );
      }
    });

    testWidgets('keeps the footer out of the destination rows', (tester) async {
      await pumpAndOpenSheet(
        tester,
        items: [
          MobileNavSheetItem(
            label: 'Projects',
            icon: const Icon(LottiIcons.folder),
            onSelected: () {},
          ),
        ],
      );

      // Support actions remain separate from the destination tiles.
      expect(
        find.descendant(
          of: find.byType(ContactSupportRow),
          matching: find.byIcon(LottiIcons.chevronRight),
        ),
        findsNothing,
      );
    });

    testWidgets('lays out a real sync-count trailing widget in a sheet row', (
      tester,
    ) async {
      // Exercise real compact sync counts inside the tile's bounded label
      // column, including a large inbound backlog.
      await pumpAndOpenSheet(
        tester,
        overrides: [
          journalDbProvider.overrideWithValue(
            mockJournalDbWithSyncFlag(enabled: true),
          ),
          syncDatabaseProvider.overrideWithValue(mockSyncDatabaseWithCount(12)),
          inboundQueueDepthProvider.overrideWith(
            (_) => Stream<int>.value(18342),
          ),
        ],
        items: [
          MobileNavSheetItem(
            label: 'Settings',
            icon: const Icon(LottiIcons.settings),
            trailing: const SyncQueueCounts(),
            onSelected: () {},
          ),
        ],
      );

      expect(tester.takeException(), isNull);
      // The gap is a narrow no-break space (U+202F), not a word space — see
      // `syncQueueArrowGap`.
      expect(find.text('↓\u202F18K'), findsOneWidget);
      expect(find.text('↑\u202F12'), findsOneWidget);
    });
  });
}
