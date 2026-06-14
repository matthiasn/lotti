import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/checkboxes/design_system_checkbox.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/widgets/picker/entity_picker_sheet.dart';

import '../../test_helper.dart';

/// Direct tests for the feature-agnostic [EntityPickerSheet]. The category and
/// label adapters cover their own wiring; this file exercises the generic body
/// itself with synthetic entries — including the rows the adapters never emit
/// (disabled items, dividers) so every branch is covered at the source.
void main() {
  PickerItem item(
    String id, {
    String? title,
    String? subtitle,
    String? semanticLabel,
    bool enabled = true,
  }) => PickerItem(
    id: id,
    rowKey: ValueKey('row-$id'),
    leading: const SizedBox(width: 24, height: 24),
    title: title ?? id,
    subtitle: subtitle,
    semanticLabel: semanticLabel,
    enabled: enabled,
  );

  Future<void> pumpSheet(
    WidgetTester tester, {
    required PickerMode mode,
    required List<PickerEntry> Function(String query) entriesBuilder,
    String? selectedId,
    ValueNotifier<Set<String>>? staged,
    void Function(String id)? onPick,
    Future<String?> Function(String query)? createFromQuery,
    bool Function(String query)? shouldShowCreate,
  }) async {
    await tester.pumpWidget(
      WidgetTestBench(
        child: Material(
          child: EntityPickerSheet(
            mode: mode,
            entriesBuilder: entriesBuilder,
            searchHintText: 'Search',
            emptyMessage: 'Nothing here',
            selectedId: selectedId,
            stagedNotifier: staged,
            onPick: onPick,
            createFromQuery: createFromQuery,
            shouldShowCreate: shouldShowCreate,
            createRowKey: const ValueKey('create'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // The title color the row applies for a given row key.
  Color titleColor(WidgetTester tester, String rowId) {
    final text = tester.widget<Text>(
      find.descendant(
        of: find.byKey(ValueKey('row-$rowId')),
        matching: find.text(rowId),
      ),
    );
    return text.style!.color!;
  }

  DsTokens tokensOf(WidgetTester tester) =>
      tester.element(find.byType(EntityPickerSheet)).designTokens;

  group('single mode', () {
    testWidgets('renders items and a divider, applies the tapped id', (
      tester,
    ) async {
      String? picked;
      await pumpSheet(
        tester,
        mode: PickerMode.single,
        onPick: (id) => picked = id,
        entriesBuilder: (_) => [
          item('alpha'),
          const PickerDivider(),
          item('beta'),
        ],
      );

      expect(find.text('alpha'), findsOneWidget);
      expect(find.text('beta'), findsOneWidget);
      expect(find.byType(Divider), findsOneWidget);

      await tester.tap(find.text('beta'));
      await tester.pump();
      expect(picked, 'beta');
    });

    testWidgets('the selected id shows a trailing check, others do not', (
      tester,
    ) async {
      await pumpSheet(
        tester,
        mode: PickerMode.single,
        selectedId: 'beta',
        entriesBuilder: (_) => [item('alpha'), item('beta')],
      );

      expect(
        find.descendant(
          of: find.byKey(const ValueKey('row-beta')),
          matching: find.byIcon(Icons.check_rounded),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('row-alpha')),
          matching: find.byIcon(Icons.check_rounded),
        ),
        findsNothing,
      );
    });

    testWidgets('Enter applies the first filtered item', (tester) async {
      String? picked;
      await pumpSheet(
        tester,
        mode: PickerMode.single,
        onPick: (id) => picked = id,
        entriesBuilder: (query) => [
          for (final id in ['alpha', 'beta'])
            if (query.isEmpty || id.contains(query)) item(id),
        ],
      );

      await tester.enterText(find.byType(TextField), 'bet');
      await tester.pump();
      await tester.showKeyboard(find.byType(TextField));
      await tester.testTextInput.receiveAction(TextInputAction.search);

      expect(picked, 'beta');
    });
  });

  group('disabled rows', () {
    testWidgets('a disabled row is not tappable and is dimmed', (tester) async {
      String? picked;
      await pumpSheet(
        tester,
        mode: PickerMode.single,
        onPick: (id) => picked = id,
        entriesBuilder: (_) => [
          item('on'),
          item('off', enabled: false),
        ],
      );

      await tester.tap(find.text('off'));
      await tester.pump();
      // The disabled row swallows the tap: onPick was never called.
      expect(picked, isNull);

      final tokens = tokensOf(tester);
      // The disabled title is rendered with the low-emphasis token, the
      // enabled one with high-emphasis — a real visual distinction.
      expect(titleColor(tester, 'off'), tokens.colors.text.lowEmphasis);
      expect(titleColor(tester, 'on'), tokens.colors.text.highEmphasis);
    });

    testWidgets('a disabled row announces a disabled semantics state', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpSheet(
        tester,
        mode: PickerMode.single,
        entriesBuilder: (_) => [item('off', enabled: false)],
      );

      final node = tester
          .getSemantics(find.byKey(const ValueKey('row-off')))
          .getSemanticsData()
          .flagsCollection;
      expect(node.isEnabled, Tristate.isFalse);

      handle.dispose();
    });
  });

  group('multi mode', () {
    testWidgets('checkbox toggles the staged set', (tester) async {
      final staged = ValueNotifier<Set<String>>({});
      addTearDown(staged.dispose);

      await pumpSheet(
        tester,
        mode: PickerMode.multi,
        staged: staged,
        entriesBuilder: (_) => [item('alpha'), item('beta')],
      );

      await tester.tap(find.text('alpha'));
      await tester.pump();
      expect(staged.value, {'alpha'});

      await tester.tap(find.text('alpha'));
      await tester.pump();
      expect(staged.value, isEmpty);
    });

    testWidgets('a seeded id renders its checkbox as checked', (tester) async {
      final staged = ValueNotifier<Set<String>>({'beta'});
      addTearDown(staged.dispose);

      await pumpSheet(
        tester,
        mode: PickerMode.multi,
        staged: staged,
        entriesBuilder: (_) => [item('alpha'), item('beta')],
      );

      bool? checked(String id) => tester
          .widget<DesignSystemCheckbox>(
            find.descendant(
              of: find.byKey(ValueKey('row-$id')),
              matching: find.byType(DesignSystemCheckbox),
            ),
          )
          .value;
      expect(checked('beta'), isTrue);
      expect(checked('alpha'), isFalse);
    });
  });

  group('empty + create', () {
    testWidgets('shows the empty message when there are no items', (
      tester,
    ) async {
      await pumpSheet(
        tester,
        mode: PickerMode.single,
        entriesBuilder: (_) => const [],
      );

      expect(find.text('Nothing here'), findsOneWidget);
    });

    testWidgets('single create picks the returned id', (tester) async {
      String? picked;
      await pumpSheet(
        tester,
        mode: PickerMode.single,
        onPick: (id) => picked = id,
        createFromQuery: (query) async => 'created-$query',
        shouldShowCreate: (query) => query.isNotEmpty,
        entriesBuilder: (_) => const [],
      );

      await tester.enterText(find.byType(TextField), 'new');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('create')));
      await tester.pump();

      expect(picked, 'created-new');
    });

    testWidgets('multi create stages the new id and clears the query', (
      tester,
    ) async {
      final staged = ValueNotifier<Set<String>>({});
      addTearDown(staged.dispose);

      await pumpSheet(
        tester,
        mode: PickerMode.multi,
        staged: staged,
        createFromQuery: (query) async => 'created-$query',
        shouldShowCreate: (query) => query.isNotEmpty,
        entriesBuilder: (_) => const [],
      );

      await tester.enterText(find.byType(TextField), 'new');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('create')));
      await tester.pump();

      expect(staged.value, {'created-new'});
      // The query was cleared, so the stale create row is gone.
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(find.byKey(const ValueKey('create')), findsNothing);
    });
  });

  group('semantics', () {
    testWidgets('the row announces its explicit semanticLabel', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpSheet(
        tester,
        mode: PickerMode.single,
        entriesBuilder: (_) => [
          item('alpha', title: 'Alpha', semanticLabel: 'Alpha, favorite'),
        ],
      );

      final node = tester.getSemantics(find.byKey(const ValueKey('row-alpha')));
      expect(node.label, 'Alpha, favorite');

      handle.dispose();
    });
  });
}
