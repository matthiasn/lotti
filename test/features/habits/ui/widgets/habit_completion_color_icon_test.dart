import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/ui/widgets/categories_type_card.dart';
import 'package:lotti/features/habits/ui/widgets/habit_completion_color_icon.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../test_helper.dart';

class MockEntitiesCacheService extends Mock implements EntitiesCacheService {}

void main() {
  late MockEntitiesCacheService mockCacheService;

  setUp(() {
    mockCacheService = MockEntitiesCacheService();
    getIt.registerSingleton<EntitiesCacheService>(mockCacheService);
  });

  tearDown(() {
    getIt.unregister<EntitiesCacheService>();
  });

  testWidgets('displays CategoryColorIcon with correct categoryId',
      (tester) async {
    const habitId = 'test-habit-id';
    const categoryId = 'test-category-id';

    when(() => mockCacheService.getHabitById(habitId)).thenReturn(
      HabitDefinition(
        id: habitId,
        name: 'Test Habit',
        categoryId: categoryId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        vectorClock: null,
        private: false,
        active: true,
        description: '',
        habitSchedule: const HabitSchedule.daily(requiredCompletions: 1),
      ),
    );

    await tester.pumpWidget(
      createTestApp(
        const HabitCompletionColorIcon(habitId),
      ),
    );

    // Verify that CategoryColorIcon is rendered with correct categoryId
    final categoryColorIcon = find.byWidgetPredicate(
      (widget) =>
          widget is CategoryColorIcon && widget.categoryId == categoryId,
    );
    expect(categoryColorIcon, findsOneWidget);
  });

  testWidgets('handles null habitId gracefully', (tester) async {
    when(() => mockCacheService.getHabitById(null)).thenReturn(null);

    await tester.pumpWidget(
      createTestApp(
        const HabitCompletionColorIcon(null),
      ),
    );

    // Verify that CategoryColorIcon is rendered with null categoryId
    final categoryColorIcon = find.byWidgetPredicate(
      (widget) => widget is CategoryColorIcon && widget.categoryId == null,
    );
    expect(categoryColorIcon, findsOneWidget);
  });

  testWidgets('respects custom size parameter', (tester) async {
    const habitId = 'test-habit-id';
    const customSize = 30.0;

    when(() => mockCacheService.getHabitById(habitId)).thenReturn(
      HabitDefinition(
        id: habitId,
        name: 'Test Habit',
        categoryId: 'test-category-id',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        vectorClock: null,
        private: false,
        active: true,
        description: '',
        habitSchedule: const HabitSchedule.daily(requiredCompletions: 1),
      ),
    );

    await tester.pumpWidget(
      createTestApp(
        const HabitCompletionColorIcon(
          habitId,
          size: customSize,
        ),
      ),
    );

    // Verify that CategoryColorIcon is rendered with correct size
    final categoryColorIcon = find.byWidgetPredicate(
      (widget) => widget is CategoryColorIcon && widget.size == customSize,
    );
    expect(categoryColorIcon, findsOneWidget);
  });
}
