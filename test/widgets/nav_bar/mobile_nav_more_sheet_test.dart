import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/widgets/nav_bar/mobile_nav_more_sheet.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

import '../../widget_test_utils.dart';

void main() {
  Future<void> pumpAndOpenSheet(
    WidgetTester tester, {
    required List<MobileNavMoreSheetItem> items,
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
}
