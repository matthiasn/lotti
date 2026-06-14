import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/features/categories/ui/widgets/category_icon_compact.dart';
import 'package:lotti/features/categories/ui/widgets/category_picker_sheet.dart';
import 'package:lotti/features/settings/ui/widgets/dashboards/dashboard_category.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../mocks/mocks.dart';
import '../../../../../test_helper.dart';
import '../../../../../widget_test_utils.dart';

void main() {
  late TestGetItMocks mocks;
  late MockEntitiesCacheService mockCacheService;

  final categoryA = CategoryDefinition(
    id: 'cat-a',
    name: 'Alpha',
    color: '#FF0000',
    createdAt: DateTime(2024, 3, 15),
    updatedAt: DateTime(2024, 3, 15),
    vectorClock: null,
    private: false,
    active: true,
  );

  final categoryB = CategoryDefinition(
    id: 'cat-b',
    name: 'Beta',
    color: '#00FF00',
    createdAt: DateTime(2024, 3, 15),
    updatedAt: DateTime(2024, 3, 15),
    vectorClock: null,
    private: false,
    active: true,
  );

  setUp(() async {
    mocks = await setUpTestGetIt();
    mockCacheService = MockEntitiesCacheService();

    // setUpTestGetIt already stubs updateStream; override getAllCategories.
    when(
      () => mocks.journalDb.getAllCategories(),
    ).thenAnswer((_) async => [categoryA, categoryB]);
    when(() => mockCacheService.getCategoryById(any())).thenReturn(null);
    when(() => mockCacheService.getCategoryById('cat-a')).thenReturn(categoryA);
    when(() => mockCacheService.getCategoryById('cat-b')).thenReturn(categoryB);

    getIt.registerSingleton<EntitiesCacheService>(mockCacheService);
  });

  tearDown(tearDownTestGetIt);

  Future<void> pumpWidget(
    WidgetTester tester, {
    required void Function(String?) setCategory,
    String? categoryId,
  }) async {
    await tester.pumpWidget(
      WidgetTestBench(
        child: SelectDashboardCategoryWidget(
          setCategory: setCategory,
          categoryId: categoryId,
        ),
      ),
    );
    // Let the StreamBuilder fetch and emit data.
    await tester.pump();
    await tester.pump();
  }

  group('SelectDashboardCategoryWidget', () {
    group('initial display', () {
      testWidgets('shows hint text when no category is selected', (
        tester,
      ) async {
        await pumpWidget(tester, setCategory: (_) {});

        expect(find.text('Select a category'), findsOneWidget);
      });

      testWidgets('shows selected category name in text field', (tester) async {
        await pumpWidget(
          tester,
          setCategory: (_) {},
          categoryId: 'cat-a',
        );

        expect(find.text('Alpha'), findsOneWidget);
      });

      testWidgets(
        'shows close button when a category is selected, hidden otherwise',
        (tester) async {
          // With a selected category – close button visible.
          await pumpWidget(
            tester,
            setCategory: (_) {},
            categoryId: 'cat-a',
          );

          expect(find.byIcon(Icons.close_rounded), findsOneWidget);

          // Without a selected category – close button absent.
          await pumpWidget(tester, setCategory: (_) {});

          expect(find.byIcon(Icons.close_rounded), findsNothing);
        },
      );

      testWidgets('renders CategoryIconCompact with correct size', (
        tester,
      ) async {
        await pumpWidget(
          tester,
          setCategory: (_) {},
          categoryId: 'cat-a',
        );

        // There are two CategoryIconCompact widgets: the leading decoration
        // icon and the suffix one when a category is set.
        final icons = tester.widgetList<CategoryIconCompact>(
          find.byType(CategoryIconCompact),
        );
        for (final icon in icons) {
          expect(icon.size, CategoryIconConstants.iconSizeMedium);
        }
      });
    });

    group('clear button', () {
      testWidgets('tapping close button calls setCategory(null)', (
        tester,
      ) async {
        String? capturedValue = 'sentinel';

        await pumpWidget(
          tester,
          setCategory: (v) => capturedValue = v,
          categoryId: 'cat-a',
        );

        final clearButton = find.byIcon(Icons.close_rounded);
        await tester.ensureVisible(clearButton);
        await tester.tap(clearButton);
        await tester.pump();

        expect(capturedValue, isNull);
      });
    });

    group('category selection modal', () {
      testWidgets('tapping the text field opens a modal listing categories', (
        tester,
      ) async {
        await pumpWidget(tester, setCategory: (_) {});

        final textField = find.descendant(
          of: find.byKey(const Key('select_dashboard_category')),
          matching: find.byType(InkWell),
        );
        await tester.ensureVisible(textField);
        await tester.tap(textField);
        await tester.pumpAndSettle();

        // Both category names appear in the modal.
        expect(find.text('Alpha'), findsOneWidget);
        expect(find.text('Beta'), findsOneWidget);

        // The picker hosts the category rows.
        expect(find.byType(CategoryPickerSheet), findsOneWidget);
      });

      testWidgets(
        'tapping a category in the modal calls setCategory with its id',
        (tester) async {
          String? selectedId;

          await pumpWidget(
            tester,
            setCategory: (v) => selectedId = v,
          );

          // Open modal.
          final textField = find.descendant(
            of: find.byKey(const Key('select_dashboard_category')),
            matching: find.byType(InkWell),
          );
          await tester.ensureVisible(textField);
          await tester.tap(textField);
          await tester.pumpAndSettle();

          // Tap the first category.
          final alphaCard = find.text('Alpha');
          await tester.ensureVisible(alphaCard);
          await tester.pumpAndSettle();
          await tester.tap(alphaCard);
          await tester.pumpAndSettle();

          expect(selectedId, equals('cat-a'));
        },
      );

      testWidgets(
        'tapping a category in the modal closes the modal afterwards',
        (tester) async {
          await pumpWidget(tester, setCategory: (_) {});

          // Open modal.
          final textField = find.descendant(
            of: find.byKey(const Key('select_dashboard_category')),
            matching: find.byType(InkWell),
          );
          await tester.ensureVisible(textField);
          await tester.tap(textField);
          await tester.pumpAndSettle();

          expect(find.byType(CategoryPickerSheet), findsOneWidget);

          // Tap a category.
          final betaCard = find.text('Beta');
          await tester.ensureVisible(betaCard);
          await tester.pumpAndSettle();
          await tester.tap(betaCard);
          await tester.pumpAndSettle();

          // Modal is dismissed.
          expect(find.byType(CategoryPickerSheet), findsNothing);
        },
      );

      testWidgets('modal lists all categories returned by db', (tester) async {
        // Verify both category names are shown so the `.map` path (lines 56–68) is exercised.
        await pumpWidget(tester, setCategory: (_) {});

        final textField = find.descendant(
          of: find.byKey(const Key('select_dashboard_category')),
          matching: find.byType(InkWell),
        );
        await tester.ensureVisible(textField);
        await tester.tap(textField);
        await tester.pumpAndSettle();

        for (final cat in [categoryA, categoryB]) {
          expect(find.text(cat.name), findsOneWidget);
        }
      });
    });
  });
}
