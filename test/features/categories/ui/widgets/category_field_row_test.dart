import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/ui/widgets/category_field_row.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

void main() {
  final at = DateTime(2026, 8, 4);
  final family = CategoryDefinition(
    id: 'cat-1',
    name: 'Family',
    private: false,
    active: true,
    color: '#00FF00',
    createdAt: at,
    updatedAt: at,
    vectorClock: null,
  );
  late MockEntitiesCacheService cache;
  late List<String?> reported;

  setUp(() async {
    reported = [];
    cache = MockEntitiesCacheService();
    when(() => cache.getCategoryById(any())).thenReturn(null);
    when(() => cache.getCategoryById('cat-1')).thenReturn(family);
    when(() => cache.sortedCategories).thenReturn([family]);
    await setUpTestGetIt(
      additionalSetup: () =>
          getIt.registerSingleton<EntitiesCacheService>(cache),
    );
  });
  tearDown(tearDownTestGetIt);

  Future<void> pump(WidgetTester tester, String? categoryId) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        CategoryFieldRow(categoryId: categoryId, onChanged: reported.add),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('with no category it invites a pick: the hint in the quiet '
      'ink, no dot, and the chevron that says it is a selector', (
    tester,
  ) async {
    await pump(tester, null);

    final hint = tester.widget<Text>(find.text('Select a category'));
    final tokens = tester.element(find.byType(CategoryFieldRow)).designTokens;
    expect(hint.style?.color, tokens.colors.text.lowEmphasis);
    expect(find.byKey(const ValueKey('category-field-dot')), findsNothing);
    expect(
      find.byKey(const ValueKey('category-field-chevron')),
      findsOneWidget,
    );
  });

  testWidgets('a category reads by name, led by a dot in its own colour', (
    tester,
  ) async {
    await pump(tester, 'cat-1');

    expect(find.text('Family'), findsOneWidget);
    final dot = tester.widget<Container>(
      find.byKey(const ValueKey('category-field-dot')),
    );
    expect(
      (dot.decoration! as BoxDecoration).color,
      const Color(0xFF00FF00),
    );
  });

  testWidgets('a tap opens the shared picker and reports the pick', (
    tester,
  ) async {
    await pump(tester, null);

    await tester.tap(find.byKey(const ValueKey('category-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Family').last);
    await tester.pumpAndSettle();

    expect(reported, ['cat-1']);
  });

  testWidgets('dismissing the picker changes nothing', (tester) async {
    await pump(tester, 'cat-1');

    await tester.tap(find.byKey(const ValueKey('category-field')));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();

    expect(reported, isEmpty);
  });
}
