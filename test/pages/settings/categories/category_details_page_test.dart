import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/pages/settings/categories/category_details_page.dart';
import 'package:mocktail/mocktail.dart';
import 'package:showcaseview/showcaseview.dart';

import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';
import '../../../widget_test_utils.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  // ignore: deprecated_member_use
  binding.window.physicalSizeTestValue = const Size(1000, 1000);
  // ignore: deprecated_member_use
  binding.window.devicePixelRatioTestValue = 1.0;

  var mockJournalDb = MockJournalDb();
  var mockPersistenceLogic = MockPersistenceLogic();

  group('CategoryDetailsPage Widget Tests - ', () {
    setUpAll(() {
      registerFallbackValue(
        FakeCategoryDefinition(),
      );
    });

    setUp(() {
      mockJournalDb = mockJournalDbWithHabits([habitFlossing]);

      when(mockJournalDb.watchCategories).thenAnswer(
        (_) => Stream<List<CategoryDefinition>>.fromIterable([
          [categoryMindfulness],
        ]),
      );

      when(() => mockJournalDb.watchCategoryById(categoryMindfulness.id))
          .thenAnswer(
        (_) => Stream<CategoryDefinition>.fromIterable([categoryMindfulness]),
      );

      mockPersistenceLogic = MockPersistenceLogic();

      getIt
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<PersistenceLogic>(mockPersistenceLogic);
    });
    tearDown(getIt.reset);

    testWidgets('category details page is displayed', (tester) async {
      when(
        () => mockPersistenceLogic.upsertEntityDefinition(any()),
      ).thenAnswer((_) async => 1);

      await tester.pumpWidget(
        makeTestableWidget(
          ShowCaseWidget(
            builder: (context) => ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: 1000,
                maxWidth: 1000,
              ),
              child: EditCategoryPage(
                categoryId: categoryMindfulness.id,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final nameFieldFinder = find.byKey(const Key('category_name_field'));
      final saveButtonFinder = find.byKey(const Key('category_save'));
      final deleteButtonFinder = find.byKey(const Key('category_delete'));

      expect(nameFieldFinder, findsOneWidget);
      expect(deleteButtonFinder, findsOneWidget);

      // save button is invisible - no changes yet
      expect(saveButtonFinder, findsNothing);

      await tester.enterText(
        nameFieldFinder,
        'new name',
      );

      await tester.pumpAndSettle();

      // save button is now visible
      expect(saveButtonFinder, findsOneWidget);

      await tester.tap(saveButtonFinder);

      await tester.pumpAndSettle();

      await tester.tap(deleteButtonFinder);

      await tester.pumpAndSettle();

      final confirmDeleteFinder = find.byIcon(Icons.warning);
      expect(confirmDeleteFinder, findsOneWidget);

      await tester.tap(confirmDeleteFinder);
      await tester.pumpAndSettle();
    });
  });
}
