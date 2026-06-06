import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/features/categories/ui/widgets/category_icon_compact.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';
import '../../test_utils.dart';

void main() {
  late MockEntitiesCacheService cacheService;

  setUp(() {
    cacheService = MockEntitiesCacheService();
    getIt
      ..pushNewScope()
      ..registerSingleton<EntitiesCacheService>(cacheService);
  });

  tearDown(() async {
    await getIt.popScope();
  });

  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(makeTestableWidgetNoScroll(Scaffold(body: child)));
    await tester.pump();
  }

  group('CategoryIconCompact', () {
    testWidgets('renders the category icon tinted with its color', (
      tester,
    ) async {
      final category = CategoryTestUtils.createTestCategory(
        id: 'cat-1',
        name: 'Fitness',
        color: '#FF0000',
        icon: CategoryIcon.fitness,
      );
      when(() => cacheService.getCategoryById('cat-1')).thenReturn(category);

      await pump(tester, const CategoryIconCompact('cat-1'));

      final icon = tester.widget<Icon>(
        find.byIcon(CategoryIcon.fitness.iconData),
      );
      expect(icon.color, const Color(0xFFFF0000));
    });

    testWidgets('falls back to the first letter when no icon is set', (
      tester,
    ) async {
      final category = CategoryTestUtils.createTestCategory(
        id: 'cat-2',
        name: 'work',
        color: '#000000',
      );
      when(() => cacheService.getCategoryById('cat-2')).thenReturn(category);

      await pump(tester, const CategoryIconCompact('cat-2'));

      // Uppercased first letter; dark background -> white text.
      final text = tester.widget<Text>(find.text('W'));
      expect(text.style?.color, Colors.white);
    });

    testWidgets('light background picks black fallback text', (tester) async {
      final category = CategoryTestUtils.createTestCategory(
        id: 'cat-3',
        name: 'sun',
        color: '#FFFF00',
      );
      when(() => cacheService.getCategoryById('cat-3')).thenReturn(category);

      await pump(tester, const CategoryIconCompact('cat-3'));

      final text = tester.widget<Text>(find.text('S'));
      expect(text.style?.color, Colors.black);
    });

    testWidgets('unknown category id renders the generic fallback icon', (
      tester,
    ) async {
      when(() => cacheService.getCategoryById(any())).thenReturn(null);

      await pump(tester, const CategoryIconCompact('missing'));

      expect(find.byIcon(Icons.category_outlined), findsOneWidget);
    });

    testWidgets('honors the size parameter', (tester) async {
      when(() => cacheService.getCategoryById(any())).thenReturn(null);

      await pump(tester, const CategoryIconCompact('missing', size: 40));

      final box = tester.getSize(find.byType(CategoryIconCompact));
      expect(box, const Size(40, 40));
    });
  });

  group('CategoryIconCompactFromDefinition', () {
    testWidgets('renders directly from a definition without the cache', (
      tester,
    ) async {
      final category = CategoryTestUtils.createTestCategory(
        id: 'cat-4',
        name: 'Health',
        color: '#00FF00',
        icon: CategoryIcon.heartHealth,
      );

      await pump(tester, CategoryIconCompactFromDefinition(category));

      expect(find.byIcon(CategoryIcon.heartHealth.iconData), findsOneWidget);
      verifyNever(() => cacheService.getCategoryById(any()));
    });
  });
}
