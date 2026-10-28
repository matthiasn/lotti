import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/glass_strip.dart';
import 'package:lotti/features/design_system/components/toggles/design_system_toggle.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tasks/ui/saved_filters/mobile/saved_task_filters_sheet_bar.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../widget_test_utils.dart';

const _editKey = Key('edit-toggle');

void main() {
  group('SavedTaskFiltersSheetBar', () {
    Future<({List<bool> flips, List<void> edits})> pumpBar(
      WidgetTester tester, {
      bool pinnedOnly = false,
      bool editing = false,
    }) async {
      final flips = <bool>[];
      final edits = <void>[];
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Align(
            alignment: Alignment.topCenter,
            child: SavedTaskFiltersSheetBar(
              pinnedOnly: pinnedOnly,
              onPinnedOnlyChanged: flips.add,
              editing: editing,
              onEditToggled: () => edits.add(null),
              editToggleKey: _editKey,
            ),
          ),
        ),
      );
      return (flips: flips, edits: edits);
    }

    testWidgets('sits on the app glass, docked to the top', (tester) async {
      await pumpBar(tester);

      final strip = tester.widget<DesignSystemGlassStrip>(
        find.byKey(SavedTaskFiltersSheetBarKeys.bar),
      );
      expect(strip.dock, DesignSystemGlassStripDock.top);
    });

    testWidgets('the switch shows the current state and asks to flip it', (
      tester,
    ) async {
      final bench = await pumpBar(tester, pinnedOnly: true);

      final toggle = tester.widget<DesignSystemToggle>(
        find.byKey(SavedTaskFiltersSheetBarKeys.pinnedOnly),
      );
      expect(toggle.value, isTrue);
      expect(toggle.label, 'Pinned only');

      await tester.tap(find.byKey(SavedTaskFiltersSheetBarKeys.pinnedOnly));
      expect(bench.flips, [false]);
    });

    testWidgets(
      'the space around the switch flips it too, a full-height target',
      (tester) async {
        final bench = await pumpBar(tester);
        final toggle = tester.getRect(
          find.byKey(SavedTaskFiltersSheetBarKeys.pinnedOnly),
        );
        final bar = tester.getRect(
          find.byKey(SavedTaskFiltersSheetBarKeys.bar),
        );

        // Below the pill, still inside the bar.
        await tester.tapAt(Offset(toggle.center.dx, bar.bottom - 3));
        expect(bench.flips, [true]);
        expect(bar.height, greaterThanOrEqualTo(48));
      },
    );

    testWidgets("the switch starts on the sheet rows' radio column", (
      tester,
    ) async {
      await pumpBar(tester);

      final spacing = dsTokensLight.spacing;
      expect(
        tester
            .getTopLeft(find.byKey(SavedTaskFiltersSheetBarKeys.pinnedOnly))
            .dx,
        spacing.step5 + spacing.step3,
      );
    });

    testWidgets('Edit reports a toggle and reads Done while editing', (
      tester,
    ) async {
      final bench = await pumpBar(tester);
      expect(find.text('Edit'), findsOneWidget);

      await tester.tap(find.byKey(_editKey));
      expect(bench.edits, hasLength(1));

      await pumpBar(tester, editing: true);
      expect(find.text('Done'), findsOneWidget);
    });
  });

  group('SavedTaskFilterPinToggle', () {
    Future<List<void>> pumpPin(
      WidgetTester tester, {
      required bool pinned,
    }) async {
      final taps = <void>[];
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Center(
            child: SavedTaskFilterPinToggle(
              filterId: 'f1',
              filterName: 'Penguin census',
              pinned: pinned,
              onToggle: () => taps.add(null),
            ),
          ),
        ),
      );
      return taps;
    }

    Icon glyph(WidgetTester tester) => tester.widget<Icon>(
      find.descendant(
        of: find.byKey(SavedTaskFiltersSheetBarKeys.pin('f1')),
        matching: find.byType(Icon),
      ),
    );

    testWidgets('unpinned: outline glyph in medium emphasis', (tester) async {
      await pumpPin(tester, pinned: false);

      expect(glyph(tester).icon, LottiIcons.pin);
      expect(glyph(tester).color, dsTokensLight.colors.text.mediumEmphasis);
    });

    testWidgets('pinned: filled glyph in the interactive accent', (
      tester,
    ) async {
      await pumpPin(tester, pinned: true);

      expect(glyph(tester).icon, LottiIconsFilled.pin);
      expect(glyph(tester).color, dsTokensLight.colors.interactive.enabled);
    });

    testWidgets('a tap reports, on a full 48dp target', (tester) async {
      final taps = await pumpPin(tester, pinned: false);

      final target = tester.getSize(
        find.byKey(SavedTaskFiltersSheetBarKeys.pin('f1')),
      );
      expect(target.width, greaterThanOrEqualTo(48));
      expect(target.height, greaterThanOrEqualTo(48));

      await tester.tap(find.byKey(SavedTaskFiltersSheetBarKeys.pin('f1')));
      expect(taps, hasLength(1));
    });

    testWidgets('the glyphs swap through a cross-fade, not a cut', (
      tester,
    ) async {
      await pumpPin(tester, pinned: false);
      await pumpPin(tester, pinned: true);

      // Mid-swap, both glyphs are on screen, each partly faded.
      await tester.pump(SavedTaskFilterPinToggle.swapDuration ~/ 2);
      expect(find.byIcon(LottiIcons.pin), findsOneWidget);
      expect(find.byIcon(LottiIconsFilled.pin), findsOneWidget);

      await tester.pump(SavedTaskFilterPinToggle.swapDuration);
      expect(find.byIcon(LottiIcons.pin), findsNothing);
      expect(find.byIcon(LottiIconsFilled.pin), findsOneWidget);
    });

    testWidgets('names the action for a screen reader', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpPin(tester, pinned: true);

      expect(
        tester.getSemantics(find.byKey(SavedTaskFiltersSheetBarKeys.pin('f1'))),
        matchesSemantics(
          label: 'Unpin Penguin census',
          isButton: true,
          hasToggledState: true,
          isToggled: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });
  });
}
