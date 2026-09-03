import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tasks/state/task_estimate_suggestions_controller.dart';
import 'package:lotti/features/tasks/ui/header/estimate_quick_pick_chips.dart';

import '../../../../test_helper.dart';

/// Serves a fixed row of suggestions, so a test states the values it is
/// asserting about instead of standing up a database.
class _FixedSuggestions extends TaskEstimateSuggestionsController {
  _FixedSuggestions(this.values);
  final List<Duration> values;

  @override
  Future<List<Duration>> build() async => values;
}

/// Never completes: the row's loading state, held open for as long as the
/// test needs it.
class _PendingSuggestions extends TaskEstimateSuggestionsController {
  @override
  Future<List<Duration>> build() => Completer<List<Duration>>().future;
}

void main() {
  const thirtyMinutes = Duration(minutes: 30);
  const oneHour = Duration(hours: 1);
  const twoHours = Duration(hours: 2);
  const ninetyMinutes = Duration(minutes: 90);

  Future<List<Duration>> pumpChips(
    WidgetTester tester, {
    required Override override,
    Duration currentEstimate = Duration.zero,
  }) async {
    final picked = <Duration>[];
    await tester.pumpWidget(
      WidgetTestBench(
        overrides: [override],
        child: Scaffold(
          body: EstimateQuickPickChips(
            currentEstimate: currentEstimate,
            onPick: picked.add,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return picked;
  }

  Override fixed(List<Duration> values) =>
      taskEstimateSuggestionsControllerProvider.overrideWith(
        () => _FixedSuggestions(values),
      );

  DsPill pillOf(WidgetTester tester, String label) => tester.widget<DsPill>(
    find.ancestor(of: find.text(label), matching: find.byType(DsPill)),
  );

  group('rendering', () {
    testWidgets('the row names the outcome of a tap, above the chips', (
      tester,
    ) async {
      // A chip commits and closes while a Done button sits on the same
      // sheet; without this line the row reads as staging, and the users
      // most wary of an irreversible tap were the ones who avoided it.
      await pumpChips(
        tester,
        override: fixed(const [thirtyMinutes, oneHour]),
      );

      expect(find.text('Tap to save and close'), findsOneWidget);
      expect(
        tester.getRect(find.text('Tap to save and close')).bottom,
        lessThanOrEqualTo(tester.getRect(find.text('30m')).top),
        reason: 'the contract is read before the control it describes',
      );
    });

    testWidgets('the wrapped hint stays centred over the chips at 2x text', (
      tester,
    ) async {
      // At 1x the line fits and centring is invisible; at accessibility
      // sizes it wraps, and an uncentred second line sits left of the row it
      // describes. Only a scaled pump can catch that.
      await tester.pumpWidget(
        WidgetTestBench(
          overrides: [
            fixed(const [thirtyMinutes, oneHour]),
          ],
          mediaQueryData: const MediaQueryData(
            size: Size(390, 844),
            textScaler: TextScaler.linear(2),
          ),
          child: const Scaffold(
            body: EstimateQuickPickChips(
              currentEstimate: Duration.zero,
              onPick: _noop,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final hint = find.text('Tap to save and close');
      expect(
        tester.widget<Text>(hint).textAlign,
        TextAlign.center,
      );
      expect(
        tester.getSize(hint).height,
        greaterThan(tester.getSize(find.text('30m')).height),
        reason: 'the hint has actually wrapped at this scale',
      );
    });

    testWidgets('the hint stays while the ranking is still loading', (
      tester,
    ) async {
      await tester.pumpWidget(
        WidgetTestBench(
          overrides: [
            taskEstimateSuggestionsControllerProvider.overrideWith(
              _PendingSuggestions.new,
            ),
          ],
          child: const Scaffold(
            body: EstimateQuickPickChips(
              currentEstimate: Duration.zero,
              onPick: _noop,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Tap to save and close'), findsOneWidget);
    });

    testWidgets('one chip per suggestion, in the order supplied', (
      tester,
    ) async {
      await pumpChips(
        tester,
        override: fixed(const [thirtyMinutes, oneHour, twoHours]),
      );

      expect(find.byType(DsPill), findsNWidgets(3));
      final labels = tester
          .widgetList<DsPill>(find.byType(DsPill))
          .map((pill) => pill.label)
          .toList();
      expect(labels, ['30m', '1h', '2h']);
    });

    testWidgets('labels use the compact form the header reads back', (
      tester,
    ) async {
      await pumpChips(tester, override: fixed(const [ninetyMinutes]));

      // Not "1h 30m 0s", not "01:30" — the same string
      // `formatRangeDuration` gives the task header's estimate read-out.
      expect(find.text('1h 30m'), findsOneWidget);
    });

    testWidgets('no "+ Other" escape chip — the wheel is directly below', (
      tester,
    ) async {
      await pumpChips(
        tester,
        override: fixed(const [thirtyMinutes, oneHour]),
      );

      expect(find.byType(DsPill), findsNWidgets(2));
      expect(find.byIcon(LottiIcons.add), findsNothing);
    });

    testWidgets(
      'an empty ranking renders no chips rather than an empty shell',
      (tester) async {
        await pumpChips(tester, override: fixed(const []));

        expect(find.byType(DsPill), findsNothing);
      },
    );

    testWidgets(
      'while the ranking loads the row shows quiet, inert placeholders',
      (tester) async {
        await tester.pumpWidget(
          WidgetTestBench(
            overrides: [
              taskEstimateSuggestionsControllerProvider.overrideWith(
                _PendingSuggestions.new,
              ),
            ],
            child: const Scaffold(
              body: EstimateQuickPickChips(
                currentEstimate: Duration.zero,
                onPick: _noop,
              ),
            ),
          ),
        );
        await tester.pump();

        // Tokens from the tree under test, so the assertion holds in
        // whichever theme the bench resolves.
        final tokens = tester
            .element(find.byType(EstimateQuickPickChips))
            .designTokens;
        final pills = tester.widgetList<DsPill>(find.byType(DsPill)).toList();
        expect(pills, hasLength(kDefaultEstimateSuggestions.length));
        expect(
          pills.every(
            (pill) =>
                pill.variant == DsPillVariant.outline &&
                pill.color == tokens.colors.decorative.level03,
          ),
          isTrue,
          reason: 'a quiet outline, not the dashed "unset — tap me" shell',
        );
        expect(
          pills.every((pill) => pill.onTap == null),
          isTrue,
          reason: 'a placeholder tap would commit a value nobody chose',
        );
        // The row holds the real row's shape, so nothing below it jumps when
        // the ranking lands.
        expect(find.text('30m'), findsOneWidget);
        expect(find.text('4h'), findsOneWidget);
      },
    );
  });

  group('selection', () {
    testWidgets('the chip holding the current estimate reads selected', (
      tester,
    ) async {
      await pumpChips(
        tester,
        override: fixed(const [thirtyMinutes, oneHour, twoHours]),
        currentEstimate: oneHour,
      );

      expect(pillOf(tester, '1h').selected, isTrue);
      expect(pillOf(tester, '30m').selected, isFalse);
      expect(pillOf(tester, '2h').selected, isFalse);
    });

    testWidgets('selection carries no leading glyph', (tester) async {
      // An icon appearing and vanishing would shift a chip by its whole
      // width plus a gap every time the wheel moved the selection to
      // another chip. Fill, border and weight say it instead.
      await pumpChips(
        tester,
        override: fixed(const [thirtyMinutes, oneHour]),
        currentEstimate: oneHour,
      );

      expect(find.byIcon(LottiIcons.confirm), findsNothing);
      expect(pillOf(tester, '1h').leading, isNull);
      expect(pillOf(tester, '30m').leading, isNull);
    });

    testWidgets('selection follows the value on show, not a fixed one', (
      tester,
    ) async {
      // Same chips, a different `currentEstimate`: the row re-points rather
      // than staying pinned to whatever it first rendered.
      await pumpChips(
        tester,
        override: fixed(const [thirtyMinutes, oneHour, twoHours]),
        currentEstimate: twoHours,
      );

      expect(pillOf(tester, '2h').selected, isTrue);
      expect(pillOf(tester, '1h').selected, isFalse);
    });

    testWidgets('no estimate selects nothing — zero is never suggested', (
      tester,
    ) async {
      await pumpChips(
        tester,
        override: fixed(const [thirtyMinutes, oneHour]),
      );

      expect(
        tester
            .widgetList<DsPill>(find.byType(DsPill))
            .every((pill) => !pill.selected),
        isTrue,
      );
    });

    testWidgets('an off-ladder estimate selects nothing — the wheel holds it', (
      tester,
    ) async {
      await pumpChips(
        tester,
        override: fixed(const [thirtyMinutes, oneHour, twoHours]),
        currentEstimate: const Duration(minutes: 47),
      );

      expect(
        tester
            .widgetList<DsPill>(find.byType(DsPill))
            .every((pill) => !pill.selected),
        isTrue,
      );
    });
  });

  group('picking', () {
    testWidgets('a tap reports that chip’s duration', (tester) async {
      final picked = await pumpChips(
        tester,
        override: fixed(const [thirtyMinutes, oneHour, twoHours]),
      );

      await tester.tap(find.text('2h'));
      await tester.pumpAndSettle();

      expect(picked, [twoHours]);
    });

    testWidgets('tapping the already-selected chip still reports it', (
      tester,
    ) async {
      // The picker decides whether that is a no-op write; the row's job is
      // only to report the tap.
      final picked = await pumpChips(
        tester,
        override: fixed(const [thirtyMinutes, oneHour]),
        currentEstimate: oneHour,
      );

      await tester.tap(find.text('1h'));
      await tester.pumpAndSettle();

      expect(picked, [oneHour]);
    });
  });

  group('semantics', () {
    testWidgets('each chip announces the estimate its tap would set', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpChips(
        tester,
        override: fixed(const [thirtyMinutes, oneHour]),
        currentEstimate: oneHour,
      );

      expect(find.bySemanticsLabel('Set estimate to 30m'), findsOneWidget);
      expect(find.bySemanticsLabel('Set estimate to 1h'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('the chip is activatable from a screen reader', (
      tester,
    ) async {
      // `excludeSemantics` drops the InkWell's own tap action, so the node
      // has to carry it — otherwise the whole point of the row is
      // unreachable without sighted pointing. `semantics.tap` throws when
      // the node does not advertise the action, so this asserts both that
      // the action exists and that performing it picks.
      final handle = tester.ensureSemantics();
      final picked = await pumpChips(
        tester,
        override: fixed(const [thirtyMinutes, oneHour]),
      );

      tester.semantics.tap(find.semantics.byLabel('Set estimate to 30m'));
      await tester.pumpAndSettle();

      expect(picked, [thirtyMinutes]);
      handle.dispose();
    });

    testWidgets('the current estimate is announced as selected', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpChips(
        tester,
        override: fixed(const [thirtyMinutes, oneHour]),
        currentEstimate: oneHour,
      );

      expect(
        tester.getSemantics(find.bySemanticsLabel('Set estimate to 1h')),
        matchesSemantics(
          label: 'Set estimate to 1h',
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Set estimate to 30m')),
        matchesSemantics(
          label: 'Set estimate to 30m',
          isButton: true,
          // Selectable, but not selected — the distinction a screen reader
          // needs to say which value the task currently holds.
          hasSelectedState: true,
          hasTapAction: true,
        ),
        reason: 'only the current estimate announces as selected',
      );
      handle.dispose();
    });
  });
}

void _noop(Duration _) {}
