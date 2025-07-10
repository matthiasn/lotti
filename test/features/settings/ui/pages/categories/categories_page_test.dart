import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/settings/ui/pages/categories/categories_page.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../mocks/mocks.dart';
import '../../../../../test_data/test_data.dart';
import '../../../../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final mockJournalDb = MockJournalDb();
  final mockEntitiesCacheService = MockEntitiesCacheService();

  group('Categories Page Widget Tests - ', () {
    setUp(() {
      when(mockJournalDb.watchCategories).thenAnswer(
        (_) => Stream<List<CategoryDefinition>>.fromIterable([
          [categoryMindfulness],
        ]),
      );

      getIt
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService);
    });
    tearDown(getIt.reset);

    testWidgets('page is displayed', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 1000,
              maxWidth: 1000,
            ),
            child: const CategoriesPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text(categoryMindfulness.name), findsOneWidget);
    });
  });
}
