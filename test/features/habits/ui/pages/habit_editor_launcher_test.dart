import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/habits/state/habit_editor_providers.dart';
import 'package:lotti/features/habits/ui/pages/habit_editor_launcher.dart';
import 'package:lotti/features/habits/ui/pages/habit_editor_page.dart';
import 'package:lotti/features/settings/ui/pages/measurables/measurables_page.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../test_data/test_data.dart';
import '../../../../widget_test_utils.dart';

void main() {
  setUpAll(() => registerFallbackValue(FakeHabitDefinition()));
  late TestGetItMocks mocks;
  String? beamedTo;

  setUp(() async {
    final cache = MockEntitiesCacheService();
    final persistence = MockPersistenceLogic();
    final notifications = MockNotificationService();
    mocks = await setUpTestGetIt(
      additionalSetup: () {
        getIt
          ..registerSingleton<PersistenceLogic>(persistence)
          ..registerSingleton<EntitiesCacheService>(cache)
          ..registerSingleton<NotificationService>(notifications);
      },
    );
    when(
      () => persistence.upsertEntityDefinition(any()),
    ).thenAnswer((_) async => 1);
    when(
      () => notifications.scheduleHabitNotification(any()),
    ).thenAnswer((_) async {});
    when(
      () => mocks.journalDb.getHabitById(habitFlossing.id),
    ).thenAnswer((_) async => habitFlossing);
    when(() => cache.sortedCategories).thenReturn([categoryMindfulness]);
    when(() => cache.getCategoryById(any())).thenReturn(null);
    beamedTo = null;
    beamToNamedOverride = (path) => beamedTo = path;
  });
  tearDown(() async {
    beamToNamedOverride = null;
    await tearDownTestGetIt();
  });

  Future<void> pumpLauncher(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Builder(
          builder: (context) => Column(
            children: [
              TextButton(
                key: const ValueKey('open-edit'),
                onPressed: () =>
                    openHabitEditor(context, habitId: habitFlossing.id),
                child: const Text('edit'),
              ),
              TextButton(
                key: const ValueKey('open-create'),
                onPressed: () => openHabitEditor(context),
                child: const Text('create'),
              ),
            ],
          ),
        ),
        mediaQueryData: MediaQueryData(size: size),
        overrides: [
          measurableDataTypesStreamProvider.overrideWith(
            (ref) => Stream.value(const []),
          ),
          workoutTypesProvider.overrideWith((ref) async => const []),
        ],
      ),
    );
  }

  group('on a phone', () {
    testWidgets('the editor is its own route', (tester) async {
      await pumpLauncher(tester, const Size(390, 844));
      await tester.tap(find.byKey(const ValueKey('open-edit')));
      expect(beamedTo, '/habits/edit/${habitFlossing.id}');
      await tester.tap(find.byKey(const ValueKey('open-create')));
      expect(beamedTo, '/habits/create');
      expect(find.byType(HabitEditorPage), findsNothing);
    });
  });

  group('on desktop', () {
    testWidgets('the editor opens embedded in a side panel over the page, '
        'and Save closes it', (tester) async {
      await pumpLauncher(tester, const Size(1400, 900));
      await tester.tap(find.byKey(const ValueKey('open-edit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(beamedTo, isNull, reason: 'no navigation on desktop');
      // A scrim over the page, and the editor inside a sheet on top of it.
      expect(find.byType(ModalBarrier), findsWidgets);
      final page = tester.widget<HabitEditorPage>(find.byType(HabitEditorPage));
      expect(page.embedded, isTrue);
      expect(find.text('Edit habit'), findsOneWidget);
      // No scaffold chrome of its own inside the panel.
      expect(
        find.descendant(
          of: find.byType(HabitEditorPage),
          matching: find.byType(AppBar),
        ),
        findsNothing,
      );
      // Two phone-width columns fit the 800px panel.
      expect(
        find.byKey(const ValueKey('habit-editor-columns')),
        findsOneWidget,
      );
      final panelWidth = tester.getSize(find.byType(HabitEditorPage)).width;
      expect(panelWidth, lessThanOrEqualTo(kHabitEditorPanelWidth));
      expect(panelWidth, greaterThan(560));

      // Save is pinned at the panel's foot: reachable without scrolling
      // even on a window shorter than the form.
      final primary = find.byKey(const ValueKey('habit-editor-primary'));
      expect(
        tester.getRect(primary).bottom,
        lessThanOrEqualTo(tester.view.physicalSize.height),
      );
      await tester.tap(primary);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(HabitEditorPage), findsNothing);
      expect(beamedTo, isNull);
    });

    testWidgets('the create wizard steps inside the panel and offers Back', (
      tester,
    ) async {
      await pumpLauncher(tester, const Size(1400, 900));
      await tester.tap(find.byKey(const ValueKey('open-create')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('New habit'), findsOneWidget);
      expect(find.byKey(const ValueKey('habit-editor-columns')), findsNothing);
      await tester.enterText(find.byType(TextField).first, 'Floss');
      await tester.tap(find.text('Continue'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.byKey(const ValueKey('habit-editor-columns')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('habit-editor-back')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('habit-editor-columns')), findsNothing);
      expect(find.text('Step 1 of 2'), findsOneWidget);
    });
    testWidgets('opened from inside a nested navigator, the panel still '
        'covers the window and closes without popping the tab', (
      tester,
    ) async {
      const size = Size(1400, 900);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          // The desktop tabs each run their own Navigator (Beamer); the
          // launcher must not push the sheet onto it, or the tab's own
          // route is what a close pops.
          Navigator(
            key: const ValueKey('tab-navigator'),
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (context) => Scaffold(
                body: TextButton(
                  key: const ValueKey('open-edit'),
                  onPressed: () =>
                      openHabitEditor(context, habitId: habitFlossing.id),
                  child: const Text('tab route'),
                ),
              ),
            ),
          ),
          mediaQueryData: const MediaQueryData(size: size),
          overrides: [
            measurableDataTypesStreamProvider.overrideWith(
              (ref) => Stream.value(const []),
            ),
            workoutTypesProvider.overrideWith((ref) async => const []),
          ],
        ),
      );
      await tester.tap(find.byKey(const ValueKey('open-edit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(HabitEditorPage), findsOneWidget);
      // On the root navigator: the panel spans the window height and the
      // scrim is not clipped to the tab.
      expect(
        tester.getSize(find.byType(HabitEditorPage)).height,
        greaterThan(700),
      );

      final primary = find.byKey(const ValueKey('habit-editor-primary'));
      await tester.tap(primary);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(HabitEditorPage), findsNothing);
      expect(
        find.text('tab route'),
        findsOneWidget,
        reason: 'the tab route survived',
      );
    });
  });
}
