import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/relationships/state/check_in_duration_suggestions_controller.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_duration_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../test_helper.dart';

/// Serves a fixed ranking, so a test states the lengths it asserts about
/// instead of standing up a database.
class _FixedSuggestions extends CheckInDurationSuggestionsController {
  _FixedSuggestions(this.values);
  final List<Duration> values;

  @override
  Future<List<Duration>> build() async => values;
}

/// Never completes: the row's loading state, held open as long as needed.
class _PendingSuggestions extends CheckInDurationSuggestionsController {
  @override
  Future<List<Duration>> build() => Completer<List<Duration>>().future;
}

void main() {
  const eleven = Duration(minutes: 11);
  const thirty = Duration(minutes: 30);
  const ninety = Duration(minutes: 90);

  Override fixed(List<Duration> values) =>
      checkInDurationSuggestionsControllerProvider.overrideWith(
        () => _FixedSuggestions(values),
      );

  DsPill pillOf(WidgetTester tester, String label) => tester.widget<DsPill>(
    find.ancestor(of: find.text(label), matching: find.byType(DsPill)),
  );

  group('checkInDurationLabel', () {
    testWidgets('zero reads as "No duration", the wheel\'s none position', (
      tester,
    ) async {
      late String zero;
      late String eleventh;
      late String hourAndHalf;
      await tester.pumpWidget(
        WidgetTestBench(
          child: Builder(
            builder: (context) {
              zero = checkInDurationLabel(context, Duration.zero);
              eleventh = checkInDurationLabel(context, eleven);
              hourAndHalf = checkInDurationLabel(context, ninety);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(zero, 'No duration');
      expect(eleventh, '11 min');
      expect(hourAndHalf, '1 h 30');
    });
  });

  group('CheckInDurationQuickPickChips', () {
    testWidgets('renders the ranked lengths as chips, the current one '
        'selected, and reports a tap', (tester) async {
      final picked = <Duration>[];
      await tester.pumpWidget(
        WidgetTestBench(
          overrides: [
            fixed(const [eleven, thirty, ninety]),
          ],
          child: Scaffold(
            body: CheckInDurationQuickPickChips(
              current: thirty,
              onPick: picked.add,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Tap a length to save it, or spin the wheel.'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('check-in-duration-pick-11')),
        findsOneWidget,
      );
      expect(pillOf(tester, '30 min').selected, isTrue);
      expect(pillOf(tester, '1 h 30').selected, isFalse);

      await tester.tap(find.byKey(const ValueKey('check-in-duration-pick-90')));
      await tester.pumpAndSettle();
      expect(picked, const [ninety]);
    });

    testWidgets("while the ranking loads, the design's first positions hold "
        'the row', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          overrides: [
            checkInDurationSuggestionsControllerProvider.overrideWith(
              _PendingSuggestions.new,
            ),
          ],
          child: Scaffold(
            body: CheckInDurationQuickPickChips(
              current: Duration.zero,
              onPick: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      for (final position in kCheckInDurationPositions.take(
        kCheckInDurationSuggestionCount,
      )) {
        expect(
          find.byKey(
            ValueKey(
              'check-in-duration-pick-placeholder-${position.inMinutes}',
            ),
          ),
          findsOneWidget,
        );
      }
      expect(
        find.byKey(const ValueKey('check-in-duration-pick-5')),
        findsNothing,
      );
    });
  });

  group('showCheckInDurationPicker', () {
    Future<Future<Duration?>> open(
      WidgetTester tester, {
      required Duration initial,
    }) async {
      final chosen = Completer<Duration?>();
      await tester.pumpWidget(
        WidgetTestBench(
          overrides: [
            fixed(const [eleven, thirty, ninety]),
          ],
          child: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async => chosen.complete(
                    await showCheckInDurationPicker(
                      context: context,
                      initialDuration: initial,
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return chosen.future;
    }

    testWidgets('titles the sheet Duration and opens the wheel on the initial '
        'length', (tester) async {
      await open(tester, initial: thirty);

      expect(find.text('Duration'), findsOneWidget);
      expect(
        tester
            .widget<CupertinoTimerPicker>(find.byType(CupertinoTimerPicker))
            .initialTimerDuration,
        thirty,
      );
      expect(pillOf(tester, '30 min').selected, isTrue);
    });

    testWidgets('a chip tap resolves to that length', (tester) async {
      final chosen = await open(tester, initial: thirty);

      await tester.tap(find.byKey(const ValueKey('check-in-duration-pick-90')));
      await tester.pumpAndSettle();

      expect(await chosen, ninety);
      expect(find.byType(CupertinoTimerPicker), findsNothing);
    });

    testWidgets('Done on an untouched wheel resolves to null — nothing '
        'changed', (tester) async {
      final chosen = await open(tester, initial: thirty);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(await chosen, isNull);
    });

    testWidgets(
      'Clear resolves to zero, which the label reads as No duration',
      (tester) async {
        final chosen = await open(tester, initial: thirty);

        await tester.tap(find.text('Clear'));
        await tester.pumpAndSettle();

        expect(await chosen, Duration.zero);
      },
    );

    testWidgets('the wheel announces its draft as "Duration: <label>"', (
      tester,
    ) async {
      await open(tester, initial: thirty);

      expect(find.bySemanticsLabel(RegExp('Duration: 30 min')), findsOneWidget);

      tester
          .widget<CupertinoTimerPicker>(find.byType(CupertinoTimerPicker))
          .onTimerDurationChanged(Duration.zero);
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel(RegExp('Duration: No duration')),
        findsOneWidget,
      );
    });
  });
}
