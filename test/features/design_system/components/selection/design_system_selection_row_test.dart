import 'dart:ui' show CheckedState, SemanticsAction, Tristate;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/checkboxes/design_system_checkbox.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/components/selection/design_system_selection_row.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

void main() {
  testWidgets('single selection uses the shared selected band and check', (
    tester,
  ) async {
    await _pump(
      tester,
      DesignSystemSelectionRow(
        key: const Key('single-row'),
        title: 'In progress',
        type: DesignSystemSelectionRowType.singleSelect,
        selected: true,
        selectedLabel: 'Selected',
        onTap: () {},
      ),
    );

    final ink = tester.widget<Ink>(find.byType(Ink));
    final decoration = ink.decoration! as BoxDecoration;
    expect(decoration.color, dsTokensLight.colors.surface.selected);
    expect(find.text('Selected'), findsOneWidget);
    expect(find.byIcon(LottiIcons.confirm), findsOneWidget);

    final semantics = tester.getSemantics(find.byKey(const Key('single-row')));
    expect(semantics.flagsCollection.isSelected, Tristate.isTrue);
  });

  testWidgets('multi selection exposes one checked row action', (tester) async {
    var taps = 0;
    final handle = tester.ensureSemantics();

    await _pump(
      tester,
      DesignSystemSelectionRow(
        key: const Key('multi-row'),
        title: 'Design system',
        type: DesignSystemSelectionRowType.multiSelect,
        selected: true,
        onTap: () => taps++,
      ),
    );

    final semantics = tester.getSemantics(find.byKey(const Key('multi-row')));
    expect(semantics.flagsCollection.isChecked, CheckedState.isTrue);
    expect(semantics.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    expect(find.bySemanticsLabel('Design system'), findsOneWidget);
    expect(find.byType(DesignSystemCheckbox), findsOneWidget);

    await tester.tap(find.text('Design system'));
    await tester.pump();
    expect(taps, 1);
    handle.dispose();
  });

  group('a multi-select row says it is selected with its checkbox alone', () {
    DesignSystemSelectionRow row({
      required DesignSystemSelectionRowType type,
      Key key = const Key('row'),
    }) => DesignSystemSelectionRow(
      key: key,
      title: 'Labels',
      type: type,
      selected: true,
      onTap: () {},
    );

    testWidgets('no selected band', (tester) async {
      await _pump(tester, row(type: DesignSystemSelectionRowType.multiSelect));

      expect(fill(tester), Colors.transparent);
      final semantics = tester.getSemantics(find.byKey(const Key('row')));
      expect(semantics.flagsCollection.isChecked, CheckedState.isTrue);
      expect(find.byType(DesignSystemCheckbox), findsOneWidget);
    });

    testWidgets('no hover fill, where a single-select row gets one', (
      tester,
    ) async {
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);

      await _pump(
        tester,
        DesignSystemSelectionRow(
          key: const Key('row'),
          title: 'Labels',
          type: DesignSystemSelectionRowType.multiSelect,
          onTap: () {},
        ),
      );
      await mouse.moveTo(tester.getCenter(find.byKey(const Key('row'))));
      await tester.pump();
      expect(fill(tester), Colors.transparent);

      await _pump(
        tester,
        DesignSystemSelectionRow(
          key: const Key('single'),
          title: 'Labels',
          type: DesignSystemSelectionRowType.singleSelect,
          onTap: () {},
        ),
      );
      await mouse.moveTo(Offset.zero);
      await mouse.moveTo(tester.getCenter(find.byKey(const Key('single'))));
      await tester.pump();
      expect(fill(tester), isNot(Colors.transparent));
    });
  });

  testWidgets('navigation rows use a chevron and activate as one row', (
    tester,
  ) async {
    var opened = false;
    await _pump(
      tester,
      DesignSystemSelectionRow(
        title: 'Choose a provider',
        subtitle: 'Five providers',
        type: DesignSystemSelectionRowType.navigation,
        onTap: () => opened = true,
      ),
    );

    expect(find.byIcon(LottiIcons.chevronRight), findsOneWidget);
    expect(find.byIcon(LottiIcons.confirm), findsNothing);

    await tester.tap(find.text('Choose a provider'));
    await tester.pump();
    expect(opened, isTrue);
  });

  testWidgets('forwards the compact row size to the shared list item', (
    tester,
  ) async {
    await _pump(
      tester,
      DesignSystemSelectionRow(
        title: 'Status',
        subtitle: 'All',
        size: DesignSystemListItemSize.small,
        type: DesignSystemSelectionRowType.navigation,
        onTap: () {},
      ),
    );

    expect(
      tester
          .widget<DesignSystemListItem>(find.byType(DesignSystemListItem))
          .size,
      DesignSystemListItemSize.small,
    );
  });

  testWidgets('disabled row exposes its reason and cannot activate', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();

    await _pump(
      tester,
      const DesignSystemSelectionRow(
        key: Key('disabled-row'),
        title: 'Unavailable profile',
        subtitle: 'Connect its provider first',
        type: DesignSystemSelectionRowType.singleSelect,
        onTap: null,
      ),
    );

    final semantics = tester.getSemantics(
      find.byKey(const Key('disabled-row')),
    );
    expect(semantics.label, contains('Connect its provider first'));
    expect(semantics.flagsCollection.isEnabled, Tristate.isFalse);
    handle.dispose();
  });

  testWidgets('iconless action preserves the minimum interactive height', (
    tester,
  ) async {
    var taps = 0;
    await _pump(
      tester,
      DesignSystemSelectionRow(
        key: const Key('iconless-action'),
        title: 'Clear selection',
        type: DesignSystemSelectionRowType.action,
        onTap: () => taps++,
      ),
    );

    expect(
      tester.getSize(find.byKey(const Key('iconless-action'))).height,
      greaterThanOrEqualTo(TapTargets.minimum),
    );
    await tester.tap(find.byKey(const Key('iconless-action')));
    expect(taps, 1);
  });

  testWidgets('keyboard focus uses the token focus fill and outline', (
    tester,
  ) async {
    await _pump(
      tester,
      DesignSystemSelectionRow(
        title: 'Keyboard target',
        type: DesignSystemSelectionRowType.singleSelect,
        onTap: () {},
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    final ink = tester.widget<Ink>(find.byType(Ink));
    final decoration = ink.decoration! as BoxDecoration;
    expect(decoration.color, dsTokensLight.colors.surface.focusPressed);
    final border = decoration.border! as Border;
    expect(border.top.color, dsTokensLight.colors.interactive.enabled);
    expect(border.top.width, dsTokensLight.spacing.step1);
  });

  testWidgets('large text removes the title line cap', (tester) async {
    const title = 'A long project label that must remain fully readable';
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const SizedBox(
          width: 220,
          child: DesignSystemSelectionRow(
            title: title,
            type: DesignSystemSelectionRowType.singleSelect,
            onTap: null,
          ),
        ),
        theme: DesignSystemTheme.light(),
        mediaQueryData: const MediaQueryData(
          size: Size(320, 800),
          textScaler: TextScaler.linear(2),
        ),
      ),
    );

    final text = tester.widget<Text>(find.text(title));
    expect(text.maxLines, isNull);
    expect(text.overflow, TextOverflow.clip);
  });

  testWidgets('secondaryLine renders below the row at the title inset', (
    tester,
  ) async {
    await _pump(
      tester,
      DesignSystemSelectionRow(
        title: 'Steps',
        type: DesignSystemSelectionRowType.multiSelect,
        secondaryLine: const SizedBox(
          key: Key('secondary-line'),
          width: 40,
          height: 10,
        ),
        onTap: () {},
      ),
    );

    final itemRect = tester.getRect(find.byType(DesignSystemListItem));
    final lineRect = tester.getRect(find.byKey(const Key('secondary-line')));
    expect(lineRect.top, greaterThanOrEqualTo(itemRect.bottom));
    expect(lineRect.left - itemRect.left, dsTokensLight.spacing.step5);
  });

  testWidgets('a leading rail widens the secondaryLine title inset', (
    tester,
  ) async {
    await _pump(
      tester,
      DesignSystemSelectionRow(
        title: 'Steps',
        leading: const Icon(LottiIcons.flag),
        type: DesignSystemSelectionRowType.multiSelect,
        secondaryLine: const SizedBox(
          key: Key('secondary-line'),
          width: 40,
          height: 10,
        ),
        onTap: () {},
      ),
    );

    final itemRect = tester.getRect(find.byType(DesignSystemListItem));
    final lineRect = tester.getRect(find.byKey(const Key('secondary-line')));
    expect(
      lineRect.left - itemRect.left,
      dsTokensLight.spacing.step5 +
          dsTokensLight.spacing.step8 +
          dsTokensLight.spacing.step3,
    );
  });

  testWidgets(
    'secondaryLine content sits outside the row tap target and keeps its '
    'own semantics',
    (tester) async {
      var rowTaps = 0;
      var adjustTaps = 0;
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        DesignSystemSelectionRow(
          title: 'Steps',
          type: DesignSystemSelectionRowType.multiSelect,
          secondaryLine: TextButton(
            onPressed: () => adjustTaps++,
            child: const Text('Adjust'),
          ),
          onTap: () => rowTaps++,
        ),
      );

      // Tapping the secondary line activates its own control, never the row.
      await tester.tap(find.text('Adjust'));
      await tester.pump();
      expect(adjustTaps, 1);
      expect(rowTaps, 0);

      // The embedded control is its own semantic button, not merged into
      // the row's semantics container.
      expect(
        tester.getSemantics(find.text('Adjust')),
        matchesSemantics(
          label: 'Adjust',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
          isFocusable: true,
          hasFocusAction: true,
        ),
      );

      await tester.tap(find.text('Steps'));
      await tester.pump();
      expect(rowTaps, 1);
      expect(adjustTaps, 1);
      handle.dispose();
    },
  );

  group('secondary action', () {
    const actionKey = Key('row-action');

    DesignSystemSelectionRow actionRow({
      required VoidCallback? onTap,
      VoidCallback? onAction,
      bool selected = false,
      bool withAction = true,
      bool showSelectedMarker = true,
      String id = 'action-row',
    }) => DesignSystemSelectionRow(
      key: Key(id),
      title: 'Garden',
      type: DesignSystemSelectionRowType.singleSelect,
      selected: selected,
      showSelectedMarker: showSelectedMarker,
      trailing: Text('Active', key: Key('badge-$id')),
      secondaryAction: withAction
          ? DesignSystemSelectionRowAction(
              key: actionKey,
              label: 'Open Garden',
              onPressed: onAction ?? () {},
            )
          : null,
      onTap: onTap,
    );

    testWidgets('a tap on the action fires it, never the row, and the other '
        'way round', (tester) async {
      var rowTaps = 0;
      var actionTaps = 0;
      await _pump(
        tester,
        actionRow(onTap: () => rowTaps++, onAction: () => actionTaps++),
      );

      await tester.tap(find.byKey(actionKey));
      await tester.pump();
      expect((rowTaps, actionTaps), (0, 1));

      await tester.tap(find.text('Garden'));
      await tester.pump();
      expect((rowTaps, actionTaps), (1, 1));
    });

    testWidgets('the action is its own button beside the row', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, actionRow(onTap: () {}));

      // The row excludes its visual subtree from semantics, so an action
      // inside it would be unreachable; beside it, it keeps its node.
      expect(
        tester.getSemantics(find.byKey(actionKey)),
        matchesSemantics(
          label: 'Open Garden',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Garden')),
        matchesSemantics(
          label: 'Garden',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasSelectedState: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('does not grow the row', (tester) async {
      await _pump(tester, actionRow(onTap: () {}, withAction: false));
      final plainHeight = tester
          .getSize(find.byKey(const Key('action-row')))
          .height;

      await _pump(tester, actionRow(onTap: () {}));
      expect(
        tester.getSize(find.byKey(const Key('action-row'))).height,
        plainHeight,
      );
    });

    testWidgets('puts a full-height open-page target at the trailing edge, '
        'not the navigation chevron', (tester) async {
      await _pump(tester, actionRow(onTap: () {}, selected: true));

      final rowRect = tester.getRect(find.byKey(const Key('action-row')));
      final target = tester.getRect(find.byKey(actionKey));
      final chevron = find.byIcon(LottiIcons.openPage);

      expect(find.byIcon(LottiIcons.chevronRight), findsNothing);

      expect(target.right, rowRect.right);
      expect(target.width, TapTargets.minimum);
      expect((target.top, target.bottom), (rowRect.top, rowRect.bottom));
      expect(tester.widget<Icon>(chevron).size, dsTokensLight.spacing.step6);
      expect(
        tester.widget<Icon>(chevron).color,
        dsTokensLight.colors.text.mediumEmphasis,
      );
    });

    testWidgets('without its marker, a selected row lets its band carry the '
        'selection, so its trailing metadata lines up with an unselected row', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          SizedBox(
            width: dsTokensLight.spacing.step13 * 2,
            child: Column(
              children: [
                actionRow(
                  onTap: () {},
                  selected: true,
                  showSelectedMarker: false,
                  id: 'picked',
                ),
                actionRow(
                  onTap: () {},
                  showSelectedMarker: false,
                  id: 'other',
                ),
              ],
            ),
          ),
          theme: DesignSystemTheme.light(),
        ),
      );

      expect(find.byIcon(LottiIcons.confirm), findsNothing);
      expect(
        tester.getRect(find.byKey(const Key('badge-picked'))).right,
        tester.getRect(find.byKey(const Key('badge-other'))).right,
      );
      final handle = tester.ensureSemantics();
      // The picked row comes first; selection stays in its semantics.
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('Garden').first)
            .flagsCollection
            .isSelected,
        Tristate.isTrue,
      );
      handle.dispose();
    });

    testWidgets('the selected band runs under the segment, and only on a '
        'selected row', (tester) async {
      Finder bandUnderSegment() => find.ancestor(
        of: find.byKey(actionKey),
        matching: find.byWidgetPredicate(
          (w) =>
              w is ColoredBox &&
              w.color == dsTokensLight.colors.surface.selected,
        ),
      );

      await _pump(tester, actionRow(onTap: () {}, selected: true));
      expect(bandUnderSegment(), findsOneWidget);
      // The band is painted once, under both targets: the content's own fill
      // stays clear, so a translucent band never doubles over the content.
      expect(fill(tester), Colors.transparent);

      await _pump(tester, actionRow(onTap: () {}));
      expect(bandUnderSegment(), findsNothing);
    });

    testWidgets('no rule separates the action from the row', (tester) async {
      await _pump(tester, actionRow(onTap: () {}));

      expect(
        find.byWidgetPredicate(
          (w) =>
              w is ColoredBox &&
              w.color == dsTokensLight.colors.decorative.level01,
        ),
        findsNothing,
      );
    });

    group('hover', () {
      Finder hoverUnderAction() => find.ancestor(
        of: find.byKey(actionKey),
        matching: find.byWidgetPredicate(
          (w) =>
              w is ColoredBox && w.color == dsTokensLight.colors.surface.hover,
        ),
      );

      Future<TestGesture> mouseAt(WidgetTester tester, Offset at) async {
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        addTearDown(mouse.removePointer);
        await mouse.addPointer(location: Offset.zero);
        await mouse.moveTo(at);
        await tester.pump();
        return mouse;
      }

      testWidgets('over the content, lights the full width, the action '
          'included, and clears on exit', (tester) async {
        await _pump(tester, actionRow(onTap: () {}));
        expect(hoverUnderAction(), findsNothing);

        final mouse = await mouseAt(
          tester,
          tester.getCenter(find.text('Garden')),
        );
        expect(hoverUnderAction(), findsOneWidget);
        // One fill, not the content's own on top of the row's.
        expect(fill(tester), Colors.transparent);

        await mouse.moveTo(
          tester.getBottomLeft(find.byType(Scaffold)) - const Offset(-1, 1),
        );
        await tester.pump();
        expect(hoverUnderAction(), findsNothing);
      });

      testWidgets('over the action, keeps the row lit', (tester) async {
        await _pump(tester, actionRow(onTap: () {}));
        await mouseAt(tester, tester.getCenter(find.byKey(actionKey)));

        expect(hoverUnderAction(), findsOneWidget);
      });

      testWidgets('the selected band wins over hover', (tester) async {
        await _pump(tester, actionRow(onTap: () {}, selected: true));
        await mouseAt(tester, tester.getCenter(find.text('Garden')));

        expect(hoverUnderAction(), findsNothing);
      });

      testWidgets('a disabled row does not light', (tester) async {
        await _pump(tester, actionRow(onTap: null));
        await mouseAt(tester, tester.getCenter(find.text('Garden')));

        expect(hoverUnderAction(), findsNothing);
      });
    });

    testWidgets('a disabled row disables its action', (tester) async {
      var actionTaps = 0;
      await _pump(
        tester,
        actionRow(onTap: null, onAction: () => actionTaps++),
      );

      await tester.tap(find.byKey(actionKey), warnIfMissed: false);
      await tester.pump();
      expect(actionTaps, 0);
      expect(
        tester.widget<Icon>(find.byIcon(LottiIcons.openPage)).color,
        dsTokensLight.colors.text.lowEmphasis,
      );
    });
  });
}

/// The list item's own fill — the content target's surface.
Color? fill(WidgetTester tester) =>
    (tester.widget<Ink>(find.byType(Ink)).decoration! as BoxDecoration).color;

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    makeTestableWidgetWithScaffold(
      SizedBox(width: dsTokensLight.spacing.step13 * 2, child: child),
      theme: DesignSystemTheme.light(),
    ),
  );
}
