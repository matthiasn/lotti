import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings/ui/pages/outbox/sync_queue_counts.dart';
import 'package:lotti/features/sync/state/outbox_state_controller.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/widgets/misc/contact_support_row.dart';
import 'package:lotti/widgets/nav_bar/mobile_nav_more_sheet.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

import '../../mocks/mocks.dart';
import '../../mocks/sync_config_test_mocks.dart';
import '../../widget_test_utils.dart';

void main() {
  Future<void> pumpAndOpenSheet(
    WidgetTester tester, {
    required List<MobileNavMoreSheetItem> items,
    List<Override> overrides = const [],
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showMobileNavMoreSheet(
              context: context,
              items: items,
            ),
            child: const Text('open'),
          ),
        ),
        theme: DesignSystemTheme.light(),
        overrides: overrides,
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  group('showMobileNavMoreSheet', () {
    testWidgets('lists every overflow destination with icon and label', (
      tester,
    ) async {
      await pumpAndOpenSheet(
        tester,
        items: [
          MobileNavMoreSheetItem(
            label: 'Projects',
            icon: const Icon(Icons.folder_outlined),
            onSelected: () {},
          ),
          MobileNavMoreSheetItem(
            label: 'Habits',
            icon: const Icon(Icons.checklist_outlined),
            onSelected: () {},
          ),
        ],
      );

      expect(find.text('Projects'), findsOneWidget);
      expect(find.byIcon(Icons.folder_outlined), findsOneWidget);
      expect(find.text('Habits'), findsOneWidget);
      expect(find.byIcon(Icons.checklist_outlined), findsOneWidget);
    });

    testWidgets('selecting a row dismisses the sheet, then navigates', (
      tester,
    ) async {
      final selections = <String>[];
      await pumpAndOpenSheet(
        tester,
        items: [
          MobileNavMoreSheetItem(
            label: 'Projects',
            icon: const Icon(Icons.folder_outlined),
            onSelected: () => selections.add('projects'),
          ),
          MobileNavMoreSheetItem(
            label: 'Habits',
            icon: const Icon(Icons.checklist_outlined),
            onSelected: () => selections.add('habits'),
          ),
        ],
      );

      await tester.tap(find.text('Habits'));
      await tester.pumpAndSettle();

      expect(selections, ['habits']);
      expect(find.byType(WoltModalSheet), findsNothing);
    });

    testWidgets('renders the trailing widget between label and chevron', (
      tester,
    ) async {
      await pumpAndOpenSheet(
        tester,
        items: [
          MobileNavMoreSheetItem(
            label: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            trailing: const Text('42', key: Key('trailing-badge')),
            onSelected: () {},
          ),
          MobileNavMoreSheetItem(
            label: 'Habits',
            icon: const Icon(Icons.checklist_outlined),
            onSelected: () {},
          ),
        ],
      );

      // The trailing widget sits right of the label and left of the
      // row's chevron — the desktop sidebar's trailing-slot contract.
      final badgeRect = tester.getRect(find.byKey(const Key('trailing-badge')));
      final labelRect = tester.getRect(find.text('Settings'));
      final chevronRect = tester.getRect(
        find
            .descendant(
              of: find.ancestor(
                of: find.text('Settings'),
                matching: find.byType(InkWell),
              ),
              matching: find.byIcon(Icons.chevron_right_rounded),
            )
            .first,
      );
      expect(badgeRect.left, greaterThan(labelRect.left));
      expect(badgeRect.right, lessThan(chevronRect.left));

      // Rows without a trailing widget render nothing extra.
      expect(find.byKey(const Key('trailing-badge')), findsOneWidget);
    });

    testWidgets('gives each row room to breathe, not just a tap target', (
      tester,
    ) async {
      await pumpAndOpenSheet(
        tester,
        items: [
          for (final label in ['Projects', 'Habits', 'Calendar'])
            MobileNavMoreSheetItem(
              label: label,
              icon: const Icon(Icons.folder_outlined),
              onSelected: () {},
            ),
        ],
      );

      // The rows sit flush against each other with no separators, so their own
      // height is the only thing keeping the labels from stacking up. A row
      // sized to the bare 44px tap target reads as a cramped list.
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
        expect(height, greaterThanOrEqualTo(52));
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
          MobileNavMoreSheetItem(
            label: 'Projects',
            icon: const Icon(Icons.folder_outlined),
            active: true,
            onSelected: () {},
          ),
          MobileNavMoreSheetItem(
            label: 'Habits',
            icon: const Icon(Icons.checklist_outlined),
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
        tester.element(find.byIcon(Icons.folder_outlined)),
      );
      expect(activeIcon.color, dsTokensLight.colors.interactive.enabled);
    });
  });

  group('showMobileNavMoreSheet contact footer', () {
    testWidgets('closes the sheet with the Contact Us footer', (tester) async {
      await pumpAndOpenSheet(
        tester,
        items: [
          MobileNavMoreSheetItem(
            label: 'Projects',
            icon: const Icon(Icons.folder_outlined),
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
            MobileNavMoreSheetItem(
              label: label,
              icon: const Icon(Icons.folder_outlined),
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
          MobileNavMoreSheetItem(
            label: 'Projects',
            icon: const Icon(Icons.folder_outlined),
            onSelected: () {},
          ),
        ],
      );

      // Destination rows carry a chevron; nothing in the footer navigates
      // within the app, so no row down there may imply that it does.
      expect(
        find.descendant(
          of: find.byType(ContactSupportRow),
          matching: find.byIcon(Icons.chevron_right_rounded),
        ),
        findsNothing,
      );
    });

    testWidgets('lays out a real sync-count trailing widget in a sheet row', (
      tester,
    ) async {
      // `_MoreSheetRow` renders `item.trailing` as an *inflexible* child of
      // its Row, which hands it unbounded horizontal constraints — while
      // `SyncQueueCounts` lays its two counts out with `Flexible`. This
      // pins the combination end to end with the real widget rather than a
      // stand-in, because a stand-in is exactly what would not catch it.
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
          MobileNavMoreSheetItem(
            label: 'Settings',
            icon: const Icon(Icons.settings_rounded),
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
