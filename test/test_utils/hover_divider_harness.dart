import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/lists/design_system_grouped_list.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';

/// Helpers for the hover-divider treatment shared by the settings lists
/// (`HoverDividerIndex`): hovering a row fades the hairlines bracketing it
/// so the hovered row is never bisected.
///
/// The contract under test is always the same shape — drive a real mouse
/// pointer onto a row, then read the divider colours back — so both live
/// here rather than being restated in each list's test file.

/// Colours of the row dividers inside a grouped-list card, in render
/// order.
///
/// A run of `n` rows renders `n - 1` dividers: the last row never draws
/// one. A `null` entry means the row passed no explicit colour and the
/// `DesignSystemListItem` fell back to its own default — which the
/// production lists never do, since the shell always passes either the
/// design-system colour or [Colors.transparent].
///
/// Scoped to [of] (a [DesignSystemGroupedList] by default) so unrelated
/// chrome dividers elsewhere on the page cannot leak into the result.
List<Color?> listRowDividerColors(WidgetTester tester, {Finder? of}) => tester
    .widgetList<Divider>(
      find.descendant(
        of: of ?? find.byType(DesignSystemGroupedList),
        matching: find.byType(Divider),
      ),
    )
    .map((divider) => divider.color)
    .toList();

/// Where the pointer rests when it is meant to be hovering nothing.
///
/// Deliberately outside the window rather than at [Offset.zero]: the
/// origin is the top-left *inside* the view, where a back button or header
/// title usually sits, so parking there would hover a real widget and let
/// unrelated chrome leak into a test about list rows.
const _pointerParked = Offset(-1, -1);

/// Moves a mouse pointer onto [row] and settles the resulting rebuild.
///
/// The pointer is parked off-screen and then *moved* onto the row. Adding
/// it directly at the row would also report hover, but entering by motion
/// is what a real pointer does, and it keeps this identical to the
/// retarget move a test makes when it continues the same gesture onto the
/// next row — so the enter path under test is the same one either way.
///
/// Returns the gesture so a test can continue the same pointer — moving
/// it to another row (retargeting) or away from the list (clearing) —
/// which is the only way to reproduce the enter/leave pairing that
/// `HoverDividerIndex` has to stay robust against. The pointer is removed
/// automatically at the end of the test.
Future<TestGesture> hoverListRow(WidgetTester tester, Finder row) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.addPointer(location: _pointerParked);
  addTearDown(gesture.removePointer);
  await gesture.moveTo(tester.getCenter(row));
  await tester.pump();
  return gesture;
}

/// Moves [gesture] off every row, clearing the hover state.
Future<void> unhoverRows(WidgetTester tester, TestGesture gesture) async {
  await gesture.moveTo(_pointerParked);
  await tester.pump();
}

/// Asserts that a page's row forwards the whole divider treatment it is
/// handed — hovering [row] must fade the hairline bracketing it.
///
/// Expects a list of exactly two rows, which renders exactly one divider
/// (beneath the first): the smallest arrangement in which a fade is
/// observable. Fails if the row drops `dividerColor` (the shell's answer
/// never reaches the divider) or `onHoverChanged` (the shell never learns
/// about the hover).
///
/// This is the per-page half of the contract, identical for every list on
/// the `DefinitionsListPage` shell. The fade logic itself belongs to
/// `HoverDividerIndex` and the shell, each covered by its own test.
Future<void> expectRowFadesDividerOnHover(
  WidgetTester tester,
  Finder row,
) async {
  expect(
    listRowDividerColors(tester),
    [isNot(Colors.transparent)],
    reason: 'two rows should render one divider, un-faded while idle',
  );

  await hoverListRow(tester, row);

  expect(listRowDividerColors(tester), [Colors.transparent]);
}

/// The live [DesignSystemListItem] rows, in render order.
///
/// Lists that own the hover index directly (rather than going through a
/// shell) assert against the rows themselves, so that both halves of the
/// contract are visible: which dividers faded, and that `showDivider`
/// never moved.
List<DesignSystemListItem> listRows(WidgetTester tester) => tester
    .widgetList<DesignSystemListItem>(
      find.byType(DesignSystemListItem),
    )
    .toList();

/// [hoverListRow] addressing the row by render position rather than by
/// finder, for lists whose rows carry no distinctive text.
Future<TestGesture> hoverRowAt(WidgetTester tester, int index) =>
    hoverListRow(tester, find.byType(DesignSystemListItem).at(index));

/// Asserts that exactly the rows in [expected] have a faded divider, and
/// — just as importantly — that every row's `showDivider` is untouched.
///
/// The layout-stability half is the whole point of fading via colour: had
/// a list hidden the hairline with `showDivider` instead, rows below the
/// pointer would jump by 1 px on hover.
void expectFadedRows(
  List<DesignSystemListItem> rows,
  Set<int> expected, {

  /// Rows that legitimately draw no divider (typically the last one).
  Set<int> dividerless = const {},
}) {
  for (final (index, row) in rows.indexed) {
    expect(
      row.showDivider,
      !dividerless.contains(index),
      reason: 'showDivider must stay stable across hover (row $index)',
    );
    // A dividerless row draws no hairline, so whatever colour it was
    // handed is unobservable — the mixin still reports one for it, and
    // asserting on it would only pin down dead state.
    if (dividerless.contains(index)) continue;
    expect(
      row.dividerColor == Colors.transparent,
      expected.contains(index),
      reason: expected.contains(index)
          ? 'row $index should be faded'
          : 'row $index should keep its default divider',
    );
  }
}
