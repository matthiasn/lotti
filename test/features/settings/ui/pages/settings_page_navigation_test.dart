import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/settings/ui/pages/settings_page.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/features/whats_new/state/whats_new_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';
import 'settings_page_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsPage divider coordination', () {
    late DesktopSettingsBench bench;

    setUp(() async {
      bench = await DesktopSettingsBench.create();
    });

    tearDown(() async {
      await bench.dispose();
    });

    List<DesignSystemListItem> readRows(WidgetTester tester) => tester
        .widgetList<DesignSystemListItem>(
          find.byType(DesignSystemListItem),
        )
        .toList();

    testWidgets(
      'with no route active and nothing hovered, the divider between two '
      'idle rows is drawn in the decorative colour (not suppressed)',
      (tester) async {
        await bench.pumpPage(tester);

        final rows = readRows(tester);
        expect(rows.length, greaterThanOrEqualTo(2));

        // Layout is stable: every row except the last still reserves
        // `showDivider: true`. Colour is what toggles to hide the line
        // between interacting rows — when all rows are idle, no override
        // is applied so the divider uses its default colour.
        for (var i = 0; i < rows.length; i++) {
          final shouldShow = i < rows.length - 1;
          expect(
            rows[i].showDivider,
            shouldShow,
            reason: 'row $i showDivider should be $shouldShow',
          );
          expect(
            rows[i].dividerColor,
            isNull,
            reason: 'idle row $i should not override divider colour',
          );
        }
      },
    );

    testWidgets(
      'activating a row paints the dividers on both sides transparent so '
      'the row is not bisected by a partial-width line, without shifting '
      'layout',
      (tester) async {
        // Activate the AI route — that row should be flagged activated,
        // and its neighbours should mask their touching dividers.
        bench.navService.desktopSelectedSettingsRoute.value = (
          path: '/settings/ai',
          pathParameters: <String, String>{},
          queryParameters: <String, String>{},
        );
        await bench.pumpPage(tester);

        final rows = readRows(tester);
        final activatedIndex = rows.indexWhere((r) => r.activated);
        expect(
          activatedIndex,
          greaterThanOrEqualTo(0),
          reason: 'Expected an activated row for /settings/ai',
        );

        // The activated row still reserves its divider space; the colour
        // is made transparent so the line visually disappears.
        expect(rows[activatedIndex].showDivider, isTrue);
        expect(rows[activatedIndex].dividerColor, Colors.transparent);

        // The row *above* the activated one also paints its divider
        // transparent — it sits between two rows where one is interacting.
        if (activatedIndex > 0) {
          expect(rows[activatedIndex - 1].showDivider, isTrue);
          expect(
            rows[activatedIndex - 1].dividerColor,
            Colors.transparent,
          );
        }
      },
    );

    testWidgets(
      'activated row also sets selected: true so screen readers announce '
      'the active settings route as the selected list item',
      (tester) async {
        bench.navService.desktopSelectedSettingsRoute.value = (
          path: '/settings/ai',
          pathParameters: <String, String>{},
          queryParameters: <String, String>{},
        );
        await bench.pumpPage(tester);

        final rows = readRows(tester);
        final activated = rows.where((r) => r.activated).toList();
        expect(activated, hasLength(1));
        expect(activated.single.selected, isTrue);

        // Every other row must not claim to be selected.
        for (final row in rows.where((r) => !r.activated)) {
          expect(row.selected, isFalse);
        }
      },
    );

    testWidgets(
      'hovering a row paints the dividers on both sides transparent',
      (tester) async {
        await bench.pumpPage(tester);

        final rows = readRows(tester);
        // Target a middle row so we can inspect both neighbours.
        final targetIndex = rows.length ~/ 2;
        final rowFinder = find.byType(DesignSystemListItem).at(targetIndex);

        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        addTearDown(gesture.removePointer);
        await gesture.addPointer(location: Offset.zero);
        await gesture.moveTo(tester.getCenter(rowFinder));
        await tester.pumpAndSettle();

        final hoveredRows = readRows(tester);

        // Row itself masks its own bottom divider (if there is one).
        if (targetIndex < hoveredRows.length - 1) {
          expect(
            hoveredRows[targetIndex].dividerColor,
            Colors.transparent,
          );
        }
        // Row above also masks its bottom divider because its next
        // neighbour (the hovered one) is interacting.
        if (targetIndex > 0) {
          expect(
            hoveredRows[targetIndex - 1].dividerColor,
            Colors.transparent,
          );
        }
      },
    );

    testWidgets(
      'moving pointer off a hovered row restores default divider colour '
      '(lines 261-262: onHoverChanged false branch)',
      (tester) async {
        await bench.pumpPage(tester);

        final rows = readRows(tester);
        // Pick a middle row that has at least one neighbour above.
        final targetIndex = (rows.length ~/ 2).clamp(1, rows.length - 1);
        final rowFinder = find.byType(DesignSystemListItem).at(targetIndex);

        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        addTearDown(gesture.removePointer);
        await gesture.addPointer(location: Offset.zero);

        // Enter hover.
        await gesture.moveTo(tester.getCenter(rowFinder));
        await tester.pumpAndSettle();

        // Confirm divider is suppressed while hovered.
        if (targetIndex < readRows(tester).length - 1) {
          expect(
            readRows(tester)[targetIndex].dividerColor,
            Colors.transparent,
          );
        }

        // Exit hover by moving far away from any row.
        await gesture.moveTo(Offset.zero);
        await tester.pumpAndSettle();

        // After hover leaves, the divider colour must return to null (not
        // suppressed) — confirming _hoveredId was cleared.
        final afterRows = readRows(tester);
        for (final row in afterRows) {
          expect(
            row.dividerColor,
            isNull,
            reason:
                'All rows should have null dividerColor after hover exits; '
                'found ${row.dividerColor}',
          );
        }
      },
    );
  });

  group('SettingsPage _SettingsListCard.didUpdateWidget', () {
    // When the items list changes (e.g. a feature flag toggled) and the
    // previously-hovered item is no longer present, didUpdateWidget must
    // clear _hoveredId so stale suppression cannot bleed through.
    // Lines 206-207 in the source.

    testWidgets(
      'clears _hoveredId when hovered item is removed from the list by a '
      'flag toggle (lines 206-207)',
      (tester) async {
        // Use StreamControllers so we can push subsequent values after the
        // widget is already on screen, triggering didUpdateWidget.
        //
        // SettingsPage reads enableMatrixFlag via configFlagProvider which
        // calls db.watchConfigFlag(enableMatrixFlag) — so we need a
        // controller for that flag specifically.
        final matrixFlagController = StreamController<bool>.broadcast();
        addTearDown(matrixFlagController.close);

        await getIt.reset();

        final mockDb = MockJournalDb();
        final mockSettingsDb = MockSettingsDb();

        when(mockDb.getJournalCount).thenAnswer((_) async => 0);
        // watchConfigFlags is called for UserActivity / other services;
        // return an empty set to avoid interference.
        when(mockDb.watchConfigFlags).thenAnswer(
          (_) => Stream<Set<ConfigFlag>>.fromIterable([<ConfigFlag>{}]),
        );
        // All flags return false by default.
        when(
          () => mockDb.watchConfigFlag(any()),
        ).thenAnswer((_) => Stream.value(false));
        // Override for the matrix flag specifically — this must be registered
        // AFTER the any() stub so mocktail's last-registered-wins order applies.
        when(
          () => mockDb.watchConfigFlag(enableMatrixFlag),
        ).thenAnswer((_) => matrixFlagController.stream);
        when(
          () => mockSettingsDb.itemByKey(any()),
        ).thenAnswer((_) async => null);
        when(
          () => mockSettingsDb.itemsByKeys(any()),
        ).thenAnswer((_) async => <String, String?>{});
        when(
          () => mockSettingsDb.saveSettingsItem(any(), any()),
        ).thenAnswer((_) async => 1);

        final navService = NavService(
          journalDb: mockDb,
          settingsDb: mockSettingsDb,
        )..isDesktopMode = true;

        getIt
          ..registerSingleton<JournalDb>(mockDb)
          ..registerSingleton<NavService>(navService)
          ..registerSingleton<UserActivityService>(UserActivityService());

        ensureThemingServicesRegistered();

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            const SettingsPage(),
            theme: DesignSystemTheme.light(),
            mediaQueryData: const MediaQueryData(size: Size(1200, 900)),
            overrides: [
              journalDbProvider.overrideWithValue(mockDb),
              whatsNewControllerProvider.overrideWith(
                TestWhatsNewController.new,
              ),
            ],
          ),
        );
        // Let the widget build its first frame so Riverpod subscribes to
        // the stream, then emit Matrix ON → Sync row appears.
        await tester.pump();
        matrixFlagController.add(true);
        await tester.pumpAndSettle();

        // Find and hover the Sync row.
        final syncFinder = find.text('Sync Settings');
        expect(syncFinder, findsOneWidget);
        final rowFinder = find.ancestor(
          of: syncFinder,
          matching: find.byType(DesignSystemListItem),
        );

        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        addTearDown(gesture.removePointer);
        await gesture.addPointer(location: Offset.zero);
        await gesture.moveTo(tester.getCenter(rowFinder));
        await tester.pumpAndSettle();

        // Confirm hover suppression is active: the Sync row's divider should
        // be transparent (it has at least one neighbour below or above).
        final rowsWhileHovered = tester
            .widgetList<DesignSystemListItem>(find.byType(DesignSystemListItem))
            .toList();
        final syncIndex = rowsWhileHovered.indexWhere(
          (r) => r.dividerColor == Colors.transparent,
        );
        expect(
          syncIndex,
          greaterThanOrEqualTo(0),
          reason: 'Hovered Sync row should suppress a divider',
        );

        // Keep the pointer HOVERED on the Sync row and trigger the flag change.
        // didUpdateWidget clears _hoveredId when the Sync row disappears from
        // the list. Moving the mouse away before the update would allow the
        // onHoverChanged(false) callback to clear _hoveredId — making the test
        // pass even if didUpdateWidget never ran.
        matrixFlagController.add(false);
        // Pump one frame so the widget rebuilds (didUpdateWidget runs) while
        // the pointer is still physically over the old Sync-row position.
        await tester.pump();
        // Now move the pointer away so any stray hover-enter on the widget that
        // slid into the Sync row's old position is resolved before we assert.
        await gesture.moveTo(const Offset(5000, 5000));
        await tester.pumpAndSettle();

        // Sync row is gone.
        expect(find.text('Sync Settings'), findsNothing);

        // No row should have a suppressed divider now that hover state was
        // cleared by didUpdateWidget.
        final rowsAfter = tester
            .widgetList<DesignSystemListItem>(find.byType(DesignSystemListItem))
            .toList();
        for (final row in rowsAfter) {
          expect(
            row.dividerColor,
            isNull,
            reason:
                'After the hovered item is removed, no divider should be '
                'suppressed; found ${row.dividerColor}',
          );
        }

        await getIt.reset();
      },
    );
  });

  group('SettingsPage desktop layout', () {
    late DesktopSettingsBench bench;

    setUp(() async {
      bench = await DesktopSettingsBench.create();
    });

    tearDown(() async {
      await bench.dispose();
    });

    testWidgets('uses ValueListenableBuilder on desktop layout', (
      tester,
    ) async {
      bench.navService.desktopSelectedSettingsRoute.value = (
        path: '/settings/ai',
        pathParameters: <String, String>{},
        queryParameters: <String, String>{},
      );
      await bench.pumpPage(tester);

      // The list items should render on desktop
      expect(find.byType(DesignSystemListItem), findsWidgets);
    });
  });
}
