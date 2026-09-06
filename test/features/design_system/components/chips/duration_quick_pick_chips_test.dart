import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/components/chips/duration_quick_pick_chips.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../test_helper.dart';

void main() {
  const five = Duration(minutes: 5);
  const fifteen = Duration(minutes: 15);
  const hour = Duration(hours: 1);

  String label(Duration duration) => '${duration.inMinutes} min';

  Future<List<Duration>> pump(
    WidgetTester tester, {
    required List<Duration>? suggestions,
    List<Duration> placeholder = const [five, fifteen],
    Duration current = Duration.zero,
  }) async {
    final picked = <Duration>[];
    await tester.pumpWidget(
      WidgetTestBench(
        child: Scaffold(
          body: DurationQuickPickChips(
            suggestions: suggestions,
            placeholder: placeholder,
            current: current,
            onPick: picked.add,
            hint: 'Tap to pick',
            labelOf: label,
            semanticsLabelOf: (label) => 'Pick $label',
            keyPrefix: 'pick',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return picked;
  }

  DsPill pillOf(WidgetTester tester, String label) => tester.widget<DsPill>(
    find.ancestor(of: find.text(label), matching: find.byType(DsPill)),
  );

  testWidgets('one live chip per suggestion, keyed by its minutes, under the '
      'hint', (tester) async {
    await pump(tester, suggestions: const [five, fifteen, hour]);

    expect(find.byKey(const ValueKey('pick-5')), findsOneWidget);
    expect(find.byKey(const ValueKey('pick-15')), findsOneWidget);
    expect(find.byKey(const ValueKey('pick-60')), findsOneWidget);
    expect(find.byType(DsPill), findsNWidgets(3));
    expect(
      tester.getRect(find.text('Tap to pick')).bottom,
      lessThanOrEqualTo(tester.getRect(find.text('5 min')).top),
      reason: 'the contract is read before the control it describes',
    );
  });

  testWidgets('the chip matching the current value reads selected, the rest '
      'do not', (tester) async {
    await pump(tester, suggestions: const [five, fifteen], current: fifteen);

    expect(pillOf(tester, '15 min').selected, isTrue);
    expect(pillOf(tester, '5 min').selected, isFalse);
  });

  testWidgets('a value off the row selects nothing', (tester) async {
    await pump(
      tester,
      suggestions: const [five, fifteen],
      current: const Duration(minutes: 47),
    );

    expect(pillOf(tester, '5 min').selected, isFalse);
    expect(pillOf(tester, '15 min').selected, isFalse);
  });

  testWidgets('tapping a chip reports that duration, once', (tester) async {
    final picked = await pump(tester, suggestions: const [five, fifteen]);

    await tester.tap(find.byKey(const ValueKey('pick-15')));
    await tester.pumpAndSettle();

    expect(picked, const [fifteen]);
  });

  testWidgets('a live chip is a button whose semantics carry the host label', (
    tester,
  ) async {
    await pump(tester, suggestions: const [five], current: five);

    final semantics = tester.getSemantics(
      find.byKey(const ValueKey('pick-5')),
    );
    expect(semantics.label, 'Pick 5 min');
    expect(semantics.flagsCollection.isButton, isTrue);
    expect(semantics.flagsCollection.isSelected, Tristate.isTrue);
  });

  testWidgets('while the ranking loads, the placeholder holds the row as '
      'inert outlines', (tester) async {
    final picked = await pump(tester, suggestions: null);

    expect(find.byKey(const ValueKey('pick-placeholder-5')), findsOneWidget);
    expect(find.byKey(const ValueKey('pick-placeholder-15')), findsOneWidget);
    expect(find.byKey(const ValueKey('pick-5')), findsNothing);
    expect(find.text('Tap to pick'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('pick-placeholder-5')));
    await tester.pumpAndSettle();
    expect(picked, isEmpty, reason: 'a placeholder is not a control');
    expect(pillOf(tester, '5 min').onTap, isNull);
  });

  testWidgets('the wrapped hint stays centred over the chips at 2x text', (
    tester,
  ) async {
    await tester.pumpWidget(
      WidgetTestBench(
        mediaQueryData: const MediaQueryData(
          size: Size(390, 844),
          textScaler: TextScaler.linear(2),
        ),
        child: Scaffold(
          body: DurationQuickPickChips(
            suggestions: const [five, fifteen],
            placeholder: const [],
            current: Duration.zero,
            onPick: (_) {},
            hint: 'Tap a length to save it and close this sheet',
            labelOf: label,
            semanticsLabelOf: (label) => label,
            keyPrefix: 'pick',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final hint = find.text('Tap a length to save it and close this sheet');
    expect(tester.widget<Text>(hint).textAlign, TextAlign.center);
    expect(
      tester.getSize(hint).height,
      greaterThan(tester.getSize(find.text('5 min')).height),
      reason: 'the hint has actually wrapped at this scale',
    );
    expect(find.byType(Wrap), findsOneWidget);
  });
}
