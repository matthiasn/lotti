import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/design_system/components/glass_action_bar.dart';
import 'package:lotti/features/settings/ui/pages/habits/habit_details_page.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/widgets/settings/settings_delete_row.dart';
import 'package:lotti/widgets/settings/settings_form_section.dart';
import 'package:lotti/widgets/settings/settings_switch_row.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../mocks/mocks.dart';
import '../../../../../test_data/test_data.dart';
import '../../../../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestGetItMocks mocks;
  late MockPersistenceLogic mockPersistenceLogic;
  late MockEntitiesCacheService mockEntitiesCacheService;
  late MockNotificationService mockNotificationService;
  String? beamedTo;

  setUpAll(() {
    registerFallbackValue(FakeDashboardDefinition());
    registerFallbackValue(FakeHabitDefinition());
  });

  setUp(() async {
    mockPersistenceLogic = MockPersistenceLogic();
    mockEntitiesCacheService = MockEntitiesCacheService();
    mockNotificationService = MockNotificationService();

    mocks = await setUpTestGetIt(
      additionalSetup: () {
        getIt
          ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
          ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService)
          ..registerSingleton<NotificationService>(mockNotificationService);
      },
    );

    when(
      () => mocks.journalDb.getHabitById(any()),
    ).thenAnswer((_) async => null);
    when(
      () => mocks.journalDb.getHabitById(habitFlossing.id),
    ).thenAnswer((_) async => habitFlossing);
    when(
      mocks.journalDb.getAllDashboards,
    ).thenAnswer((_) async => [testDashboardConfig]);
    when(
      () => mockEntitiesCacheService.sortedCategories,
    ).thenReturn([categoryMindfulness]);
    when(
      () => mockNotificationService.scheduleHabitNotification(any()),
    ).thenAnswer((_) async {});
    when(
      () => mockPersistenceLogic.upsertEntityDefinition(any()),
    ).thenAnswer((_) async => 1);

    // Back/cancel/save/delete beam to the list route (V2's desktop detail
    // surface mounts the page inline; there is no Navigator route to pop).
    beamedTo = null;
    beamToNamedOverride = (path) => beamedTo = path;
  });

  tearDown(() async {
    beamToNamedOverride = null;
    await tearDownTestGetIt();
  });

  /// Pumps [child] on a tall surface so the whole form including the
  /// sticky action bar is hittable, then drains the initial frames.
  Future<void> pumpPage(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        child,
        mediaQueryData: const MediaQueryData(size: Size(1200, 1600)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  DsGlassPill saveAction(WidgetTester tester) => tester.widget<DsGlassPill>(
    find.widgetWithText(DsGlassPill, 'Save'),
  );

  HabitDefinition capturedUpsert() {
    final captured = verify(
      () => mockPersistenceLogic.upsertEntityDefinition(captureAny()),
    ).captured;
    return captured.last as HabitDefinition;
  }

  group('HabitDetailsPage', () {
    testWidgets(
      'edit mode seeds fields, gates Save on dirty, persists edited values, '
      'and beams to the habits list',
      (tester) async {
        await pumpPage(tester, EditHabitPage(habitId: habitFlossing.id));

        // Seeded from the loaded definition.
        expect(find.text('Flossing'), findsOneWidget);
        expect(find.text('Maintain healthy teeth and gums'), findsOneWidget);
        // Daily schedule renders the daily-only time fields.
        expect(find.text('Show from'), findsOneWidget);
        expect(find.text('Show alert at'), findsOneWidget);

        // Save pill renders disabled while the form is clean.
        expect(saveAction(tester).enabled, isFalse);

        await tester.enterText(
          find.byKey(const Key('habit_name_field')),
          'Flossing updated',
        );
        await tester.pump();

        expect(saveAction(tester).enabled, isTrue);

        await tester.tap(find.widgetWithText(DsGlassPill, 'Save'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final saved = capturedUpsert();
        expect(saved.id, habitFlossing.id);
        expect(saved.name, 'Flossing updated');
        // Untouched fields keep their seeded values through the save.
        expect(saved.description, 'Maintain healthy teeth and gums');
        verify(
          () => mockNotificationService.scheduleHabitNotification(any()),
        ).called(1);
        expect(beamedTo, '/settings/habits');
      },
    );

    testWidgets(
      'Options section card groups Favorite, Private, then Active with the '
      'unified copy',
      (tester) async {
        await pumpPage(tester, EditHabitPage(habitId: habitFlossing.id));

        final optionsSection = find.ancestor(
          of: find.text('Options'),
          matching: find.byType(SettingsFormSection),
        );
        expect(optionsSection, findsOneWidget);

        final rows = tester
            .widgetList<SettingsSwitchRow>(
              find.descendant(
                of: optionsSection,
                matching: find.byType(SettingsSwitchRow),
              ),
            )
            .toList();
        expect(rows.map((row) => row.title), ['Favorite', 'Private', 'Active']);
        expect(rows[0].icon, Icons.star_outline_rounded);
        expect(rows[0].subtitle, isNull);
        expect(rows[1].icon, Icons.lock_outline);
        expect(
          rows[1].subtitle,
          'Only visible when private entries are shown',
        );
        expect(rows[2].icon, Icons.visibility_outlined);
        expect(
          rows[2].subtitle,
          'Can be chosen for new entries when on',
        );
      },
    );

    testWidgets(
      'toggling the Favorite and Active switches persists priority=true '
      'and active=false',
      (tester) async {
        await pumpPage(tester, EditHabitPage(habitId: habitFlossing.id));

        // The star toggle announces "Favorite" (matching the list row) and
        // the visibility toggle uses Active polarity (ON = visible).
        expect(find.text('Favorite'), findsOneWidget);
        expect(find.text('Active'), findsOneWidget);
        expect(find.text('Archived'), findsNothing);

        final priorityFinder = find.byKey(const Key('habit_priority'));
        await tester.ensureVisible(priorityFinder);
        await tester.pump();
        await tester.tap(priorityFinder);
        await tester.pump();

        // habitFlossing is active, so the switch starts ON; tapping it
        // turns the habit inactive.
        final activeFinder = find.byKey(const Key('habit_active'));
        await tester.ensureVisible(activeFinder);
        await tester.pump();
        await tester.tap(activeFinder);
        await tester.pump();

        await tester.tap(find.widgetWithText(DsGlassPill, 'Save'));
        await tester.pump();

        final saved = capturedUpsert();
        expect(saved.priority, isTrue);
        expect(saved.active, isFalse);
      },
    );

    testWidgets(
      'delete flow confirms via the action sheet, soft-deletes the habit, '
      'and beams to the habits list',
      (tester) async {
        await pumpPage(tester, EditHabitPage(habitId: habitFlossing.id));

        await tester.scrollUntilVisible(
          find.widgetWithText(SettingsDeleteRow, 'Delete'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        // The sticky glass action bar overlays the viewport bottom; nudge
        // the row above it so the tap hits the row, not the bar.
        await tester.drag(
          find.byType(Scrollable).first,
          const Offset(0, -120),
          warnIfMissed: false,
        );
        await tester.pump();
        await tester.tap(find.widgetWithText(SettingsDeleteRow, 'Delete'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(
          find.text('Do you want to delete this habit?'),
          findsOneWidget,
        );

        await tester.tap(find.text('YES, DELETE THIS HABIT'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        final saved = capturedUpsert();
        expect(saved.id, habitFlossing.id);
        expect(saved.deletedAt, isNotNull);
        expect(beamedTo, '/settings/habits');
      },
    );

    testWidgets(
      'back arrow and Cancel beam to the habits list without saving',
      (tester) async {
        await pumpPage(tester, EditHabitPage(habitId: habitFlossing.id));

        await tester.tap(find.byIcon(Icons.chevron_left));
        await tester.pump();
        expect(beamedTo, '/settings/habits');

        beamedTo = null;
        await tester.tap(find.widgetWithText(DsGlassPill, 'Cancel'));
        await tester.pump();
        expect(beamedTo, '/settings/habits');

        verifyNever(() => mockPersistenceLogic.upsertEntityDefinition(any()));
      },
    );

    testWidgets(
      'Ctrl+S only saves once the form is dirty',
      (tester) async {
        await pumpPage(tester, EditHabitPage(habitId: habitFlossing.id));

        // Focus the form without changing any value.
        await tester.tap(find.byKey(const Key('habit_name_field')));
        await tester.pump();

        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pump();

        verifyNever(() => mockPersistenceLogic.upsertEntityDefinition(any()));

        await tester.enterText(
          find.byKey(const Key('habit_name_field')),
          'Flossing twice',
        );
        await tester.pump();

        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(capturedUpsert().name, 'Flossing twice');
        expect(beamedTo, '/settings/habits');
      },
    );

    testWidgets(
      'create mode shows the create title and Create action and hides the '
      'delete affordance',
      (tester) async {
        await pumpPage(
          tester,
          const HabitDetailsPage(habitId: 'new-habit-id', isCreateMode: true),
        );

        expect(find.text('Create habit'), findsOneWidget);
        expect(find.widgetWithText(SettingsDeleteRow, 'Delete'), findsNothing);

        final createPill = tester.widget<DsGlassPill>(
          find.widgetWithText(DsGlassPill, 'Create'),
        );
        expect(createPill.enabled, isFalse);
      },
    );

    testWidgets(
      'edit mode for an unknown habit renders the empty scaffold',
      (tester) async {
        await pumpPage(tester, const EditHabitPage(habitId: 'missing'));

        expect(find.byKey(const Key('habit_name_field')), findsNothing);
        expect(find.byType(DsGlassPill), findsNothing);
      },
    );
  });
}
