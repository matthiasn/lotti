import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/habits/ui/widgets/habit_dashboard.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../test_data/test_data.dart';
import '../../../../test_helper.dart';

class MockUpdateNotifications extends Mock implements UpdateNotifications {}

void main() {
  late MockJournalDb mockJournalDb;
  late MockPersistenceLogic mockPersistenceLogic;
  late MockEntitiesCacheService mockEntitiesCacheService;
  late MockNotificationService mockNotificationService;
  late MockTagsService mockTagsService;
  late MockUpdateNotifications mockUpdateNotifications;

  setUpAll(() {
    registerFallbackValue(FakeHabitDefinition());
  });

  setUp(() {
    mockJournalDb = mockJournalDbWithHabits([habitFlossing]);
    mockPersistenceLogic = MockPersistenceLogic();
    mockEntitiesCacheService = MockEntitiesCacheService();
    mockNotificationService = MockNotificationService();
    mockTagsService = mockTagsServiceWithTags([]);
    mockUpdateNotifications = MockUpdateNotifications();

    when(mockJournalDb.watchDashboards).thenAnswer(
      (_) => Stream<List<DashboardDefinition>>.fromIterable([
        [testDashboardConfig, emptyTestDashboardConfig],
      ]),
    );

    when(mockTagsService.watchTags).thenAnswer(
      (_) => Stream<List<TagEntity>>.fromIterable([[]]),
    );

    when(() => mockEntitiesCacheService.sortedCategories).thenReturn([]);

    when(() => mockUpdateNotifications.updateStream)
        .thenAnswer((_) => const Stream<Set<String>>.empty());

    getIt
      ..registerSingleton<JournalDb>(mockJournalDb)
      ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
      ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService)
      ..registerSingleton<NotificationService>(mockNotificationService)
      ..registerSingleton<TagsService>(mockTagsService)
      ..registerSingleton<UpdateNotifications>(mockUpdateNotifications);
  });

  tearDown(getIt.reset);

  testWidgets('displays dashboard selection widget', (tester) async {
    await tester.pumpWidget(
      RiverpodWidgetTestBench(
        child: SelectDashboardWidget(habitId: habitFlossing.id),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(SelectDashboardWidget), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('opens dashboard modal and selects dashboard', (tester) async {
    await tester.pumpWidget(
      RiverpodWidgetTestBench(
        child: SelectDashboardWidget(habitId: habitFlossing.id),
      ),
    );

    await tester.pumpAndSettle();

    // Tap to open modal
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();

    // Find dashboard in modal and tap it
    final dashboardFinder = find.text(testDashboardConfig.name);
    expect(dashboardFinder, findsWidgets);

    await tester.tap(dashboardFinder.first);
    await tester.pumpAndSettle();
  });

  testWidgets('clears dashboard when close icon tapped', (tester) async {
    // Create habit with a dashboard already set
    final habitWithDashboard = habitFlossing.copyWith(
      dashboardId: testDashboardConfig.id,
    );

    // Use a StreamController to control when data is emitted
    final habitController = StreamController<HabitDefinition?>.broadcast();
    addTearDown(habitController.close);

    // Update the mock to use the StreamController for this specific habit
    when(() => mockJournalDb.watchHabitById(habitWithDashboard.id))
        .thenAnswer((_) => habitController.stream);

    await tester.pumpWidget(
      RiverpodWidgetTestBench(
        child: SelectDashboardWidget(habitId: habitWithDashboard.id),
      ),
    );

    // Pump to build the widget and set up listeners
    await tester.pump();

    // Now emit the habit data after listeners are set up
    habitController.add(habitWithDashboard);

    // Allow time for async state updates
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    // Find and tap the close icon
    final closeIcon = find.byIcon(Icons.close_rounded);
    expect(closeIcon, findsOneWidget);

    await tester.tap(closeIcon);
    await tester.pumpAndSettle();

    // After clearing, the close icon should no longer be visible
    expect(find.byIcon(Icons.close_rounded), findsNothing);
  });
}
