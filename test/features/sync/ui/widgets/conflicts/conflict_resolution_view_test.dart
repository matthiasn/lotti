import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/sync/ui/pages/conflicts/conflict_detail_shared.dart';
import 'package:lotti/features/sync/ui/widgets/conflicts/conflict_resolution_view.dart';
import 'package:lotti/features/sync/ui/widgets/conflicts/entry_field_diff.dart';

import '../../../../../widget_test_utils.dart';
import 'conflict_test_entities.dart';

void main() {
  // Captured callback arguments.
  ConflictSide? keptSide;
  ConflictSide? combineBase;
  Map<EntryField, ConflictSide>? combineChoices;

  Future<void> pump(WidgetTester tester, EntryDiff diff) async {
    keptSide = null;
    combineBase = null;
    combineChoices = null;
    await tester.pumpWidget(
      makeTestableWidget(
        ConflictResolutionView(
          diff: diff,
          onKeepSide: (side) async => keptSide = side,
          onCombine: ({required baseSide, required choices}) async {
            combineBase = baseSide;
            combineChoices = choices;
          },
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> tapButton(WidgetTester tester, String label) async {
    final finder = find.widgetWithText(DesignSystemButton, label);
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pump();
  }

  group('choosing mode', () {
    testWidgets('Use this device keeps the local side', (tester) async {
      await pump(
        tester,
        computeEntryDiff(entryOf(text: 'a'), entryOf(text: 'b')),
      );
      await tapButton(tester, 'Use this device');
      expect(keptSide, ConflictSide.local);
    });

    testWidgets('Use from sync keeps the remote side', (tester) async {
      await pump(
        tester,
        computeEntryDiff(entryOf(text: 'a'), entryOf(text: 'b')),
      );
      await tapButton(tester, 'Use from sync');
      expect(keptSide, ConflictSide.remote);
    });

    testWidgets('Combine is recommended when several fields differ', (
      tester,
    ) async {
      await pump(
        tester,
        computeEntryDiff(
          entryOf(text: 'a', starred: true),
          entryOf(text: 'b', starred: false),
        ),
      );
      expect(find.text('Recommended'), findsOneWidget);
    });

    testWidgets('Combine is not recommended for a single-field difference', (
      tester,
    ) async {
      await pump(
        tester,
        computeEntryDiff(entryOf(starred: true), entryOf(starred: false)),
      );
      expect(find.text('Recommended'), findsNothing);
    });
  });

  group('combine mode', () {
    testWidgets('applying with defaults combines from the local base', (
      tester,
    ) async {
      await pump(
        tester,
        computeEntryDiff(entryOf(starred: true), entryOf(starred: false)),
      );
      await tester.tap(
        find.widgetWithIcon(DesignSystemButton, Icons.merge_rounded),
      );
      await tester.pump();

      // Combine surface is now shown.
      expect(find.text('Start from'), findsOneWidget);

      await tapButton(tester, 'Apply combined');

      expect(combineBase, ConflictSide.local);
      expect(combineChoices, {EntryField.starred: ConflictSide.local});
    });

    testWidgets('changing the base side flips every field choice', (
      tester,
    ) async {
      await pump(
        tester,
        computeEntryDiff(entryOf(starred: true), entryOf(starred: false)),
      );
      await tester.tap(
        find.widgetWithIcon(DesignSystemButton, Icons.merge_rounded),
      );
      await tester.pump();

      // The first "Use from sync" toggle is the base-side selector.
      await tester.tap(
        find.widgetWithText(DesignSystemButton, 'Use from sync').first,
      );
      await tester.pump();

      await tapButton(tester, 'Apply combined');

      expect(combineBase, ConflictSide.remote);
      expect(combineChoices, {EntryField.starred: ConflictSide.remote});
    });

    testWidgets('toggling one field overrides only that field, not the base', (
      tester,
    ) async {
      await pump(
        tester,
        computeEntryDiff(entryOf(starred: true), entryOf(starred: false)),
      );
      await tester.tap(
        find.widgetWithIcon(DesignSystemButton, Icons.merge_rounded),
      );
      await tester.pump();

      // The *second* "Use from sync" is the per-field toggle (the first is the
      // base-side selector); tapping it pulls just that field from remote.
      final fieldToggle = find
          .widgetWithText(DesignSystemButton, 'Use from sync')
          .at(1);
      await tester.ensureVisible(fieldToggle);
      await tester.tap(fieldToggle);
      await tester.pump();

      await tapButton(tester, 'Apply combined');

      expect(combineBase, ConflictSide.local);
      expect(combineChoices, {EntryField.starred: ConflictSide.remote});
    });

    testWidgets('Back returns from combine to the choosing surface', (
      tester,
    ) async {
      await pump(
        tester,
        computeEntryDiff(entryOf(starred: true), entryOf(starred: false)),
      );
      await tester.tap(
        find.widgetWithIcon(DesignSystemButton, Icons.merge_rounded),
      );
      await tester.pump();
      expect(find.text('Start from'), findsOneWidget);

      await tapButton(tester, 'Back');

      // We are back on the choosing surface: the combine header is gone and the
      // Combine entry-point button is offered again.
      expect(find.text('Start from'), findsNothing);
      expect(
        find.widgetWithIcon(DesignSystemButton, Icons.merge_rounded),
        findsOneWidget,
      );
    });
  });

  group('type change', () {
    testWidgets('hides Combine and offers a binary choice', (tester) async {
      await pump(tester, computeEntryDiff(entryOf(), taskOf()));

      expect(
        find.widgetWithIcon(DesignSystemButton, Icons.merge_rounded),
        findsNothing,
      );
      expect(find.text('Use this device'), findsOneWidget);
      expect(find.text('Use from sync'), findsOneWidget);
    });
  });

  group('delete-vs-edit', () {
    testWidgets('keeps the edited (remote) side when local was deleted', (
      tester,
    ) async {
      final diff = computeEntryDiff(
        entryOf(text: 'hello', deletedAt: DateTime(2024, 3, 15, 13)),
        entryOf(text: 'hello'),
      );
      expect(diff.shape, ConflictShape.deletedOnLocal);

      await pump(tester, diff);

      expect(find.text('Deleted on one device'), findsOneWidget);
      await tapButton(tester, 'Keep the edited version');
      expect(keptSide, ConflictSide.remote);
    });

    testWidgets('confirm deletion keeps the deleted side', (tester) async {
      final diff = computeEntryDiff(
        entryOf(text: 'hello'),
        entryOf(text: 'hello', deletedAt: DateTime(2024, 3, 15, 13)),
      );
      expect(diff.shape, ConflictShape.deletedOnRemote);

      await pump(tester, diff);
      await tapButton(tester, 'Confirm deletion');
      expect(keptSide, ConflictSide.remote);
    });
  });
}
