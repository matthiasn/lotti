import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/habits/ui/widgets/habit_category.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../test_data/test_data.dart';
import '../../../../test_helper.dart';

void main() {
  late MockJournalDb mockJournalDb;
  late MockPersistenceLogic mockPersistenceLogic;
  late MockEntitiesCacheService mockEntitiesCacheService;
  late MockNotificationService mockNotificationService;
  late MockTagsService mockTagsService;

  setUpAll(() {
    registerFallbackValue(FakeHabitDefinition());
  });

  setUp(() {
    mockJournalDb = mockJournalDbWithHabits([habitFlossing]);
    mockPersistenceLogic = MockPersistenceLogic();
    mockEntitiesCacheService = MockEntitiesCacheService();
    mockNotificationService = MockNotificationService();
    mockTagsService = mockTagsServiceWithTags([]);

    when(mockJournalDb.watchDashboards).thenAnswer(
      (_) => Stream<List<DashboardDefinition>>.fromIterable([[]]),
    );

    when(mockTagsService.watchTags).thenAnswer(
      (_) => Stream<List<TagEntity>>.fromIterable([[]]),
    );

    when(() => mockEntitiesCacheService.sortedCategories).thenReturn(
      [categoryMindfulness],
    );

    when(() => mockEntitiesCacheService.getCategoryById(any())).thenReturn(null);

    getIt
      ..registerSingleton<JournalDb>(mockJournalDb)
      ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
      ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService)
      ..registerSingleton<NotificationService>(mockNotificationService)
      ..registerSingleton<TagsService>(mockTagsService);
  });

  tearDown(getIt.reset);

  testWidgets('displays category selection widget', (tester) async {
    await tester.pumpWidget(
      RiverpodWidgetTestBench(
        child: SelectCategoryWidget(habitId: habitFlossing.id),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(SelectCategoryWidget), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('opens category modal and selects category', (tester) async {
    when(() => mockEntitiesCacheService.getCategoryById(categoryMindfulness.id))
        .thenReturn(categoryMindfulness);

    await tester.pumpWidget(
      RiverpodWidgetTestBench(
        child: SelectCategoryWidget(habitId: habitFlossing.id),
      ),
    );

    await tester.pumpAndSettle();

    // Tap to open modal
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();

    // Find category in modal and tap it
    final categoryFinder = find.text(categoryMindfulness.name);
    expect(categoryFinder, findsWidgets);

    await tester.tap(categoryFinder.first);
    await tester.pumpAndSettle();
  });
}
