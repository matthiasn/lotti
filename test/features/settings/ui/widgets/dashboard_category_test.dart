import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/features/categories/ui/widgets/category_icon_compact.dart';
import 'package:lotti/features/settings/ui/widgets/dashboards/dashboard_category.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../test_helper.dart';

class MockEntitiesCacheService extends Mock implements EntitiesCacheService {}

class MockJournalDb extends Mock implements JournalDb {}

class MockUpdateNotifications extends Mock implements UpdateNotifications {}

void main() {
  late MockEntitiesCacheService mockCacheService;
  late MockJournalDb mockJournalDb;
  final testCategory = CategoryDefinition(
    id: 'test-id',
    name: 'Test Category',
    color: '#FF0000',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    vectorClock: null,
    private: false,
    active: true,
  );

  setUp(() {
    mockCacheService = MockEntitiesCacheService();
    mockJournalDb = MockJournalDb();

    final mockUpdateNotifications = MockUpdateNotifications();
    when(() => mockUpdateNotifications.updateStream)
        .thenAnswer((_) => const Stream.empty());

    // Mock JournalDb methods
    when(() => mockJournalDb.getAllCategories()).thenAnswer(
      (_) async => [testCategory],
    );

    getIt
      ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
      ..registerSingleton<EntitiesCacheService>(mockCacheService)
      ..registerSingleton<JournalDb>(mockJournalDb);
  });

  tearDown(getIt.reset);

  Widget createTestWidget({
    required void Function(String?) setCategory,
    String? categoryId,
  }) {
    return WidgetTestBench(
      child: SelectDashboardCategoryWidget(
        setCategory: setCategory,
        categoryId: categoryId,
      ),
    );
  }

  testWidgets('displays category icon with correct size', (tester) async {
    when(() => mockCacheService.getCategoryById('test-id'))
        .thenReturn(testCategory);

    await tester.pumpWidget(
      createTestWidget(
        categoryId: 'test-id',
        setCategory: (_) {},
      ),
    );

    final icon =
        tester.widget<CategoryIconCompact>(find.byType(CategoryIconCompact));
    expect(icon.size, equals(CategoryIconConstants.iconSizeMedium));
  });
}
