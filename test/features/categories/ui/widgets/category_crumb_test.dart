import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/ui/widgets/category_crumb.dart';
import 'package:lotti/features/categories/ui/widgets/category_picker_sheet.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/repositories/entry_category_move.dart';
import 'package:lotti/providers/service_providers.dart';
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
    String? entryId = 'person-pip',
    String? categoryId = 'cat-ops',
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        CategoryCrumb(entryId: entryId, categoryId: categoryId),
        overrides: [
          entryCategoryMoveProvider.overrideWithValue(move),
          entitiesCacheServiceProvider.overrideWithValue(cache),
        ],
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openPicker(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('category-crumb')));
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

  testWidgets('a caption-sized label still gets a touch-sized target', (
    tester,
  ) async {
    await pump(tester);

    expect(
      tester.getSize(find.byKey(const ValueKey('category-crumb'))).height,
      greaterThanOrEqualTo(TapTargets.compact),
    );
  });

  testWidgets(
    'picking another category moves the entry — and everything it holds — '
    'through the category move',
    (tester) async {
      when(() => move.move(any(), any())).thenAnswer((_) async => true);
      await pump(tester);

      await openPicker(tester);
      await tester.tap(find.text('Launch crew'));
      await tester.pumpAndSettle();

      verify(() => move.move('person-pip', 'cat-crew')).called(1);
      expect(find.byType(CategoryPickerSheet), findsNothing);
      // It committed at once, so it says where the entry went.
      expect(find.text('Moved to Launch crew'), findsOneWidget);
    },
  );

  testWidgets('Undo on the toast moves the entry back where it was', (
    tester,
  ) async {
    when(() => move.move(any(), any())).thenAnswer((_) async => true);
    var moved = 0;
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        CategoryCrumb(
          entryId: 'person-pip',
          categoryId: 'cat-ops',
          onMoved: () => moved++,
        ),
        overrides: [
          entryCategoryMoveProvider.overrideWithValue(move),
          entitiesCacheServiceProvider.overrideWithValue(cache),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await openPicker(tester);
    await tester.tap(find.text('Launch crew'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    verifyInOrder([
      () => move.move('person-pip', 'cat-crew'),
      () => move.move('person-pip', 'cat-ops'),
    ]);
    expect(moved, 2);
  });

  testWidgets('picking the category the entry is already in writes nothing', (
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

  testWidgets('an Undo that fails says so too, rather than failing silently', (
    tester,
  ) async {
    when(
      () => move.move('person-pip', 'cat-crew'),
    ).thenAnswer((_) async => true);
    when(
      () => move.move('person-pip', 'cat-ops'),
    ).thenAnswer((_) async => false);
    await pump(tester);

    await openPicker(tester);
    await tester.tap(find.text('Launch crew'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    verify(() => move.move('person-pip', 'cat-ops')).called(1);
    expect(find.text("That didn't save — please try again."), findsOneWidget);
  });

  testWidgets(
    'Undo still moves the entry back after the page that moved it is gone',
    (tester) async {
      when(() => move.move(any(), any())).thenAnswer((_) async => true);
      await pump(tester);

      await openPicker(tester);
      await tester.tap(find.text('Launch crew'));
      await tester.pumpAndSettle();
      // The user leaves: the crumb is torn down, the toast stays up.
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const SizedBox.shrink(),
          overrides: [
            entryCategoryMoveProvider.overrideWithValue(move),
            entitiesCacheServiceProvider.overrideWithValue(cache),
          ],
        ),
      );
      expect(find.byType(CategoryCrumb), findsNothing);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      verify(() => move.move('person-pip', 'cat-ops')).called(1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'clearing the category moves the entry out of it and says so',
    (tester) async {
      when(() => move.move(any(), any())).thenAnswer((_) async => true);
      await pump(tester);

      await openPicker(tester);
      await tester.tap(find.byKey(const ValueKey('category-picker-clear')));
      await tester.pumpAndSettle();

      verify(() => move.move('person-pip', null)).called(1);
      expect(find.text('No category now'), findsOneWidget);
    },
  );

  testWidgets('a pointer over the crumb washes it, and leaving clears it', (
    tester,
  ) async {
    await pump(tester);
    final tokens = tester.element(find.byType(CategoryCrumb)).designTokens;
    Color? wash() =>
        (tester
                    .widget<AnimatedContainer>(
                      find.descendant(
                        of: find.byKey(const ValueKey('category-crumb')),
                        matching: find.byType(AnimatedContainer),
                      ),
                    )
                    .decoration!
                as BoxDecoration)
            .color;

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(
      tester.getCenter(find.byKey(const ValueKey('category-crumb'))),
    );
    await tester.pumpAndSettle();
    expect(wash(), tokens.colors.surface.hover);

    await mouse.moveTo(Offset.zero);
    await tester.pumpAndSettle();
    expect(wash(), Colors.transparent);
  });

  testWidgets('a failed move says so', (tester) async {
    when(() => move.move(any(), any())).thenAnswer((_) async => false);
    await pump(tester);

    await openPicker(tester);
    await tester.tap(find.text('Launch crew'));
    await tester.pumpAndSettle();

    verify(() => move.move('person-pip', 'cat-crew')).called(1);
    expect(find.text("That didn't save — please try again."), findsOneWidget);
  });

  testWidgets('an entry in no category is offered one, in the same place', (
    tester,
  ) async {
    when(() => move.move(any(), any())).thenAnswer((_) async => true);
    await pump(tester, categoryId: null);

    expect(find.text('Set category'), findsOneWidget);
    await openPicker(tester);
    await tester.tap(find.text('Penguin Operations'));
    await tester.pumpAndSettle();

    verify(() => move.move('person-pip', 'cat-ops')).called(1);
    expect(find.text('Moved to Penguin Operations'), findsOneWidget);
  });

  testWidgets(
    'while the host is still reading which row to move, the crumb shows '
    'the category but opens nothing',
    (tester) async {
      await pump(tester, entryId: null);

      expect(find.text('Penguin Operations'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('category-crumb')));
      await tester.pumpAndSettle();
      expect(find.byType(CategoryPickerSheet), findsNothing);
    },
  );
}
