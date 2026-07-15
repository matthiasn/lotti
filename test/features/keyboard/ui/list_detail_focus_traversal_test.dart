import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/keyboard/ui/list_detail_focus_traversal.dart';

import '../../../widget_test_utils.dart';

void main() {
  testWidgets('focusDetails skips the divider and enters the detail pane', (
    tester,
  ) async {
    final listFocusNode = FocusNode(debugLabel: 'test-list-row');
    final dividerFocusNode = FocusNode(debugLabel: 'test-divider');
    final detailFocusNode = FocusNode(debugLabel: 'test-detail-action');
    addTearDown(listFocusNode.dispose);
    addTearDown(dividerFocusNode.dispose);
    addTearDown(detailFocusNode.dispose);

    Widget buildTraversal() {
      return makeTestableWidgetNoScroll(
        ListDetailFocusTraversal(
          debugLabel: 'test-split',
          listPane: SizedBox(
            width: 240,
            child: TextButton(
              focusNode: listFocusNode,
              onPressed: () {},
              child: const Text('List row'),
            ),
          ),
          divider: Focus(
            focusNode: dividerFocusNode,
            child: const SizedBox(width: 3),
          ),
          detailPane: Align(
            alignment: Alignment.topLeft,
            child: TextButton(
              focusNode: detailFocusNode,
              onPressed: () {},
              child: const Text('Detail action'),
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(buildTraversal());

    final listContext = tester.element(find.text('List row'));
    listFocusNode.requestFocus();
    await tester.pump();
    final controller = ListDetailFocusTraversal.maybeOf(
      listContext,
    )!..focusDetails();
    await tester.pump();
    await tester.pump();

    expect(
      detailFocusNode.hasFocus,
      isTrue,
      reason:
          'primary focus: ${FocusManager.instance.primaryFocus?.debugLabel}; '
          'list focus: ${listFocusNode.hasFocus}',
    );
    expect(dividerFocusNode.hasFocus, isFalse);

    await tester.pumpWidget(buildTraversal());
    expect(
      ListDetailFocusTraversal.maybeOf(
        tester.element(find.text('List row')),
      ),
      same(controller),
    );
  });

  testWidgets('a queued detail-focus request is safe after disposal', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        ListDetailFocusTraversal(
          debugLabel: 'test-split',
          listPane: const SizedBox(width: 240, child: Text('List row')),
          divider: const SizedBox(width: 3),
          detailPane: TextButton(
            onPressed: () {},
            child: const Text('Detail action'),
          ),
        ),
      ),
    );

    ListDetailFocusTraversal.maybeOf(
      tester.element(find.text('List row')),
    )!.focusDetails();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'an empty detail pane retains focus until its controls render',
    (tester) async {
      final showDetailAction = ValueNotifier(false);
      final detailFocusNode = FocusNode(debugLabel: 'test-late-detail-action');
      addTearDown(showDetailAction.dispose);
      addTearDown(detailFocusNode.dispose);

      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          ListDetailFocusTraversal(
            debugLabel: 'test-split',
            listPane: const SizedBox(width: 240, child: Text('List row')),
            divider: const SizedBox(width: 3),
            detailPane: ValueListenableBuilder<bool>(
              valueListenable: showDetailAction,
              builder: (context, showAction, _) => showAction
                  ? TextButton(
                      focusNode: detailFocusNode,
                      onPressed: () {},
                      child: const Text('Late detail action'),
                    )
                  : const CircularProgressIndicator(),
            ),
          ),
        ),
      );

      ListDetailFocusTraversal.maybeOf(
        tester.element(find.text('List row')),
      )!.focusDetails();
      await tester.pump();
      await tester.pump();

      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'test-split-detail',
      );

      showDetailAction.value = true;
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      expect(detailFocusNode.hasFocus, isTrue);
    },
  );
}
