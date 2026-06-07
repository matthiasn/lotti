import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/habits/state/habit_settings_controller.dart';
import 'package:lotti/features/habits/ui/widgets/habit_dashboard.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../test_data/test_data.dart';
import '../../../../test_helper.dart';

void main() {
  late MockJournalDb mockJournalDb;
  late MockPersistenceLogic mockPersistenceLogic;
  late MockEntitiesCacheService mockEntitiesCacheService;
  late MockNotificationService mockNotificationService;
  late MockUpdateNotifications mockUpdateNotifications;

  setUpAll(() {
    registerFallbackValue(FakeHabitDefinition());
  });

  setUp(() {
    mockJournalDb = mockJournalDbWithHabits([habitFlossing]);
    mockPersistenceLogic = MockPersistenceLogic();
    mockEntitiesCacheService = MockEntitiesCacheService();
    mockNotificationService = MockNotificationService();
    mockUpdateNotifications = MockUpdateNotifications();

    when(mockJournalDb.getAllDashboards).thenAnswer(
      (_) async => [testDashboardConfig, emptyTestDashboardConfig],
    );

    when(() => mockEntitiesCacheService.sortedCategories).thenReturn([]);

    when(
      () => mockUpdateNotifications.updateStream,
    ).thenAnswer((_) => const Stream<Set<String>>.empty());

    getIt
      ..registerSingleton<JournalDb>(mockJournalDb)
      ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
      ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService)
      ..registerSingleton<NotificationService>(mockNotificationService)
      ..registerSingleton<UpdateNotifications>(mockUpdateNotifications);
  });

  tearDown(getIt.reset);

  testWidgets('displays dashboard selection widget', (tester) async {
    await tester.pumpWidget(
      RiverpodWidgetTestBench(
        child: SelectDashboardWidget(habitId: habitFlossing.id),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(SelectDashboardWidget), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('opens dashboard modal and selects dashboard', (tester) async {
    await tester.pumpWidget(
      RiverpodWidgetTestBench(
        child: SelectDashboardWidget(habitId: habitFlossing.id),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Tap to open modal
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Find dashboard in modal and tap it
    final dashboardFinder = find.text(testDashboardConfig.name);
    expect(dashboardFinder, findsWidgets);

    await tester.tap(dashboardFinder.first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('clears dashboard when close icon tapped', (tester) async {
    // The shared test fixtures both use `id: ''`, which collides in the
    // widget's by-id lookup — give this test's dashboard a distinct id.
    final dashboard = testDashboardConfig.copyWith(id: 'dashboard-1');
    when(mockJournalDb.getAllDashboards).thenAnswer(
      (_) async => [dashboard, emptyTestDashboardConfig],
    );

    // Create habit with a dashboard already set
    final habitWithDashboard = habitFlossing.copyWith(
      dashboardId: dashboard.id,
    );

    // Stub getHabitById to return the habit with dashboard set
    // (notificationDrivenItemStream fetches via getHabitById)
    when(
      () => mockJournalDb.getHabitById(habitWithDashboard.id),
    ).thenAnswer((_) async => habitWithDashboard);

    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: WidgetTestBench(
          child: SelectDashboardWidget(habitId: habitWithDashboard.id),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // The field starts with the dashboard's name resolved and shown.
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      dashboard.name,
    );

    // Find and tap the close icon
    final closeIcon = find.byIcon(Icons.close_rounded);
    expect(closeIcon, findsOneWidget);

    await tester.tap(closeIcon);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // After clearing, the close icon should no longer be visible
    expect(find.byIcon(Icons.close_rounded), findsNothing);

    // The clear actually landed in the settings state: dashboardId is
    // null again, the change is marked dirty, and the text field no
    // longer shows the dashboard name.
    final state = container.read(
      habitSettingsControllerProvider(habitWithDashboard.id),
    );
    expect(state.habitDefinition.dashboardId, isNull);
    expect(state.dirty, isTrue);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
  });
}
