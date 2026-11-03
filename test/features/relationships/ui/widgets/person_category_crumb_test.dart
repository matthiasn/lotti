import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/ui/widgets/category_picker_sheet.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/relationships/ui/widgets/person_category_crumb.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/repositories/entry_category_move.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_get_it.dart';
import '../../../../mocks/mocks.dart';

void main() {
  late MockEntryCategoryMove move;
  late MockEntitiesCacheService cache;

  CategoryDefinition category(String id, String name) => CategoryDefinition(
    id: id,
    name: name,
    color: '#3A7BD5',
    createdAt: DateTime(2026, 8),
    updatedAt: DateTime(2026, 8),
    vectorClock: null,
    private: false,
    active: true,
  );

  final operations = category('cat-ops', 'Penguin Operations');
  final crew = category('cat-crew', 'Launch crew');

  setUp(() async {
    move = MockEntryCategoryMove();
    cache = MockEntitiesCacheService();
    when(() => cache.getCategoryById(any())).thenReturn(null);
    when(() => cache.getCategoryById('cat-ops')).thenReturn(operations);
    when(() => cache.getCategoryById('cat-crew')).thenReturn(crew);
    when(() => cache.sortedCategories).thenReturn([operations, crew]);
    await setUpTestGetIt(
      additionalSetup: () =>
          getIt.registerSingleton<EntitiesCacheService>(cache),
    );
  });
  tearDown(tearDownTestGetIt);

  Future<void> pump(
    WidgetTester tester, {
    String? categoryId = 'cat-ops',
    String? categoryName = 'Penguin Operations',
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        PersonCategoryCrumb(
          relationshipId: 'person-pip',
          categoryId: categoryId,
          categoryName: categoryName,
        ),
        overrides: [entryCategoryMoveProvider.overrideWithValue(move)],
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openPicker(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('person-category-crumb')));
    await tester.pumpAndSettle();
    expect(find.byType(CategoryPickerSheet), findsOneWidget);
  }

  testWidgets('names the category and opens the shared picker on it', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('Penguin Operations'), findsOneWidget);
    await openPicker(tester);
    verifyNever(() => move.move(any(), any()));
  });

  testWidgets(
    'picking another category moves the person — and everything they hold — '
    'through the category move',
    (tester) async {
      when(() => move.move(any(), any())).thenAnswer((_) async => true);
      await pump(tester);

      await openPicker(tester);
      await tester.tap(find.text('Launch crew'));
      await tester.pumpAndSettle();

      verify(() => move.move('person-pip', 'cat-crew')).called(1);
      expect(find.byType(CategoryPickerSheet), findsNothing);
      expect(find.byType(DesignSystemToast), findsNothing);
    },
  );

  testWidgets('picking the category the person is already in writes nothing', (
    tester,
  ) async {
    await pump(tester);

    await openPicker(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(CategoryPickerSheet),
        matching: find.text('Penguin Operations'),
      ),
    );
    await tester.pumpAndSettle();

    verifyNever(() => move.move(any(), any()));
  });

  testWidgets('a failed move says so', (tester) async {
    when(() => move.move(any(), any())).thenAnswer((_) async => false);
    await pump(tester);

    await openPicker(tester);
    await tester.tap(find.text('Launch crew'));
    await tester.pumpAndSettle();

    verify(() => move.move('person-pip', 'cat-crew')).called(1);
    expect(
      find.text('Could not save the changes. Please try again.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'a person in no category is offered one, in the same place',
    (tester) async {
      when(() => move.move(any(), any())).thenAnswer((_) async => true);
      await pump(tester, categoryId: null, categoryName: null);

      expect(find.text('Set category'), findsOneWidget);
      await openPicker(tester);
      await tester.tap(find.text('Penguin Operations'));
      await tester.pumpAndSettle();

      verify(() => move.move('person-pip', 'cat-ops')).called(1);
    },
  );
}
