import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/design_system/components/selection/design_system_selection_row.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/front_agent/model/front_conversation.dart';
import 'package:lotti/features/front_agent/state/front_chat_category.dart';
import 'package:lotti/features/front_agent/state/front_conversation_providers.dart';
import 'package:lotti/features/front_agent/state/front_mention_categories.dart';
import 'package:lotti/features/front_agent/ui/front_category_chip.dart';
import 'package:material_ui/material_ui.dart';

import '../../../widget_test_utils.dart';
import '../../categories/test_utils.dart';

void main() {
  // The penguin world's categories she may see.
  final penguins = CategoryTestUtils.createTestCategory(
    id: 'cat-penguins',
    name: 'Penguin Operations',
    color: '#4AB6E8',
  );
  final habitat = CategoryTestUtils.createTestCategory(
    id: 'cat-habitat',
    name: 'Habitat Engineering',
    color: '#7BD3A0',
  );

  /// Pumps [child] with `c-1` open, last scoped to [stored].
  Future<ProviderContainer> pump(
    WidgetTester tester,
    Widget child, {
    Set<String> stored = const {},
    FutureOr<String> Function()? active,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        child,
        overrides: [
          frontMentionCategoriesProvider.overrideWithValue([
            penguins,
            habitat,
          ]),
          frontConversationsProvider.overrideWith(
            (ref) async => FrontConversationIndex(
              conversations: [
                FrontConversation(
                  id: 'c-1',
                  title: 'Plan the census',
                  lastActivity: DateTime(2026, 11, 11),
                  archived: false,
                  categoryIds: stored,
                ),
              ],
            ),
          ),
          frontActiveConversationProvider.overrideWith(
            (ref) async => (active ?? () => 'c-1')(),
          ),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();
    return ProviderScope.containerOf(tester.element(find.byWidget(child)));
  }

  group('FrontCategorySwatch', () {
    BoxDecoration decorationOf(WidgetTester tester) =>
        tester
                .widget<DecoratedBox>(
                  find.descendant(
                    of: find.byType(FrontCategorySwatch),
                    matching: find.byType(DecoratedBox),
                  ),
                )
                .decoration
            as BoxDecoration;

    testWidgets("a category's colour as a small rounded square", (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(FrontCategorySwatch(category: penguins)),
      );
      final tokens = tester
          .element(find.byType(FrontCategorySwatch))
          .designTokens;

      expect(decorationOf(tester).color, const Color(0xFF4AB6E8));
      expect(decorationOf(tester).border, isNull);
      expect(decorationOf(tester).borderRadius, isNotNull);
      expect(
        tester.getSize(find.byType(FrontCategorySwatch)),
        Size.square(tokens.spacing.step3),
      );
    });

    testWidgets('no category is its outline', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(const FrontCategorySwatch()),
      );

      expect(decorationOf(tester).color, isNull);
      expect(decorationOf(tester).border, isNotNull);
    });
  });

  group('FrontCategoryChip', () {
    testWidgets('says "Everything" for a conversation in no category, '
        'with the outline and a chevron', (tester) async {
      await pump(tester, const FrontCategoryChip());

      expect(find.text('Everything'), findsOne);
      expect(
        tester
            .widget<FrontCategorySwatch>(find.byType(FrontCategorySwatch))
            .category,
        isNull,
      );
      expect(find.byIcon(LottiIcons.chevronDown), findsOne);
    });

    testWidgets("names the conversation's category, and says what it is to "
        'assistive technology as one button', (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(tester, const FrontCategoryChip(), stored: {'cat-habitat'});

      expect(find.text('Habitat Engineering'), findsOne);
      expect(
        tester.getSemantics(find.byType(FrontCategoryChip)),
        isSemantics(
          label: 'Category for this chat: Habitat Engineering',
          isButton: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      semantics.dispose();
    });

    testWidgets('does nothing until a conversation is open', (tester) async {
      final pending = Completer<String>();
      await pump(
        tester,
        const FrontCategoryChip(),
        active: () => pending.future,
      );

      await tester.tap(find.byKey(FrontCategoryChipKeys.chip));
      await tester.pumpAndSettle();
      expect(find.byType(FrontCategorySheet), findsNothing);
      pending.complete('c-1');
    });

    testWidgets('assistive technology opens the sheet with the same tap', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pump(tester, FrontCategoryChip(key: UniqueKey()));

      tester.semantics.tap(
        find.semantics.byLabel('Category for this chat: Everything'),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FrontCategorySheet), findsOne);
      semantics.dispose();
    });

    testWidgets('a tap opens the sheet', (tester) async {
      await pump(tester, const FrontCategoryChip());

      await tester.tap(find.byKey(FrontCategoryChipKeys.chip));
      await tester.pumpAndSettle();

      expect(find.byType(FrontCategorySheet), findsOne);
      expect(find.text('Chat in a category'), findsOne);
    });
  });

  group('FrontCategorySheet', () {
    Future<ProviderContainer> openSheet(
      WidgetTester tester, {
      Set<String> stored = const {},
    }) async {
      final container = await pump(
        tester,
        const FrontCategoryChip(),
        stored: stored,
      );
      await tester.tap(find.byKey(FrontCategoryChipKeys.chip));
      await tester.pumpAndSettle();
      return container;
    }

    bool selected(WidgetTester tester, Key key) =>
        tester.widget<DesignSystemSelectionRow>(find.byKey(key)).selected;

    testWidgets('says what a category does, offers one row per category she '
        'may see and "Everything" last, and says what @ does', (tester) async {
      await openSheet(tester);

      expect(
        find.text(
          'From here on, the answers in this chat draw on this category only.',
        ),
        findsOne,
      );
      expect(
        find.text('Typing @ in a message narrows just that one question.'),
        findsOne,
      );
      final rows = tester
          .widgetList<DesignSystemSelectionRow>(
            find.byType(DesignSystemSelectionRow),
          )
          .map((row) => row.title)
          .toList();
      expect(rows, ['Penguin Operations', 'Habitat Engineering', 'Everything']);
      // Each row wears its category's square; "Everything" its outline.
      final swatches = tester
          .widgetList<FrontCategorySwatch>(
            find.descendant(
              of: find.byType(FrontCategorySheet),
              matching: find.byType(FrontCategorySwatch),
            ),
          )
          .map((swatch) => swatch.category)
          .toList();
      expect(swatches, <CategoryDefinition?>[penguins, habitat, null]);
    });

    testWidgets('checks the current one: "Everything" for none', (
      tester,
    ) async {
      await openSheet(tester);

      expect(selected(tester, FrontCategoryChipKeys.everything), isTrue);
      expect(
        selected(tester, FrontCategoryChipKeys.option('cat-penguins')),
        isFalse,
      );
    });

    testWidgets("checks the conversation's category", (tester) async {
      await openSheet(tester, stored: {'cat-penguins'});

      expect(
        selected(tester, FrontCategoryChipKeys.option('cat-penguins')),
        isTrue,
      );
      expect(selected(tester, FrontCategoryChipKeys.everything), isFalse);
    });

    testWidgets('picking a category scopes the open conversation to it and '
        'closes the sheet; the chip says so', (tester) async {
      final container = await openSheet(tester);

      await tester.tap(find.byKey(FrontCategoryChipKeys.option('cat-habitat')));
      await tester.pumpAndSettle();

      final pick = container.read(frontChatCategoryPickProvider)!;
      expect(pick.conversationId, 'c-1');
      expect(pick.categoryId, 'cat-habitat');
      expect(find.byType(FrontCategorySheet), findsNothing);
      expect(find.text('Habitat Engineering'), findsOne);
    });

    testWidgets('"Everything" takes a scope away', (tester) async {
      final container = await openSheet(tester, stored: {'cat-penguins'});

      await tester.tap(find.byKey(FrontCategoryChipKeys.everything));
      await tester.pumpAndSettle();

      final pick = container.read(frontChatCategoryPickProvider)!;
      expect(pick.categoryId, isNull);
      expect(find.text('Everything'), findsOne);
    });
  });
}
