import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_icon_action.dart';
import 'package:lotti/features/front_agent/state/front_chat_controller.dart';
import 'package:lotti/features/front_agent/state/front_draft_pages.dart';
import 'package:lotti/features/front_agent/ui/front_category_chip.dart';
import 'package:lotti/features/front_agent/ui/front_draft_pager.dart';
import 'package:material_ui/material_ui.dart';

import '../../../widget_test_utils.dart';

void main() {
  group('FrontDraftPager', () {
    late List<int> shown;

    setUp(() => shown = []);

    Future<void> pump(WidgetTester tester, {required int page}) =>
        tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            FrontDraftPager(page: page, count: 3, onShow: shown.add),
          ),
        );

    VoidCallback? onPressed(WidgetTester tester, Key key) =>
        tester.widget<DesignSystemIconAction>(find.byKey(key)).onPressed;

    testWidgets('shows which page is in the box, counting from one, and '
        'names it for assistive technology', (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(tester, page: 1);

      expect(find.text('2/3'), findsOneWidget);
      expect(find.bySemanticsLabel('Draft 2 of 3'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('the arrows show the page before and after', (tester) async {
      await pump(tester, page: 1);

      await tester.tap(find.byKey(FrontDraftPagerKeys.previous));
      await tester.tap(find.byKey(FrontDraftPagerKeys.next));

      expect(shown, [0, 2]);
    });

    testWidgets('no page before the first, nor after the last', (
      tester,
    ) async {
      await pump(tester, page: 0);
      expect(onPressed(tester, FrontDraftPagerKeys.previous), isNull);
      expect(onPressed(tester, FrontDraftPagerKeys.next), isNotNull);

      await pump(tester, page: 2);
      expect(onPressed(tester, FrontDraftPagerKeys.previous), isNotNull);
      expect(onPressed(tester, FrontDraftPagerKeys.next), isNull);
    });
  });

  group('frontComposerLeading', () {
    final paged = const FrontChatComposerState().withDraftPages(
      FrontDraftPages(const [
        FrontDraftPage('Also check the ridge nests'),
        FrontDraftPage('Count the chicks', editingMessageId: 'u1'),
      ], 1),
    );

    test('nothing to show leaves the box its helper text', () {
      expect(
        frontComposerLeading(
          category: false,
          composer: const FrontChatComposerState(),
          onShowPage: (_) {},
        ),
        isNull,
      );
    });

    test("the conversation's category alone is its chip, as it always "
        'was; with pages, the pager follows it', () {
      expect(
        frontComposerLeading(
          category: true,
          composer: const FrontChatComposerState(),
          onShowPage: (_) {},
        ),
        isA<FrontCategoryChip>(),
      );

      final row =
          frontComposerLeading(
                category: true,
                composer: paged,
                onShowPage: (_) {},
              )!
              as Row;
      expect(row.children.first, isA<FrontCategoryChip>());
      expect(
        row.children.last,
        isA<FrontDraftPager>()
            .having((p) => p.page, 'page', 1)
            .having((p) => p.count, 'count', 2),
      );
    });

    testWidgets('a box with pages shows the pager, at the page in it', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          frontComposerLeading(
            category: false,
            composer: paged,
            onShowPage: (_) {},
          )!,
        ),
      );

      expect(find.text('2/2'), findsOneWidget);
    });
  });
}
