import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/design_system/components/glass_action_bar.dart';
import 'package:lotti/features/settings/ui/pages/habits/habit_create_page.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/widgets/settings/settings_delete_row.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../mocks/mocks.dart';
import '../../../../../test_data/test_data.dart';
import '../../../../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestGetItMocks mocks;
  late MockPersistenceLogic mockPersistenceLogic;
  String? beamedTo;

  setUpAll(() {
    registerFallbackValue(FakeHabitDefinition());
  });

  setUp(() async {
    mockPersistenceLogic = MockPersistenceLogic();
    final mockEntitiesCacheService = MockEntitiesCacheService();
    final mockNotificationService = MockNotificationService();

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

    beamedTo = null;
    beamToNamedOverride = (path) => beamedTo = path;
  });

  tearDown(() async {
    beamToNamedOverride = null;
    await tearDownTestGetIt();
  });

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

  group('CreateHabitPage', () {
    testWidgets(
      'mounts the details page in create mode: create title, no delete '
      'affordance, Create gated on dirty, and a filled form persists the '
      'new habit',
      (tester) async {
        final page = CreateHabitPage();
        await pumpPage(tester, page);

        expect(find.text('Create habit'), findsOneWidget);
        expect(find.widgetWithText(SettingsDeleteRow, 'Delete'), findsNothing);

        final createFinder = find.widgetWithText(DsGlassPill, 'Create');
        expect(tester.widget<DsGlassPill>(createFinder).enabled, isFalse);

        await tester.enterText(
          find.byKey(const Key('habit_name_field')),
          'Morning stretch',
        );
        await tester.enterText(
          find.byKey(const Key('habit_description_field')),
          'Five minutes after waking up',
        );
        await tester.pump();

        expect(tester.widget<DsGlassPill>(createFinder).enabled, isTrue);

        await tester.tap(createFinder);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final saved =
            verify(
                  () => mockPersistenceLogic.upsertEntityDefinition(
                    captureAny(),
                  ),
                ).captured.single
                as HabitDefinition;
        expect(saved.id, page.habitId);
        expect(saved.name, 'Morning stretch');
        expect(saved.description, 'Five minutes after waking up');
        // The untouched Active switch persists the new habit as active.
        expect(saved.active, isTrue);
        expect(beamedTo, '/settings/habits');
      },
    );
  });
}
