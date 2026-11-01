import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/design_system/components/chips/design_system_chip.dart';
import 'package:lotti/features/design_system/theme/icon_tokens.dart';
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

  /// Chosen: the check every chosen chip carries.
  bool selected(WidgetTester tester, String id) =>
      tester
          .widget<DesignSystemChip>(find.byKey(FrontCategoryChipsKeys.chip(id)))
          .leadingIcon ==
      LottiIcons.confirm;

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

  testWidgets('"Answers from" leads; All is checked until a category is '
      'chosen, and a tap on it lets every chosen one go', (tester) async {
    final container = await pumpChips(tester, options: [colony, nests]);
    IconData? check(Key key) =>
        tester.widget<DesignSystemChip>(find.byKey(key)).leadingIcon;
    expect(find.text('Answers from'), findsOne);
    expect(check(FrontCategoryChipsKeys.all), LottiIcons.confirm);

    await tester.tap(find.byKey(FrontCategoryChipsKeys.chip('nests')));
    await tester.pump();
    expect(check(FrontCategoryChipsKeys.all), isNull);
    expect(check(FrontCategoryChipsKeys.chip('nests')), LottiIcons.confirm);

    await tester.tap(find.byKey(FrontCategoryChipsKeys.all));
    await tester.pump();
    expect(
      container.read(frontConversationCategoriesProvider.notifier).of('c-1'),
      isEmpty,
    );
    expect(check(FrontCategoryChipsKeys.all), LottiIcons.confirm);
  });

  testWidgets('a screen reader hears which chips are chosen', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpChips(tester, options: [colony, nests]);
    // The chip's own node, as a screen reader reaches it: by its words.
    bool chosen(String label) =>
        tester
            .getSemantics(find.bySemanticsLabel(label))
            .getSemanticsData()
            .flagsCollection
            .isSelected
            .toBoolOrNull() ??
        false;

    expect(chosen('All'), isTrue);
    expect(chosen('Colony'), isFalse);

    await tester.tap(find.byKey(FrontCategoryChipsKeys.chip('colony')));
    await tester.pump();
    expect(chosen('All'), isFalse);
    expect(chosen('Colony'), isTrue);
    semantics.dispose();
  });

  testWidgets('with a single category there is nothing to choose, so no '
      'chips', (tester) async {
    await pumpChips(tester, options: [colony]);

    expect(find.byType(DesignSystemChip), findsNothing);
  });
}
