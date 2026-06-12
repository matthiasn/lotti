import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/features/categories/ui/widgets/category_icon_chip.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/utils/color.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';
import '../../test_utils.dart';

void main() {
  late MockEntitiesCacheService cache;

  setUp(() async {
    await setUpTestGetIt(
      additionalSetup: () {
        cache = MockEntitiesCacheService();
        getIt.registerSingleton<EntitiesCacheService>(cache);
      },
    );
  });

  tearDown(tearDownTestGetIt);

  Future<void> pumpChip(WidgetTester tester, Widget chip) async {
    await tester.pumpWidget(makeTestableWidgetNoScroll(Scaffold(body: chip)));
    await tester.pump();
  }

  DefinitionIconChip innerChip(WidgetTester tester) =>
      tester.widget<DefinitionIconChip>(find.byType(DefinitionIconChip));

  group('DefinitionIconChip', () {
    testWidgets('renders the icon when provided, never the letter', (
      tester,
    ) async {
      await pumpChip(
        tester,
        const DefinitionIconChip(
          background: Colors.black,
          icon: Icons.spa,
          name: 'Health',
        ),
      );

      expect(find.byIcon(Icons.spa), findsOneWidget);
      expect(find.text('H'), findsNothing);
    });

    testWidgets(
      'falls back to the uppercased first letter with a white foreground '
      'on a dark background',
      (tester) async {
        await pumpChip(
          tester,
          const DefinitionIconChip(
            background: Color(0xFF000033),
            name: 'health',
          ),
        );

        final letter = tester.widget<Text>(find.text('H'));
        expect(letter.style?.color, Colors.white);
      },
    );

    testWidgets('derives a black foreground on a light background', (
      tester,
    ) async {
      await pumpChip(
        tester,
        const DefinitionIconChip(
          background: Color(0xFFFFFFCC),
          name: 'apple',
        ),
      );

      final letter = tester.widget<Text>(find.text('A'));
      expect(letter.style?.color, Colors.black);
    });

    testWidgets('renders ? for an empty name', (tester) async {
      await pumpChip(
        tester,
        const DefinitionIconChip(background: Colors.black, name: ''),
      );

      expect(find.text('?'), findsOneWidget);
    });
  });

  group('CategoryIconChip (direct category)', () {
    testWidgets('renders the category icon on the category color', (
      tester,
    ) async {
      final category = CategoryTestUtils.createTestCategory(
        name: 'Fitness',
        color: '#FF0000',
        icon: CategoryIcon.fitness,
      );

      await pumpChip(tester, CategoryIconChip(category: category));

      expect(find.byIcon(Icons.fitness_center), findsOneWidget);
      expect(find.text('F'), findsNothing);
      expect(innerChip(tester).background, colorFromCssHex('#FF0000'));
    });

    testWidgets('renders the category initial when no icon is set', (
      tester,
    ) async {
      final category = CategoryTestUtils.createTestCategory(
        name: 'Work',
        color: '#FF0000',
      );

      await pumpChip(tester, CategoryIconChip(category: category));

      expect(find.text('W'), findsOneWidget);
      expect(innerChip(tester).background, colorFromCssHex('#FF0000'));
    });
  });

  group('CategoryIconChip.fromId', () {
    testWidgets(
      'unresolved id without letterFrom renders the neutral more_horiz chip',
      (tester) async {
        when(() => cache.getCategoryById(any())).thenReturn(null);

        await pumpChip(tester, const CategoryIconChip.fromId('missing'));

        expect(find.byIcon(Icons.more_horiz), findsOneWidget);

        final tokens = tester
            .element(find.byType(CategoryIconChip))
            .designTokens;
        expect(innerChip(tester).background, tokens.colors.background.level03);
        expect(innerChip(tester).foreground, tokens.colors.text.lowEmphasis);
      },
    );

    testWidgets(
      'unresolved id with letterFrom renders the item letter at '
      'mediumEmphasis on the neutral chip — no more_horiz glyph',
      (tester) async {
        when(() => cache.getCategoryById(any())).thenReturn(null);

        await pumpChip(
          tester,
          const CategoryIconChip.fromId('missing', letterFrom: 'Run 5k'),
        );

        expect(find.byIcon(Icons.more_horiz), findsNothing);
        expect(find.text('R'), findsOneWidget);

        final tokens = tester
            .element(find.byType(CategoryIconChip))
            .designTokens;
        expect(innerChip(tester).background, tokens.colors.background.level03);
        expect(
          innerChip(tester).foreground,
          tokens.colors.text.mediumEmphasis,
        );
      },
    );

    testWidgets(
      'resolved category with letterFrom renders the item letter on the '
      'category color even when the category has an icon',
      (tester) async {
        final category = CategoryTestUtils.createTestCategory(
          id: 'cat-health',
          name: 'Health',
          color: '#00FF00',
          icon: CategoryIcon.fitness,
        );
        when(() => cache.getCategoryById('cat-health')).thenReturn(category);

        await pumpChip(
          tester,
          const CategoryIconChip.fromId('cat-health', letterFrom: 'Run 5k'),
        );

        // The item's initial, never the category's icon or initial.
        expect(find.text('R'), findsOneWidget);
        expect(find.byIcon(Icons.fitness_center), findsNothing);
        expect(find.text('H'), findsNothing);
        expect(innerChip(tester).background, colorFromCssHex('#00FF00'));
      },
    );

    testWidgets(
      'resolved category without letterFrom keeps the category identity '
      '(icon on category color)',
      (tester) async {
        final category = CategoryTestUtils.createTestCategory(
          id: 'cat-health',
          name: 'Health',
          color: '#00FF00',
          icon: CategoryIcon.fitness,
        );
        when(() => cache.getCategoryById('cat-health')).thenReturn(category);

        await pumpChip(tester, const CategoryIconChip.fromId('cat-health'));

        expect(find.byIcon(Icons.fitness_center), findsOneWidget);
        expect(innerChip(tester).background, colorFromCssHex('#00FF00'));
      },
    );
  });
}
