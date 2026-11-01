import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/design_system/components/chips/design_system_chip.dart';
import 'package:lotti/features/front_agent/state/front_category_scope.dart';
import 'package:lotti/features/front_agent/state/front_conversation_providers.dart';
import 'package:lotti/features/front_agent/ui/front_category_chips.dart';
import 'package:material_ui/material_ui.dart';

import '../../../widget_test_utils.dart';
import '../../categories/test_utils.dart';

void main() {
  final colony = CategoryTestUtils.createTestCategory(
    id: 'colony',
    name: 'Colony',
  );
  final nests = CategoryTestUtils.createTestCategory(
    id: 'nests',
    name: 'Nests',
  );

  Future<ProviderContainer> pumpChips(
    WidgetTester tester, {
    required List<CategoryDefinition> options,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const Scaffold(body: FrontCategoryChips()),
        overrides: [
          frontCategoryOptionsProvider.overrideWith((ref) => options),
          frontActiveConversationProvider.overrideWith((ref) async => 'c-1'),
        ],
      ),
    );
    await tester.pump();
    return ProviderScope.containerOf(
      tester.element(find.byType(FrontCategoryChips)),
    );
  }

  bool selected(WidgetTester tester, String id) => tester
      .widget<DesignSystemChip>(find.byKey(FrontCategoryChipsKeys.chip(id)))
      .selected;

  testWidgets('a chip chooses its category for the open conversation, and '
      'a second tap lets it go', (tester) async {
    final container = await pumpChips(tester, options: [colony, nests]);
    expect(find.text('Colony'), findsOne);
    expect(find.text('Nests'), findsOne);
    expect(selected(tester, 'colony'), isFalse);

    await tester.tap(find.byKey(FrontCategoryChipsKeys.chip('colony')));
    await tester.pump();
    expect(selected(tester, 'colony'), isTrue);
    expect(
      container.read(frontConversationCategoriesProvider.notifier).of('c-1'),
      {'colony'},
    );

    await tester.tap(find.byKey(FrontCategoryChipsKeys.chip('colony')));
    await tester.pump();
    expect(selected(tester, 'colony'), isFalse);
  });

  testWidgets('with a single category there is nothing to choose, so no '
      'chips', (tester) async {
    await pumpChips(tester, options: [colony]);

    expect(find.byType(DesignSystemChip), findsNothing);
  });
}
